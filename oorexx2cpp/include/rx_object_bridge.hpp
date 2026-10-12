#pragma once
#include <cstdio>
// Real interpreter objects as rx::Value. One wrapper, two backends:
//  RX2CPP_KERNEL   : the interpreter compiled into the program (rx_kernel_bif.cpp)
//  RX2CPP_HOST_API : the interpreter that loaded this library (public oorexxapi.h, current thread context)
// Either way messages go to the interpreter's own dispatch and results are its own objects: no marshalling.
#if defined(RX2CPP_KERNEL) || defined(RX2CPP_HOST_API)
#include "minirexx_runtime.hpp"
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
#include <cstdlib>
#include <map>
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
    return (void *)t->RequestGlobalReference((RexxObjectPtr)c);
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
// An environment symbol that is not a class: the package's LOCAL directory, then .local, then .environment.
inline void *environmentEntry(const std::string &name) {
    RexxThreadContext *t = need();
    RexxObjectPtr o = NULLOBJECT;
    if (libraryPackage() != NULLOBJECT) {
        RexxObjectPtr local = t->SendMessage0(libraryPackage(), "LOCAL");
        if (t->CheckCondition()) t->ClearCondition();
        else if (local != NULLOBJECT) o = t->SendMessage1(local, "[]", t->String(name.c_str()));
        if (o == t->Nil()) o = NULLOBJECT;
    }
    if (o == NULLOBJECT) o = t->DirectoryAt(t->GetLocalEnvironment(), name.c_str());
    if (o == NULLOBJECT) o = t->DirectoryAt(t->GetGlobalEnvironment(), name.c_str());
    if (t->CheckCondition()) t->ClearCondition();
    if (o == NULLOBJECT) return nullptr;
    return (void *)t->RequestGlobalReference(o);
}
inline void release(void *h) { if (h && current) current->ReleaseGlobalReference((RexxObjectPtr)h); }
// A value that crosses as a plain string: a .String (or the interpreter's internal integer/number forms of it). An instance of
// a String SUBCLASS (json.cls JsonString, ...) is an object and keeps its class.
inline bool isPlainString(RexxThreadContext *t, RexxObjectPtr o) {
    if (t->IsString(o)) return true;
    if (!t->IsOfType(o, "STRING")) return false;
    static thread_local RexxObjectPtr stringClass = NULLOBJECT;
    if (stringClass == NULLOBJECT) stringClass = t->RequestGlobalReference((RexxObjectPtr)t->FindClass("STRING"));
    RexxObjectPtr cls = t->SendMessage0(o, "CLASS");
    if (t->CheckCondition()) { t->ClearCondition(); return true; }
    return cls == stringClass;
}
// The substitution values (ADDITIONAL) of the last interpreter condition a send turned into a C++ exception, so the
// condition can be raised again unchanged when it leaves compiled code.
inline std::vector<std::string> &lastAdditional() { static thread_local std::vector<std::string> v; return v; }
inline void captureAdditional(RexxThreadContext *t, RexxDirectoryObject info) {
    lastAdditional().clear();
    if (info == NULLOBJECT) return;
    RexxObjectPtr add = t->DirectoryAt(info, "ADDITIONAL");
    if (add == NULLOBJECT || !t->IsArray(add)) return;
    const size_t n = t->ArraySize((RexxArrayObject)add);
    for (size_t i = 1; i <= n; ++i) {
        RexxObjectPtr o = t->ArrayAt((RexxArrayObject)add, i);
        lastAdditional().push_back(o == NULLOBJECT ? std::string() : std::string(t->ObjectToStringValue(o)));
    }
}
inline bool send(void *target, const std::string &selector, const std::vector<Arg> &args, Result &out,
                 std::string &code, std::string &text) {
    RexxThreadContext *t = need();
    LocalRefs temps(t);
    RexxArrayObject arr = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(args.size()));
    // Omitted arguments stay holes at their positions (an array hole is an omitted ARG).
    for (std::size_t i = 0; i < args.size(); i++) {
        const Arg &a = args[i];
        if (a.omitted) continue;
        t->ArrayPut(arr, a.obj ? (RexxObjectPtr)a.obj : temps((RexxObjectPtr)t->NewString(a.bytes.data(), a.bytes.size())), i + 1);
    }
    RexxObjectPtr r = temps(t->SendMessage((RexxObjectPtr)target, selector.c_str(), arr));
    if (t->CheckCondition()) {
        RexxDirectoryObject info = t->GetConditionInfo();
        RexxCondition cd; t->DecodeConditionInfo(info, &cd);
        code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        text = cd.message ? t->ObjectToStringValue(cd.message) : "error in message " + selector;
        captureAdditional(t, info);
        t->ClearCondition();
        return false;
    }
    if (r == NULLOBJECT) { out.kind = 0; return true; }
    if (isPlainString(t, r)) {
        RexxStringObject str = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(r));
        out.kind = 1; out.bytes.assign(t->StringData(str), t->StringLength(str));
    } else { out.kind = 2; out.obj = (void *)t->RequestGlobalReference(r); }
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
        text = cd.message ? t->ObjectToStringValue(cd.message) : "error in message " + selector;
        t->ClearCondition();
        return false;
    }
    if (r == NULLOBJECT) { out.kind = 0; return true; }
    if (isPlainString(t, r)) {
        RexxStringObject str = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(r));
        out.kind = 1; out.bytes.assign(t->StringData(str), t->StringLength(str));
    } else { out.kind = 2; out.obj = (void *)t->RequestGlobalReference(r); }
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
        std::string text = cd.message ? t->ObjectToStringValue(cd.message) : "error in " + name;
        t->ClearCondition();
        throw rx::SyntaxCondition(code, text, false);
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
inline std::optional<Value> (*selfObjectHook)() = nullptr;
struct EnvObject final : ObjectDispatch {
    void *handle;
    explicit EnvObject(void *h) : handle(h) {}
    ~EnvObject() override { rxobj::release(handle); }
    static Value wrap(const rxobj::Result &r) {
        if (r.kind == 2) return Value::fromObject(std::make_shared<EnvObject>(r.obj));
        return Value::string(r.bytes);
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
                    if (auto *n = dynamic_cast<NativeRefBase *>(v.object.get())) {
                        a.obj = n->materialize();
                        out.push_back(std::move(a));
                        continue;
                    }
                    throw std::runtime_error("only interpreter objects can be passed to interpreter messages");
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
            if (code == "97.1") throw NoMethod(text);
            SyntaxCondition condition(code, text, false);
            for (const std::string &a : rxobj::lastAdditional()) condition.substitutions.push_back(Value::string(a));
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
    return Value::fromObject(std::make_shared<EnvObject>(h));
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
        if (void *entry = rxobj::environmentEntry(name)) return Value::fromObject(std::make_shared<EnvObject>(entry));
        throw std::runtime_error("unknown environment class ." + name);
    }
    auto obj = std::make_shared<EnvObject>(h);
    Value value = Value::fromObject(obj);
    cache.emplace(name, value);
    return value;
}
#ifdef RX2CPP_HOST_API
// Stream BIFs (STREAM CHARIN CHAROUT CHARS LINEIN LINEOUT LINES) from compiled code: one interpreter .Stream object per
// name and thread, so OPEN / CHAROUT / CLOSE issued by separate BIF calls act on the same stream (the interpreter keeps
// such a table per activation; a compiled activation needs its own). A call without a stream name (default streams)
// returns nullopt and goes the ordinary route.
inline std::optional<Value> streamBif(const std::string &name, const std::vector<std::optional<Value>> &a) {
    static const char *names[] = {"STREAM","CHARIN","CHAROUT","CHARS","LINEIN","LINEOUT","LINES", nullptr};
    bool known = false;
    for (const char **n = names; *n; ++n) if (name == *n) known = true;
    if (!known || a.empty() || !a[0] || a[0]->isObject() || a[0]->bytes.empty()) return std::nullopt;
    static thread_local std::unordered_map<std::string, Value> table;
    const std::string &key = a[0]->bytes;
    auto it = table.find(key);
    if (it == table.end()) {
        Value cls = envClass("STREAM");
        MessageResult made = cls.object->sendMessage("NEW", {Value::string(key)});
        if (!made || !made->isObject()) throw std::runtime_error("cannot create stream " + key);
        it = table.emplace(key, *made).first;
    }
    Value stream = it->second;
    std::vector<Value> rest;
    for (std::size_t i = 1; i < a.size(); ++i) rest.push_back(a[i] ? *a[i] : omittedArgument());
    while (!rest.empty() && rest.back().isObject() && dynamic_cast<EnvObject *>(rest.back().object.get()) &&
           static_cast<EnvObject *>(rest.back().object.get())->handle == nullptr) rest.pop_back();
    std::string selector = name;
    if (name == "STREAM") {
        std::string op = rest.empty() || rest[0].isObject() ? std::string("S") : rest[0].bytes;
        const char o = op.empty() ? 'S' : static_cast<char>(std::toupper(static_cast<unsigned char>(op[0])));
        std::vector<Value> args;
        if (o == 'C') {
            if (rest.size() < 2) return std::nullopt;
            selector = "COMMAND"; args.push_back(rest[1]);
            std::string cmd = rest[1].bytes;
            for (char &c : cmd) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
            MessageResult r = stream.object->sendMessage(selector, args);
            if (cmd.find("CLOSE") != std::string::npos) table.erase(key);
            return r ? *r : Value::string("");
        }
        selector = o == 'D' ? "DESCRIPTION" : "STATE";
        MessageResult r = stream.object->sendMessage(selector, {});
        return r ? *r : Value::string("");
    }
    MessageResult r = stream.object->sendMessage(selector, rest);
    if ((name == "CHAROUT" || name == "LINEOUT") && rest.empty()) table.erase(key);   // CHAROUT(name) closes the stream
    return r ? *r : Value::string("");
}
// CALL / function call of a routine only the interpreter can resolve (rexxutil SysXxx, external .rex routines), run in a
// small interpreter routine under the caller's NUMERIC settings. An argument that names a stem the callee filled
// (SysFileTree spec, 'files.', ...) is copied back into the caller's compiled variables, as the interpreter would leave it.
inline MessageResult interpreterCall(Variables &vars, const std::string &name, const std::vector<std::optional<Value>> &args) {
    RexxThreadContext *t = rxobj::need();
    rxobj::LocalRefs temps(t);
    rxobj::bifStat("CALL " + name);
    std::string call = "call " + name + " ";
    for (std::size_t i = 0; i < args.size(); ++i) {
        if (i) call += ",";
        if (args[i]) call += "arg(" + std::to_string(i + 1) + ")";
    }
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
        routine = t->NewRoutine("rx2cpp_call", source.c_str(), source.size());
        if (routine == NULLOBJECT) throw std::runtime_error("cannot create interpreter call for " + name);
        t->RequestGlobalReference((RexxObjectPtr)routine);
        cache.emplace(source, routine);
    } else routine = it->second;
    RexxArrayObject arr = (RexxArrayObject)temps((RexxObjectPtr)t->NewArray(args.size()));
    std::vector<rxobj::Arg> conv;
    for (std::size_t i = 0; i < args.size(); ++i) {
        if (!args[i]) continue;
        conv.clear(); EnvObject::convert({*args[i]}, conv);
        RexxObjectPtr o = conv[0].obj ? (RexxObjectPtr)conv[0].obj : temps((RexxObjectPtr)t->NewString(conv[0].bytes.data(), conv[0].bytes.size()));
        t->ArrayPut(arr, o, i + 1);
    }
    RexxObjectPtr r = temps(t->CallRoutine(routine, arr));
    if (t->CheckCondition()) {
        RexxCondition cd; t->DecodeConditionInfo(t->GetConditionInfo(), &cd);
        std::string code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        std::string text = cd.message ? t->ObjectToStringValue(cd.message) : "error in " + name;
        t->ClearCondition();
        throw SyntaxCondition(code, text, false);
    }
    if (r == NULLOBJECT) return std::nullopt;
    RexxArrayObject out = (RexxArrayObject)r;
    auto text = [&](RexxObjectPtr o) { RexxStringObject so = (RexxStringObject)temps((RexxObjectPtr)t->ObjectToString(o)); return std::string(t->StringData(so), t->StringLength(so)); };
    auto valueOf = [&](RexxObjectPtr o) -> Value {
        if (o == t->Nil()) return nil();
        if (rxobj::isPlainString(t, o)) return Value::string(text(o));
        return Value::fromObject(std::make_shared<EnvObject>((void *)t->RequestGlobalReference(o)));
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
#endif
}
#endif
