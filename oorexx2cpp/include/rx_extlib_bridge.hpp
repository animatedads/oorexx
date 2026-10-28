#ifndef RX2CPP_EXTLIB_BRIDGE_HPP
#define RX2CPP_EXTLIB_BRIDGE_HPP
// Generated programs that declare ::REQUIRES "x" LIBRARY include this header. It binds the external
// library host (rx2cpp_extlib.hpp) to the compiled activation's variable pool (getSymbol/setSymbol/
// variableOwner) so library routines see the caller's variables exactly as rxsock/socket.cls expect.
// Needs oorexxapi.h (headers only; the interpreter is never linked) and -ldl.
#include <cstdlib>
#include "minirexx_runtime.hpp"
#include "rx2cpp_extlib.hpp"
namespace rx { namespace ext {
inline rxext::Host &host() {
    static rxext::Host h;
    static bool init = false;
    if (!init) {
        init = true;
        if (const char *p = std::getenv("RX2CPP_LIBPATH")) {          // colon separated extra directories
            std::string s = p; std::size_t a = 0;
            while (a <= s.size()) { auto b = s.find(':', a); if (b == std::string::npos) b = s.size();
                if (b > a) h.searchDirs.push_back(s.substr(a, b - a));
                a = b + 1; }
        }
    }
    return h;
}
inline std::string fold(std::string s) { for (auto &c : s) c = (char)std::toupper((unsigned char)c); return s; }
// The activation the current library call belongs to.
struct Binding {
    Variables *vars;
    Binding *prev;
    explicit Binding(Variables &v) : vars(&v), prev(current()) { current() = this; }
    ~Binding() { current() = prev; }
    Binding(const Binding &) = delete;
    Binding &operator=(const Binding &) = delete;
    static Binding *&current() { static thread_local Binding *c = nullptr; return c; }
};
inline Variables &cur() { return *Binding::current()->vars; }
inline std::optional<std::string> readSymbol(const std::string &raw) {
    const std::string name = fold(raw);
    const Value *v = nullptr;
    if (!compoundSymbol(name)) v = lookup(cur(), name);
    else {
        v = lookup(cur(), compoundKey(cur(), name));
        if (!v) v = lookup(cur(), name.substr(0, name.find('.') + 1));
    }
    if (!v) return std::nullopt;
    if (v->isObject()) throw std::runtime_error("object-valued variable crosses the external library boundary");
    return v->bytes.str();
}
inline void bind(rxext::Host &h) {
    h.varSet = [](const std::string &n, const std::string &v) { setSymbol(cur(), fold(n), Value::string(v)); };
    h.varGet = [](const std::string &n) { return readSymbol(n); };
    h.varDrop = [](const std::string &n) {
        const std::string name = fold(n);
        drop(cur(), compoundSymbol(name) ? compoundKey(cur(), name) : name); };
    // literal tails: stem names arrive as resolved by ResolveStemVariable ("STEM."), tails are NOT substituted
    h.tailSet = [](const std::string &stem, const std::string &tail, const std::string &v) { set(cur(), stem + tail, Value::string(v)); };
    h.tailGet = [](const std::string &stem, const std::string &tail) -> std::optional<std::string> {
        const Value *v = lookup(cur(), stem + tail);
        if (!v) return std::nullopt;
        if (v->isObject()) throw std::runtime_error("object-valued variable crosses the external library boundary");
        return v->bytes.str(); };
    h.tailDrop = [](const std::string &stem, const std::string &tail) { drop(cur(), stem + tail); };
}
inline void require(const std::string &name) {
    rxext::Host &h = host();
    try { bind(h); h.load(name); }
    catch (const rxext::Error &e) {
        // A class library (native ::CLASS methods) needs the interpreter's object model: the hosted tier loads it.
        if (std::string(e.what()).find("declares native classes") != std::string::npos && classLibraryLoader() && classLibraryLoader()(name)) return;
        throw std::runtime_error("Error " + e.code + ": " + e.what());
    }
}
inline MessageResult call(Variables &vars, const std::string &name, const std::vector<Value> &args) {
    rxext::Host &h = host(); bind(h);
    Binding b(vars);
    std::vector<rxext::Host::Arg> a;
    for (const Value &v : args) {
        if (v.isObject()) throw std::runtime_error("object argument crosses the external library boundary");
        rxext::Host::Arg x; x.s = v.bytes; a.push_back(x);
    }
    try {
        auto r = h.call(name, a);
        if (!r) return std::nullopt;
        return Value::string(*r);
    } catch (const rxext::Error &e) {
        throw std::runtime_error("Error " + e.code + ": " + e.what());
    } catch (const rxext::Unsupported &e) { throw std::runtime_error(e.what()); }
}
inline Value callValue(Variables &vars, const std::string &name, const std::vector<Value> &args) {
    MessageResult r = call(vars, name, args);
    if (!r) throw std::runtime_error("function " + name + " returned no result");
    return *r;
}
inline void callInstruction(Variables &vars, const std::string &name, const std::vector<Value> &args) {
    MessageResult r = call(vars, name, args);
    if (r) set(vars, "RESULT", *r); else drop(vars, "RESULT");
}
}}
#endif
