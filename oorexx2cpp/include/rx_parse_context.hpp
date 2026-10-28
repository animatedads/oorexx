#ifndef RX_PARSE_CONTEXT_HPP
#define RX_PARSE_CONTEXT_HPP
// Standalone ooRexx activation metadata. This is language machinery, not BIF.
// Native ooRexx package entry points will supply their own activation context.
inline std::vector<Value> mainArguments(int argc, char **argv) {
    if (argc <= 1) return {}; // omitted argument is not an empty argument
    std::string text;
    for (int i = 1; i < argc; ++i) {
        if (i > 1) text += ' ';
        if (argv[i] != nullptr) text += argv[i];
    }
    return {Value::string(text)};
}
inline Value argumentAt(const std::vector<Value> &args, std::size_t i) {
    return i < args.size() ? args[i] : Value::string("");
}
inline Value parseUpper(const Value &v) {
    if (v.isObject()) throw std::runtime_error("PARSE UPPER requires string conversion");
    std::string b = v.bytes.str();
    // ASCII-alphabetic subset; full ooRexx locale-aware string casing
    // remains a separately qualified runtime semantics task.
    for (char &c : b) {
        if (static_cast<unsigned char>(c) >= 128)
            throw std::runtime_error("PARSE UPPER non-ASCII casing not qualified");
        if (c >= 'a' && c <= 'z') c = static_cast<char>(c - 'a' + 'A');
    }
    return Value::string(b);
}
inline Value parseLower(const Value &v) {
    if (v.isObject()) throw std::runtime_error("PARSE LOWER requires string conversion");
    std::string b = v.bytes.str();
    for (char &c : b) {
        if (static_cast<unsigned char>(c) >= 128)
            throw std::runtime_error("PARSE LOWER non-ASCII casing not qualified");
        if (c >= 'A' && c <= 'Z') c = static_cast<char>(c - 'A' + 'a');
    }
    return Value::string(b);
}
inline Value sourceDescriptor(const std::string &sourceName) {
#if defined(__linux__)
    return Value::string("LINUX COMMAND " + sourceName);
#else
    throw std::runtime_error("PARSE SOURCE standalone platform not qualified");
#endif
}
#endif
