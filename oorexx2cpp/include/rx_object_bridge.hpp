#pragma once
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
inline void *selfHandle() { return nullptr; }   // the kernel backend has no receiver
inline void *nilObject() { return nullptr; }     // not supported by the kernel backend
inline void *stringHandle(const std::string &) { throw std::runtime_error("interpreter String fallback is not available in kernel mode"); }
inline bool send(void *t, const std::string &s, const std::vector<Arg> &a, Result &r, std::string &c, std::string &x) {
    return rxkernel::send(t, s, a, r, c, x);
}
}
#else
#include <oorexxapi.h>
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
inline void *selfHandle() {
    if (!current || currentSelf == NULLOBJECT) return nullptr;
    return (void *)current->RequestGlobalReference(currentSelf);
}
inline void *stringHandle(const std::string &bytes) {
    RexxThreadContext *t = current;
    if (!t) throw std::runtime_error("interpreter object used outside a native entry");
    return (void *)t->RequestGlobalReference((RexxObjectPtr)t->NewString(bytes.data(), bytes.size()));
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
inline void release(void *h) { if (h && current) current->ReleaseGlobalReference((RexxObjectPtr)h); }
inline bool send(void *target, const std::string &selector, const std::vector<Arg> &args, Result &out,
                 std::string &code, std::string &text) {
    RexxThreadContext *t = need();
    RexxArrayObject arr = t->NewArray(args.size());
    // Omitted arguments stay holes at their positions (an array hole is an omitted ARG).
    for (std::size_t i = 0; i < args.size(); i++) {
        const Arg &a = args[i];
        if (a.omitted) continue;
        t->ArrayPut(arr, a.obj ? (RexxObjectPtr)a.obj : (RexxObjectPtr)t->NewString(a.bytes.data(), a.bytes.size()), i + 1);
    }
    RexxObjectPtr r = t->SendMessage((RexxObjectPtr)target, selector.c_str(), arr);
    if (t->CheckCondition()) {
        RexxCondition cd; t->DecodeConditionInfo(t->GetConditionInfo(), &cd);
        code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        text = cd.message ? t->ObjectToStringValue(cd.message) : "error in message " + selector;
        t->ClearCondition();
        return false;
    }
    if (r == NULLOBJECT) { out.kind = 0; return true; }
    if (t->IsString(r) || t->IsOfType(r, "STRING")) {
        RexxStringObject str = t->ObjectToString(r);
        out.kind = 1; out.bytes.assign(t->StringData(str), t->StringLength(str));
    } else { out.kind = 2; out.obj = (void *)t->RequestGlobalReference(r); }
    return true;
}
// Delegated BIFs run in the host interpreter: a tiny routine per (name, omission pattern, NUMERIC settings), cached.
// receiver~selector(args) for a String receiver, executed under the caller's NUMERIC settings (omitted arguments stay omitted).
inline bool sendStringNumeric(const std::string &receiver, const std::string &selector, const std::vector<Arg> &args,
                              std::size_t digits, std::size_t fuzz, bool engineering, Result &out,
                              std::string &code, std::string &text) {
    RexxThreadContext *t = need();
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
    RexxArrayObject arr = t->NewArray(args.size() + 1);
    t->ArrayPut(arr, (RexxObjectPtr)t->NewString(receiver.data(), receiver.size()), 1);
    for (std::size_t i = 0; i < args.size(); i++) {
        if (args[i].omitted) continue;
        t->ArrayPut(arr, args[i].obj ? (RexxObjectPtr)args[i].obj : (RexxObjectPtr)t->NewString(args[i].bytes.data(), args[i].bytes.size()), i + 2);
    }
    RexxObjectPtr r = t->CallRoutine(routine, arr);
    if (t->CheckCondition()) {
        RexxCondition cd; t->DecodeConditionInfo(t->GetConditionInfo(), &cd);
        code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        text = cd.message ? t->ObjectToStringValue(cd.message) : "error in message " + selector;
        t->ClearCondition();
        return false;
    }
    if (r == NULLOBJECT) { out.kind = 0; return true; }
    if (t->IsString(r) || t->IsOfType(r, "STRING")) {
        RexxStringObject str = t->ObjectToString(r);
        out.kind = 1; out.bytes.assign(t->StringData(str), t->StringLength(str));
    } else { out.kind = 2; out.obj = (void *)t->RequestGlobalReference(r); }
    return true;
}
inline std::string callBif(const std::string &name, const std::vector<std::pair<bool, std::string>> &args,
                           std::size_t digits, std::size_t fuzz, bool engineering, const std::string &directives = std::string()) {
    RexxThreadContext *t = need();
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
    RexxArrayObject arr = t->NewArray(args.size());
    for (const auto &a : args) {
        if (a.first) t->ArrayAppend(arr, (RexxObjectPtr)t->NewString(a.second.data(), a.second.size()));
        else t->ArrayAppend(arr, (RexxObjectPtr)t->Nil());
    }
    RexxObjectPtr r = t->CallRoutine(routine, arr);
    if (t->CheckCondition()) {
        RexxCondition cd; t->DecodeConditionInfo(t->GetConditionInfo(), &cd);
        std::string code = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
        std::string text = cd.message ? t->ObjectToStringValue(cd.message) : "error in " + name;
        t->ClearCondition();
        throw rx::SyntaxCondition(code, text, false);
    }
    if (r == NULLOBJECT) return std::string();
    RexxStringObject str = t->ObjectToString(r);
    return std::string(t->StringData(str), t->StringLength(str));
}
}
#endif
namespace rx {
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
                if (!k) throw std::runtime_error("only interpreter objects can be passed to interpreter messages");
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
            throw SyntaxCondition(code, text, false);
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
// An omitted argument slot (CALL f(,x) / obj~m(,x)).
inline Value omittedArgument() { return Value::fromObject(std::make_shared<EnvObject>(nullptr)); }
// SELF inside a native method is the receiver, as the interpreter sees it.
inline Value selfObject() {
    void *h = rxobj::selfHandle();
    if (!h) throw std::runtime_error("SELF is not available here");
    return Value::fromObject(std::make_shared<EnvObject>(h));
}
// .NAME environment symbols resolve to the interpreter's own classes (.ARRAY, .DIRECTORY, .LIST, ...).
inline Value envClass(const std::string &name) {
    void *h = rxobj::findClass(name);
    if (!h) throw std::runtime_error("unknown environment class ." + name);
    return Value::fromObject(std::make_shared<EnvObject>(h));
}
}
#endif
