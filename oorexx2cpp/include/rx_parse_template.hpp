#ifndef RX_PARSE_TEMPLATE_HPP
#define RX_PARSE_TEMPLATE_HPP
// Included inside rx after Value. This is a language implementation, not BIF.
// All positions are ooRexx's 1-based positions. Parsing is binary-safe.
// PARSE works on the string value of its source: an object is asked MAKESTRING, then STRING (the interpreter's
// REQUEST('STRING') order, verified against ooRexx 5.3.0: toString is ignored). USE ARG keeps the object itself.
inline Value parseSourceString(const Value &source) {
    if (!source.isObject()) return source;
    MessageResult r;
    try { r = source.object->sendMessage("MAKESTRING", {}); }
    catch (const NoMethod &) { r = source.object->sendMessage("STRING", {}); }
    if (!r || r->isObject()) throw std::runtime_error("PARSE source: string conversion did not return a string");
    return *r;
}
inline std::vector<Value> parseBlankTemplate(const Value &sourceIn, std::size_t count) {
    if (count == 0) throw std::runtime_error("empty PARSE template");
    const Value source = parseSourceString(sourceIn);
    std::vector<Value> parts;
    parts.reserve(count);
    const std::string &s = source.bytes;
    std::size_t cursor = 0;
    auto blank = [](char c) { return c == ' ' || c == '\t'; };
    for (std::size_t i = 0; i < count; ++i) {
        if (i + 1 == count) {
            parts.emplace_back(Value::string(s.substr(cursor)));
            break;
        }
        while (cursor < s.size() && blank(s[cursor])) ++cursor;
        const std::size_t first = cursor;
        while (cursor < s.size() && !blank(s[cursor])) ++cursor;
        parts.emplace_back(Value::string(s.substr(first, cursor - first)));
        if (cursor < s.size()) ++cursor;
    }
    return parts;
}

struct ParseOp {
    enum class Kind { Target, Absolute, Relative, Literal } kind;
    std::int64_t position = 0;
    std::string delimiter;
    static ParseOp target() { return {Kind::Target, 0, {}}; }
    static ParseOp absolute(std::int64_t n) { return {Kind::Absolute, n, {}}; }
    static ParseOp relative(std::int64_t n) { return {Kind::Relative, n, {}}; }
    static ParseOp literal(std::string s) { return {Kind::Literal, 0, std::move(s)}; }
    static ParseOp literalValue(const Value &v) {
        if (v.isObject()) throw std::runtime_error("PARSE object delimiter conversion unsupported");
        if (v.bytes.empty()) throw std::runtime_error("empty dynamic PARSE delimiter unsupported");
        return literal(v.bytes);
    }
};

inline std::vector<Value> parseTemplate(const Value &sourceIn, const std::vector<ParseOp> &ops) {
    const Value source = parseSourceString(sourceIn);
    if (ops.empty() || ops.size() > 64) throw std::runtime_error("invalid PARSE template size");
    const std::string &s = source.bytes;
    std::vector<Value> values;
    std::size_t cursor = 0;
    std::size_t pending = 0;
    // Saturated 1-based ooRexx position, clipped to [1, len+1].
    auto clip = [&s](std::int64_t p) -> std::size_t {
        if (p <= 1) return 0;
        const auto bound = static_cast<std::uint64_t>(s.size());
        const auto n = static_cast<std::uint64_t>(p - 1);
        return n > bound ? s.size() : static_cast<std::size_t>(n);
    };
    auto flush = [&](const std::string &segment) {
        if (!pending) return;
        auto parts = parseBlankTemplate(Value::string(segment), pending);
        values.insert(values.end(), parts.begin(), parts.end());
        pending = 0;
    };
    for (const ParseOp &op : ops) {
        if (op.kind == ParseOp::Kind::Target) { ++pending; continue; }
        std::size_t boundary = cursor, next = cursor;
        if (op.kind == ParseOp::Kind::Absolute) {
            boundary = next = clip(op.position);
        } else if (op.kind == ParseOp::Kind::Relative) {
            // Clamp without signed overflow for a (bounded) source string.
            if (op.position < 0) {
                const auto n = static_cast<std::uint64_t>(-(op.position + 1)) + 1;
                next = n >= cursor ? 0 : cursor - static_cast<std::size_t>(n);
            } else {
                const auto n = static_cast<std::uint64_t>(op.position);
                next = n >= s.size() - cursor ? s.size() : cursor + static_cast<std::size_t>(n);
            }
            boundary = next;
        } else {
            if (op.delimiter.empty()) throw std::runtime_error("empty PARSE delimiter");
            const auto found = s.find(op.delimiter, cursor);
            boundary = found == std::string::npos ? s.size() : found;
            next = found == std::string::npos ? s.size() : found + op.delimiter.size();
        }
        // An anchor behind the cursor gives the preceding target the remaining
        // source; the next target starts at the newly selected backward anchor.
        flush(boundary <= cursor ? s.substr(cursor) : s.substr(cursor, boundary - cursor));
        cursor = next;
    }
    flush(s.substr(cursor));
    if (values.empty()) throw std::runtime_error("PARSE requires a target");
    return values;
}
#endif
