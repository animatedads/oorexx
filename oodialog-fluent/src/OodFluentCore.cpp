// Architecture: Tom Dyer. Code: ChatGPT (GPT-6).
#include "OodFluentCore.hpp"

#include <algorithm>
#include <fstream>
#include <limits>
#include <sstream>
#include <vector>

namespace oodfluent {

Error::Error(ErrorCode code, const std::string &message)
    : std::runtime_error(message), code_(code) {}

namespace {

std::vector<std::string> split(const std::string &text, char separator) {
    std::vector<std::string> result;
    std::size_t start = 0;
    while (true) {
        const auto end = text.find(separator, start);
        result.push_back(text.substr(start, end == std::string::npos ? end : end - start));
        if (end == std::string::npos) break;
        start = end + 1;
    }
    return result;
}

std::unordered_set<std::string> names(const std::string &field, std::size_t line) {
    std::unordered_set<std::string> result;
    if (field == "-") return result;
    for (const auto &name : split(field, ',')) {
        if (name.empty() || name == "-" || !result.insert(name).second)
            throw Error(ErrorCode::InvalidCatalogue, "invalid or duplicate property/event on line " + std::to_string(line));
    }
    return result;
}

bool contains(const std::string &item, const std::initializer_list<const char *> &allowed) {
    for (const auto *option : allowed) if (item == option) return true;
    return false;
}

bool commonProperty(const std::string &name) {
    return contains(name, {"enabled", "visible", "automationName", "tabIndex", "helpText"});
}

} // namespace

Catalogue Catalogue::fromTsv(const std::string &path) {
    std::ifstream file(path);
    if (!file) throw Error(ErrorCode::InvalidCatalogue, "cannot open catalogue: " + path);
    Catalogue out;
    std::string row;
    std::size_t line = 0;
    while (std::getline(file, row)) {
        ++line;
        if (!row.empty() && row.back() == '\r') row.pop_back();
        if (line == 1) {
            if (row != "name\tgroup\tavailability\trenderer\tlegacy\tproperties\tevents")
                throw Error(ErrorCode::InvalidCatalogue, "catalogue header does not match version 1");
            continue;
        }
        if (row.empty()) continue;
        auto fields = split(row, '\t');
        if (fields.size() != 7)
            throw Error(ErrorCode::InvalidCatalogue, "expected 7 fields on line " + std::to_string(line));
        for (const auto &field : fields)
            if (field.empty()) throw Error(ErrorCode::InvalidCatalogue, "empty field on line " + std::to_string(line));
        if (!contains(fields[2], {"stable", "experimental", "optional"}) ||
            !contains(fields[3], {"winui3", "webview2", "composition", "win32", "pattern"}))
            throw Error(ErrorCode::InvalidCatalogue, "unknown availability/renderer on line " + std::to_string(line));
        Spec spec{fields[0], fields[1], fields[2], fields[3], fields[4],
                  names(fields[5], line), names(fields[6], line)};
        if (!out.types_.emplace(spec.name, spec).second)
            throw Error(ErrorCode::InvalidCatalogue, "duplicate control name: " + fields[0]);
    }
    if (line == 0 || out.types_.empty())
        throw Error(ErrorCode::InvalidCatalogue, "catalogue has no controls");
    return out;
}

const Spec &Catalogue::type(const std::string &name) const {
    auto it = types_.find(name);
    if (it == types_.end()) throw Error(ErrorCode::UnknownControl, "unknown control: " + name);
    return it->second;
}

Session::Session(const Catalogue &catalogue, bool enableExperimental)
    : catalogue_(catalogue), experimental_(enableExperimental) {}

std::uint64_t Session::create(std::int64_t resourceId, const std::string &type) {
    if (nextUid_ == std::numeric_limits<std::uint64_t>::max())
        throw Error(ErrorCode::StaleOccurrence, "occurrence UID exhausted");
    const std::uint64_t uid = registerControl(resourceId, type, nextUid_);
    ++nextUid_;
    return uid;
}

std::uint64_t Session::createWithUid(std::int64_t resourceId, const std::string &type,
                                     std::uint64_t authoredUid) {
    if (authoredUid == 0 || authoredUid >= AutomaticUidBase)
        throw Error(ErrorCode::StaleOccurrence, "authored occurrence UID outside reserved range [1, 2^63)");
    return registerControl(resourceId, type, authoredUid);
}

std::uint64_t Session::registerControl(std::int64_t resourceId, const std::string &type,
                                      std::uint64_t uid) {
    const auto &spec = catalogue_.type(type);
    if (spec.availability != "stable" && !experimental_)
        throw Error(ErrorCode::ExperimentalDisabled, "control requires an optional capability: " + type);
    if (!uid || !issuedUids_.insert(uid).second)
        throw Error(ErrorCode::StaleOccurrence, "zero or previously used occurrence UID: " + std::to_string(uid));
    controls_.emplace(uid, Control{uid, resourceId, type, 0, {}, {}});
    return uid;
}

const Control &Session::control(std::uint64_t uid) const {
    const auto it = controls_.find(uid);
    if (it == controls_.end())
        throw Error(ErrorCode::StaleOccurrence, "unknown/stale control occurrence: " + std::to_string(uid));
    return it->second;
}

void Session::set(std::uint64_t uid, const std::string &property, const std::string &value) {
    const auto &current = control(uid);
    const auto &spec = catalogue_.type(current.type);
    if (!commonProperty(property) && !spec.properties.count(property))
        throw Error(ErrorCode::InvalidProperty, "property " + property + " unsupported by " + current.type);
    auto &item = controls_.at(uid);
    auto existing = item.properties.find(property);
    if (existing != item.properties.end() && existing->second == value) return;
    item.properties[property] = value;
    ++item.revision;
}

void Session::bind(std::uint64_t uid, const std::string &event, const std::string &handler) {
    const auto &current = control(uid);
    const auto &spec = catalogue_.type(current.type);
    if (!spec.events.count(event))
        throw Error(ErrorCode::InvalidEvent, "event " + event + " unsupported by " + current.type);
    if (handler.empty())
        throw Error(ErrorCode::InvalidHandler, "handler name cannot be empty");
    controls_.at(uid).bindings[event] = handler;
}

bool Session::raise(std::uint64_t uid, const std::string &event, const std::string &value) {
    const auto &item = control(uid);
    const auto &spec = catalogue_.type(item.type);
    if (!spec.events.count(event))
        throw Error(ErrorCode::InvalidEvent, "event " + event + " unsupported by " + item.type);
    auto handler = item.bindings.find(event);
    if (handler == item.bindings.end()) return false;
    events_.push_back(Event{item.resourceId, uid, event, value, handler->second, item.revision});
    return true;
}

bool Session::take(Event &out) {
    while (!events_.empty()) {
        Event event = std::move(events_.front());
        events_.pop_front();
        if (controls_.find(event.uid) == controls_.end()) continue;
        out = std::move(event);
        return true;
    }
    return false;
}

void Session::remove(std::uint64_t uid) {
    (void)control(uid);
    controls_.erase(uid);
    events_.erase(std::remove_if(events_.begin(), events_.end(),
                                 [uid](const Event &event) { return event.uid == uid; }), events_.end());
}

void Session::clear() noexcept {
    controls_.clear();
    events_.clear();
}

} // namespace oodfluent
