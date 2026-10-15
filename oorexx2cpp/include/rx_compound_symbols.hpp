#ifndef RX2CPP_COMPOUND_SYMBOLS_HPP
#define RX2CPP_COMPOUND_SYMBOLS_HPP
// Included inside namespace rx, after Value, Variables, get() and set().
// Compound symbol resolution is a language feature, not a BIF.
inline Value sendBinary(const Value &lhs, const std::string &selector, const Value &rhs);
inline Value sendUnary(const std::string &selector, const Value &operand);
inline bool compoundSymbol(const std::string &name) {
    return name.find('.') != std::string::npos;
}
// Resolve a dynamically substituted tail under the current activation's
// variable pool. Each activation uses its own variable pool with EXPOSE redirection.
inline std::string compoundKey(const Variables &vars, const std::string &symbol) {
    const auto dot = symbol.find('.');
    if (dot == std::string::npos) return symbol;
    std::string key;
    key.reserve(symbol.size() + 16);
    key.append(symbol, 0, dot + 1);
    static thread_local std::string part;
    std::size_t start = dot + 1;
    while (start < symbol.size()) {
        auto end = symbol.find('.', start);
        if (end == std::string::npos) end = symbol.size();
        if (end > start) {
            // A numeric-leading tail is a literal; a symbol-leading tail
            // consults its simple variable. Empty segments stay empty.
            if (symbol[start] >= '0' && symbol[start] <= '9') key.append(symbol, start, end - start);
            else {
                part.assign(symbol, start, end - start);
                if (const Value *resolved = lookup(vars, part)) {
                    if (resolved->isObject())
                        throw std::runtime_error("object-valued compound tail needs ooRexx string conversion");
                    key += resolved->bytes;
                } else key += part;   // an unset tail is its name: no NOVALUE for it (only the compound's own)
            }
        }
        if (end == symbol.size()) break;
        key += '.';
        start = end + 1;
    }
    return key;
}
// A stem as an object (ooRexx .Stem). A stem variable stays a flat set of map entries ("S.", "S.TAIL") until the stem
// itself is used as a value (passed as an argument, USE ARG S., S. = stemObject). From then on the variable "S." holds
// a StemObject and every compound access goes to it, so all holders of the object share one stem: element changes made by
// a called method are seen by the caller, while S. = .stem~new in the method only rebinds the method's own variable.
// When the object crosses into the hosted interpreter it becomes a real interpreter stem and the native object forwards
// to it from then on (one source of truth, also for methods running on other threads).
struct StemObject final : ObjectDispatch {
    std::string name;                                   // e.g. "S." (names the missing element: "S.TAIL")
    std::optional<Value> dflt;
    std::unordered_map<std::string, Value> tails;
    std::unordered_set<std::string> dropped;            // DROPped elements under a default
    std::shared_ptr<ObjectDispatch> remote;             // interpreter stem, once the object has crossed
    mutable std::mutex lock;
    explicit StemObject(std::string n) : name(std::move(n)) {}
    Value get(const std::string &tail) {
        if (remote) { auto r = remote->sendMessage("[]", {Value::string(tail)}); return r ? *r : Value::string(name + tail); }
        std::lock_guard<std::mutex> g(lock);
        auto it = tails.find(tail);
        if (it != tails.end()) return it->second;
        if (dflt && !dropped.count(tail)) return *dflt;
        return Value::string(name + tail);
    }
    // True when the element has a value (its own or the stem default, unless DROPped).
    bool has(const std::string &tail) {
        if (remote) { auto r = remote->sendMessage("HASINDEX", {Value::string(tail)}); return r && !r->isObject() && r->bytes == "1"; }
        std::lock_guard<std::mutex> g(lock);
        return tails.count(tail) || (dflt && !dropped.count(tail));
    }
    void set(const std::string &tail, Value v) {
        if (remote) { remote->sendMessage("[]=", {std::move(v), Value::string(tail)}); return; }
        std::lock_guard<std::mutex> g(lock);
        dropped.erase(tail);
        tails.insert_or_assign(tail, std::move(v));
    }
    // DROP stem.tail: uninitialized even under a stem default.
    void drop(const std::string &tail) {
        if (remote) { remote->sendMessage("REMOVE", {Value::string(tail)}); return; }
        std::lock_guard<std::mutex> g(lock);
        tails.erase(tail);
        if (dflt) dropped.insert(tail);
    }
    // S. = value: new default, every element dropped (same object).
    void reset(Value v) {
        if (remote) { remote->sendMessage("[]=", {std::move(v)}); return; }
        std::lock_guard<std::mutex> g(lock);
        tails.clear(); dropped.clear(); dflt = std::move(v);
    }
    Value defaultValue() {
        if (remote) { auto r = remote->sendMessage("[]", {}); return r ? *r : Value::string(name); }
        std::lock_guard<std::mutex> g(lock);
        return dflt ? *dflt : Value::string(name);
    }
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override {
        if (remote) return remote->sendMessage(selector, args);
        auto tailOf = [&](std::size_t from) {
            std::string t;
            for (std::size_t i = from; i < args.size(); ++i) {
                if (args[i].isObject()) throw std::runtime_error("stem index must be a string");
                if (i > from) t += '.';
                t += args[i].bytes;
            }
            return t;
        };
        bool plain = true;
        for (const Value &a : args) if (a.isObject()) plain = false;
        if (plain) {
            if (selector == "[]") return args.empty() ? defaultValue() : get(tailOf(0));
            if (selector == "[]=" && !args.empty()) {
                if (args.size() == 1) reset(args[0]); else set(tailOf(1), args[0]);
                return std::nullopt;
            }
            if (selector == "STRING") return defaultValue();
        }
        // Any other Stem method (AT, PUT, TODIRECTORY, ITEMS, ...) and object indexes: the stem becomes an interpreter
        // stem holding its contents (as when it crosses), and the interpreter's Stem class answers, errors included.
        if (promoteHook()) {
            promoteHook()(*this);
            if (remote) return remote->sendMessage(selector, args);
        }
        if (selector == "STRING") return defaultValue();
        return ObjectDispatch::sendMessage(selector, args);
    }
    bool noMakeString() const override { return true; }   // Stem has STRING, no MAKESTRING
    // Operators: Stem hides the Object comparison methods (s.~hasMethod('==') is 0), so every operator reaches its
    // UNKNOWN, which forwards it to the default value (s. == t. compares two default values; S. || 'x').
    Value sendBinary(const std::string &selector, const Value &rhs) override {
        if (remote) return remote->sendBinary(selector, rhs);
        return rx::sendBinary(defaultValue(), selector, rhs);
    }
    Value sendUnary(const std::string &selector) override {
        if (remote) return remote->sendUnary(selector);
        return rx::sendUnary(selector, defaultValue());
    }
    static void (*&promoteHook())(StemObject &) { static void (*hook)(StemObject &) = nullptr; return hook; }
    // True for an interpreter Stem object (set by the object bridge).
    static bool (*&foreignStemHook())(const Value &) { static bool (*hook)(const Value &) = nullptr; return hook; }
    std::string display() const override {
        if (remote) return remote->display();
        std::lock_guard<std::mutex> g(lock);
        if (!dflt) return name;
        return dflt->isObject() ? dflt->object->display() : dflt->bytes.str();
    }
};
inline std::atomic<bool> &stemObjectsInUse() { static std::atomic<bool> used{false}; return used; }
// The StemObject a stem variable is bound to, or null (the common, flat case).
inline StemObject *boundStem(const Variables &vars, const std::string &stem) {
    if (!stemObjectsInUse().load(std::memory_order_relaxed)) return nullptr;
    const Value *v = lookup(vars, stem);
    if (!v || !v->isObject()) return nullptr;
    return dynamic_cast<StemObject *>(v->object.get());
}
// The stem as a value: bind the variable to a StemObject (moving its flat entries into it) and return the object.
inline Value stemArg(Variables &vars, const std::string &stem) {
    Variables &owner = variableOwner(vars, stem);
    auto self = owner.find(stem);
    if (self != owner.end() && self->second.isObject() && dynamic_cast<StemObject *>(self->second.object.get()))
        return self->second;
    auto obj = std::make_shared<StemObject>(stem);
    for (auto it = owner.begin(); it != owner.end();) {
        if (it->first == stem) { obj->dflt = it->second; ++it; }
        else if (it->first.size() > stem.size() && it->first.compare(0, stem.size(), stem) == 0) {
            obj->tails.emplace(it->first.substr(stem.size()), std::move(it->second));
            it = owner.erase(it);
        } else ++it;
    }
    stemObjectsInUse().store(true, std::memory_order_relaxed);
    Value v = Value::fromObject(obj);
    owner.insert_or_assign(stem, v);
    return v;
}
// The .STEM class object: NEW([name]) gives a fresh StemObject.
struct StemClassObject final : ObjectDispatch {
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override {
        if (selector == "NEW" && args.size() <= 1) {
            if (!args.empty() && args[0].isObject()) throw std::runtime_error(".STEM~NEW name must be a string");
            stemObjectsInUse().store(true, std::memory_order_relaxed);
            return Value::fromObject(std::make_shared<StemObject>(args.empty() ? std::string() : args[0].bytes.str()));
        }
        return ObjectDispatch::sendMessage(selector, args);
    }
    std::string display() const override { return "The Stem class"; }
};
inline Value stemClass() { static const Value c = Value::fromObject(std::make_shared<StemClassObject>()); return c; }
// The stem's string value (its default value, or its name): what a built-in function receives for S.
inline Value stemValue(Variables &vars, const std::string &stem) {
    if (StemObject *bound = boundStem(vars, stem)) return bound->defaultValue();
    if (const Value *v = lookup(vars, stem)) return *v;
    return Value::string(stem);
}
// Assignment to the whole stem (S. = value). A stem object rebinds the variable; any other value starts a new stem.
inline void assignStem(Variables &vars, const std::string &stem, Value value) {
    // An interpreter Stem object (S. = .stem~new): the variable shares it, as with a compiled stem object.
    if (value.isObject() && !dynamic_cast<StemObject *>(value.object.get()) && StemObject::foreignStemHook() &&
        StemObject::foreignStemHook()(value)) {
        auto obj = std::make_shared<StemObject>(stem);
        obj->remote = value.object;
        value = Value::fromObject(obj);
    }
    if (value.isObject() && dynamic_cast<StemObject *>(value.object.get())) {
        resetStem(vars, stem);
        stemObjectsInUse().store(true, std::memory_order_relaxed);
        set(vars, stem, std::move(value));
        return;
    }
    // Any other value gives the variable a new stem (verified: after B. = A., A. = 'x' leaves B.'s elements alone):
    // the binding, if any, is replaced by the flat default.
    resetStem(vars, stem);
    set(vars, stem, std::move(value));
}
// USE ARG S.: the argument stem object is shared; a string argument gives a fresh stem with that default.
inline void useStemArgument(Variables &vars, const std::vector<Value> &args, const std::string &stem, std::size_t index) {
    if (index >= args.size()) return;
    const Value &a = args[index];
    if (a.isObject() && dynamic_cast<StemObject *>(a.object.get())) { assignStem(vars, stem, a); return; }
    if (a.isObject()) {
        // An interpreter stem (or other stem-like object) arriving from the hosted tier: share it.
        auto obj = std::make_shared<StemObject>(stem);
        obj->remote = a.object;
        assignStem(vars, stem, Value::fromObject(obj));
        return;
    }
    auto obj = std::make_shared<StemObject>(stem);
    obj->dflt = a;
    assignStem(vars, stem, Value::fromObject(obj));
}
inline Value compoundGet(const Variables &vars, const std::string &key, const char *stem);
inline Value getSymbol(const Variables &vars, const std::string &symbol) {
    if (!compoundSymbol(symbol)) return get(vars, symbol);
    const std::string key = compoundKey(vars, symbol);
    if (symbol.find('.') != symbol.size() - 1 && key.find('.') == key.size() - 1) {   // a tail that resolved to ''
        const std::string stemName = key;
        return compoundGet(vars, key, stemName.c_str());
    }
    if (const Value *v = lookup(vars, key)) return *v;
    const std::string stem = symbol.substr(0, symbol.find('.') + 1);
    if (const Value *v = lookup(vars, stem)) {
        if (key.size() > stem.size() && v->isObject())
            if (auto *bound = dynamic_cast<StemObject *>(v->object.get())) return bound->get(key.substr(stem.size()));
        return *v;
    }
    return Value::string(key);
}
// Compiled compound access: the derived name is built from literal tails and tail-variable values the caller already
// read (through slots), then looked up once. Same results as getSymbol()/setSymbol() for a name with tails.
struct TailLiteral { const char *text; };
inline void appendTail(std::string &key, const TailLiteral &t) { key += t.text; }
inline void appendTail(std::string &key, const Value &v) {
    if (v.isObject()) throw std::runtime_error("object-valued compound tail needs ooRexx string conversion");
    key += v.bytes;
}
template <typename First, typename... Rest>
inline void appendTails(std::string &key, const First &first, const Rest &...rest) {
    appendTail(key, first);
    if constexpr (sizeof...(rest) > 0) { key += '.'; appendTails(key, rest...); }
}
template <typename... Tails>
inline std::string compoundKeyOf(const char *stem, const Tails &...tails) {
    std::string key;
    key.reserve(32);
    key += stem;
    appendTails(key, tails...);
    return key;
}
inline Value compoundGet(const Variables &vars, const std::string &key, const char *stem) {
    // An empty tail (S.T with T = ''): the derived name equals the stem's own; the element lives in the stem object.
    if (key.size() == std::strlen(stem)) {
        if (StemObject *bound = boundStem(vars, key)) return bound->get(std::string());
        if (const Value *v = lookup(vars, key)) return *v;   // the stem's default value
        return Value::string(key);
    }
    if (const Value *v = lookup(vars, key)) return *v;
    if (const Value *v = lookup(vars, std::string(stem))) {
        if (v->isObject())
            if (auto *bound = dynamic_cast<StemObject *>(v->object.get())) return bound->get(key.substr(std::strlen(stem)));
        return *v;
    }
    return Value::string(key);
}
inline void compoundSet(Variables &vars, const std::string &key, Value value) {
    // An empty tail: the element must not overwrite the stem's default (same derived name), so the stem becomes an
    // object, which keeps its elements apart from its default.
    if (key.find('.') == key.size() - 1) {
        stemArg(vars, key);
        if (StemObject *bound = boundStem(vars, key)) { bound->set(std::string(), std::move(value)); return; }
    }
    if (stemObjectsInUse().load(std::memory_order_relaxed)) {
        const std::string stem = key.substr(0, key.find('.') + 1);
        if (StemObject *bound = boundStem(vars, stem)) { bound->set(key.substr(stem.size()), std::move(value)); return; }
    }
    set(vars, key, std::move(value));
}
// DROP symbol. A stem: the variable gets a new empty stem (no default, no elements; the stem variable still exists, as
// interpreted). A compound: the element is dropped, and stays uninitialized under a stem default.
inline void dropSymbol(Variables &vars, const std::string &symbol) {
    if (!compoundSymbol(symbol)) { drop(vars, symbol); return; }
    if (symbol.find('.') == symbol.size() - 1) {
        resetStem(vars, symbol);
        stemObjectsInUse().store(true, std::memory_order_relaxed);
        set(vars, symbol, Value::fromObject(std::make_shared<StemObject>(symbol)));
        return;
    }
    const std::string key = compoundKey(vars, symbol);
    const std::string stem = key.substr(0, key.find('.') + 1);
    if (StemObject *bound = boundStem(vars, stem)) { bound->drop(key.substr(stem.size())); return; }
    if (lookup(vars, stem)) {   // a stem default: the element needs a tombstone, which the stem object keeps
        stemArg(vars, stem);
        if (StemObject *bound = boundStem(vars, stem)) { bound->drop(key.substr(stem.size())); return; }
    }
    drop(vars, key);
}
// DROP (name): every blank-delimited word of the value is a variable name.
inline void dropList(Variables &vars, const Value &list) {
    if (list.isObject()) throw std::runtime_error("DROP (name): the list must be a string");
    const std::string text = list.bytes.str();
    std::size_t i = 0;
    while (i < text.size()) {
        while (i < text.size() && (text[i] == ' ' || text[i] == '\t')) ++i;
        std::size_t j = i;
        while (j < text.size() && text[j] != ' ' && text[j] != '\t') ++j;
        if (j > i) {
            std::string name = text.substr(i, j - i);
            for (char &c : name) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
            dropSymbol(vars, name);
        }
        i = j;
    }
}
inline void setSymbol(Variables &vars, const std::string &symbol, Value value) {
    if (!compoundSymbol(symbol)) { set(vars, symbol, std::move(value)); return; }
    // Reassigning an entire stem changes the default and discards all
    // assigned compound entries under it (the ooRexx reset behaviour).
    if (symbol.find('.') == symbol.size() - 1) { assignStem(vars, symbol, std::move(value)); return; }
    compoundSet(vars, compoundKey(vars, symbol), std::move(value));
}
#endif
