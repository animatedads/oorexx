// Hosted tier: classes the native runtime does not implement (.DateTime, .TimeSpan, ...) are loaded from a
// persistent embedded ooRexx interpreter session and kept as live object handles. Compiled programs that
// reference such a class include this header and link librexx/librexxapi; programs that never do stay fully
// native. Messages go to the real object, so run-time mutation, INTERPRET-defined methods and interpreter quirks
// behave exactly as in the interpreter. See hosted_tier/README.md.
//
// Values crossing the boundary: strings/numbers are copied as Rexx strings; HostObject values travel as handles;
// native objects (.Array built by the native runtime, user classes) cannot enter the interpreter yet and are
// rejected with an explicit error rather than being converted lossily.
#ifndef RX2CPP_HOST_TIER_HPP
#define RX2CPP_HOST_TIER_HPP
#include "minirexx_runtime.hpp"
#include <oorexxapi.h>
#include <mutex>
#include <thread>
#include <string>
#include <vector>
namespace rx { namespace host {

class Session {
public:
    static Session &get() { static Session s; return s; }
    // The calling thread's context: the creating thread's own, or a freshly attached one.
    RexxThreadContext *ctx() {
        thread_local ThreadSlot slot;
        if (!slot.c) {
            if (std::this_thread::get_id() == mainThread_) slot.c = mainCtx_;
            else {
                if (!inst_->AttachThread(&slot.c)) throw std::runtime_error("hosted tier: cannot attach thread to interpreter");
                slot.attached = true;
            }
        }
        return slot.c;
    }
private:
    struct ThreadSlot {
        RexxThreadContext *c = nullptr; bool attached = false;
        ~ThreadSlot() { if (attached && c) c->DetachThread(); }
    };
    Session() {
        RexxOption options[1]; options[0].optionName = nullptr;
        if (!RexxCreateInterpreter(&inst_, &mainCtx_, options))
            throw SyntaxCondition("98.926", "hosted tier: cannot create an interpreter instance", false);
        mainThread_ = std::this_thread::get_id();
    }
    RexxInstance *inst_ = nullptr;
    RexxThreadContext *mainCtx_ = nullptr;
    std::thread::id mainThread_;
};

// Turn the interpreter's pending condition into the compiler's SyntaxCondition ("Error 97.1: text").
[[noreturn]] inline void raisePending(RexxThreadContext *c) {
    RexxCondition cd;
    c->DecodeConditionInfo(c->GetConditionInfo(), &cd);
    std::string text = cd.message ? c->ObjectToStringValue(cd.message) : "";
    const std::string code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
    c->ClearCondition();
    throw SyntaxCondition(code, text, false);
}

struct HostObject;
inline Value wrap(RexxThreadContext *c, RexxObjectPtr o);

struct HostObject final : ObjectDispatch {
    RexxObjectPtr handle;
    explicit HostObject(RexxObjectPtr h) : handle(h) { Session::get().ctx()->RequestGlobalReference(handle); }
    ~HostObject() override { Session::get().ctx()->ReleaseGlobalReference(handle); }
    HostObject(const HostObject &) = delete;
    HostObject &operator=(const HostObject &) = delete;

