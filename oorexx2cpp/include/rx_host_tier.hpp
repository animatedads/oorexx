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
    // Program end: like the rexx command, wait for activities still running in the interpreter (methods that
    // REPLYed, START-ed messages) before the instance goes away. Static destruction runs after main's locals are gone;
    // every static that holds an interpreter reference was constructed after this Session, so it is released first.
    ~Session() { if (inst_) inst_->Terminate(); }
    RexxInstance *inst_ = nullptr;
    RexxThreadContext *mainCtx_ = nullptr;
    std::thread::id mainThread_;
};

// Turn the interpreter's pending condition into the compiler's SyntaxCondition ("Error 97.1: text").
[[noreturn]] inline void raisePending(RexxThreadContext *c) {
    RexxCondition cd;
    c->DecodeConditionInfo(c->GetConditionInfo(), &cd);
    std::string text = (cd.message && c->IsString(cd.message)) ? c->ObjectToStringValue(cd.message) : "";
    const std::string code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
    c->ClearCondition();
    if (code == "97.1") throw NoMethod(text);
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
        if (auto st = std::dynamic_pointer_cast<StemObject>(v.object)) {
            // A compiled stem object crosses once: it becomes an interpreter stem holding its contents, and the native
            // object forwards to that stem from then on, so both sides keep sharing one stem.
            std::lock_guard<rx::SpinLock> g(st->lock);
            if (st->remote) {
                if (auto h = std::dynamic_pointer_cast<HostObject>(st->remote)) return h->handle;
                throw std::runtime_error("stem object is bound to a non-interpreter object");
            }
            RexxStemObject stem = c->NewStem(st->name.c_str());
            auto host = std::make_shared<HostObject>(stem);
            if (st->dflt) {
                RexxArrayObject one = c->ArrayOfOne(toRexx(c, *st->dflt));
                c->SendMessage(stem, "[]=", one);
                if (c->CheckCondition()) raisePending(c);
            }
            st->takeElements([&](const std::string &tail, const Value &v) { c->SetStemElement(stem, tail.c_str(), toRexx(c, v)); });
            st->dflt.reset();
            st->remote = host;
            return stem;
        }
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
        return r->isObject() ? r->object->display() : r->bytes.str();
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

// .CONTEXT in compiled main code. The compiled activation is not an interpreter activation, so only what is
// defined without one is answered: PACKAGE is the program's own package (the hosted unit, loaded under the
// program's path). Every other RexxContext method fails loudly rather than inventing activation state.
struct ContextObject final : ObjectDispatch {
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override {
        if (selector == "PACKAGE" && args.empty()) {
            if (!unitPackage()) throw std::runtime_error(".CONTEXT~PACKAGE: the program has no hosted package");
            return wrap(Session::get().ctx(), unitPackage());
        }
        throw SyntaxCondition("98.926", ".CONTEXT~" + selector + " is not implemented for compiled code", false);
    }
    std::string display() const override { return "a RexxContext"; }
};
inline Value contextObject() {
    static const Value ctx = Value::fromObject(std::make_shared<ContextObject>());
    return ctx;
}

// .LOCAL and .ENVIRONMENT: the interpreter's local and global environment directories.
inline Value environmentDirectory(const std::string &which) {
    RexxThreadContext *c = Session::get().ctx();
    RexxDirectoryObject d = which == "LOCAL" ? c->GetLocalEnvironment() : c->GetGlobalEnvironment();
    if (c->CheckCondition()) raisePending(c);
    if (!d) throw std::runtime_error("hosted tier: environment directory unavailable");
    return wrap(c, d);
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

// Packages of class libraries required by the compiled program (::REQUIRES "x" LIBRARY with native classes).
inline std::vector<RexxPackageObject> &libraryPackages() { static std::vector<RexxPackageObject> v; return v; }
inline bool requireClassLibrary(const std::string &name) {
    RexxThreadContext *c = Session::get().ctx();
    const std::string src = "::requires \"" + name + "\" library\n";
    RexxPackageObject p = c->LoadPackageFromData(("rx2cpp-library-" + name).c_str(), src.c_str(), src.size());
    if (c->CheckCondition()) raisePending(c);
    if (!p) throw std::runtime_error("hosted tier: cannot load library " + name);
    c->RequestGlobalReference(p);
    libraryPackages().push_back(p);
    return true;
}
inline const bool classLibraryLoaderInstalled = (classLibraryLoader() = &requireClassLibrary, true);
// A string message the native subset and the BIFs do not cover goes to the interpreter's String class.
inline std::optional<MessageResult> hostStringMessage(const Value &receiver, const std::string &selector, const std::vector<Value> &args) {
    RexxThreadContext *c = Session::get().ctx();
    RexxObjectPtr str = c->String(receiver.bytes.data(), receiver.bytes.size());
    RexxArrayObject list = c->NewArray(args.size());
    for (std::size_t i = 0; i < args.size(); ++i) c->ArrayPut(list, HostObject::toRexx(c, args[i]), i + 1);
    RexxObjectPtr result = c->SendMessage(str, selector.c_str(), list);
    if (c->CheckCondition()) raisePending(c);
    if (!result) return MessageResult(std::nullopt);
    return MessageResult(wrap(c, result));
}
inline const bool hostStringMessageInstalled = (stringHostExtension() = &hostStringMessage, true);

// .NAME environment symbols that name a class: the loaded unit's classes first, then the interpreter's.
inline Value findClass(const std::string &name) {
    RexxThreadContext *c = Session::get().ctx();
    if (unitPackage()) {
        RexxClassObject own = c->FindPackageClass(unitPackage(), name.c_str());   // own and ::REQUIRES-imported classes
        if (c->CheckCondition()) c->ClearCondition();
        if (own) return Value::fromObject(std::make_shared<HostObject>(static_cast<RexxObjectPtr>(own)));
    }
    for (RexxPackageObject lib : libraryPackages()) {
        RexxClassObject own = c->FindPackageClass(lib, name.c_str());
        if (c->CheckCondition()) c->ClearCondition();
        if (own) return Value::fromObject(std::make_shared<HostObject>(static_cast<RexxObjectPtr>(own)));
    }
    RexxClassObject cls = c->FindClass(name.c_str());
    if (c->CheckCondition()) c->ClearCondition();
    if (!cls) throw SyntaxCondition("98.926", "hosted tier: no interpreter class named ." + name, false);
    return Value::fromObject(std::make_shared<HostObject>(static_cast<RexxObjectPtr>(cls)));
}

inline const bool hostedClassLookupInstalled = (hostedClassLookup() = &findClass, true);

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

// INTERPRET: the code string runs in the embedded interpreter with a copy of the activation's simple variables and
// NUMERIC settings; afterwards every variable (new, changed, dropped) and the NUMERIC settings are copied back.
// Not implemented (fail closed at run time, never silently wrong): stem/compound variables, EXPOSEd variables,
// native objects held in variables, and interpreted code that leaves the wrapper (RETURN, EXIT, SIGNAL, LEAVE).
inline const char *interpretWrapper() {
    return
        "::routine rxinterp\n"
        "  use arg _rx_code, _rx_in, _rx_d, _rx_f, _rx_fm\n"
        "  do _rx_n over _rx_in~allIndexes\n"
        "    _rx_x = value(_rx_n, _rx_in[_rx_n])\n"
        "  end\n"
        "  numeric digits _rx_d\n"
        "  numeric fuzz _rx_f\n"
        "  numeric form value _rx_fm\n"
        "  interpret _rx_code\n"
        "  _rx_out = .array~new\n"
        "  _rx_v = .context~variables\n"
        "  do _rx_n over _rx_v~allIndexes\n"
        "    if _rx_n~left(4) \\== '_RX_' then do\n"
        "      _rx_out~append(_rx_n)\n"
        "      _rx_out~append(_rx_v[_rx_n])\n"
        "    end\n"
        "  end\n"
        "  _rx_out~append('_RX_D'); _rx_out~append(digits())\n"
        "  _rx_out~append('_RX_F'); _rx_out~append(fuzz())\n"
        "  _rx_out~append('_RX_FM'); _rx_out~append(form())\n"
        "  return _rx_out\n";
}
inline void interpret(Variables &vars, const Value &code) {
    if (code.isObject()) throw std::runtime_error("INTERPRET of an object is not implemented");
    if (!vars.exposed.empty()) throw std::runtime_error("INTERPRET with EXPOSEd variables is not implemented");
    RexxThreadContext *c = Session::get().ctx();
    static RexxRoutineObject routine = nullptr;
    if (!routine) {
        const std::string src = interpretWrapper();
        RexxPackageObject p = c->LoadPackageFromData("rx2cpp_interpret", src.c_str(), src.size());
        if (c->CheckCondition()) raisePending(c);
        c->RequestGlobalReference(p);
        routine = static_cast<RexxRoutineObject>(c->DirectoryAt(c->GetPackageRoutines(p), "RXINTERP"));
        c->RequestGlobalReference(routine);
    }
    RexxDirectoryObject in = c->NewDirectory();
    std::vector<std::string> before;
    forEachVariable(vars, [&](const std::string &name, const Value &value) {
        if (name.find('.') != std::string::npos)
            throw std::runtime_error("INTERPRET with stem or compound variables is not implemented");
        c->DirectoryPut(in, HostObject::toRexx(c, value), name.c_str());
        before.push_back(name);
    });
    RexxArrayObject a = c->NewArray(5);
    c->ArrayPut(a, c->String(code.bytes.data(), code.bytes.size()), 1);
    c->ArrayPut(a, in, 2);
    c->ArrayPut(a, c->String(std::to_string(vars.numeric.digits).c_str()), 3);
    c->ArrayPut(a, c->String(std::to_string(vars.numeric.fuzz).c_str()), 4);
    c->ArrayPut(a, c->String(vars.numeric.engineering ? "ENGINEERING" : "SCIENTIFIC"), 5);
    RexxObjectPtr r = c->CallRoutine(routine, a);
    if (c->CheckCondition()) raisePending(c);
    if (!r || !c->IsOfType(r, "ARRAY"))
        throw std::runtime_error("INTERPRET of RETURN, EXIT, SIGNAL or LEAVE is not implemented");
    RexxArrayObject out = static_cast<RexxArrayObject>(r);
    std::unordered_map<std::string, Value> after;
    const size_t n = c->ArrayItems(out);
    for (size_t i = 1; i + 1 <= n; i += 2) {
        RexxObjectPtr nm = c->ArrayAt(out, i), val = c->ArrayAt(out, i + 1);
        if (!nm || !val) continue;
        after.insert_or_assign(std::string(c->ObjectToStringValue(nm)), wrap(c, val));
    }
    for (const std::string &name : before) if (!after.count(name)) drop(vars, name);
    variablesErased();
    for (auto &kv : after) {
        if (kv.first == "_RX_D") vars.numeric.digits = std::stoul(kv.second.bytes);
        else if (kv.first == "_RX_F") vars.numeric.fuzz = std::stoul(kv.second.bytes);
        else if (kv.first == "_RX_FM") vars.numeric.engineering = kv.second.bytes == "ENGINEERING";
        else set(vars, kv.first, kv.second);
    }
}

}}
#endif
