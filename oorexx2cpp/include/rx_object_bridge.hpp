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
inline bool send(void *t, const std::string &s, const std::vector<Arg> &a, Result &r, std::string &c, std::string &x) {
    return rxkernel::send(t, s, a, r, c, x);
}
}
#else
#include <oorexxapi.h>
namespace rxobj {
struct Arg { void *obj = nullptr; std::string bytes; };
struct Result { int kind = 0; std::string bytes; void *obj = nullptr; };
inline thread_local RexxThreadContext *current = nullptr;
// Set by every native method/routine entry for the duration of the call.
struct Scope {
    RexxThreadContext *previous;
    explicit Scope(RexxThreadContext *c) : previous(current) { current = c; }
    ~Scope() { current = previous; }
};
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
    for (const Arg &a : args)
        t->ArrayAppend(arr, a.obj ? (RexxObjectPtr)a.obj : (RexxObjectPtr)t->NewString(a.bytes.data(), a.bytes.size()));
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
                if (!k) throw std::runtime_error("only interpreter objects can be passed to interpreter messages");
                a.obj = k->handle;
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
// .NAME environment symbols resolve to the interpreter's own classes (.ARRAY, .DIRECTORY, .LIST, ...).
inline Value envClass(const std::string &name) {
    void *h = rxobj::findClass(name);
    if (!h) throw std::runtime_error("unknown environment class ." + name);
    return Value::fromObject(std::make_shared<EnvObject>(h));
}
}
#endif