    static RexxObjectPtr toRexx(RexxThreadContext *c, const Value &v) {
        if (!v.isObject()) return c->String(v.bytes.data(), v.bytes.size());
        if (auto h = std::dynamic_pointer_cast<HostObject>(v.object)) return h->handle;
        if (std::dynamic_pointer_cast<NilObject>(v.object)) return c->Nil();
        throw std::runtime_error("native object cannot be passed to the hosted interpreter (not implemented)");
    }
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override {
        RexxThreadContext *c = Session::get().ctx();
        RexxArrayObject list = c->NewArray(args.size());
        for (std::size_t i = 0; i < args.size(); ++i) c->ArrayPut(list, toRexx(c, args[i]), i + 1);
        RexxObjectPtr result = c->SendMessage(handle, selector.c_str(), list);
        if (c->CheckCondition()) raisePending(c);
        if (!result) return std::nullopt;
        return wrap(c, result);
    }
    Value sendBinary(const std::string &selector, const Value &rhs) override {
        const MessageResult r = sendMessage(selector, {rhs});
        if (!r) throw std::runtime_error("hosted operator did not return a result");
        return *r;
    }
    std::string display() const override {
        auto r = const_cast<HostObject *>(this)->sendMessage("STRING", {});
        if (!r) throw std::runtime_error("hosted STRING method returned no result");
        return r->isObject() ? r->object->display() : r->bytes;
    }
};

// Strings and numbers become plain native values; everything else stays a live handle.
inline Value wrap(RexxThreadContext *c, RexxObjectPtr o) {
    if (!o) throw std::runtime_error("hosted tier: null object is not .NIL");
    if (o == c->Nil()) return rx::nil();
    if (c->IsString(o)) {
        RexxStringObject s = static_cast<RexxStringObject>(o);
        return Value::string(std::string(c->StringData(s), c->StringLength(s)));
    }
    if (c->IsOfType(o, "STRING")) return Value::number(c->ObjectToStringValue(o));
    return Value::fromObject(std::make_shared<HostObject>(o));
}

// The program's directive section (::CLASS with options, ::REQUIRES of Rexx programs, ...) that the compiler
// cannot translate natively runs in the interpreter as one package. Its classes and routines are then looked up
// here by the natively compiled main program.
inline RexxPackageObject &unitPackage() { static RexxPackageObject p = nullptr; return p; }
// GetPackageRoutines returns an ooRexx StringTable. Pin one wrapper per unit.
inline std::shared_ptr<HostObject> &cachedPackageRoutines() {
    static std::shared_ptr<HostObject> retained;
    return retained;
}
inline void loadUnit(const std::string &name, const std::string &source) {
    RexxThreadContext *c = Session::get().ctx();
    RexxPackageObject p = c->LoadPackageFromData(name.c_str(), source.c_str(), source.size());
    if (c->CheckCondition()) raisePending(c);
    if (!p) throw std::runtime_error("hosted tier: package load returned null");
    c->RequestGlobalReference(p);
    cachedPackageRoutines().reset();
    if (unitPackage()) c->ReleaseGlobalReference(unitPackage());
    unitPackage() = p;
}

// .OUTPUT belongs to the thread's local environment, not to the class registry.
inline Value localSymbol(const std::string &name) {
    RexxThreadContext *c = Session::get().ctx();
    RexxDirectoryObject local = c->GetLocalEnvironment();
    if (c->CheckCondition()) raisePending(c);
    if (!local) throw std::runtime_error("hosted tier: local environment unavailable");
    RexxObjectPtr object = c->DirectoryAt(local, name.c_str());
    if (c->CheckCondition()) raisePending(c);
    if (!object) throw SyntaxCondition("98.926", "hosted tier: unknown local symbol ." + name, false);
    return wrap(c, object);
}
// .ROUTINES belongs to the source's package, not the global environment.
inline Value packageRoutines() {
    RexxThreadContext *c = Session::get().ctx();
    // A source with no directives has an empty package routine directory.
    if (!unitPackage()) loadUnit("rx2cpp-empty-directives", "\n");
    auto &pinned = cachedPackageRoutines();
    if (!pinned) {
        RexxDirectoryObject routines = c->GetPackageRoutines(unitPackage());
        if (c->CheckCondition()) raisePending(c);
        if (!routines) throw std::runtime_error("hosted tier: GetPackageRoutines returned null");
        pinned = std::make_shared<HostObject>(static_cast<RexxObjectPtr>(routines));
    }
    return Value::fromObject(pinned);
}

// .NAME environment symbols that name a class: the loaded unit's classes first, then the interpreter's.
inline Value findClass(const std::string &name) {
    RexxThreadContext *c = Session::get().ctx();
    if (unitPackage()) {
        RexxClassObject own = c->FindPackageClass(unitPackage(), name.c_str());   // own and ::REQUIRES-imported classes
        if (c->CheckCondition()) c->ClearCondition();
        if (own) return Value::fromObject(std::make_shared<HostObject>(static_cast<RexxObjectPtr>(own)));
    }
    RexxClassObject cls = c->FindClass(name.c_str());
    if (c->CheckCondition()) c->ClearCondition();
    if (!cls) throw SyntaxCondition("98.926", "hosted tier: no interpreter class named ." + name, false);
    return Value::fromObject(std::make_shared<HostObject>(static_cast<RexxObjectPtr>(cls)));
}

// CALL/function invocation of a ::ROUTINE that lives in the loaded unit (private routines included).
inline MessageResult callRoutine(const std::string &name, const std::vector<Value> &args) {
    RexxThreadContext *c = Session::get().ctx();
    RexxObjectPtr r = unitPackage() ? c->DirectoryAt(c->GetPackageRoutines(unitPackage()), name.c_str()) : nullptr;
    if (!r) throw SyntaxCondition("43.1", "Could not find routine \"" + name + "\"", false);
    RexxArrayObject list = c->NewArray(args.size());
    for (std::size_t i = 0; i < args.size(); ++i) c->ArrayPut(list, HostObject::toRexx(c, args[i]), i + 1);
    RexxObjectPtr result = c->CallRoutine(static_cast<RexxRoutineObject>(r), list);
    if (c->CheckCondition()) raisePending(c);
    if (!result) return std::nullopt;
    return wrap(c, result);
}
inline Value callValue(const std::string &name, const std::vector<Value> &args) {
    MessageResult r = callRoutine(name, args);
    if (!r) throw SyntaxCondition("44.1", "Function \"" + name + "\" did not return data", false);
    return *r;
}
inline void callInstruction(Variables &vars, const std::string &name, const std::vector<Value> &args) {
    MessageResult r = callRoutine(name, args);
    if (r) set(vars, "RESULT", *r); else drop(vars, "RESULT");
}

}}
#endif
