// Architecture: Tom Dyer. Code: ChatGPT (GPT-6).
// Native-independent model; it contains NO WinUI, HWND or ooRexx objects.
#pragma once

#include <cstdint>
#include <deque>
#include <map>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <unordered_set>

namespace oodfluent {

enum class ErrorCode {
    InvalidCatalogue, UnknownControl, ExperimentalDisabled, InvalidProperty,
    InvalidEvent, InvalidHandler, StaleOccurrence
};

class Error final : public std::runtime_error {
public:
    Error(ErrorCode code, const std::string &message);
    ErrorCode code() const noexcept { return code_; }
private:
    ErrorCode code_;
};

struct Spec {
    std::string name;
    std::string group;
    std::string availability;
    std::string renderer;
    std::string legacy;
    std::unordered_set<std::string> properties;
    std::unordered_set<std::string> events;
};

class Catalogue final {
public:
    static Catalogue fromTsv(const std::string &path);
    const Spec &type(const std::string &name) const;
    std::size_t size() const noexcept { return types_.size(); }
private:
    std::unordered_map<std::string, Spec> types_;
};

// An occurrence is not an HWND. resourceId may be repeated (e.g. IDC_STATIC).
struct Control {
    std::uint64_t uid;
    std::int64_t resourceId;
    std::string type;
    std::uint64_t revision;
    std::map<std::string, std::string> properties;
    std::map<std::string, std::string> bindings;
};

struct Event {
    std::int64_t resourceId;
    std::uint64_t uid;
    std::string name;
    std::string value;
    std::string handler;
    std::uint64_t revision;
};

class Session final {
public:
    explicit Session(const Catalogue &catalogue, bool enableExperimental = false);
    std::uint64_t create(std::int64_t resourceId, const std::string &type);
    void set(std::uint64_t uid, const std::string &property, const std::string &value);
    void bind(std::uint64_t uid, const std::string &event, const std::string &handler);
    bool raise(std::uint64_t uid, const std::string &event, const std::string &value);
    bool take(Event &out);
    void remove(std::uint64_t uid);
    void clear() noexcept;
    const Control &control(std::uint64_t uid) const;
    std::size_t size() const noexcept { return controls_.size(); }
    std::size_t pending() const noexcept { return events_.size(); }
private:
    const Catalogue &catalogue_;
    bool experimental_;
    std::uint64_t nextUid_ = 1;
    std::unordered_map<std::uint64_t, Control> controls_;
    std::deque<Event> events_;
};

} // namespace oodfluent
