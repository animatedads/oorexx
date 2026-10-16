#ifndef RX_PARSE_TEMPLATE_HPP
#define RX_PARSE_TEMPLATE_HPP
// Included inside rx after Value. This is a language implementation, not BIF.
// All positions are ooRexx's 1-based positions. Parsing is binary-safe.
// PARSE works on the string value of its source: an object is asked MAKESTRING, then STRING (the interpreter's
// REQUEST('STRING') order, verified against ooRexx 5.3.0: toString is ignored). USE ARG keeps the object itself.
inline Value parseSourceString(const Value &source);
// (a string source is the source itself, moved)
inline Value parseSourceString(Value &&source) {
    if (!source.isObject()) return std::move(source);
    return parseSourceString(static_cast<const Value &>(source));
}
inline Value parseSourceString(const Value &source) {
    if (!source.isObject()) return source;
    MessageResult r;
    if (source.object->noMakeString()) r = source.object->sendMessage("STRING", {});   // a Stem
    else {
        try { r = source.object->sendMessage("MAKESTRING", {}); }
        catch (const NoMethod &) { r = source.object->sendMessage("STRING", {}); }
    }
    if (!r || r->isObject()) throw std::runtime_error("PARSE source: string conversion did not return a string");
    return *r;
}
// Word-split one segment into `count` targets, appending to `parts` (no intermediate copies).
inline void parseBlankSegment(const char *s, std::size_t size, std::size_t count, std::vector<Value> &parts) {
    std::size_t cursor = 0;
    auto blank = [](char c) { return c == ' ' || c == '\t'; };
    for (std::size_t i = 0; i < count; ++i) {
        if (i + 1 == count) {
            parts.emplace_back(std::string(s + cursor, size - cursor));
            break;
        }
        while (cursor < size && blank(s[cursor])) ++cursor;
        const std::size_t first = cursor;
        while (cursor < size && !blank(s[cursor])) ++cursor;
        parts.emplace_back(std::string(s + first, cursor - first));
        if (cursor < size) ++cursor;
    }
}
inline std::vector<Value> parseBlankTemplate(const Value &sourceIn, std::size_t count) {
    if (count == 0) throw std::runtime_error("empty PARSE template");
    std::vector<Value> parts;
    parts.reserve(count);
    if (!sourceIn.isObject()) { parseBlankSegment(sourceIn.bytes.data(), sourceIn.bytes.size(), count, parts); return parts; }
    const Value source = parseSourceString(sourceIn);
    parseBlankSegment(source.bytes.data(), source.bytes.size(), count, parts);
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
    static ParseOp absoluteValue(const Value &v) {
        if (v.isObject()) throw std::runtime_error("PARSE position must be a whole number");
        std::size_t b = v.bytes.find_first_not_of(' '), e = v.bytes.find_last_not_of(' ');
        std::string t = b == std::string::npos ? std::string() : v.bytes.substr(b, e - b + 1);
        if (t.empty() || t.size() > 18 || t.find_first_not_of("0123456789") != std::string::npos)
            throw std::runtime_error("PARSE position must be a whole number");
        return absolute(std::stoll(t));
    }
    // +(expr) / -(expr): a relative position computed at run time (a whole number).
    static ParseOp relativeValue(const Value &v, bool negative) {
        if (v.isObject()) throw std::runtime_error("PARSE position must be a whole number");
        std::size_t b = v.bytes.find_first_not_of(' '), e = v.bytes.find_last_not_of(' ');
        std::string t = b == std::string::npos ? std::string() : v.bytes.substr(b, e - b + 1);
        bool neg = negative;
        if (!t.empty() && (t[0] == '-' || t[0] == '+')) { if (t[0] == '-') neg = !neg; t.erase(0, 1); }
        if (t.empty() || t.size() > 18 || t.find_first_not_of("0123456789") != std::string::npos)
            throw std::runtime_error("PARSE position must be a whole number");
        const std::int64_t n = std::stoll(t);
        return relative(neg ? -n : n);
    }
    static ParseOp literalValue(const Value &v) {
        if (v.isObject()) throw std::runtime_error("PARSE object delimiter conversion unsupported");
        if (v.bytes.empty()) throw std::runtime_error("empty dynamic PARSE delimiter unsupported");
        return literal(v.bytes);
    }
};

