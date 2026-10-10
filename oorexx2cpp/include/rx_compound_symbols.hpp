#ifndef RX2CPP_COMPOUND_SYMBOLS_HPP
#define RX2CPP_COMPOUND_SYMBOLS_HPP
// Included inside namespace rx, after Value, Variables, get() and set().
// Compound symbol resolution is a language feature, not a BIF.
inline bool compoundSymbol(const std::string &name) {
    return name.find('.') != std::string::npos;
}
// Resolve a dynamically substituted tail under the current activation's
// variable pool. Each activation uses its own variable pool with EXPOSE redirection.
inline std::string compoundKey(const Variables &vars, const std::string &symbol) {
    const auto dot = symbol.find('.');
    if (dot == std::string::npos) return symbol;
    std::string key = symbol.substr(0, dot + 1);
    std::size_t start = dot + 1;
    while (start < symbol.size()) {
        const auto end = symbol.find('.', start);
        const std::string part = symbol.substr(start, end == std::string::npos ?
                                                    std::string::npos : end - start);
        if (!part.empty()) {
            // A numeric-leading tail is a literal; a symbol-leading tail
            // consults its simple variable. Empty segments stay empty.
            if (part[0] >= '0' && part[0] <= '9') key += part;
            else {
                const Value resolved = get(vars, part);
                if (resolved.isObject())
                    throw std::runtime_error("object-valued compound tail needs ooRexx string conversion");
                key += resolved.bytes;
            }
        }
        if (end == std::string::npos) break;
        key += '.';
        start = end + 1;
    }
    return key;
}
inline Value getSymbol(const Variables &vars, const std::string &symbol) {
    if (!compoundSymbol(symbol)) return get(vars, symbol);
    const std::string key = compoundKey(vars, symbol);
    if (const Value *v = lookup(vars, key)) return *v;
    const std::string stem = symbol.substr(0, symbol.find('.') + 1);
    if (const Value *v = lookup(vars, stem)) return *v;
    return Value::string(key);
}
inline void setSymbol(Variables &vars, const std::string &symbol, Value value) {
    if (!compoundSymbol(symbol)) { set(vars, symbol, std::move(value)); return; }
    const std::string key = compoundKey(vars, symbol);
    // Reassigning an entire stem changes the default and discards all
    // assigned compound entries under it (the ooRexx reset behaviour).
    if (symbol.find('.') == symbol.size() - 1) {
        resetStem(vars, symbol);
    }
    set(vars, key, std::move(value));
}
#endif
