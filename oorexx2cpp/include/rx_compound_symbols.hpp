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
                } else {
                    if (novalueArmed && *novalueArmed) throw NoValueCondition(part);
                    key += part;
                }
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
    std::shared_ptr<ObjectDispatch> remote;             // interpreter stem, once the object has crossed
    mutable std::mutex lock;
    explicit StemObject(std::string n) : name(std::move(n)) {}
    Value get(const std::string &tail) {
        if (remote) { auto r = remote->sendMessage("[]", {Value::string(tail)}); return r ? *r : Value::string(name + tail); }
        std::lock_guard<std::mutex> g(lock);
        auto it = tails.find(tail);
        if (it != tails.end()) return it->second;
        if (dflt) return *dflt;
        return Value::string(name + tail);
    }
    void set(const std::string &tail, Value v) {
        if (remote) { remote->sendMessage("[]=", {std::move(v), Value::string(tail)}); return; }
        std::lock_guard<std::mutex> g(lock);
        tails.insert_or_assign(tail, std::move(v));
    }
    // S. = value: new default, every element dropped (same object).
    void reset(Value v) {
        if (remote) { remote->sendMessage("[]=", {std::move(v)}); return; }
        std::lock_guard<std::mutex> g(lock);
        tails.clear(); dflt = std::move(v);
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
        if (selector == "[]" || selector == "AT") return args.empty() ? defaultValue() : get(tailOf(0));
        if ((selector == "[]=" || selector == "PUT") && !args.empty()) {
            if (args.size() == 1) reset(args[0]); else set(tailOf(1), args[0]);
            return std::nullopt;
        }
        if (selector == "STRING" || selector == "MAKESTRING") return defaultValue();
        return ObjectDispatch::sendMessage(selector, args);
    }
    std::string display() const override {
        if (remote) return remote->display();
        std::lock_guard<std::mutex> g(lock);
        if (!dflt) return name;
        return dflt->isObject() ? dflt->object->display() : dflt->bytes;
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
            return Value::fromObject(std::make_shared<StemObject>(args.empty() ? std::string() : args[0].bytes));
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
inline Value getSymbol(const Variables &vars, const std::string &symbol) {
    if (!compoundSymbol(symbol)) return get(vars, symbol);
    const std::string key = compoundKey(vars, symbol);
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
    if (const Value *v = lookup(vars, key)) return *v;
    if (const Value *v = lookup(vars, std::string(stem))) {
        if (v->isObject())
            if (auto *bound = dynamic_cast<StemObject *>(v->object.get())) return bound->get(key.substr(std::strlen(stem)));
        return *v;
    }
    return Value::string(key);
}
inline void compoundSet(Variables &vars, const std::string &key, Value value) {
    if (stemObjectsInUse().load(std::memory_order_relaxed)) {
        const std::string stem = key.substr(0, key.find('.') + 1);
        if (StemObject *bound = boundStem(vars, stem)) { bound->set(key.substr(stem.size()), std::move(value)); return; }
    }
    set(vars, key, std::move(value));
}
inline void setSymbol(Variables &vars, const std::string &symbol, Value value) {
    if (!compoundSymbol(symbol)) { set(vars, symbol, std::move(value)); return; }
    // Reassigning an entire stem changes the default and discards all
    // assigned compound entries under it (the ooRexx reset behaviour).
    if (symbol.find('.') == symbol.size() - 1) { assignStem(vars, symbol, std::move(value)); return; }
    compoundSet(vars, compoundKey(vars, symbol), std::move(value));
}
#endif
