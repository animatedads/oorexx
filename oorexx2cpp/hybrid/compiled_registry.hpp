#ifndef RX2CPP_COMPILED_REGISTRY_HPP
#define RX2CPP_COMPILED_REGISTRY_HPP
// Native object registry for the hybrid boundary. The registry and callback
// MUST reside in the same shared library so callback calls see live objects.
#include <memory>
#include <string>
#include <unordered_map>
#include <mutex>
#include <condition_variable>
#include <thread>
#include <vector>
#include <optional>
#include <stdexcept>
#include "minirexx_runtime.hpp"
#include <stdexcept>

namespace rx2cpp {
/* Recursive lock whose whole recursion depth can be released while the native
   method calls back into the interpreter, then restored. Holding a C++ lock
   across an interpreter callout would hide a deadlock from ooRexx's detector. */
class ScopeLock {
    std::mutex m_;
    std::condition_variable cv_;
    std::thread::id owner_{};
    unsigned depth_ = 0;
public:
    void lock() {
        std::unique_lock<std::mutex> g(m_);
        const auto me = std::this_thread::get_id();
        cv_.wait(g, [&] { return depth_ == 0 || owner_ == me; });
        owner_ = me; ++depth_;
    }
    void unlock() {
        std::lock_guard<std::mutex> g(m_);
        if (--depth_ == 0) { owner_ = std::thread::id(); cv_.notify_one(); }
    }
    unsigned release_all() {
        std::lock_guard<std::mutex> g(m_);
        const unsigned d = depth_;
        depth_ = 0; owner_ = std::thread::id(); cv_.notify_one();
        return d;
    }
    void reacquire(unsigned d) {
        std::unique_lock<std::mutex> g(m_);
        cv_.wait(g, [&] { return depth_ == 0; });
        owner_ = std::this_thread::get_id(); depth_ = d;
    }
};
/* SELF~selector(arg): the sender is installed only for the duration of one
   interpreter-invoked native method on the current thread. It is never cached
   globally; with no active frame the send fails explicitly. */
struct SelfSender {
    virtual ~SelfSender() = default;
    virtual std::string send(const std::string &selector, const std::vector<std::string> &args) = 0;
    virtual std::string forward(const std::string &selector) = 0;
    /* Object-capable send (host-API libraries): arguments/result are interpreter objects or strings, omitted arguments
       are rx::omittedArgument(); nullopt = the method returned no value. The scope lock is released around the send. */
    virtual std::optional<rx::Value> sendValues(const std::string &selector, const std::vector<rx::Value> &) {
        throw std::runtime_error("object-capable SELF send needs the host-API native lane: " + selector);
    }
};
namespace detail { inline thread_local SelfSender *currentSender = nullptr; }
inline std::string selfSend(const std::string &selector, const std::vector<std::string> &args) {
    if (!detail::currentSender)
        throw std::runtime_error("SELF send outside an interpreter-invoked native method");
    return detail::currentSender->send(selector, args);
}
/* FORWARD runs against the interpreter method activation, not the synthetic
   C++ scope. The host supplies the original arguments and SELF identity. */
inline std::string forwardMessage(const std::string &selector) {
    if (!detail::currentSender)
        throw std::runtime_error("FORWARD outside an interpreter-invoked native method");
    return detail::currentSender->forward(selector);
}
inline std::optional<rx::Value> selfSendValues(const std::string &selector, const std::vector<rx::Value> &args) {
    if (!detail::currentSender)
        throw std::runtime_error("SELF send outside an interpreter-invoked native method");
    return detail::currentSender->sendValues(selector, args);
}
inline rx::Value selfSendValue(const std::string &selector, const std::vector<rx::Value> &args) {
    auto r = selfSendValues(selector, args);
    if (!r) throw std::runtime_error("SELF~" + selector + " returned no value");
    return *r;
}
struct CompiledObject {
    /* One lock per class scope. It protects the compiled C++ state against
       concurrent interpreter activities even for UNGUARDED methods. It is a
       memory-safety lock, not the ooRexx GUARD semantics (the interpreter's
       scope lock still decides what GUARDED means). */
    ScopeLock scope_lock;
    virtual ~CompiledObject() = default;
    virtual std::string invoke(const std::string &selector, const std::string &value) = 0;
    virtual std::string invoke2(const std::string &selector, const std::string &, const std::string &) {
        throw std::runtime_error("two-argument selector not implemented: " + selector);
    }
    virtual std::string invoke0(const std::string &selector) {
        throw std::runtime_error("zero-argument selector not implemented: " + selector);
    }
    /* The ooRexx ARGLIST as sparse positional values (nullopt = omitted). Generated classes override this one
       entry point and accept any number of arguments. Hand-written objects that only implement invoke0/invoke/invoke2
       keep working through this default (at most two arguments). */
    virtual std::string invokeArgs(const std::string &selector,
                                   const std::vector<std::optional<std::string>> &arguments) {
        auto at = [&](std::size_t i) { return arguments[i] ? *arguments[i] : std::string(); };
        if (arguments.empty()) return invoke0(selector);
        if (arguments.size() == 1) return invoke(selector, at(0));
        if (arguments.size() == 2) return invoke2(selector, at(0), at(1));
        throw std::runtime_error("selector does not accept " + std::to_string(arguments.size()) + " arguments: " + selector);
    }
    /* Interpreter-object-capable entry: arguments and result are rx::Value (strings or interpreter objects, omitted = nullopt).
       Generated classes override this; invokeArgs above is then only the string adapter. The default bridges the other way, so
       hand-written string-only objects keep working (they cannot receive objects). */
    virtual rx::Value invokeValues(const std::string &selector, const std::vector<std::optional<rx::Value>> &arguments) {
        std::vector<std::optional<std::string>> strings;
        strings.reserve(arguments.size());
        for (const auto &a : arguments) {
            if (!a) strings.emplace_back(std::nullopt);
            else if (a->isObject()) throw std::runtime_error("object argument not supported by native selector: " + selector);
            else strings.emplace_back(a->bytes);
        }
        return rx::Value::string(invokeArgs(selector, strings));
    }
    /* Native package routine ABI receives the ooRexx ARGLIST as sparse,
       positional values; omitted and missing arguments stay unbound. */
    virtual std::string invokeMany(const std::string &selector,
                                   const std::vector<std::optional<std::string>> &) {
        throw std::runtime_error("multi-argument native routine not implemented: " + selector);
    }
};
class Registry {
    std::mutex gate_;
    std::unordered_map<std::string, std::shared_ptr<CompiledObject>> objects_;
    unsigned long next_ = 0;
public:
    static Registry &instance();
    std::string add(std::shared_ptr<CompiledObject> object);
    void remove(const std::string &token);
    std::shared_ptr<CompiledObject> find(const std::string &token);
};
// Counter stands in for a generated C++ ooRexx object in this first ABI test.
// Actual generated class binding is NOT implemented yet.
class CompiledCounter : public CompiledObject {
    long value_;
public:
    explicit CompiledCounter(long start = 0) : value_(start) {}
    long value() const { return value_; }
    std::string invoke(const std::string &selector, const std::string &text) override;
};
}
#endif
