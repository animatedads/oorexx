#pragma once
#include <cstdio>
// Real interpreter objects as rx::Value. One wrapper, two backends:
//  RX2CPP_KERNEL   : the interpreter compiled into the program (rx_kernel_bif.cpp)
//  RX2CPP_HOST_API : the interpreter that loaded this library (public oorexxapi.h, current thread context)
// Either way messages go to the interpreter's own dispatch and results are its own objects: no marshalling.
#if defined(RX2CPP_KERNEL) || defined(RX2CPP_HOST_API)
#include "minirexx_runtime.hpp"
#include <csignal>
#ifdef RX2CPP_KERNEL
#include "rx_kernel_bif.h"
namespace rxobj {
using Arg = rxkernel::Arg; using Result = rxkernel::Result;
inline void *findClass(const std::string &n) { return rxkernel::findClass(n); }
inline void release(void *h) { rxkernel::release(h); }
inline void *environmentObject(const std::string &) { return nullptr; }
inline void *environmentEntry(const std::string &) { return nullptr; }
inline void *selfHandle() { return nullptr; }   // the kernel backend has no receiver
inline void *nilObject() { return rxkernel::nil(); }
inline void *stringHandle(const std::string &) { throw std::runtime_error("interpreter String fallback is not available in kernel mode"); }
inline bool send(void *t, const std::string &s, const std::vector<Arg> &a, Result &r, std::string &c, std::string &x) {
    return rxkernel::send(t, s, a, r, c, x);
}
}
#else
#include <oorexxapi.h>
#include <mutex>
#include <typeinfo>
#include <cstdlib>
#include <pwd.h>
#include <sys/time.h>
#include <ctime>
#include <unistd.h>
#include <map>
namespace rx { inline std::shared_ptr<ObjectDispatch> takeKeptCondition(); }
namespace rxobj {
struct Arg { void *obj = nullptr; std::string bytes; bool omitted = false; };
struct Result { int kind = 0; std::string bytes; void *obj = nullptr; };
inline thread_local RexxThreadContext *current = nullptr;
inline thread_local RexxObjectPtr currentSelf = NULLOBJECT;
// Set by every native method/routine entry for the duration of the call (self is NULLOBJECT in routines).
struct Scope {
    RexxThreadContext *previous; RexxObjectPtr previousSelf;
    explicit Scope(RexxThreadContext *c, RexxObjectPtr self = NULLOBJECT)
        : previous(current), previousSelf(currentSelf) { current = c; currentSelf = self; }
    ~Scope() { current = previous; currentSelf = previousSelf; }
};
// Every object an API call returns stays referenced until the native method returns. A long-running compiled method makes
// millions of temporaries, so each is dropped as soon as it has been used.
struct LocalRefs {
    RexxThreadContext *t; std::vector<RexxObjectPtr> objs;
    explicit LocalRefs(RexxThreadContext *c) : t(c) {}
    RexxObjectPtr operator()(RexxObjectPtr o) { objs.push_back(o); return o; }
    ~LocalRefs() { for (RexxObjectPtr o : objs) if (o != NULLOBJECT) t->ReleaseLocalReference(o); }
};
inline void *selfHandle() {
    if (!current || currentSelf == NULLOBJECT) return nullptr;
    return (void *)current->RequestGlobalReference(currentSelf);
}
inline void *stringHandle(const std::string &bytes) {
    RexxThreadContext *t = current;
    if (!t) throw std::runtime_error("interpreter object used outside a native entry");
    RexxStringObject str = t->NewString(bytes.data(), bytes.size());
    void *h = (void *)t->RequestGlobalReference((RexxObjectPtr)str);
    t->ReleaseLocalReference((RexxObjectPtr)str);
    return h;
}
inline void *nilObject() { return current ? (void *)current->Nil() : nullptr; }
inline RexxThreadContext *need() {
    if (!current) throw std::runtime_error("interpreter object used outside a native entry");
    return current;
}
inline void *findClass(const std::string &name) {
    RexxThreadContext *t = need();
    RexxClassObject c = t->FindClass(name.c_str());
    if (c == NULLOBJECT) { t->ClearCondition(); return nullptr; }
    void *h = (void *)t->RequestGlobalReference((RexxObjectPtr)c);
    t->ReleaseLocalReference((RexxObjectPtr)c);   // a long native call keeps every unreleased local reference
    return h;
}
// .LOCAL / .ENVIRONMENT are environment directories, not classes.
inline void *environmentObject(const std::string &name) {
    RexxThreadContext *t = need();
    RexxObjectPtr d = NULLOBJECT;
    if (name == "LOCAL") d = (RexxObjectPtr)t->GetLocalEnvironment();
    else if (name == "ENVIRONMENT") d = (RexxObjectPtr)t->GetGlobalEnvironment();
    if (d == NULLOBJECT) return nullptr;
    return (void *)t->RequestGlobalReference(d);
}
// The package that declares a native library's classes (set by its loader): .CONTEXT~PACKAGE, package-local symbols.
inline RexxObjectPtr &libraryPackage() { static RexxObjectPtr p = NULLOBJECT; return p; }
// An interpreter routine for compiled code to run: created in the library's declaration package when there is one, so
// it resolves names as the compiled code's own package would (public routines and classes of its ::REQUIRES, e.g. PP of
// ooTest.frm); otherwise a routine of its own.
inline RexxRoutineObject packageRoutine(RexxThreadContext *t, const char *name, const std::string &source) {
    if (libraryPackage() == NULLOBJECT) return t->NewRoutine(name, source.c_str(), source.size());
    RexxObjectPtr routineClass = (RexxObjectPtr)t->FindClass("ROUTINE");
    RexxArrayObject lines = t->NewArray(0);
    std::size_t from = 0;
    while (from <= source.size()) {
        std::size_t nl = source.find('\n', from);
        if (nl == std::string::npos) nl = source.size();
        t->ArrayAppend(lines, (RexxObjectPtr)t->NewString(source.data() + from, nl - from));
        from = nl + 1;
    }
    RexxArrayObject args = t->ArrayOfThree((RexxObjectPtr)t->String(name), (RexxObjectPtr)lines, libraryPackage());
    RexxObjectPtr r = t->SendMessage(routineClass, "NEW", args);
    if (t->CheckCondition()) { t->ClearCondition(); return NULLOBJECT; }
    return (RexxRoutineObject)r;
}
// An environment symbol that is not a class: the package's LOCAL directory, then .local, then .environment.
inline void *environmentEntry(const std::string &name) {
    RexxThreadContext *t = need();
    // Every local reference made here is released: inside one long native call they would pile up in its table.
    LocalRefs temps(t);
    RexxObjectPtr o = NULLOBJECT;
    if (libraryPackage() != NULLOBJECT) {
        RexxObjectPtr local = temps(t->SendMessage0(libraryPackage(), "LOCAL"));
        if (t->CheckCondition()) t->ClearCondition();
        else if (local != NULLOBJECT) o = temps(t->SendMessage1(local, "[]", temps((RexxObjectPtr)t->String(name.c_str()))));
        if (o == t->Nil()) o = NULLOBJECT;
    }
    if (o == NULLOBJECT) o = temps(t->DirectoryAt((RexxDirectoryObject)temps((RexxObjectPtr)t->GetLocalEnvironment()), name.c_str()));
    if (o == NULLOBJECT) o = temps(t->DirectoryAt((RexxDirectoryObject)temps((RexxObjectPtr)t->GetGlobalEnvironment()), name.c_str()));
    if (t->CheckCondition()) t->ClearCondition();
    if (o == NULLOBJECT) return nullptr;
    return (void *)t->RequestGlobalReference(o);
}
// RX2CPP_REF_STATS=1: global references taken by sends, released, and dropped without a context (leaked); printed at exit.
struct RefStats {
    std::atomic<unsigned long> taken{0}, released{0}, dropped{0};
    bool on = std::getenv("RX2CPP_REF_STATS") != nullptr;
    ~RefStats() { if (on) std::fprintf(stderr, "rx2cpp refs: taken %lu released %lu dropped %lu\n", taken.load(), released.load(), dropped.load()); }
};
inline RefStats &refStats() { static RefStats s; return s; }
inline void release(void *h) {
    if (!h) return;
    if (current) { current->ReleaseGlobalReference((RexxObjectPtr)h); if (refStats().on) ++refStats().released; }
    else if (refStats().on) ++refStats().dropped;
}
// A value that crosses as a plain string: a .String (or the interpreter's internal integer/number forms of it). An instance of
// a String SUBCLASS (json.cls JsonString, ...) is an object and keeps its class.
inline bool isPlainString(RexxThreadContext *t, RexxObjectPtr o) {
    if (t->IsString(o)) return true;
    static thread_local RexxObjectPtr stringClass = NULLOBJECT;
    if (stringClass == NULLOBJECT) stringClass = t->RequestGlobalReference((RexxObjectPtr)t->FindClass("STRING"));
    // Instance test against the cached class object, not a by-name class lookup per result.
    if (!t->IsInstanceOf(o, (RexxClassObject)stringClass)) return false;
    RexxObjectPtr cls = t->SendMessage0(o, "CLASS");
    if (t->CheckCondition()) { t->ClearCondition(); return true; }
    if (cls != NULLOBJECT) t->ReleaseLocalReference(cls);
    return cls == stringClass;
}
// The substitution values (ADDITIONAL) of the last interpreter condition a send turned into a C++ exception, so the
// condition can be raised again unchanged when it leaves compiled code.
inline std::vector<std::string> &lastAdditional() { static thread_local std::vector<std::string> v; return v; }
// The interpreter's condition object (a global reference) of the last condition the bridge cleared to throw it in C++;
// the thrower attaches it to the exception (takeKeptCondition), so a compiled SIGNAL ON trap sees the real object.
inline void *&keptCondition() { static thread_local void *h = nullptr; return h; }
inline void keepCondition(RexxThreadContext *t) {
    if (keptCondition()) { t->ReleaseGlobalReference((RexxObjectPtr)keptCondition()); keptCondition() = nullptr; }
    RexxDirectoryObject info = t->GetConditionInfo();
    if (info != NULLOBJECT) keptCondition() = (void *)t->RequestGlobalReference((RexxObjectPtr)info);
}
inline void captureAdditional(RexxThreadContext *t, RexxDirectoryObject info) {
    lastAdditional().clear();
    if (info == NULLOBJECT) return;
    RexxObjectPtr add = t->DirectoryAt(info, "ADDITIONAL");
    if (add == NULLOBJECT || !t->IsArray(add)) return;
    const size_t n = t->ArraySize((RexxArrayObject)add);
    for (size_t i = 1; i <= n; ++i) {
        RexxObjectPtr o = t->ArrayAt((RexxArrayObject)add, i);
        if (o == NULLOBJECT) { lastAdditional().push_back(std::string()); continue; }
        // An explicit ~STRING: the API's implicit conversion would raise NOSTRING when the caller traps ANY.
        RexxObjectPtr s = t->IsString(o) ? o : t->SendMessage0(o, "STRING");
        if (t->CheckCondition()) { t->ClearCondition(); s = NULLOBJECT; }
        lastAdditional().push_back(s == NULLOBJECT || !t->IsString(s) ? std::string() : std::string(t->ObjectToStringValue(s)));
    }
}
// A new interpreter Array of `size` slots holding `items` (items[i] at index i+1; an omitted Arg leaves a hole).
inline void *newArray(std::size_t size, const std::vector<Arg> &items) {
    RexxThreadContext *t = need();
    LocalRefs temps(t);
    RexxArrayObject arr = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(size));
    for (std::size_t i = 0; i < items.size(); i++) {
        const Arg &a = items[i];
        if (a.omitted) continue;
        t->ArrayPut(arr, a.obj ? (RexxObjectPtr)a.obj : temps((RexxObjectPtr)t->NewString(a.bytes.data(), a.bytes.size())), i + 1);
    }
    return (void *)t->RequestGlobalReference((RexxObjectPtr)arr);
}
// Store entries into an interpreter Directory in the given order (the same as [] = for each, without a send per entry).
inline void directoryPutAll(void *dir, const std::vector<std::string> &keys, const std::vector<Arg> &values) {
    RexxThreadContext *t = need();
    for (std::size_t i = 0; i < keys.size(); i++) {
        LocalRefs temps(t);
        const Arg &a = values[i];
        RexxObjectPtr value = a.obj ? (RexxObjectPtr)a.obj : temps((RexxObjectPtr)t->NewString(a.bytes.data(), a.bytes.size()));
        if (keys[i].find('\0') == std::string::npos) t->DirectoryPut((RexxDirectoryObject)dir, value, keys[i].c_str());
        else temps(t->SendMessage2((RexxObjectPtr)dir, "[]=", value, temps((RexxObjectPtr)t->NewString(keys[i].data(), keys[i].size()))));
    }
}
// The interpreter's condition object for SYNTAX `code` with these substitutions, made by the interpreter itself (a tiny
// routine that RAISEs it under SIGNAL ON SYNTAX): CODE, RC, MESSAGE, ERRORTEXT, ADDITIONAL, DESCRIPTION are exact.
inline void *conditionObject(const std::string &code, const std::vector<Arg> &subs) {
    RexxThreadContext *t = need();
    static thread_local RexxObjectPtr routine = NULLOBJECT;
    if (routine == NULLOBJECT) {
        static const char source[] =
            "use arg code, subs\n"
            "signal on syntax\n"
            "if subs~items = 0 then raise syntax (code)\n"
            "raise syntax (code) additional (subs)\n"
            "syntax: return condition('O')\n";
        RexxRoutineObject made = t->NewRoutine("rx2cpp_condition", source, sizeof(source) - 1);
        if (made == NULLOBJECT || t->CheckCondition()) { t->ClearCondition(); throw std::runtime_error("cannot build a condition object"); }
        routine = t->RequestGlobalReference((RexxObjectPtr)made);
    }
    LocalRefs temps(t);
    RexxArrayObject array = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(subs.size()));
    for (std::size_t i = 0; i < subs.size(); i++)
        t->ArrayPut(array, subs[i].obj ? (RexxObjectPtr)subs[i].obj : temps((RexxObjectPtr)t->NewString(subs[i].bytes.data(), subs[i].bytes.size())), i + 1);
    RexxArrayObject args = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(2));
    t->ArrayPut(args, temps((RexxObjectPtr)t->NewString(code.data(), code.size())), 1);
    t->ArrayPut(args, (RexxObjectPtr)array, 2);
    RexxObjectPtr r = temps(t->CallRoutine((RexxRoutineObject)routine, args));
    if (t->CheckCondition() || r == NULLOBJECT) { t->ClearCondition(); throw std::runtime_error("cannot build a condition object for " + code); }
    return (void *)t->RequestGlobalReference(r);
}
// PARSE VERSION of the interpreter running this library (asked once).
inline std::string interpreterVersion() {
    static std::string version;
    static std::once_flag once;
    std::call_once(once, [] {
        RexxThreadContext *t = need();
        static const char source[] = "parse version v\nreturn v\n";
        RexxRoutineObject r = t->NewRoutine("rx2cpp_version", source, sizeof(source) - 1);
        RexxObjectPtr v = r == NULLOBJECT ? NULLOBJECT : t->CallRoutine(r, t->NewArray(0));
        if (t->CheckCondition() || v == NULLOBJECT) { t->ClearCondition(); throw std::runtime_error("cannot read PARSE VERSION"); }
        version = t->ObjectToStringValue(v);
    });
    return version;
}
inline void bifStat(const std::string &name);
inline bool send(void *target, const std::string &selector, const std::vector<Arg> &args, Result &out,
                 std::string &code, std::string &text) {
    RexxThreadContext *t = need();
    static const bool sendStats = std::getenv("RX2CPP_BIF_STATS") != nullptr;
    if (sendStats) {
        std::string cls = t->ObjectToStringValue(t->SendMessage0((RexxObjectPtr)target, "CLASS"));
        // A class object: name the class itself (.Directory~new, .MathInteger~coerce, ...).
        if (cls == "The Class class") cls = std::string("class ") + t->ObjectToStringValue(t->SendMessage0((RexxObjectPtr)target, "ID"));
        bifStat("~" + selector + " to " + cls);
        // RX2CPP_TRAP_SEND="~NEW to class X": stop in the debugger at that send (where does it come from?).
        static const char *trap = std::getenv("RX2CPP_TRAP_SEND");
        if (trap && ("~" + selector + " to " + cls) == trap) std::raise(SIGTRAP);
    }
    LocalRefs temps(t);
    auto argObj = [&](const Arg &a) -> RexxObjectPtr {
        return a.obj ? (RexxObjectPtr)a.obj : temps((RexxObjectPtr)t->NewString(a.bytes.data(), a.bytes.size()));
    };
    bool holes = false;
    for (const Arg &a : args) holes = holes || a.omitted;
    RexxObjectPtr r;
    // Up to two arguments and no omitted ones: no argument array is built.
    if (!holes && args.empty()) r = temps(t->SendMessage0((RexxObjectPtr)target, selector.c_str()));
    else if (!holes && args.size() == 1) r = temps(t->SendMessage1((RexxObjectPtr)target, selector.c_str(), argObj(args[0])));
    else if (!holes && args.size() == 2) {
        RexxObjectPtr a1 = argObj(args[0]), a2 = argObj(args[1]);
        r = temps(t->SendMessage2((RexxObjectPtr)target, selector.c_str(), a1, a2));
    } else {
        RexxArrayObject arr = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(args.size()));
        // Omitted arguments stay holes at their positions (an array hole is an omitted ARG).
        for (std::size_t i = 0; i < args.size(); i++) {
            const Arg &a = args[i];
            if (a.omitted) continue;
            t->ArrayPut(arr, argObj(a), i + 1);
        }
        r = temps(t->SendMessage((RexxObjectPtr)target, selector.c_str(), arr));
    }
    if (t->CheckCondition()) {
        RexxDirectoryObject info = t->GetConditionInfo();
        RexxCondition cd; t->DecodeConditionInfo(info, &cd);
        code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        text = (cd.message && t->IsString(cd.message)) ? t->ObjectToStringValue(cd.message) : "error in message " + selector;
        keepCondition(t);          // the condition object itself, before anything else runs in the interpreter
        t->ClearCondition();
        captureAdditional(t, info);   // sends ~STRING: only with no condition pending
        return false;
    }
    if (r == NULLOBJECT) { out.kind = 0; return true; }
    if (isPlainString(t, r)) {
        RexxStringObject str = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(r));
        out.kind = 1; out.bytes.assign(t->StringData(str), t->StringLength(str));
    } else { out.kind = 2; out.obj = (void *)t->RequestGlobalReference(r); if (refStats().on) ++refStats().taken; }
    return true;
}
// RX2CPP_BIF_STATS=1: count the BIFs/String methods that went to the interpreter (printed at exit): the next native candidates.
inline void bifStat(const std::string &name) {
    static const bool stats = std::getenv("RX2CPP_BIF_STATS") != nullptr;
    if (!stats) return;
    static std::mutex m;
    static std::map<std::string, std::size_t> counts;
    std::lock_guard<std::mutex> g(m);
    static const bool registered = (std::atexit([] { for (auto &c : counts) std::fprintf(stderr, "rx2cpp via interpreter: %s %zu\n", c.first.c_str(), c.second); }), true);
    (void)registered;
    ++counts[name];
}
// Delegated BIFs run in the host interpreter: a tiny routine per (name, omission pattern, NUMERIC settings), cached.
// receiver~selector(args) for a String receiver, executed under the caller's NUMERIC settings (omitted arguments stay omitted).
inline bool sendStringNumeric(const std::string &receiver, const std::string &selector, const std::vector<Arg> &args,
                              std::size_t digits, std::size_t fuzz, bool engineering, Result &out,
                              std::string &code, std::string &text) {
    RexxThreadContext *t = need();
    LocalRefs temps(t);
    static thread_local std::unordered_map<std::string, RexxRoutineObject> cache;
    std::string source = "numeric digits " + std::to_string(digits) + "; numeric fuzz " + std::to_string(fuzz) +
                         "; numeric form " + (engineering ? "engineering" : "scientific") + "; return arg(1)~" + selector + "(";
    for (std::size_t i = 0; i < args.size(); i++) {
        if (i) source += ",";
        if (!args[i].omitted) source += "arg(" + std::to_string(i + 2) + ")";
    }
    source += ")";
    RexxRoutineObject routine;
    auto it = cache.find(source);
    if (it == cache.end()) {
        routine = t->NewRoutine("rx2cpp_msg", source.c_str(), source.size());
        if (routine == NULLOBJECT) { code = "98.900"; text = "cannot create message routine for " + selector; t->ClearCondition(); return false; }
        t->RequestGlobalReference((RexxObjectPtr)routine);
        cache.emplace(source, routine);
    } else routine = it->second;
    RexxArrayObject arr = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(args.size() + 1));
    t->ArrayPut(arr, temps((RexxObjectPtr)t->NewString(receiver.data(), receiver.size())), 1);
    for (std::size_t i = 0; i < args.size(); i++) {
        if (args[i].omitted) continue;
        t->ArrayPut(arr, args[i].obj ? (RexxObjectPtr)args[i].obj : temps((RexxObjectPtr)t->NewString(args[i].bytes.data(), args[i].bytes.size())), i + 2);
    }
    RexxObjectPtr r = temps(t->CallRoutine(routine, arr));
    if (t->CheckCondition()) {
        RexxCondition cd; t->DecodeConditionInfo(t->GetConditionInfo(), &cd);
        code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        text = (cd.message && t->IsString(cd.message)) ? t->ObjectToStringValue(cd.message) : "error in message " + selector;
        keepCondition(t);
        t->ClearCondition();
        return false;
    }
    if (r == NULLOBJECT) { out.kind = 0; return true; }
    if (isPlainString(t, r)) {
        RexxStringObject str = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(r));
        out.kind = 1; out.bytes.assign(t->StringData(str), t->StringLength(str));
    } else { out.kind = 2; out.obj = (void *)t->RequestGlobalReference(r); if (refStats().on) ++refStats().taken; }
    return true;
}
inline std::string callBif(const std::string &name, const std::vector<std::pair<bool, std::string>> &args,
                           std::size_t digits, std::size_t fuzz, bool engineering, const std::string &directives = std::string()) {
    RexxThreadContext *t = need();
    LocalRefs temps(t);
    bifStat(name);
    static thread_local std::unordered_map<std::string, RexxRoutineObject> cache;
    std::string source = "numeric digits " + std::to_string(digits) + "; numeric fuzz " + std::to_string(fuzz) +
                         "; numeric form " + (engineering ? "engineering" : "scientific") + "; return " + name + "(";
    for (std::size_t i = 0; i < args.size(); i++) {
        if (i) source += ",";
        if (args[i].first) source += "arg(" + std::to_string(i + 1) + ")";
    }
    source += ")";
    if (!directives.empty()) source += "\n" + directives + "\n";
    auto it = cache.find(source);
    RexxRoutineObject routine;
    if (it == cache.end()) {
        routine = t->NewRoutine("rx2cpp_bif", source.c_str(), source.size());
        if (routine == NULLOBJECT) throw std::runtime_error("cannot create BIF routine for " + name);
        t->RequestGlobalReference((RexxObjectPtr)routine);
        cache.emplace(source, routine);
    } else routine = it->second;
    RexxArrayObject arr = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(args.size()));
    for (const auto &a : args) {
        if (a.first) t->ArrayAppend(arr, temps((RexxObjectPtr)t->NewString(a.second.data(), a.second.size())));
        else t->ArrayAppend(arr, (RexxObjectPtr)t->Nil());
    }
    RexxObjectPtr r = temps(t->CallRoutine(routine, arr));
    if (t->CheckCondition()) {
        RexxCondition cd; t->DecodeConditionInfo(t->GetConditionInfo(), &cd);
        std::string code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        std::string text = (cd.message && t->IsString(cd.message)) ? t->ObjectToStringValue(cd.message) : "error in " + name;
        RexxDirectoryObject info = t->GetConditionInfo();
        keepCondition(t);
        t->ClearCondition();
        captureAdditional(t, info);   // the message substitutions, no condition pending
        rx::SyntaxCondition raised(code, text, false);
        for (const std::string &a : lastAdditional()) raised.substitutions.push_back(rx::Value::string(a));
        raised.conditionObject = rx::takeKeptCondition();
        throw raised;
    }
    if (r == NULLOBJECT) return std::string();
    RexxStringObject str = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(r));
    return std::string(t->StringData(str), t->StringLength(str));
}
}
#endif
namespace rx {
// A compiled instance that has no interpreter object yet (dual representation). Handing it to the interpreter creates one.
struct NativeRefBase : ObjectDispatch {
    virtual void *materialize() = 0;   // the interpreter object (valid for the current native call)
};
// Hooks installed by a generated library: package classes created natively, and SELF of a natively dispatched method.
inline std::optional<Value> (*packageClassHook)(const std::string &) = nullptr;
// An interpreter object that is a live instance of one of this library's compiled classes comes back as that native
// instance (its compiled methods then run directly). The hook takes over the global reference it is given.
inline std::optional<Value> (*adoptHook)(void *globalRef) = nullptr;
inline std::optional<Value> (*selfObjectHook)() = nullptr;
struct EnvObject final : ObjectDispatch {
    void *handle;
    explicit EnvObject(void *h) : handle(h) {}
    ~EnvObject() override { rxobj::release(handle); }
    // A global reference from the interpreter as a Value: a compiled instance of this library, or an interpreter object.
    static Value adopt(void *globalRef) {
        if (adoptHook) if (auto v = adoptHook(globalRef)) return std::move(*v);
        return Value::fromObject(std::make_shared<EnvObject>(globalRef));
    }
    static Value wrap(const rxobj::Result &r) {
        if (r.kind == 2) return adopt(r.obj);
        return Value::string(r.bytes);
    }
    // A compiled stem object crosses once: it becomes an interpreter stem holding its contents, and the compiled object
    // forwards to that stem from then on (both sides share one stem), as in the hosted tier.
    static void *stemHandle(StemObject &st) {
        std::lock_guard<std::mutex> g(st.lock);
        if (st.remote) {
            if (auto *e = dynamic_cast<EnvObject *>(st.remote.get())) return e->handle;
            throw std::runtime_error("stem object is bound to a non-interpreter object");
        }
        RexxThreadContext *t = rxobj::need();
        rxobj::LocalRefs temps(t);
        RexxStemObject stem = t->NewStem(st.name.c_str());
        void *h = (void *)t->RequestGlobalReference((RexxObjectPtr)stem);
        auto one = [&](const Value &v) -> RexxObjectPtr {
            std::vector<rxobj::Arg> c; convert({v}, c);
            return c[0].obj ? (RexxObjectPtr)c[0].obj : temps((RexxObjectPtr)t->NewString(c[0].bytes.data(), c[0].bytes.size()));
        };
        if (st.dflt) {
            t->SendMessage1((RexxObjectPtr)stem, "[]=", one(*st.dflt));
            if (t->CheckCondition()) { t->ClearCondition(); throw std::runtime_error("cannot set the stem default"); }
        }
        for (const auto &e : st.tails) t->SetStemElement(stem, e.first.c_str(), one(e.second));
        st.tails.clear(); st.dflt.reset();
        st.remote = std::make_shared<EnvObject>(h);
        return h;
    }
    static void convert(const std::vector<Value> &args, std::vector<rxobj::Arg> &out) {
        for (const Value &v : args) {
            rxobj::Arg a;
            if (v.isObject()) {
                auto *k = dynamic_cast<EnvObject *>(v.object.get());
                if (!k && dynamic_cast<NilObject *>(v.object.get())) {
                    a.obj = rxobj::nilObject();
                    if (!a.obj) throw std::runtime_error(".NIL cannot be passed to interpreter messages here");
                    out.push_back(std::move(a));
                    continue;
                }
                if (!k) {
                    if (auto *st = dynamic_cast<StemObject *>(v.object.get())) {
                        a.obj = stemHandle(*st);
                        out.push_back(std::move(a));
                        continue;
                    }
                    if (auto *n = dynamic_cast<NativeRefBase *>(v.object.get())) {
                        a.obj = n->materialize();
                        out.push_back(std::move(a));
                        continue;
                    }
                    throw std::runtime_error(std::string("only interpreter objects can be passed to interpreter messages (") +
                                             typeid(*v.object).name() + ")");
                }
                if (k->handle == nullptr) a.omitted = true;   // rx::omittedArgument()
                else a.obj = k->handle;
            } else a.bytes = v.bytes;
            out.push_back(std::move(a));
        }
    }
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override {
        std::vector<rxobj::Arg> in; convert(args, in);
        rxobj::Result r; std::string code, text;
        if (!rxobj::send(handle, selector, in, r, code, text)) {
            if (code == "97.1") { NoMethod missing(text); missing.conditionObject = takeKeptCondition(); throw missing; }
            SyntaxCondition condition(code, text, false);
            for (const std::string &a : rxobj::lastAdditional()) condition.substitutions.push_back(Value::string(a));
            condition.conditionObject = takeKeptCondition();
            throw condition;
        }
        if (r.kind == 0) return std::nullopt;
        return wrap(r);
    }
    Value sendBinary(const std::string &selector, const Value &rhs) override {
        auto r = sendMessage(selector, {rhs});
        if (!r) throw std::runtime_error("operator message returned no value: " + selector);
        return *r;
    }
    Value sendUnary(const std::string &selector) override {
        auto r = sendMessage(selector, {});
        if (!r) throw std::runtime_error("operator message returned no value: " + selector);
        return *r;
    }
    std::string display() const override {
        std::vector<rxobj::Arg> none; rxobj::Result r; std::string code, text;
        if (!rxobj::send(handle, "STRING", none, r, code, text) || r.kind != 1)
            throw std::runtime_error("object has no string value");
        return r.bytes;
    }
};
#ifdef RX2CPP_HOST_API
// Install the interpreter String fallback (done at every native entry; cheap and idempotent).
inline MessageResult hostStringMessage(const Value &receiver, const std::string &selector, const std::vector<Value> &args) {
    // Only numeric-sensitive String methods need a routine that carries the caller's NUMERIC settings (a routine call starts a
    // whole activity and is slow); all others are a plain message send.
    static const std::unordered_set<std::string> numericSensitive{
        "ABS","CEILING","FLOOR","ROUND","TRUNC","FORMAT","SIGN","MAX","MIN","SQRT","C2D","D2C","X2D","D2X","B2X","X2B","DATATYPE",
        "+","-","*","/","%","//","**","=","\\=","<",">","<=",">=","<>","><","==","\\==","COMPARE","ISINTEGER","ISWHOLE"};
    std::string upperSelector = selector;
    for (char &c : upperSelector) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
    // RX2CPP_STRING_FALLBACK_STATS=1 prints, at exit, which String messages still reach the interpreter (the next BIFs to mirror).
    struct Stats {
        std::unordered_map<std::string, unsigned long> counts; bool on = std::getenv("RX2CPP_STRING_FALLBACK_STATS") != nullptr;
        ~Stats() { if (on) for (auto &kv : counts) std::fprintf(stderr, "string fallback %s %lu\n", kv.first.c_str(), kv.second); }
    };
    static Stats stats;
    if (stats.on) stats.counts[upperSelector]++;
    if (!numericSensitive.count(upperSelector)) {
        EnvObject str(rxobj::stringHandle(receiver.bytes));
        return str.sendMessage(selector, args);
    }
    std::vector<rxobj::Arg> in; EnvObject::convert(args, in);
    const ActivationNumeric def;
    const ActivationNumeric &n = currentNumeric ? *currentNumeric : def;
    rxobj::Result r; std::string code, text;
    if (!rxobj::sendStringNumeric(receiver.bytes, selector, in, n.digits, n.fuzz, n.engineering, r, code, text)) {
        if (code == "97.1") throw NoMethod(text);
        throw SyntaxCondition(code, text, false);
    }
    if (r.kind == 0) return std::nullopt;
    return EnvObject::wrap(r);
}
inline const bool hostStringFallbackInstalled = (stringMessageFallback() = &hostStringMessage, true);
inline MessageResult hostNilMessage(const std::string &selector, const std::vector<Value> &args) {
    RexxThreadContext *t = rxobj::need();
    EnvObject nil((void *)t->RequestGlobalReference(t->Nil()));   // the interpreter's own .NIL (released with this wrapper)
    return nil.sendMessage(selector, args);
}
inline const bool hostNilFallbackInstalled = (nilMessageFallback() = &hostNilMessage, true);
#endif
#ifdef RX2CPP_HOST_API
inline Value envClass(const std::string &name);
// .CONTEXT inside a native library method: PACKAGE is the library's package; other RexxContext methods fail loudly
// (a compiled method has no interpreter activation to describe).
struct LibraryContext final : ObjectDispatch {
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &) override {
        if (selector == "PACKAGE" && rxobj::libraryPackage() != NULLOBJECT) {
            RexxThreadContext *t = rxobj::need();
            return Value::fromObject(std::make_shared<EnvObject>((void *)t->RequestGlobalReference(rxobj::libraryPackage())));
        }
        throw SyntaxCondition("98.926", ".CONTEXT~" + selector + " is not available in compiled code", false);
    }
    std::string display() const override { return "a RexxContext"; }
};
// The interpreter condition object kept by the last failing interpreter call (see rxobj::keepCondition).
inline std::shared_ptr<ObjectDispatch> takeKeptCondition() {
    void *h = rxobj::keptCondition();
    if (!h) return nullptr;
    rxobj::keptCondition() = nullptr;
    return std::make_shared<EnvObject>(h);
}
// ---- SIGNAL ON / OFF, labels and CONDITION() in a compiled activation (method or package routine) ----
// A library-specific way to recognise "a condition is pending in the interpreter" (the template's PendingCondition):
// returns the condition object and clears the condition.
inline std::shared_ptr<ObjectDispatch> (*pendingConditionHook)(const std::exception &) = nullptr;
struct RaisedCondition {
    std::string name = "SYNTAX";
    std::string code;
    std::vector<Value> substitutions;
    std::shared_ptr<ObjectDispatch> object;
};
inline bool numericCode(const std::string &c) {
    return !c.empty() && c.find('.') != std::string::npos && c.find_first_not_of("0123456789.") == std::string::npos;
}
// The condition an exception from compiled code stands for (false: not a condition, e.g. EXIT).
inline bool describeRaised(std::exception_ptr e, RaisedCondition &out) {
    try { std::rethrow_exception(e); }
    catch (const SyntaxCondition &c) {
        out.object = c.conditionObject;
        if (numericCode(c.code)) { out.code = c.code; out.substitutions = c.substitutions; }
        else { out.code = "98.900"; out.substitutions = {Value::string(c.what())}; }
        return true;
    }
    catch (const NoMethod &m) { out.object = m.conditionObject; out.code = "98.900"; out.substitutions = {Value::string(m.what())}; return true; }
    catch (const NotReadyCondition &n) { out.name = "NOTREADY"; out.object = n.conditionObject; return true; }
    catch (const SignalJump &) { return false; }
    catch (const std::exception &x) {
        if (pendingConditionHook) if (auto o = pendingConditionHook(x)) { out.object = o; return true; }
        out.code = "98.900"; out.substitutions = {Value::string(x.what())};
        return true;
    }
    catch (...) { return false; }
}
inline Value conditionEntry(const std::shared_ptr<ObjectDispatch> &object, const char *key) {
    MessageResult v = object->sendMessage("[]", {Value::string(key)});
    return v ? *v : nil();
}
struct MethodTraps {
    enum Kind { SYNTAX, ERROR, FAILURE, NOVALUE, NOTREADY, ANY, KINDS };
    bool on[KINDS] = {};
    int label[KINDS] = {};
    bool has = false;                          // a condition was trapped in this activation
    std::string name;
    std::shared_ptr<ObjectDispatch> object;
    MethodTraps *saved = nullptr;
    // The running activation's traps are known to the stream built-ins (NOTREADY), through its ActivationScope.
    MethodTraps() { if (ActivationScope *a = ActivationScope::current()) { saved = a->traps; a->traps = this; } }
    ~MethodTraps() { if (ActivationScope *a = ActivationScope::current()) if (a->traps == this) a->traps = saved; }
    MethodTraps(const MethodTraps &) = delete;
    MethodTraps &operator=(const MethodTraps &) = delete;
    // Is NOTREADY trapped in the running activation (SIGNAL ON NOTREADY, or ANY)?
    static bool notReadyArmed() {
        ActivationScope *a = ActivationScope::current();
        return a && a->traps && (a->traps->on[NOTREADY] || a->traps->on[ANY]);
    }
    static int kindOf(const std::string &c) {
        if (c == "SYNTAX") return SYNTAX;
        if (c == "ERROR") return ERROR;
        if (c == "FAILURE") return FAILURE;
        if (c == "NOVALUE") return NOVALUE;
        if (c == "NOTREADY") return NOTREADY;
        if (c == "ANY") return ANY;
        return -1;
    }
    void set(const char *c, int target) { const int k = kindOf(c); on[k] = true; label[k] = target; }
    void clear(const char *c) { on[kindOf(c)] = false; }
    // An exception reached the activation: the label to continue at (the trap is turned off), or -1 to let it go on.
    int fire(Variables &vars, std::size_t line, std::exception_ptr e) {
        RaisedCondition raised;
        if (!describeRaised(e, raised)) return -1;
        const int k = kindOf(raised.name);
        const int use = (k >= 0 && on[k]) ? k : (on[ANY] ? ANY : -1);
        if (use < 0) return -1;
        on[use] = false;
        if (!raised.object) {
            std::vector<rxobj::Arg> subs; EnvObject::convert(raised.substitutions, subs);
            raised.object = std::make_shared<EnvObject>(rxobj::conditionObject(raised.code, subs));
        }
        has = true;
        name = raised.name;
        object = raised.object;
        if (name == "SYNTAX" || name == "ERROR" || name == "FAILURE") set(vars, "RC", conditionEntry(object, "RC"));
        rx::set(vars, "SIGL", Value::string(std::to_string(line)));
        return label[use];
    }
    static void set(Variables &vars, const char *n, const Value &v) { rx::set(vars, n, v); }
    // CONDITION([option]) of this activation.
    Value condition(const std::optional<Value> &arg) const {
        char option = 'I';
        if (arg && !arg->isObject() && !arg->bytes.empty())
            option = static_cast<char>(std::toupper(static_cast<unsigned char>(arg->bytes[0])));
        switch (option) {
        case 'A': return has ? conditionEntry(object, "ADDITIONAL") : nil();
        case 'O': return has ? Value::fromObject(object) : nil();
        case 'C': return Value::string(has ? name : std::string());
        case 'I': return Value::string(has ? "SIGNAL" : "");
        case 'D': {
            if (!has) return Value::string(std::string());
            Value d = conditionEntry(object, "DESCRIPTION");
            return d.isObject() ? Value::string(std::string()) : d;
        }
        case 'S': {
            if (!has) return Value::string(std::string());
            const int k = kindOf(name);
            return Value::string(k >= 0 && on[k] ? "ON" : "OFF");
        }
        default: throw SyntaxCondition("40.904", "CONDITION option must be one of ACDIOS", false);
        }
    }
    // RAISE PROPAGATE: the trapped condition again, to the caller.
    [[noreturn]] void propagate() const {
        if (!has) throw SyntaxCondition("93.900", "RAISE PROPAGATE outside a condition trap", false);
        Value code = conditionEntry(object, "CODE");
        SyntaxCondition again(code.isObject() ? std::string("98.900") : code.bytes.str(), name, false);
        Value additional = conditionEntry(object, "ADDITIONAL");
        if (additional.isObject() && !dynamic_cast<NilObject *>(additional.object.get()))
            for (const Value &item : arrayItems(additional)) again.substitutions.push_back(item);
        again.conditionObject = object;
        throw again;
    }
};
// CONDITION() in an activation that traps nothing: no condition information.
inline Value noCondition(const std::optional<Value> &arg) {
    char option = 'I';
    if (arg && !arg->isObject() && !arg->bytes.empty())
        option = static_cast<char>(std::toupper(static_cast<unsigned char>(arg->bytes[0])));
    if (option == 'A' || option == 'O') return nil();
    return Value::string(std::string());
}
inline Value interpreterVersion() { return Value::string(rxobj::interpreterVersion()); }
// The interpreter's system name (first word of PARSE SOURCE: LINUX, WindowsNT, ...).
inline std::string interpreterSystem() {
    static std::string name;
    static std::once_flag once;
    std::call_once(once, [] {
        RexxThreadContext *t = rxobj::need();
        static const char source[] = "parse source s .\nreturn s\n";
        RexxRoutineObject r = t->NewRoutine("rx2cpp_system", source, sizeof(source) - 1);
        RexxObjectPtr v = r == NULLOBJECT ? NULLOBJECT : t->CallRoutine(r, t->NewArray(0));
        if (t->CheckCondition() || v == NULLOBJECT) { t->ClearCondition(); throw std::runtime_error("cannot read PARSE SOURCE"); }
        name = t->ObjectToStringValue(v);
    });
    return name;
}
inline Value libraryContext() { static const Value c = Value::fromObject(std::make_shared<LibraryContext>()); return c; }
// The method's own argument list as an interpreter array (omitted arguments stay empty slots): FORWARD's default ARGUMENTS.
inline Value argumentArray(const std::vector<std::optional<Value>> &args) {
    Value array = envClass("ARRAY");
    MessageResult made = array.object->sendMessage("NEW", {Value::string(std::to_string(args.size()))});
    if (!made) throw std::runtime_error("cannot create argument array");
    for (std::size_t i = 0; i < args.size(); ++i)
        if (args[i]) made->object->sendMessage("PUT", {*args[i], Value::string(std::to_string(i + 1))});
    return *made;
}
#endif
// An omitted argument slot (CALL f(,x) / obj~m(,x)).
inline Value omittedArgument() { return Value::fromObject(std::make_shared<EnvObject>(nullptr)); }
// SELF inside a native method is the receiver, as the interpreter sees it.
inline Value selfObject() {
    if (selfObjectHook) if (auto v = selfObjectHook()) return *v;
    void *h = rxobj::selfHandle();
    if (!h) throw std::runtime_error("SELF is not available here");
    return EnvObject::adopt(h);
}
// .NAME environment symbols resolve to the interpreter's own classes (.ARRAY, .DIRECTORY, .LIST, ...).
inline Value envClass(const std::string &name) {
    // Class objects live as long as the interpreter instance: resolve each name once per thread (FindClass is a full lookup).
    static thread_local std::unordered_map<std::string, Value> cache;
    auto it = cache.find(name);
    if (it != cache.end()) return it->second;
    if (packageClassHook) if (auto v = packageClassHook(name)) { cache.emplace(name, *v); return *v; }
    void *h = (name == "LOCAL" || name == "ENVIRONMENT") ? rxobj::environmentObject(name) : rxobj::findClass(name);
    if (!h) {
        // Not a class: an environment entry (.REXXINFO, .OUTPUT, an application's .local['X']), looked up each time.
        if (void *entry = rxobj::environmentEntry(name)) {
            // A String entry (.local~v1 = 'a') is a string value in compiled code, as strings are everywhere.
            RexxThreadContext *t = rxobj::need();
            if (rxobj::isPlainString(t, (RexxObjectPtr)entry)) {
                RexxStringObject so = (RexxStringObject)t->ObjectToString((RexxObjectPtr)entry);
                Value v = Value::string(std::string(t->StringData(so), t->StringLength(so)));
                rxobj::release(entry);
                return v;
            }
            return Value::fromObject(std::make_shared<EnvObject>(entry));
        }
        return Value::string("." + name);   // an unknown environment symbol is its own name, as interpreted (.FOO, ...)
    }
    auto obj = std::make_shared<EnvObject>(h);
    Value value = Value::fromObject(obj);
    cache.emplace(name, value);
    return value;
}
#ifdef RX2CPP_HOST_API
// .MUTABLEBUFFER in compiled library code. A buffer built and read by compiled code (json.cls: one APPEND per token)
// stays native: APPEND of plain strings, STRING, MAKESTRING and LENGTH run here without crossing to the interpreter.
// Any other message, or handing the buffer to the interpreter, creates the interpreter's own MutableBuffer with the
// same content; from then on this object forwards everything to it, so there is one object with one identity.
struct NativeMutableBuffer final : NativeRefBase, std::enable_shared_from_this<NativeMutableBuffer> {
    std::string data;
    std::optional<Value> real;   // the interpreter MutableBuffer, once created
    explicit NativeMutableBuffer(std::string initial) : data(std::move(initial)) {}
    Value &promote() {
        if (!real) {
            MessageResult made = envClass("MUTABLEBUFFER").object->sendMessage("NEW", {Value::string(data)});
            if (!made || !made->isObject()) throw std::runtime_error(".MutableBuffer~new returned no object");
            real = *made;
            std::string().swap(data);
        }
        return *real;
    }
    void *materialize() override {
        auto *env = dynamic_cast<EnvObject *>(promote().object.get());
        if (!env) throw std::runtime_error("MutableBuffer is not an interpreter object");
        return env->handle;
    }
    static bool plain(const std::vector<Value> &args) {
        for (const Value &a : args) if (a.isObject()) return false;
        return true;
    }
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override {
        if (!real) {
            if (selector == "APPEND" && !args.empty() && plain(args)) {
                for (const Value &a : args) data.append(a.bytes.data(), a.bytes.size());
                return Value::fromObject(shared_from_this());
            }
            if ((selector == "STRING" || selector == "MAKESTRING") && args.empty()) return Value::string(data);
            if (selector == "LENGTH" && args.empty()) return Value::string(std::to_string(data.size()));
        }
        return promote().object->sendMessage(selector, args);
    }
    Value sendBinary(const std::string &selector, const Value &rhs) override {
        return promote().object->sendBinary(selector, rhs);
    }
    Value sendUnary(const std::string &selector) override { return promote().object->sendUnary(selector); }
    std::string display() const override {
        if (!real) return data;
        MessageResult text = real->object->sendMessage("STRING", {});
        return text ? text->bytes.str() : std::string();
    }
};
// The .MUTABLEBUFFER class: NEW with plain-string arguments makes a NativeMutableBuffer; everything else is the
// interpreter's class (which is also what the interpreter receives for it).
struct NativeMutableBufferClass final : NativeRefBase {
    static Value interpreterClass() { return envClass("MUTABLEBUFFER"); }
    void *materialize() override {
        auto *env = dynamic_cast<EnvObject *>(interpreterClass().object.get());
        if (!env) throw std::runtime_error(".MutableBuffer is not an interpreter class");
        return env->handle;
    }
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override {
        // NEW([string] [, buffersize]): the initial content; the size is only a capacity hint.
        if (selector == "NEW" && args.size() <= 2 && NativeMutableBuffer::plain(args)) {
            if (args.size() == 2) {
                const std::string &n = args[1].bytes;
                if (n.empty() || n.find_first_not_of("0123456789") != std::string::npos)
                    return interpreterClass().object->sendMessage(selector, args);   // let the interpreter raise its error
            }
            auto buffer = std::make_shared<NativeMutableBuffer>(args.empty() ? std::string() : args[0].bytes.str());
            if (args.size() == 2) {
                const std::string &n = args[1].bytes;
                buffer->data.reserve(n.size() > 8 ? std::size_t(1) << 26 : std::min<std::size_t>(std::stoull(n), std::size_t(1) << 26));
            }
            return Value::fromObject(buffer);
        }
        return interpreterClass().object->sendMessage(selector, args);
    }
    Value sendBinary(const std::string &selector, const Value &rhs) override {
        return interpreterClass().object->sendBinary(selector, rhs);
    }
    std::string display() const override { return "The MutableBuffer class"; }
};
inline Value mutableBufferClass() {
    static thread_local const Value c = Value::fromObject(std::make_shared<NativeMutableBufferClass>());
    return c;
}
// .ARRAY in compiled library code (single dimension). Native while it stays in compiled code: [] []= AT PUT APPEND
// ITEMS SIZE FIRST LAST FIRSTITEM LASTITEM ISEMPTY HASINDEX REMOVE MAKEARRAY ALLITEMS ALLINDEXES ISA CLASS and the
// identity comparisons. Any other message, an index that is not a plain positive whole number, or leaving compiled
// code creates the interpreter's own Array with the same slots and size; from then on this object forwards to it.
// SIZE follows the interpreter: the larger of the NEW size and the highest index used; APPEND uses last item + 1.
struct NativeArrayClass;
inline Value nativeArrayClass();
struct NativeArray final : NativeRefBase, ItemSnapshot, std::enable_shared_from_this<NativeArray> {
    std::vector<std::optional<Value>> slots;   // slots.size() is the Array's SIZE
    std::size_t count = 0;                      // ITEMS
    std::optional<Value> real;
    static constexpr std::size_t maxSlots = std::size_t(1) << 20;
    explicit NativeArray(std::size_t size = 0) : slots(size) {}
    // A positive whole number written plainly (blanks around allowed); anything else is left to the interpreter.
    static bool index(const Value &v, std::size_t &out) {
        if (v.isObject()) return false;
        const std::string &s = v.bytes;
        std::size_t a = s.find_first_not_of(' '), b = s.find_last_not_of(' ');
        if (a == std::string::npos || b - a + 1 > 9) return false;
        std::size_t n = 0;
        for (std::size_t i = a; i <= b; ++i) {
            if (s[i] < '0' || s[i] > '9') return false;
            n = n * 10 + static_cast<std::size_t>(s[i] - '0');
        }
        if (n == 0) return false;
        out = n;
        return true;
    }
    static bool omitted(const Value &v) {
        auto *e = dynamic_cast<EnvObject *>(v.object.get());
        return e && e->handle == nullptr;
    }
    std::size_t lastIndex() const {
        for (std::size_t i = slots.size(); i > 0; --i) if (slots[i - 1]) return i;
        return 0;
    }
    bool place(std::size_t i, const Value &v) {      // false: too sparse to keep natively
        if (i > slots.size()) {
            if (i > maxSlots) return false;
            slots.resize(i);
        }
        if (!slots[i - 1]) ++count;
        slots[i - 1] = v;
        return true;
    }
    Value &promote() {
        if (!real) {
            std::vector<Value> values;
            std::vector<bool> holes;
            values.reserve(slots.size());
            for (const auto &s : slots) { values.push_back(s ? *s : Value::string(std::string())); holes.push_back(!s); }
            std::vector<rxobj::Arg> in; EnvObject::convert(values, in);
            for (std::size_t i = 0; i < in.size(); ++i) if (holes[i]) in[i].omitted = true;
            real = Value::fromObject(std::make_shared<EnvObject>(rxobj::newArray(slots.size(), in)));
            std::vector<std::optional<Value>>().swap(slots);
            count = 0;
        }
        return *real;
    }
    void *materialize() override { return static_cast<EnvObject *>(promote().object.get())->handle; }
    std::optional<std::vector<Value>> snapshotItems() override {
        if (real) return std::nullopt;
        std::vector<Value> items;
        items.reserve(count);
        for (const auto &s : slots) if (s) items.push_back(*s);
        return items;
    }
    Value self() { return Value::fromObject(shared_from_this()); }
    static Value number(std::size_t n) { return Value::string(std::to_string(n)); }
    Value newArrayOf(std::vector<Value> items) {
        auto a = std::make_shared<NativeArray>(items.size());
        for (std::size_t i = 0; i < items.size(); ++i) a->slots[i] = std::move(items[i]);
        a->count = items.size();
        return Value::fromObject(a);
    }
    MessageResult forward(const std::string &selector, const std::vector<Value> &args) {
        return promote().object->sendMessage(selector, args);
    }
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override;
    Value sendBinary(const std::string &selector, const Value &rhs) override {
        if (!real && (selector == "==" || selector == "=" || selector == "\\==" || selector == "\\=" || selector == "<>" || selector == "><")) {
            const bool same = rhs.isObject() && rhs.object.get() == this;
            const bool positive = selector == "==" || selector == "=";
            return Value::string(same == positive ? "1" : "0");
        }
        return promote().object->sendBinary(selector, rhs);
    }
    Value sendUnary(const std::string &selector) override { return promote().object->sendUnary(selector); }
    std::string display() const override {
        MessageResult text = const_cast<NativeArray *>(this)->forward("STRING", {});
        return text ? text->bytes.str() : std::string();
    }
};
struct NativeArrayClass final : NativeRefBase {
    static Value interpreterClass() { return envClass("ARRAY"); }
    void *materialize() override { return static_cast<EnvObject *>(interpreterClass().object.get())->handle; }
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override {
        if (selector == "NEW") {
            std::size_t n = 0;
            if (args.empty()) return Value::fromObject(std::make_shared<NativeArray>());
            if (args.size() == 1 && !args[0].isObject()) {
                const std::string &s = args[0].bytes;
                const std::size_t a = s.find_first_not_of(' ');
                if (a != std::string::npos && s.substr(a, s.find_last_not_of(' ') - a + 1) == "0")
                    return Value::fromObject(std::make_shared<NativeArray>(0));
                if (NativeArray::index(args[0], n) && n <= NativeArray::maxSlots)
                    return Value::fromObject(std::make_shared<NativeArray>(n));
            }
        } else if (selector == "OF") {
            auto a = std::make_shared<NativeArray>(args.size());
            for (std::size_t i = 0; i < args.size(); ++i) {
                if (NativeArray::omitted(args[i])) continue;
                a->slots[i] = args[i];
                ++a->count;
            }
            return Value::fromObject(a);
        }
        return interpreterClass().object->sendMessage(selector, args);
    }
    Value sendBinary(const std::string &selector, const Value &rhs) override {
        return interpreterClass().object->sendBinary(selector, rhs);
    }
    std::string display() const override { return "The Array class"; }
};
inline Value nativeArrayClass() {
    static thread_local const Value c = Value::fromObject(std::make_shared<NativeArrayClass>());
    return c;
}
// .DIRECTORY in compiled library code. Native while it stays in compiled code: [] []= AT PUT HASINDEX ITEMS ISEMPTY ISA
// CLASS and the identity comparisons, with plain string indexes. Iteration order is the interpreter's hash order, which
// depends on insertion history: anything that shows order (ALLINDEXES, MAKEARRAY, SUPPLIER, DO OVER, ...), REMOVE,
// any other message, or leaving compiled code creates the interpreter's Directory by replaying the first insertions in
// their original order (the same history gives the same table) and forwards to it from then on.
struct NativeDirectoryClass;
inline Value nativeDirectoryClass();
struct NativeDirectory final : NativeRefBase, std::enable_shared_from_this<NativeDirectory> {
    std::vector<std::string> order;                       // first-insertion order
    std::unordered_map<std::string, Value> entries;
    std::optional<Value> real;
    Value &promote() {
        if (!real) {
            MessageResult made = envClass("DIRECTORY").object->sendMessage("NEW", {});
            if (!made || !made->isObject()) throw std::runtime_error(".Directory~new returned no object");
            auto *env = dynamic_cast<EnvObject *>(made->object.get());
            if (!env) throw std::runtime_error(".Directory~new is not an interpreter object");
            std::vector<Value> values;
            values.reserve(order.size());
            for (const auto &k : order) values.push_back(entries.at(k));
            std::vector<rxobj::Arg> in; EnvObject::convert(values, in);
            rxobj::directoryPutAll(env->handle, order, in);
            real = *made;
            std::vector<std::string>().swap(order);
            std::unordered_map<std::string, Value>().swap(entries);
        }
        return *real;
    }
    void *materialize() override { return static_cast<EnvObject *>(promote().object.get())->handle; }
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override {
        if (real) return real->object->sendMessage(selector, args);
        const std::size_t n = args.size();
        const bool key0 = n >= 1 && !args[n == 2 ? 1 : 0].isObject();
        if ((selector == "[]" || selector == "AT") && n == 1 && key0) {
            auto it = entries.find(args[0].bytes);
            return it == entries.end() ? nil() : it->second;
        }
        if ((selector == "[]=" || selector == "PUT") && n == 2 && key0 && !NativeArray::omitted(args[0])) {
            const std::string &k = args[1].bytes;
            auto it = entries.find(k);
            if (it == entries.end()) { order.push_back(k); entries.emplace(k, args[0]); }
            else it->second = args[0];
            return std::nullopt;
        }
        if (selector == "HASINDEX" && n == 1 && key0) return Value::string(entries.count(args[0].bytes) ? "1" : "0");
        if (selector == "ITEMS" && n == 0) return Value::string(std::to_string(entries.size()));
        if (selector == "ISEMPTY" && n == 0) return Value::string(entries.empty() ? "1" : "0");
        if (selector == "CLASS" && n == 0) return nativeDirectoryClass();
        if (selector == "ISA" && n == 1 && args[0].isObject()) {
            if (args[0].object.get() == nativeDirectoryClass().object.get()) return Value::string("1");
            Value cls = envClass("DIRECTORY");
            if (auto *e = dynamic_cast<EnvObject *>(args[0].object.get()))
                if (e->handle == static_cast<EnvObject *>(cls.object.get())->handle) return Value::string("1");
            return cls.object->sendMessage("ISSUBCLASSOF", args);
        }
        return promote().object->sendMessage(selector, args);
    }
    Value sendBinary(const std::string &selector, const Value &rhs) override {
        if (!real && (selector == "==" || selector == "=" || selector == "\\==" || selector == "\\=" || selector == "<>" || selector == "><")) {
            const bool same = rhs.isObject() && rhs.object.get() == this;
            const bool positive = selector == "==" || selector == "=";
            return Value::string(same == positive ? "1" : "0");
        }
        return promote().object->sendBinary(selector, rhs);
    }
    Value sendUnary(const std::string &selector) override { return promote().object->sendUnary(selector); }
    std::string display() const override {
        MessageResult text = const_cast<NativeDirectory *>(this)->promote().object->sendMessage("STRING", {});
        return text ? text->bytes.str() : std::string();
    }
};
struct NativeDirectoryClass final : NativeRefBase {
    void *materialize() override { return static_cast<EnvObject *>(envClass("DIRECTORY").object.get())->handle; }
    MessageResult sendMessage(const std::string &selector, const std::vector<Value> &args) override {
        // Only .Directory~new without arguments: an initial size changes the interpreter's table layout (and order).
        if (selector == "NEW" && args.empty()) return Value::fromObject(std::make_shared<NativeDirectory>());
        return envClass("DIRECTORY").object->sendMessage(selector, args);
    }
    Value sendBinary(const std::string &selector, const Value &rhs) override {
        return envClass("DIRECTORY").object->sendBinary(selector, rhs);
    }
    std::string display() const override { return "The Directory class"; }
};
inline Value nativeDirectoryClass() {
    static thread_local const Value c = Value::fromObject(std::make_shared<NativeDirectoryClass>());
    return c;
}
inline MessageResult NativeArray::sendMessage(const std::string &selector, const std::vector<Value> &args) {
    if (real) return real->object->sendMessage(selector, args);
    std::size_t i = 0;
    const std::size_t n = args.size();
    switch (selector.empty() ? 0 : selector[0]) {
    case '[':
        if (selector == "[]" && n == 1 && index(args[0], i))
            return i <= slots.size() && slots[i - 1] ? *slots[i - 1] : nil();
        if (selector == "[]=" && n == 2 && !omitted(args[0]) && index(args[1], i) && place(i, args[0])) return std::nullopt;
        break;
    case 'A':
        if (selector == "AT" && n == 1 && index(args[0], i))
            return i <= slots.size() && slots[i - 1] ? *slots[i - 1] : nil();
        if (selector == "APPEND" && n == 1 && !omitted(args[0])) {
            const std::size_t at = lastIndex() + 1;
            if (place(at, args[0])) return number(at);
        }
        if (selector == "ALLITEMS" && n == 0) return newArrayOf(*snapshotItems());
        if (selector == "ALLINDEXES" && n == 0) {
            std::vector<Value> ix;
            for (std::size_t k = 0; k < slots.size(); ++k) if (slots[k]) ix.push_back(number(k + 1));
            return newArrayOf(std::move(ix));
        }
        break;
    case 'C':
        if (selector == "CLASS" && n == 0) return nativeArrayClass();
        break;
    case 'F':
        if (selector == "FIRST" && n == 0) {
            for (std::size_t k = 0; k < slots.size(); ++k) if (slots[k]) return number(k + 1);
            return nil();
        }
        if (selector == "FIRSTITEM" && n == 0) {
            for (const auto &s : slots) if (s) return *s;
            return nil();
        }
        break;
    case 'H':
        if (selector == "HASINDEX" && n == 1 && index(args[0], i))
            return Value::string(i <= slots.size() && slots[i - 1] ? "1" : "0");
        break;
    case 'I':
        if (selector == "ITEMS" && n == 0) return number(count);
        if (selector == "ISEMPTY" && n == 0) return Value::string(count == 0 ? "1" : "0");
        if (selector == "ISA" && n == 1 && args[0].isObject()) {
            if (dynamic_cast<NativeArrayClass *>(args[0].object.get())) return Value::string("1");
            // An Array instance: isA(c) is c == .Array or .Array~isSubclassOf(c) (no promotion needed).
            Value cls = NativeArrayClass::interpreterClass();
            if (auto *e = dynamic_cast<EnvObject *>(args[0].object.get()))
                if (e->handle == static_cast<EnvObject *>(cls.object.get())->handle) return Value::string("1");
            return cls.object->sendMessage("ISSUBCLASSOF", args);
        }
        break;
    case 'L':
        if (selector == "LAST" && n == 0) { const std::size_t l = lastIndex(); return l ? number(l) : nil(); }
        if (selector == "LASTITEM" && n == 0) { const std::size_t l = lastIndex(); return l ? *slots[l - 1] : nil(); }
        break;
    case 'M':
        if (selector == "MAKEARRAY" && n == 0) return newArrayOf(*snapshotItems());
        break;
    case 'P':
        if (selector == "PUT" && n == 2 && !omitted(args[0]) && index(args[1], i) && place(i, args[0])) return std::nullopt;
        break;
    case 'R':
        if (selector == "REMOVE" && n == 1 && index(args[0], i)) {
            if (i > slots.size() || !slots[i - 1]) return nil();
            Value out = std::move(*slots[i - 1]);
            slots[i - 1].reset();
            --count;
            return out;
        }
        break;
    case 'S':
        if (selector == "SIZE" && n == 0) return number(slots.size());
        break;
    default: break;
    }
    return forward(selector, args);
}
#endif
#ifdef RX2CPP_HOST_API
// CALL / function call of a routine only the interpreter can resolve (rexxutil SysXxx, external .rex routines), run in a
// small interpreter routine under the caller's NUMERIC settings. An argument that names a stem the callee filled
// (SysFileTree spec, 'files.', ...) is copied back into the caller's compiled variables, as the interpreter would leave it.
// dynamicName: CALL (expression), the routine name computed at run time (passed as one more argument).
inline MessageResult interpreterCall(Variables &vars, const std::string &name, const std::vector<std::optional<Value>> &args,
                                     const std::optional<Value> &dynamicName = std::nullopt) {
    RexxThreadContext *t = rxobj::need();
    rxobj::LocalRefs temps(t);
    rxobj::bifStat("CALL " + name);
    std::string call = dynamicName ? "call (arg(" + std::to_string(args.size() + 1) + ")) " : "call " + name + " ";
    for (std::size_t i = 0; i < args.size(); ++i) {
        if (i) call += ",";
        if (args[i]) call += "arg(" + std::to_string(i + 1) + ")";
    }
    // End the clause explicitly: a trailing omitted argument leaves a final comma, which at the end of a line would
    // continue the clause into the next one (f(a,) has 2 arguments, the second omitted).
    call += ";";
    const std::string source =
        "numeric digits " + std::to_string(vars.numeric.digits) + "; numeric fuzz " + std::to_string(vars.numeric.fuzz) +
        "; numeric form " + (vars.numeric.engineering ? "engineering" : "scientific") + "\n" + call +
        "\nout = .array~new; if var('RESULT') then out[1] = result\n"
        "do i = 1 to arg(); if \\arg(i, 'E') then iterate; a = arg(i)\n"
        "  if \\a~isA(.string) then iterate; if right(a, 1) \\== '.' | symbol(a) \\== 'VAR' then iterate\n"
        "  interpret 'st =' a; if st~isA(.stem) then out~append(.array~of(translate(a), st))\n"
        "end\nreturn out\n";
    static thread_local std::unordered_map<std::string, RexxRoutineObject> cache;
    auto it = cache.find(source);
    RexxRoutineObject routine;
    if (it == cache.end()) {
        routine = rxobj::packageRoutine(t, "rx2cpp_call", source);
        if (routine == NULLOBJECT) throw std::runtime_error("cannot create interpreter call for " + name);
        t->RequestGlobalReference((RexxObjectPtr)routine);
        cache.emplace(source, routine);
    } else routine = it->second;
    RexxArrayObject arr = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(args.size() + (dynamicName ? 1 : 0)));
    std::vector<rxobj::Arg> conv;
    for (std::size_t i = 0; i < args.size(); ++i) {
        if (!args[i]) continue;
        conv.clear(); EnvObject::convert({*args[i]}, conv);
        RexxObjectPtr o = conv[0].obj ? (RexxObjectPtr)conv[0].obj : temps((RexxObjectPtr)t->NewString(conv[0].bytes.data(), conv[0].bytes.size()));
        t->ArrayPut(arr, o, i + 1);
    }
    if (dynamicName) {
        conv.clear(); EnvObject::convert({*dynamicName}, conv);
        t->ArrayPut(arr, conv[0].obj ? (RexxObjectPtr)conv[0].obj : temps((RexxObjectPtr)t->NewString(conv[0].bytes.data(), conv[0].bytes.size())), args.size() + 1);
    }
    RexxObjectPtr r = temps(t->CallRoutine(routine, arr));
    if (t->CheckCondition()) {
        RexxCondition cd; t->DecodeConditionInfo(t->GetConditionInfo(), &cd);
        std::string code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        std::string text = (cd.message && t->IsString(cd.message)) ? t->ObjectToStringValue(cd.message) : "error in " + name;
        RexxDirectoryObject info = t->GetConditionInfo();
        rxobj::keepCondition(t);
        t->ClearCondition();
        rxobj::captureAdditional(t, info);   // the message substitutions (43.1 "Could not find routine &1"), no condition pending
        SyntaxCondition raised(code, text, false);
        for (const std::string &a : rxobj::lastAdditional()) raised.substitutions.push_back(Value::string(a));
        raised.conditionObject = takeKeptCondition();
        throw raised;
    }
    if (r == NULLOBJECT) return std::nullopt;
    RexxArrayObject out = (RexxArrayObject)r;
    auto text = [&](RexxObjectPtr o) { RexxStringObject so = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(o)); return std::string(t->StringData(so), t->StringLength(so)); };
    auto valueOf = [&](RexxObjectPtr o) -> Value {
        if (o == t->Nil()) return nil();
        if (rxobj::isPlainString(t, o)) return Value::string(text(o));
        return EnvObject::adopt((void *)t->RequestGlobalReference(o));
    };
    const std::size_t n = t->ArraySize(out);
    for (std::size_t i = 2; i <= n; ++i) {
        RexxArrayObject pair = (RexxArrayObject)t->ArrayAt(out, i);
        const std::string stem = text(t->ArrayAt(pair, 1));
        RexxObjectPtr st = t->ArrayAt(pair, 2);
        resetStem(vars, stem);
        RexxArrayObject tails = (RexxArrayObject)temps(t->SendMessage0(st, "ALLINDEXES"));
        const std::size_t m = tails ? t->ArraySize(tails) : 0;
        for (std::size_t k = 1; k <= m; ++k) {
            RexxObjectPtr tail = t->ArrayAt(tails, k);
            RexxObjectPtr v = temps(t->SendMessage1(st, "[]", tail));
            set(vars, stem + text(tail), valueOf(v));
        }
    }
    RexxObjectPtr res = t->ArrayAt(out, 1);
    if (res == NULLOBJECT) return std::nullopt;
    return valueOf(res);
}
// ADDRESS environment command: the interpreter that loaded this library runs the command with its own environment
// handlers (same shell, same output, same RC); RC is then set in the compiled method's variables.
// Not yet: ERROR / FAILURE conditions for a SIGNAL ON / CALL ON trap in the compiled method.
inline void interpreterCommand(Variables &vars, const Value &environment, const Value &command) {
    RexxThreadContext *t = rxobj::need();
    rxobj::LocalRefs temps(t);
    rxobj::bifStat("ADDRESS " + environment.bytes.str());
    static thread_local RexxRoutineObject routine = NULLOBJECT;
    if (routine == NULLOBJECT) {
        static const char source[] = "use arg rx2cppEnvironment, rx2cppCommand\naddress value rx2cppEnvironment\n"
                                     "rx2cppCommand\nreturn rc\n";
        routine = t->NewRoutine("rx2cpp_address", source, sizeof(source) - 1);
        if (routine == NULLOBJECT) throw std::runtime_error("cannot create interpreter ADDRESS helper");
        t->RequestGlobalReference((RexxObjectPtr)routine);
    }
    std::vector<rxobj::Arg> conv;
    RexxArrayObject arr = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(2));
    std::size_t index = 0;
    for (const Value *v : {&environment, &command}) {
        conv.clear(); EnvObject::convert({*v}, conv);
        RexxObjectPtr o = conv[0].obj ? (RexxObjectPtr)conv[0].obj : temps((RexxObjectPtr)t->NewString(conv[0].bytes.data(), conv[0].bytes.size()));
        t->ArrayPut(arr, o, ++index);
    }
    RexxObjectPtr r = temps(t->CallRoutine(routine, arr));
    if (t->CheckCondition()) {
        RexxCondition cd; t->DecodeConditionInfo(t->GetConditionInfo(), &cd);
        std::string code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        std::string text = (cd.message && t->IsString(cd.message)) ? t->ObjectToStringValue(cd.message) : "error in ADDRESS";
        RexxDirectoryObject info = t->GetConditionInfo();
        rxobj::keepCondition(t);
        t->ClearCondition();
        rxobj::captureAdditional(t, info);   // the message substitutions (43.1 "Could not find routine &1"), no condition pending
        SyntaxCondition raised(code, text, false);
        for (const std::string &a : rxobj::lastAdditional()) raised.substitutions.push_back(Value::string(a));
        raised.conditionObject = takeKeptCondition();
        throw raised;
    }
    if (r == NULLOBJECT) throw std::runtime_error("ADDRESS helper returned no RC");
    RexxStringObject rs = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(r));
    set(vars, "RC", Value::string(std::string(t->StringData(rs), t->StringLength(rs))));
}
// SAY in a native library: the line goes to the interpreter's .OUTPUT (~SAY), as interpreted SAY output does, so a
// redirected .OUTPUT (a Monitor on a stream, ...) receives it and the order with interpreted output is kept.
inline void hostSay(const std::string &line) {
    RexxThreadContext *t = rxobj::need();
    rxobj::LocalRefs temps(t);
    RexxDirectoryObject local = (RexxDirectoryObject)temps((RexxObjectPtr)t->GetLocalEnvironment());
    RexxObjectPtr stream = local ? t->DirectoryAt(local, "OUTPUT") : NULLOBJECT;
    if (stream == NULLOBJECT || stream == t->Nil()) { std::fwrite(line.data(), 1, line.size(), stdout); std::fputc('\n', stdout); return; }
    temps(t->SendMessage1(stream, "SAY", temps((RexxObjectPtr)t->NewString(line.data(), line.size()))));
    if (t->CheckCondition()) {
        RexxCondition cd; t->DecodeConditionInfo(t->GetConditionInfo(), &cd);
        std::string code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        std::string text = (cd.message && t->IsString(cd.message)) ? t->ObjectToStringValue(cd.message) : std::string("error in SAY");
        RexxDirectoryObject info = t->GetConditionInfo();
        rxobj::keepCondition(t);
        t->ClearCondition();
        rxobj::captureAdditional(t, info);
        SyntaxCondition raised(code, text, false);
        for (const std::string &a : rxobj::lastAdditional()) raised.substitutions.push_back(Value::string(a));
        raised.conditionObject = takeKeptCondition();
        throw raised;
    }
}
inline const bool hostSayInstalled = (sayHook() = &hostSay, true);
// Runs one small interpreter helper (source, arguments); a condition it raises is re-raised in the compiled code as is.
inline RexxObjectPtr interpreterHelper(RexxThreadContext *t, rxobj::LocalRefs &temps, RexxRoutineObject &routine,
                                       const char *name, const char *source, const std::vector<Value> &args) {
    if (routine == NULLOBJECT) {
        routine = t->NewRoutine(name, source, std::strlen(source));
        if (routine == NULLOBJECT) throw std::runtime_error(std::string("cannot create interpreter helper ") + name);
        t->RequestGlobalReference((RexxObjectPtr)routine);
    }
    std::vector<rxobj::Arg> conv;
    RexxArrayObject arr = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(args.size()));
    std::size_t index = 0;
    for (const Value &v : args) {
        conv.clear(); EnvObject::convert({v}, conv);
        RexxObjectPtr o = conv[0].obj ? (RexxObjectPtr)conv[0].obj : temps((RexxObjectPtr)t->NewString(conv[0].bytes.data(), conv[0].bytes.size()));
        t->ArrayPut(arr, o, ++index);
    }
    RexxObjectPtr r = temps(t->CallRoutine(routine, arr));
    if (t->CheckCondition()) {
        RexxCondition cd; t->DecodeConditionInfo(t->GetConditionInfo(), &cd);
        std::string code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        std::string text = (cd.message && t->IsString(cd.message)) ? t->ObjectToStringValue(cd.message) : std::string("error in ") + name;
        RexxDirectoryObject info = t->GetConditionInfo();
        rxobj::keepCondition(t);
        t->ClearCondition();
        rxobj::captureAdditional(t, info);
        SyntaxCondition raised(code, text, false);
        for (const std::string &a : rxobj::lastAdditional()) raised.substitutions.push_back(Value::string(a));
        raised.conditionObject = takeKeptCondition();
        throw raised;
    }
    return r;
}
// PARSE PULL / PULL (linein false): the interpreter's current external data queue, standard input when it is empty;
// PARSE LINEIN (linein true): standard input. As interpreted, read by the interpreter.
inline Value interpreterParseSource(bool linein) {
    RexxThreadContext *t = rxobj::need();
    rxobj::LocalRefs temps(t);
    static thread_local RexxRoutineObject pull = NULLOBJECT, line = NULLOBJECT;
    RexxObjectPtr r = linein ? interpreterHelper(t, temps, line, "rx2cpp_linein", "parse linein rx2cppLine\nreturn rx2cppLine\n", {})
                             : interpreterHelper(t, temps, pull, "rx2cpp_pull", "parse pull rx2cppLine\nreturn rx2cppLine\n", {});
    if (r == NULLOBJECT) return Value::string(std::string());
    RexxStringObject rs = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(r));
    return Value::string(std::string(t->StringData(rs), t->StringLength(rs)));
}
// PUSH (lifo) / QUEUE: one line onto the interpreter's current external data queue.
inline void interpreterQueue(bool lifo, const Value &line) {
    RexxThreadContext *t = rxobj::need();
    rxobj::LocalRefs temps(t);
    static thread_local RexxRoutineObject push = NULLOBJECT, queue = NULLOBJECT;
    if (lifo) interpreterHelper(t, temps, push, "rx2cpp_push", "push arg(1)\nreturn\n", {line});
    else interpreterHelper(t, temps, queue, "rx2cpp_queue", "queue arg(1)\nreturn\n", {line});
}
// One stream method, sent by a small interpreter routine: a NOTREADY the stream raises lands in that Rexx activation
// (as interpreted, the first Rexx activation above the stream decides), not in the interpreted caller of this compiled
// code. With NOTREADY trapped in the running compiled activation (SIGNAL ON NOTREADY / ANY), the helper traps it and the
// condition goes to that trap (NotReadyCondition); otherwise it is ignored, as an untrapped NOTREADY is.
inline Value streamSend(const Value &stream, const std::string &selector, const std::vector<Value> &args) {
    RexxThreadContext *t = rxobj::need();
    rxobj::LocalRefs temps(t);
    const bool armed = MethodTraps::notReadyArmed();
    static thread_local RexxRoutineObject plain = NULLOBJECT, trapping = NULLOBJECT;
    RexxArrayObject list = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(args.size()));
    std::vector<rxobj::Arg> conv;
    for (std::size_t i = 0; i < args.size(); ++i) {
        const Value &v = args[i];
        if (v.isObject()) if (auto *e = dynamic_cast<EnvObject *>(v.object.get())) if (e->handle == nullptr) continue;   // omitted
        conv.clear(); EnvObject::convert({v}, conv);
        t->ArrayPut(list, conv[0].obj ? (RexxObjectPtr)conv[0].obj : temps((RexxObjectPtr)t->NewString(conv[0].bytes.data(), conv[0].bytes.size())), i + 1);
    }
    const std::vector<Value> helperArgs{stream, Value::string(selector), EnvObject::adopt((void *)t->RequestGlobalReference((RexxObjectPtr)list))};
    RexxObjectPtr r = armed
        ? interpreterHelper(t, temps, trapping, "rx2cpp_stream_trap",
              "use arg rx2cppStream, rx2cppMessage, rx2cppArgs\nsignal on notready name rx2cppNotReady\n"
              "return .array~of(rx2cppStream~sendWith(rx2cppMessage, rx2cppArgs))\n"
              "rx2cppNotReady: return .array~of(.nil, condition('O'))\n", helperArgs)
        : interpreterHelper(t, temps, plain, "rx2cpp_stream",
              "use arg rx2cppStream, rx2cppMessage, rx2cppArgs\n"
              "return .array~of(rx2cppStream~sendWith(rx2cppMessage, rx2cppArgs))\n", helperArgs);
    if (r == NULLOBJECT) return Value::string(std::string());
    RexxArrayObject out = (RexxArrayObject)r;
    if (t->ArraySize(out) >= 2) {
        RexxObjectPtr cond = t->ArrayAt(out, 2);
        if (cond != NULLOBJECT && cond != t->Nil())
            throw NotReadyCondition(std::make_shared<EnvObject>((void *)t->RequestGlobalReference(cond)));
    }
    RexxObjectPtr res = t->ArrayAt(out, 1);
    if (res == NULLOBJECT) return Value::string(std::string());
    if (rxobj::isPlainString(t, res)) {
        RexxStringObject so = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(res));
        return Value::string(std::string(t->StringData(so), t->StringLength(so)));
    }
    return EnvObject::adopt((void *)t->RequestGlobalReference(res));
}
// SysFileSystem::canonicalizeName (Unix): ~ is the home directory, a relative name is under the current directory, then
// duplicate and trailing slashes, "." and ".." are removed (whether the file exists or not). The stream table key.
inline std::string qualifyStreamName(const std::string &name) {
    std::string full = name;
    if (!full.empty() && full[0] == '~') {
        const std::size_t slash = full.find('/');
        const std::string user = full.substr(1, slash == std::string::npos ? std::string::npos : slash - 1);
        const char *home = nullptr;
        if (user.empty()) home = std::getenv("HOME");
        else if (struct passwd *pw = getpwnam(user.c_str())) home = pw->pw_dir;
        if (home) full = std::string(home) + (slash == std::string::npos ? std::string() : full.substr(slash));
    }
    if (full.empty() || full[0] != '/') {
        char cwd[4096];
        if (!getcwd(cwd, sizeof cwd)) return name;
        full = std::string(cwd) + "/" + full;
    }
    std::string out = "/";
    std::size_t previousSlash = 0;
    for (std::size_t i = 0; i < full.size(); ++i) {
        const char c = full[i];
        const char next = i + 1 < full.size() ? full[i + 1] : '\0';
        if (c == '/') {
            if (next != '.') previousSlash = out.size() - 1;
            if (out.back() == '/') continue;
            out += c;
        } else if (c == '.' && out.back() == '/') {
            if (next == '\0' || next == '/') continue;
            if (next == '.') {
                const char after = i + 2 < full.size() ? full[i + 2] : '\0';
                if (after == '\0' || after == '/') {
                    ++i;
                    out.resize(previousSlash + 1);
                    while (previousSlash > 0) { if (out[--previousSlash] == '/') break; }
                    continue;
                }
            }
            out += c;
        } else out += c;
    }
    if (out.size() > 1 && out.back() == '/') out.pop_back();
    return out;
}
// The stream built-ins (LINEIN LINEOUT LINES CHARIN CHAROUT CHARS STREAM), as BuiltinFunctions.cpp runs them: the name
// resolves (RexxActivation::resolveStream) to the default .INPUT / .OUTPUT ("" or omitted), STDIN STDOUT STDERR, or the
// stream object of this activation's stream table (made with .Stream~new on first use); the BIF then sends the stream
// method with the arguments given. The QUEUE: name and any call the BIF rejects go to the interpreter's own built-in
// (they do not touch the stream table): its result or exact error.
inline Value streamBif(Variables &vars, const std::string &name, const std::vector<std::optional<Value>> &a) {
    auto delegate = [&]() -> Value {
        auto r = interpreterCall(vars, name, a);
        if (!r) throw std::runtime_error("BIF " + name + ": no result");
        return std::move(*r);
    };
    const std::size_t argc = a.size();
    auto text = [&](std::size_t i) -> std::optional<std::string> {
        if (i >= argc || !a[i]) return std::nullopt;
        return a[i]->bytes.str();
    };
    auto upper = [](std::string v) { for (char &c : v) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c))); return v; };
    for (const auto &slot : a) if (slot && slot->isObject()) return delegate();
    const std::optional<std::string> streamName = text(0);
    if (streamName && upper(*streamName) == "QUEUE:") return delegate();
    // positions and counts must be whole numbers (optional_big_integer); anything else is the interpreter's error
    auto whole = [&](std::size_t i) {
        if (i >= argc || !a[i]) return true;
        RexxDecimal d; const char *err = nullptr;
        if (!tryParseRexxDecimal(*a[i], d, err)) return false;
        if (d.exponent >= 0 || d.coefficient == 0) return true;
        return d.coefficient % decimalPow10(-d.exponent) == 0;
    };
    auto &table = ActivationScope::streams();
    std::string fullName;
    auto resolve = [&](bool input, bool add) -> Value {
        fullName = streamName ? *streamName : std::string();
        if (!streamName || streamName->empty()) return envClass(input ? "INPUT" : "OUTPUT");
        const std::string u = upper(*streamName);
        if (u == "STDIN" || u == "STDIN:") return envClass("INPUT");
        if (u == "STDOUT" || u == "STDOUT:") return envClass("OUTPUT");
        if (u == "STDERR" || u == "STDERR:") return envClass("ERROR");
        fullName = qualifyStreamName(*streamName);
        auto it = table.find(fullName);
        if (it != table.end()) return it->second;
        MessageResult made = envClass("STREAM").object->sendMessage("NEW", {Value::string(*streamName)});
        if (!made || !made->isObject()) throw std::runtime_error("cannot create stream " + *streamName);
        if (add) table.emplace(fullName, *made);
        return *made;
    };
    auto send = [&](const Value &stream, const std::string &selector, std::vector<Value> args) -> Value {
        while (!args.empty() && args.back().isObject() && dynamic_cast<EnvObject *>(args.back().object.get()) &&
               static_cast<EnvObject *>(args.back().object.get())->handle == nullptr) args.pop_back();
        return streamSend(stream, selector, args);
    };
    auto arg = [&](std::size_t i) { return i < argc && a[i] ? *a[i] : omittedArgument(); };
    if (name == "LINEIN" || name == "CHARIN") {
        if (argc > 3 || !whole(1) || !whole(2)) return delegate();
        Value stream = resolve(true, true);
        if (argc <= 1) return send(stream, name, {});
        if (argc == 2) return send(stream, name, {arg(1)});
        return send(stream, name, {arg(1), arg(2)});
    }
    if (name == "LINEOUT" || name == "CHAROUT") {
        if (argc > 3 || !whole(2)) return delegate();
        Value stream = resolve(false, true);
        if (argc == 0) return send(stream, name, {});
        if (argc == 1) {
            Value r = send(stream, name, {});
            if (name == "LINEOUT") table.erase(fullName);   // a close request: removeFileName
            return r;
        }
        if (argc == 2) return send(stream, name, {arg(1)});
        return send(stream, name, {arg(1), arg(2)});
    }
    if (name == "LINES") {
        if (argc > 2) return delegate();
        std::string option = "NORMAL";
        if (auto o = text(1)) { if (o->empty()) return delegate(); option = *o; }
        const char opt = static_cast<char>(std::toupper(static_cast<unsigned char>(option[0])));
        if (opt != 'C' && opt != 'N') return delegate();
        Value stream = resolve(true, true);
        Value r = send(stream, "LINES", {Value::string(option)});
        if (opt == 'N' && !r.isObject()) {
            RexxDecimal d; const char *err = nullptr;
            if (tryParseRexxDecimal(r, d, err)) return Value::string(d.coefficient != 0 ? "1" : "0");
        }
        return r;
    }
    if (name == "CHARS") {
        if (argc > 1) return delegate();
        return send(resolve(true, true), "CHARS", {});
    }
    if (name == "STREAM") {
        if (argc < 1 || argc > 3 || !streamName || streamName->empty()) return delegate();
        char action = 'S';
        if (auto op = text(1)) { if (op->empty()) return delegate(); action = static_cast<char>(std::toupper(static_cast<unsigned char>((*op)[0]))); }
        if (action == 'S' || action == 'D') {
            if (argc > 2) return delegate();
            return send(resolve(true, false), action == 'S' ? "STATE" : "DESCRIPTION", {});
        }
        if (action != 'C' || argc < 3 || !a[2]) return delegate();
        const Value command = *a[2];
        auto hasWord = [&](const char *w) {
            std::istringstream in(upper(command.bytes.str())); std::string t;
            while (in >> t) if (t == w) return true;
            return false;
        };
        if (hasWord("OPEN")) {
            Value stream = resolve(true, true);
            Value r = send(stream, "COMMAND", {command});
            if (r.isObject() || r.bytes.str() != "READY:") table.erase(fullName);
            return r;
        }
        if (hasWord("CLOSE")) {
            Value stream = resolve(true, true);
            Value r = send(stream, "COMMAND", {command});
            table.erase(fullName);
            return r;
        }
        if (hasWord("SEEK") || hasWord("POSITION")) return send(resolve(true, true), "COMMAND", {command});
        return send(resolve(true, false), "COMMAND", {command});
    }
    throw std::runtime_error("not a stream built-in: " + name);
}
// RANDOM([min] [, max] [, seed]) as BUILTIN(RANDOM) and RexxActivation::random run it, on this activation's seed (see
// rx::ActivationScope): the same seeded sequences as interpreted. A call the BIF rejects goes to the interpreter's own
// RANDOM for its exact error (after the seed was set, as there).
inline Value randomBif(Variables &vars, const std::vector<std::optional<Value>> &a) {
    auto delegate = [&]() -> Value {
        auto r = interpreterCall(vars, "RANDOM", a);
        if (!r) throw std::runtime_error("BIF RANDOM: no result");
        return std::move(*r);
    };
    const std::size_t argc = a.size();
    if (argc > 3) return delegate();
    for (const auto &slot : a) if (slot && slot->isObject()) return delegate();
    auto intArg = [&](std::size_t i, std::optional<std::int64_t> &out) -> bool {   // optional_integer
        if (i >= argc || !a[i]) return true;
        RexxDecimal d; const char *err = nullptr;
        std::int64_t v = 0;
        if (!tryParseRexxDecimal(*a[i], d, err) || !oorexxWholeNumber(d, 18, true, v)) return false;
        out = v;
        return true;
    };
    std::optional<std::int64_t> mn, mx, sd;
    if (argc == 2 && !a[0] && !a[1]) { mn = 0; mx = 999; }   // RANDOM(,) is not RANDOM()
    else if (!intArg(0, mn) || !intArg(1, mx)) return delegate();
    if (!intArg(2, sd)) return delegate();
    constexpr std::uint64_t factor = 25214903917ULL, adder = 11ULL;
    std::uint64_t &seed = ActivationScope::randomSeed();
    if (sd) {
        if (*sd < 0) return delegate();
        seed = ~static_cast<std::uint64_t>(*sd);
        for (int i = 0; i < 13; ++i) seed = seed * factor + adder;
    }
    seed = seed * factor + adder;
    std::uint64_t bits = seed;
    std::int64_t minimum = 0, maximum = 999;
    if (mn) {
        if (!mx && !sd) maximum = *mn;
        else if (!mx && sd) minimum = *mn;
        else { minimum = *mn; maximum = *mx; }
    } else if (mx) maximum = *mx;
    if (maximum < minimum || maximum - minimum > 999999999) return delegate();
    if (minimum != maximum) {
        std::uint64_t work = 0;
        for (int i = 0; i < 64; ++i) { work <<= 1; work |= (bits & 1ULL); bits >>= 1; }
        minimum += static_cast<std::int64_t>(work % static_cast<std::uint64_t>(maximum - minimum + 1));
    }
    return Value::number(std::to_string(minimum));
}
// RexxActivation::getTime: the clause's time stamp (SystemInterpreter::getCurrentTime on first use in the clause).
inline ClauseClock &clauseTime() {
    ClauseClock &c = ActivationScope::clock();
    if (!c.valid) {
        if (c.elapsedReset) { c.elapsed = c.utc; c.elapsedReset = false; }   // TIME('R') in an earlier clause
        timeval tv; gettimeofday(&tv, nullptr);
        std::tm local{}; time_t secs = tv.tv_sec; localtime_r(&secs, &local);
        constexpr std::int64_t epochBase = 62135596800LL * 1000000LL;   // 0001-01-01 to 1970-01-01
        c.utc = static_cast<std::int64_t>(tv.tv_sec) * 1000000LL + tv.tv_usec + epochBase;
        c.offset = static_cast<std::int64_t>(local.tm_gmtoff) * 1000000LL;
        c.local = c.utc + c.offset;
        c.valid = true;
    }
    return c;
}
// TIME and DATE (BuiltinFunctions.cpp) on this activation's clock: the elapsed timer here; every other form of the
// current time is formatted by the interpreter's own TIME / DATE from the clause's time stamp (input style 'F'), so
// all the TIME / DATE calls of one clause see the same instant. A conversion (an input time or date) is the
// interpreter's, as are rejected calls.
inline Value timeDateBif(Variables &vars, const std::string &name, const std::vector<std::optional<Value>> &a) {
    auto delegate = [&](const std::vector<std::optional<Value>> &args) -> Value {
        auto r = interpreterCall(vars, name, args);
        if (!r) throw std::runtime_error("BIF " + name + ": no result");
        return std::move(*r);
    };
    for (const auto &slot : a) if (slot && slot->isObject()) return delegate(a);
    if (a.size() > 1) return delegate(a);
    char style = 'N';
    if (!a.empty() && a[0]) {
        if (a[0]->bytes.empty()) return delegate(a);
        style = static_cast<char>(std::toupper(static_cast<unsigned char>(a[0]->bytes[0])));
    }
    ClauseClock &c = clauseTime();
    if (name == "TIME" && (style == 'E' || style == 'R')) {
        if (c.elapsed == 0) c.elapsed = c.utc;                               // getElapsed: the first call starts it
        const std::int64_t threshold = c.utc - c.elapsed;
        std::string out = "0";
        if (threshold < 0) c.elapsedReset = true;
        else if (threshold > 0) {
            char work[64];
            std::snprintf(work, sizeof work, "%d.%06d", static_cast<int>(threshold / 1000000LL), static_cast<int>(threshold % 1000000LL));
            out = work;
        }
        if (style == 'R') c.elapsedReset = true;
        return Value::string(out);
    }
    std::vector<std::optional<Value>> args;
    args.push_back(a.empty() ? std::nullopt : a[0]);
    args.push_back(Value::string(std::to_string(c.local)));
    args.push_back(Value::string("F"));
    return delegate(args);
}
inline bool streamBifName(const std::string &name) {
    return name == "LINEIN" || name == "LINEOUT" || name == "LINES" || name == "CHARIN" || name == "CHAROUT" ||
           name == "CHARS" || name == "STREAM";
}
#endif
}
#endif

#ifdef RX2CPP_HOST_API
#include "rx_native_nine.hpp"
#endif