// PARSE CASELESS: a string pattern matches regardless of case (ASCII letters, as the interpreter's caseless search).
inline std::size_t parseFindCaseless(const std::string &s, const std::string &needle, std::size_t from) {
    auto up = [](char c) { return static_cast<char>(std::toupper(static_cast<unsigned char>(c))); };
    if (needle.size() > s.size()) return std::string::npos;
    for (std::size_t i = from; i + needle.size() <= s.size(); ++i) {
        std::size_t k = 0;
        while (k < needle.size() && up(s[i + k]) == up(needle[k])) ++k;
        if (k == needle.size()) return i;
    }
    return std::string::npos;
}
inline std::vector<Value> parseTemplate(const Value &sourceIn, const std::vector<ParseOp> &ops, bool caseless = false) {
    std::optional<Value> converted;
    if (sourceIn.isObject()) converted = parseSourceString(sourceIn);
    const std::string &s = converted ? converted->bytes : sourceIn.bytes;
    if (ops.size() > 64) throw std::runtime_error("invalid PARSE template size");
    if (ops.empty()) return {};   // an empty template (PULL alone): the source is read and discarded
    std::vector<Value> values;
    values.reserve(ops.size());
    std::size_t cursor = 0;
    // A relative position counts from where the previous pattern matched: the START of a string pattern's match
    // (parse value 'abcdef' with 'c' x +2 y: x = 'cd'), otherwise the previous position.
    std::size_t anchor = 0;
    std::size_t pending = 0;
    // Saturated 1-based ooRexx position, clipped to [1, len+1].
    auto clip = [&s](std::int64_t p) -> std::size_t {
        if (p <= 1) return 0;
        const auto bound = static_cast<std::uint64_t>(s.size());
        const auto n = static_cast<std::uint64_t>(p - 1);
        return n > bound ? s.size() : static_cast<std::size_t>(n);
    };
    auto flush = [&](std::size_t from, std::size_t len) {
        if (!pending) return;
        parseBlankSegment(s.data() + from, len, pending, values);
        pending = 0;
    };
    for (const ParseOp &op : ops) {
        if (op.kind == ParseOp::Kind::Target) { ++pending; continue; }
        std::size_t boundary = cursor, next = cursor;
        if (op.kind == ParseOp::Kind::Absolute) {
            boundary = next = clip(op.position);
        } else if (op.kind == ParseOp::Kind::Relative) {
            // After a string pattern, the data before a relative position starts at the start of that string's match.
            cursor = anchor;
            // Clamp without signed overflow for a (bounded) source string.
            if (op.position < 0) {
                const auto n = static_cast<std::uint64_t>(-(op.position + 1)) + 1;
                next = n >= anchor ? 0 : anchor - static_cast<std::size_t>(n);
            } else {
                const auto n = static_cast<std::uint64_t>(op.position);
                next = n >= s.size() - anchor ? s.size() : anchor + static_cast<std::size_t>(n);
            }
            boundary = next;
        } else {
            // a null string pattern matches at the end of the source
            const auto found = op.delimiter.empty() ? s.size()
                             : caseless ? parseFindCaseless(s, op.delimiter, cursor) : s.find(op.delimiter, cursor);
            boundary = found == std::string::npos ? s.size() : found;
            next = found == std::string::npos ? s.size() : found + op.delimiter.size();
        }
        const std::size_t matchStart = boundary;
        // A positional pattern at or behind the cursor gives the preceding target the remaining
        // source; the next target starts at the newly selected backward anchor. A string pattern
        // is never behind: found at the cursor it delimits an empty field ('a::b' with ':' ':').
        if (op.kind == ParseOp::Kind::Literal) flush(cursor, boundary - cursor);
        else flush(cursor, boundary <= cursor ? s.size() - cursor : boundary - cursor);
        cursor = next;
        anchor = op.kind == ParseOp::Kind::Literal ? matchStart : next;
    }
    flush(cursor, s.size() - cursor);
    if (values.empty()) throw std::runtime_error("PARSE requires a target");
    return values;
}
// PARSE as the interpreter runs it (RexxInstructionParse::execute, ParseTrigger::parse, RexxTarget): each trigger of the
// template moves the cursor, then assigns the variables written before it (all but the last get a blank-delimited
// word, the last the remainder). Compiled as a sequence of calls on a ParseCursor, so a trigger's expression is
// evaluated when the trigger runs, after the variables before it are assigned (len +2 val >(len)).
struct ParseCursor {
    Value holder = Value::string(std::string());
    const std::string *str = nullptr;
    std::size_t start = 0, end = 0, patternStart = 0, patternEnd = 0, subcurrent = 0, length = 0;
    bool caseless = false;
    explicit ParseCursor(Value source, bool caselessSearch = false) : holder(parseSourceString(std::move(source))), caseless(caselessSearch) { bind(); }
    ParseCursor(const ParseCursor &) = delete;
    ParseCursor &operator=(const ParseCursor &) = delete;
    // RexxTarget::next: a new string (the first, or the next one after a comma in the template)
    void reset(const Value &source) {
        holder = parseSourceString(source);
        bind();
    }
    void bind() {
        str = &holder.bytes.str();
        start = end = patternStart = patternEnd = subcurrent = 0;
        length = str->size();
    }
    // ParseTrigger::integerTrigger: requestUnsignedNumber under DIGITS, else 26.4
    static std::size_t position(const Value &v, const ActivationNumeric &numeric) {
        auto bad = [&]() {
            const std::string found = v.isObject() ? v.object->display() : v.bytes.str();
            SyntaxCondition e("26.4", "Positional pattern of PARSE template must be a whole number; found \"" + found + "\"", false);
            e.substitutions.push_back(v);
            throw e;
        };
        if (v.isObject()) bad();
        RexxDecimal d; const char *err = nullptr;
        if (!tryParseRexxDecimal(v, d, err)) bad();
        std::int64_t n = 0;
        if (!oorexxWholeNumber(d, static_cast<long>(numeric.digits), false, n) || n < 0) bad();
        return static_cast<std::size_t>(n);
    }
    void toEnd() { start = patternEnd; patternEnd = length; patternStart = length; end = length; subcurrent = start; }
    void forward(std::size_t offset) {
        start = patternStart;
        end = offset >= length - start ? length : start + offset;
        if (end <= start) { end = length; patternStart = start; }
        else patternStart = end;
        patternEnd = patternStart;
        subcurrent = start;
    }
    void forwardLength(std::size_t offset) {
        start = patternStart;
        end = offset >= length - start ? length : start + offset;
        patternStart = end;
        patternEnd = patternStart;
        subcurrent = start;
    }
    void absolute(std::size_t offset) {
        if (offset > 0) --offset;
        start = patternEnd;
        if (offset <= start) { end = length; patternStart = offset; }
        else { end = offset >= length ? length : offset; patternStart = end; }
        patternEnd = patternStart;
        subcurrent = start;
    }
    void backward(std::size_t offset) {
        start = patternStart;
        end = length;
        patternStart = offset > patternStart ? 0 : patternStart - offset;
        patternEnd = patternStart;
        subcurrent = start;
    }
    void backwardLength(std::size_t offset) {
        start = offset > patternStart ? 0 : patternStart - offset;
        end = patternStart;
        patternStart = start;
        patternEnd = patternStart;
        subcurrent = start;
    }
    // RexxTarget::search / caselessSearch (RexxString::pos: a null needle is never found)
    void search(const Value &pattern) {
        Value converted = Value::string(std::string());
        const std::string &needle = (pattern.isObject() ? (converted = parseSourceString(pattern)) : pattern).bytes.str();
        start = patternEnd;
        std::size_t found = std::string::npos;
        if (!needle.empty() && start <= length)
            found = caseless ? parseFindCaseless(*str, needle, start) : str->find(needle, start);
        if (found == std::string::npos) { end = length; patternStart = length; patternEnd = length; }
        else { end = found; patternStart = found; patternEnd = found + needle.size(); }
        subcurrent = start;
    }
    static bool blank(char c) { return c == ' ' || c == '\t'; }
    Value word() {
        if (subcurrent >= end) return Value::string(std::string());
        while (subcurrent < length && blank((*str)[subcurrent])) ++subcurrent;
        if (subcurrent >= end) return Value::string(std::string());
        const std::size_t first = subcurrent;
        std::size_t scan = first;
        while (scan < end && !blank((*str)[scan])) ++scan;
        if (scan >= end) { subcurrent = end; return Value::string(str->substr(first, end - first)); }
        subcurrent = scan + 1;
        return Value::string(str->substr(first, scan - first));
    }
    Value rest() {
        if (subcurrent >= end) return Value::string(std::string());
        const std::size_t first = subcurrent;
        subcurrent = end;
        if (first == 0 && end == length) return holder;   // the whole string: the same string (shared, not copied)
        return Value::string(str->substr(first, end - first));
    }
    void skipWord() { (void)word(); }
    void skipRest() { subcurrent = end; }
};
#endif
