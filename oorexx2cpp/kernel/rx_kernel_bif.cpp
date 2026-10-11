#include "RexxCore.h"
#include "StringClass.hpp"
#include "IntegerClass.hpp"
#include "ArrayClass.hpp"
#include "RexxActivation.hpp"
#include "Activity.hpp"
#include "NativeActivation.hpp"
#include "ExpressionStack.hpp"
#include "BuiltinFunctions.hpp"
#include "ContextApi.hpp"
#include "ProtectedObject.hpp"
#include "oorexxapi.h"
#include "rx_kernel_bif.h"
#include <cstdlib>
#include <cstring>
#include <unordered_map>
#include <memory>
#include "bif_decls.inc"
namespace {
struct Entry { const char *name; RexxObject *(*fn)(RexxActivation *, size_t, ExpressionStack *); };
const Entry table[] = {
#include "bif_table.inc"
};
RexxInstance *instance = nullptr;
RexxThreadContext *thread = nullptr;
std::unique_ptr<ApiContext> session;   // one kernel entry for the whole run
void shutdown() { session.reset(); if (instance) instance->Terminate(); }
bool start() {
    if (thread) return true;
    if (!RexxCreateInterpreter(&instance, &thread, nullptr)) return false;
    std::atexit(shutdown);
    return true;
}
const Entry *find(const std::string &n) {
    static std::unordered_map<std::string, const Entry *> idx;
    if (idx.empty()) for (const Entry &e : table) idx[e.name] = &e;
    auto it = idx.find(n);
    return it == idx.end() ? nullptr : it->second;
}
}
namespace rxkernel {
bool handles(const std::string &n) { return find(n) != nullptr; }
bool call(const std::string &n, const std::vector<std::string> &args, const std::vector<bool> &present,
          std::string &rxResult, std::string &rxCode, std::string &rxText) {
    const Entry *e = find(n);
    if (!e || !start()) { rxCode = "98.1"; rxText = "kernel BIF " + n + " unavailable"; return false; }
    bool ok = true;
    {
        if (!session) session.reset(new ApiContext(thread));
        ArrayClass *held = new_array(args.size() ? args.size() : 1);
        ProtectedObject keep(held);
        for (size_t i = 0; i < args.size(); i++) {
            if (!present[i]) continue;
            RexxString *s = new_string(args[i].data(), args[i].size());
            ProtectedObject p(s);
            held->put(s, i + 1);
        }
        RexxInternalObject *frame[64];
        ExpressionStack st(frame, 64);
        for (size_t i = 0; i < args.size(); i++) st.push(present[i] ? held->get(i + 1) : OREF_NULL);
        try {
            RexxObject *r = e->fn(NULL, args.size(), &st);
            if (r == OREF_NULL) rxResult.clear();
            else { RexxString *rs = r->stringValue(); rxResult.assign(rs->getStringData(), rs->getLength()); }
        } catch (NativeActivation *) { ok = false; }
    }
    if (!ok) {
        rxCode = "40.0"; rxText = "Incorrect call to routine " + n;
        if (thread->CheckCondition()) {
            RexxCondition cd; thread->DecodeConditionInfo(thread->GetConditionInfo(), &cd);
            rxCode = std::to_string(cd.code / 1000) + "." + std::to_string(cd.code % 1000);
            if (cd.message) rxText = thread->ObjectToStringValue(cd.message);
            thread->ClearCondition();
        }
    }
    return ok;
}
}
