// rx2cpp external-library host: loads ooRexx typed-routine packages (the RexxGetPackage ABI used by
// rxsock, rxmath, rxunixsys ...) and calls their routines through a host-implemented
// RexxCallContext / RexxThreadContext. It does NOT link to the interpreter. Every context
// function that is not implemented FAILS CLOSED with a diagnostic naming the slot.
#pragma once
#include <dlfcn.h>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>
#include "oorexxapi.h"

namespace rxext {

struct Error : std::runtime_error {      // a Rexx condition raised by a routine or by the host
    std::string code;                    // "40.1", "93.906" ...
    Error(std::string c, const std::string &m) : std::runtime_error(m), code(std::move(c)) {}
};
struct Unsupported : std::runtime_error {
    explicit Unsupported(const std::string &slot)
        : std::runtime_error("rx2cpp external library: context function '" + slot + "' is not implemented") {}
};

// Stem storage is abstract so a compiled program's own variable pool can back it.
struct StemStore {
    virtual ~StemStore() = default;
    virtual std::optional<std::string> get(const std::string &tail) = 0;
    virtual void set(const std::string &tail, const std::string &v) = 0;
    virtual void drop(const std::string &tail) = 0;
};
struct MapStem : StemStore {
    std::map<std::string, std::string> m;
    std::optional<std::string> get(const std::string &t) override {
        auto i = m.find(t); if (i == m.end()) return std::nullopt; return i->second; }
    void set(const std::string &t, const std::string &v) override { m[t] = v; }
    void drop(const std::string &t) override { m.erase(t); }
};

// A stem living in the caller's variable pool: tail T of stem "S." is the variable "S.T".
struct PoolStem : StemStore {
    std::string name;   // as resolved by the provider; ends with '.'
    std::function<void(const std::string &, const std::string &, const std::string &)> *setFn = nullptr;
    std::function<std::optional<std::string>(const std::string &, const std::string &)> *getFn = nullptr;
    std::function<void(const std::string &, const std::string &)> *dropFn = nullptr;
    std::optional<std::string> get(const std::string &t) override { return (*getFn)(name, t); }
    void set(const std::string &t, const std::string &v) override { (*setFn)(name, t, v); }
    void drop(const std::string &t) override { (*dropFn)(name, t); }
};

struct Obj {
    enum Kind { Str, Stem, Array } kind = Str;
    std::string s;                       // Str value
    StemStore *stem = nullptr;           // Stem
    std::vector<Obj *> arr;              // Array
};

namespace detail {
#include "extlib_messages.inc"
[[noreturn]] inline void trapped(const char *name) { throw Unsupported(name); }
#include "extlib_traps.inc"
[[noreturn]] static void trapCall_GetArguments() { trapped("call:GetArguments"); }
[[noreturn]] static void trapCall_GetArgument() { trapped("call:GetArgument"); }
[[noreturn]] static void trapCall_GetRoutineName() { trapped("call:GetRoutineName"); }
[[noreturn]] static void trapCall_GetRoutine() { trapped("call:GetRoutine"); }
[[noreturn]] static void trapCall_SetContextVariable() { trapped("call:SetContextVariable"); }
[[noreturn]] static void trapCall_GetContextVariable() { trapped("call:GetContextVariable"); }
[[noreturn]] static void trapCall_DropContextVariable() { trapped("call:DropContextVariable"); }
[[noreturn]] static void trapCall_GetAllContextVariables() { trapped("call:GetAllContextVariables"); }
[[noreturn]] static void trapCall_ResolveStemVariable() { trapped("call:ResolveStemVariable"); }
[[noreturn]] static void trapCall_InvalidRoutine() { trapped("call:InvalidRoutine"); }
[[noreturn]] static void trapCall_GetContextDigits() { trapped("call:GetContextDigits"); }
[[noreturn]] static void trapCall_GetContextFuzz() { trapped("call:GetContextFuzz"); }
[[noreturn]] static void trapCall_GetContextForm() { trapped("call:GetContextForm"); }
[[noreturn]] static void trapCall_GetCallerContext() { trapped("call:GetCallerContext"); }
[[noreturn]] static void trapCall_FindContextClass() { trapped("call:FindContextClass"); }
[[noreturn]] static void trapCall_GetContextVariableReference() { trapped("call:GetContextVariableReference"); }
[[noreturn]] static void trapCall_ThrowException0() { trapped("call:ThrowException0"); }
[[noreturn]] static void trapCall_ThrowException1() { trapped("call:ThrowException1"); }
[[noreturn]] static void trapCall_ThrowException2() { trapped("call:ThrowException2"); }
[[noreturn]] static void trapCall_ThrowException() { trapped("call:ThrowException"); }
[[noreturn]] static void trapCall_ThrowCondition() { trapped("call:ThrowCondition"); }
}

class Host {
public:
    struct Arg { std::string s; StemStore *stem = nullptr; bool omitted = false; };
    struct Numeric { size_t digits = 9, fuzz = 0; int form = 0; } numeric;   // fed from the caller's NUMERIC state
    std::vector<std::string> searchDirs;
    // The caller's variable pool, as seen by SetContextVariable/GetContextVariable/DropContextVariable.
    // Defaults to a private map; a compiled program binds its own Variables here.
    std::function<void(const std::string &, const std::string &)> varSet =
        [this](const std::string &n, const std::string &v) { defaultVars_[upper(n)] = v; };
    std::function<std::optional<std::string>(const std::string &)> varGet =
        [this](const std::string &n) -> std::optional<std::string> { auto i = defaultVars_.find(upper(n)); if (i == defaultVars_.end()) return std::nullopt; return i->second; };
    std::function<void(const std::string &)> varDrop =
        [this](const std::string &n) { defaultVars_.erase(upper(n)); };
    // Stem elements are addressed by a LITERAL tail (no variable substitution), unlike the symbol hooks
    // above whose names get normal Rexx symbol resolution (a compound tail naming a variable is resolved,
    // with its case, in the current activation). A compiled activation provider should bind both.
    // Defaults emulate them over the flat map.
    std::function<void(const std::string &, const std::string &, const std::string &)> tailSet =
        [this](const std::string &stem, const std::string &tail, const std::string &v) { defaultVars_[stem + tail] = v; };
    std::function<std::optional<std::string>(const std::string &, const std::string &)> tailGet =
        [this](const std::string &stem, const std::string &tail) -> std::optional<std::string> {
            auto i = defaultVars_.find(stem + tail); if (i == defaultVars_.end()) return std::nullopt; return i->second; };
    std::function<void(const std::string &, const std::string &)> tailDrop =
        [this](const std::string &stem, const std::string &tail) { defaultVars_.erase(stem + tail); };

    Host() { build(); }
    Host(const Host &) = delete;
    Host &operator=(const Host &) = delete;

    void load(const std::string &name) {
        if (libs_.count(name)) return;
        void *h = nullptr;
        std::vector<std::string> tries;
        for (auto &d : searchDirs) tries.push_back(d + "/lib" + name + ".so");
        tries.push_back("lib" + name + ".so");
        tries.push_back(name);
        for (auto &t : tries) if ((h = dlopen(t.c_str(), RTLD_NOW | RTLD_LOCAL))) break;
        if (!h) throw Error("98.926", "unable to load library '" + name + "'");
        auto get = reinterpret_cast<RexxPackageEntry *(*)()>(dlsym(h, "RexxGetPackage"));
        if (!get) throw Error("98.926", "library '" + name + "' exports no RexxGetPackage");
        RexxPackageEntry *pkg = get();
        if (pkg->size != sizeof(RexxPackageEntry))
            throw Error("98.926", "library '" + name + "' has an incompatible package header");
        if (pkg->methods && pkg->methods->name)
            throw Error("98.926", "library '" + name + "' declares native classes; use the native class backend");
        std::map<std::string, void *> found;
        for (RexxRoutineEntry *r = pkg->routines; r && r->name; r++) {
            if (r->style != ROUTINE_TYPED_STYLE)
                throw Error("98.926", "library '" + name + "': classic-style routine " + r->name + " is not supported");
            found[upper(r->name)] = r->entryPoint;
        }
        libs_[name] = pkg;
        for (auto &f : found) routines_[f.first] = f.second;
        if (pkg->loader) guarded([&] { pkg->loader(&threadCtx_); });
    }
    // A stem bound to the caller's variable pool (what a `h.` argument or ResolveStemVariable yields).
    StemStore *poolStem(std::string name) {
        name = upper(name);
        auto p = std::make_unique<PoolStem>(); p->name = std::move(name);
        p->setFn = &tailSet; p->getFn = &tailGet; p->dropFn = &tailDrop;
        poolStems_.push_back(std::move(p)); return poolStems_.back().get();
    }
    bool hasRoutine(const std::string &n) const { return routines_.count(upper(n)) != 0; }

    // Returns nullopt for "no result" (NULL CSTRING / NULL object).
    std::optional<std::string> call(const std::string &routine, const std::vector<Arg> &args) {
        auto it = routines_.find(upper(routine));
        if (it == routines_.end()) throw Error("43.1", "Could not find routine \"" + routine + "\"");
        typedef uint16_t *(*Stub)(RexxCallContext *, ValueDescriptor *);
        Stub stub = reinterpret_cast<Stub>(it->second);
        const uint16_t *sig = stub(&callCtx_, nullptr);
        const uint16_t ret = sig[0];
        std::vector<uint16_t> ptypes(sig + 1, std::find(sig + 1, sig + 64, (uint16_t)0));
        size_t required = 0;
        for (size_t i = 0; i < ptypes.size(); i++) {
            const uint16_t t = ptypes[i];
            if (!(t & REXX_OPTIONAL_ARGUMENT) && t != REXX_VALUE_ARGLIST && t != REXX_VALUE_NAME) required = i + 1;
        }
        const bool wantsArglist = !ptypes.empty() && ptypes[0] == REXX_VALUE_ARGLIST;
        if (!wantsArglist && args.size() > ptypes.size())
            throw Error("88.922", "Too many arguments in invocation; " + std::to_string(ptypes.size()) + " expected.");
        if (!wantsArglist) {
            for (size_t i = 0; i < required; i++)
                if (i >= args.size() || args[i].omitted)
                    throw Error("88.901", "Missing argument; argument " + std::to_string(i + 1) + " is required.");
        }
        return guarded([&]() -> std::optional<std::string> {
            routineName_ = routine; curArgs_ = &args;
            std::vector<ValueDescriptor> d(ptypes.size() + 1);
            std::memset(d.data(), 0, d.size() * sizeof(ValueDescriptor));
            d[0].type = ret;
            for (size_t i = 0; i < ptypes.size(); i++) {
                ValueDescriptor &v = d[i + 1];
                v.type = ptypes[i];
                const bool optional = (ptypes[i] & REXX_OPTIONAL_ARGUMENT) != 0;
                const uint16_t t = ptypes[i] & ~REXX_OPTIONAL_ARGUMENT;
                if (t == REXX_VALUE_ARGLIST) {
                    Obj *a = mk(Obj::Array);
                    for (auto &x : args) a->arr.push_back(handleFor(x));
                    v.value.value_ARGLIST = reinterpret_cast<RexxArrayObject>(a); v.flags = ARGUMENT_EXISTS; continue;
                }
                if (t == REXX_VALUE_NAME) { v.value.value_NAME = keep(routine); v.flags = ARGUMENT_EXISTS; continue; }
                const bool present = i < args.size() && !args[i].omitted;
                if (!present) { if (!optional) throw Error("88.901", "Missing argument; argument " + std::to_string(i + 1) + " is required."); continue; }
                v.flags = ARGUMENT_EXISTS;
                convertIn(v, t, args[i], i + 1, routine);
            }
            callCtx_.arguments = d.data();
            stub(&callCtx_, d.data());
            if (pendingCode_) { auto c = *pendingCode_; auto m = pendingText_; throw Error(c, m); }
            return convertOut(d[0], ret & ~REXX_OPTIONAL_ARGUMENT);
        });
    }

private:
    std::map<std::string, RexxPackageEntry *> libs_;
    std::map<std::string, void *> routines_;
    std::vector<std::unique_ptr<Obj>> arena_;
    std::vector<std::unique_ptr<std::string>> strs_;
    std::vector<std::unique_ptr<MapStem>> ownStems_;
    std::vector<std::unique_ptr<PoolStem>> poolStems_;
    std::vector<std::unique_ptr<Obj>> persistent_;
    int depth_ = 0;
    std::map<std::string, std::string> defaultVars_;
    std::string routineName_;
    const std::vector<Arg> *curArgs_ = nullptr;
    std::optional<std::string> pendingCode_; std::string pendingText_;

    RexxThreadInterface thr_{};
    CallContextInterface callIf_{};
    RexxInstanceInterface instIf_{};
    RexxInstance inst_{};
    RexxThreadContext threadCtx_{};
    RexxCallContext callCtx_{};

    static std::string upper(std::string s) { for (auto &c : s) c = (char)toupper((unsigned char)c); return s; }
    template <class F> auto guarded(F f) -> decltype(f()) {
        struct Reset { Host &h; ~Reset() {
            if (--h.depth_ == 0) { h.arena_.clear(); h.strs_.clear(); h.pendingCode_.reset(); h.pendingText_.clear(); h.curArgs_ = nullptr; } } };
        depth_++; Reset r{*this};
        return f();
    }
    Obj *mk(Obj::Kind k, std::string s = "") {
        arena_.push_back(std::make_unique<Obj>()); arena_.back()->kind = k; arena_.back()->s = std::move(s); return arena_.back().get(); }
    CSTRING keep(const std::string &s) { strs_.push_back(std::make_unique<std::string>(s)); return strs_.back()->c_str(); }
    Obj *handleFor(const Arg &a) {
        if (a.stem) { Obj *o = mk(Obj::Stem); o->stem = a.stem; return o; }
        return mk(Obj::Str, a.s);
    }
    template <class T> static T *R(const Obj *o) { return reinterpret_cast<T *>(const_cast<Obj *>(o)); }
    static Obj *O(const void *p) { return static_cast<Obj *>(const_cast<void *>(p)); }
    static Host &H(RexxThreadContext *c) { return *static_cast<Host *>(c->instance->applicationData); }
    static Host &HC(RexxCallContext *c) { return H(c->threadContext); }

    // ---- value conversion (Rexx whole-number / number rules) -------------------------------
    static std::string trim(const std::string &s) {
        size_t a = 0, b = s.size();
        while (a < b && s[a] == ' ') a++;
        while (b > a && s[b - 1] == ' ') b--;
        return s.substr(a, b - a);
    }
    // Rexx number -> whole number: optional sign (blanks allowed after it), digits with an optional
    // fraction and exponent, accepted only when the value is integral and fits in 64 bits.
    static bool parseWhole(const std::string &raw, long long &out) {
        std::string s = trim(raw); if (s.empty()) return false;
        size_t i = 0; bool neg = false;
        if (s[i] == '+' || s[i] == '-') { neg = s[i] == '-'; i++; while (i < s.size() && s[i] == ' ') i++; }
        std::string digits; long exp10 = 0; bool any = false, dot = false;
        for (; i < s.size(); i++) {
            const char ch = s[i];
            if (isdigit((unsigned char)ch)) { digits += ch; any = true; if (dot) exp10--; }
            else if (ch == '.' && !dot) dot = true;
            else break;
        }
        if (!any) return false;
        if (i < s.size()) {
            if (s[i] != 'E' && s[i] != 'e') return false;
            i++; bool eneg = false;
            if (i < s.size() && (s[i] == '+' || s[i] == '-')) { eneg = s[i] == '-'; i++; }
            if (i >= s.size()) return false;
            long e = 0;
            for (; i < s.size(); i++) { if (!isdigit((unsigned char)s[i]) || e > 100000) return false; e = e * 10 + (s[i] - '0'); }
            exp10 += eneg ? -e : e;
        }
        size_t lead = 0; while (lead + 1 < digits.size() && digits[lead] == '0') lead++;
        digits.erase(0, lead);
        if (digits == "0") { out = 0; return true; }
        while (exp10 < 0 && !digits.empty() && digits.back() == '0') { digits.pop_back(); exp10++; }
        if (exp10 < 0) return false;
        if (digits.size() + (size_t)exp10 > 19) return false;
        unsigned long long v = 0;
        for (char ch : digits) v = v * 10 + (ch - '0');
        for (long k = 0; k < exp10; k++) { if (v > ~0ULL / 10) return false; v *= 10; }
        if (neg) { if (v > (unsigned long long)INT64_MAX + 1) return false; out = (long long)(0 - v); }
        else { if (v > (unsigned long long)INT64_MAX) return false; out = (long long)v; }
        return true;
    }
    static bool parseDouble(const std::string &raw, double &out) {
        std::string s = trim(raw); if (s.empty()) return false;
        for (char c : s) if (!(isdigit((unsigned char)c) || c == '+' || c == '-' || c == '.' || c == 'e' || c == 'E')) return false;
        char *end = nullptr; out = std::strtod(s.c_str(), &end);
        return end && *end == 0 && std::isfinite(out);
    }
    static std::string fromWhole(long long v) { return std::to_string(v); }
    static std::string fromUnsigned(unsigned long long v) { return std::to_string(v); }
    // Mirrors NumberString::newInstanceFromDouble + stringValue (ooRexx 5.3.0): print with
    // "%.*g" at min(16,digits)+2 significant digits, round to `digits` digits keeping the zeros,
    // then plain notation unless adjusted size >= digits or |exponent| > 2*digits.
    static std::string fromDouble(double d, size_t prec) {
        if (std::isnan(d)) return "nan";
        if (std::isinf(d)) return d < 0 ? "-infinity" : "+infinity";
        if (d == 0) return "0";
        if (prec < 1) prec = 1;
        char b[64]; std::snprintf(b, sizeof b, "%.*g", (int)std::min<size_t>(16, prec) + 2, d);
        std::string s = b; const bool neg = s[0] == '-'; if (neg) s.erase(0, 1);
        long exp10 = 0; size_t e = s.find('e');
        if (e != std::string::npos) { exp10 = std::atol(s.c_str() + e + 1); s.erase(e); }
        std::string digits; bool dot = false;
        for (char c : s) { if (c == '.') { dot = true; continue; } digits += c; if (dot) exp10--; }
        size_t lead = 0; while (lead + 1 < digits.size() && digits[lead] == '0') lead++;
        digits.erase(0, lead);
        if (digits.size() > prec) {                         // round half up to `prec` digits
            const bool up = digits[prec] >= '5';
            const long removed = (long)(digits.size() - prec);
            digits.erase(prec); exp10 += removed;
            if (up) {
                int i = (int)digits.size() - 1;
                while (i >= 0 && digits[i] == '9') { digits[i] = '0'; i--; }
                if (i >= 0) digits[i]++;
                else { digits.insert(digits.begin(), '1'); digits.pop_back(); exp10++; }
            }
        }
        const long n = (long)digits.size();
        std::string out;
        if (exp10 == 0) { out = digits; }                     // all integer digits
        else {
            long adjSize = exp10 + n - 1, adjExp = exp10; std::string expstr;
            if (adjSize >= (long)prec || std::labs(exp10) > (long)prec * 2) {
                adjExp -= adjSize;
                if (adjSize != 0) expstr = std::string("E") + (adjSize < 0 ? "-" : "+") + std::to_string(std::labs(adjSize));
            }
            const long adjLen = adjExp + n;
            if (adjLen <= 0) out = "0." + std::string(-adjLen, '0') + digits;
            else if (adjLen >= n) out = digits + std::string(adjLen - n, '0');
            else out = digits.substr(0, adjLen) + "." + digits.substr(adjLen);
            out += expstr;
        }
        return neg ? "-" + out : out;
    }
    // text of any object (stems/arrays have no string value here)
    static const std::string &text(const Obj *o) { return o->s; }

    // Messages and codes mirror ooRexx 5.3.0 r13196 (88.901/88.905/88.907/88.921/88.922 verified against the
    // interpreter; the others are the neighbouring ooRexx codes and are marked UNVERIFIED in the docs).
    [[noreturn]] void badArg(size_t pos, uint16_t t, const std::string &found) {
        const std::string a = "Argument " + std::to_string(pos) + " ";
        const std::string f = "; found \"" + found + "\".";
        switch (t) {
        case REXX_VALUE_int: case REXX_VALUE_int32_t: throw Error("88.907", a + "must be in the range -2147483648 to 2147483647" + f);
        case REXX_VALUE_int8_t: throw Error("88.907", a + "must be in the range -128 to 127" + f);
        case REXX_VALUE_int16_t: throw Error("88.907", a + "must be in the range -32768 to 32767" + f);
        case REXX_VALUE_uint8_t: throw Error("88.907", a + "must be in the range 0 to 255" + f);
        case REXX_VALUE_uint16_t: throw Error("88.907", a + "must be in the range 0 to 65535" + f);
        case REXX_VALUE_uint32_t: throw Error("88.907", a + "must be in the range 0 to 4294967295" + f);
        case REXX_VALUE_positive_wholenumber_t: throw Error("88.905", a + "must be a positive whole number" + f);
        case REXX_VALUE_nonnegative_wholenumber_t: case REXX_VALUE_stringsize_t: case REXX_VALUE_size_t:
        case REXX_VALUE_uint64_t: case REXX_VALUE_uintptr_t: throw Error("88.904", a + "must be a non-negative whole number" + f);
        case REXX_VALUE_double: case REXX_VALUE_float: throw Error("88.921", a + "must be a valid double value" + f);
        case REXX_VALUE_logical_t: throw Error("88.908", a + "must be 0 or 1" + f);
        case REXX_VALUE_CSTRING: case REXX_VALUE_RexxStringObject: throw Error("88.914", a + "must be a string" + f);
        case REXX_VALUE_RexxStemObject: throw Error("88.914", a + "must be a stem" + f);
        default: throw Error("88.906", a + "must be a whole number" + f);
        }
    }
    void convertIn(ValueDescriptor &v, uint16_t t, const Arg &a, size_t pos, const std::string &) {
        long long w = 0; double dv = 0;
        auto whole = [&](long long lo, long long hi) -> long long {
            if (a.stem || !parseWhole(a.s, w) || w < lo || w > hi) badArg(pos, t, a.stem ? "stem" : a.s);
            return w; };
        switch (t) {
        case REXX_VALUE_CSTRING: if (a.stem) badArg(pos, t, "stem"); v.value.value_CSTRING = keep(a.s); break;
        case REXX_VALUE_RexxStringObject: if (a.stem) badArg(pos, t, "stem"); v.value.value_RexxStringObject = R<_RexxStringObject>(mk(Obj::Str, a.s)); break;
        case REXX_VALUE_RexxObjectPtr: v.value.value_RexxObjectPtr = R<_RexxObjectPtr>(handleFor(a)); break;
        case REXX_VALUE_RexxStemObject:
            if (!a.stem) badArg(pos, t, a.s);
            v.value.value_RexxStemObject = R<_RexxStemObject>(handleFor(a)); break;
        case REXX_VALUE_int: case REXX_VALUE_int32_t: v.value.value_int = (int)whole(INT32_MIN, INT32_MAX); break;
        case REXX_VALUE_int8_t: v.value.value_int8_t = (int8_t)whole(INT8_MIN, INT8_MAX); break;
        case REXX_VALUE_int16_t: v.value.value_int16_t = (int16_t)whole(INT16_MIN, INT16_MAX); break;
        case REXX_VALUE_wholenumber_t: case REXX_VALUE_int64_t: case REXX_VALUE_ssize_t: case REXX_VALUE_intptr_t:
            v.value.value_int64_t = whole(INT64_MIN, INT64_MAX); break;
        case REXX_VALUE_positive_wholenumber_t: v.value.value_wholenumber_t = whole(1, INT64_MAX); break;
        case REXX_VALUE_nonnegative_wholenumber_t: case REXX_VALUE_stringsize_t: case REXX_VALUE_size_t:
        case REXX_VALUE_uint64_t: case REXX_VALUE_uintptr_t: v.value.value_uint64_t = (uint64_t)whole(0, INT64_MAX); break;
        case REXX_VALUE_uint8_t: v.value.value_uint8_t = (uint8_t)whole(0, UINT8_MAX); break;
        case REXX_VALUE_uint16_t: v.value.value_uint16_t = (uint16_t)whole(0, UINT16_MAX); break;
        case REXX_VALUE_uint32_t: v.value.value_uint32_t = (uint32_t)whole(0, UINT32_MAX); break;
        case REXX_VALUE_double: if (a.stem || !parseDouble(a.s, dv)) badArg(pos, t, a.stem ? "stem" : a.s); v.value.value_double = dv; break;
        case REXX_VALUE_float: if (a.stem || !parseDouble(a.s, dv)) badArg(pos, t, a.stem ? "stem" : a.s); v.value.value_float = (float)dv; break;
        case REXX_VALUE_logical_t:
            if (a.stem || (a.s != "0" && a.s != "1")) badArg(pos, t, a.stem ? "stem" : a.s);
            v.value.value_logical_t = a.s == "1"; break;
        default: throw Unsupported("argument type " + std::to_string(t));
        }
    }
    std::optional<std::string> convertOut(const ValueDescriptor &d, uint16_t t) {
        switch (t) {
        case REXX_VALUE_int: case REXX_VALUE_int32_t: return fromWhole(d.value.value_int);
        case REXX_VALUE_int8_t: return fromWhole(d.value.value_int8_t);
        case REXX_VALUE_int16_t: return fromWhole(d.value.value_int16_t);
        case REXX_VALUE_wholenumber_t: case REXX_VALUE_int64_t: case REXX_VALUE_ssize_t: case REXX_VALUE_intptr_t:
        case REXX_VALUE_positive_wholenumber_t: case REXX_VALUE_nonnegative_wholenumber_t:
            return fromWhole(d.value.value_int64_t);
        case REXX_VALUE_stringsize_t: case REXX_VALUE_size_t: case REXX_VALUE_uint64_t: case REXX_VALUE_uintptr_t:
            return fromUnsigned(d.value.value_uint64_t);
        case REXX_VALUE_uint8_t: return fromUnsigned(d.value.value_uint8_t);
        case REXX_VALUE_uint16_t: return fromUnsigned(d.value.value_uint16_t);
        case REXX_VALUE_uint32_t: return fromUnsigned(d.value.value_uint32_t);
        case REXX_VALUE_logical_t: return std::string(d.value.value_logical_t ? "1" : "0");
        case REXX_VALUE_double: return fromDouble(d.value.value_double, numeric.digits);
        case REXX_VALUE_float: return fromDouble(d.value.value_float, numeric.digits);
        case REXX_VALUE_CSTRING: if (!d.value.value_CSTRING) return std::nullopt; return std::string(d.value.value_CSTRING);
        case REXX_VALUE_RexxStringObject: case REXX_VALUE_RexxObjectPtr:
            if (!d.value.value_RexxObjectPtr) return std::nullopt;
            { Obj *o = O(d.value.value_RexxObjectPtr);
              if (o->kind != Obj::Str) throw Unsupported("returning a non-string object");
              return o->s; }
        default: throw Unsupported("return type " + std::to_string(t));
        }
    }

    void raise(size_t number, const std::vector<std::string> &subs) {
        const int major = (int)(number / 1000), minor = (int)(number % 1000);
        char code[32]; std::snprintf(code, sizeof code, "%d.%03d", major, minor);
        std::string text = "error " + std::string(code);
        for (auto &m : detail::kMessages)
            if (m.code == major && m.sub == minor) {
                text.clear();
                for (const char *q = m.text; *q; q++) {
                    if (*q == '&' && q[1] >= '1' && q[1] <= '9') {
                        size_t k = (size_t)(q[1] - '1'); if (k < subs.size()) text += subs[k]; q++;
                    } else text += *q;
                }
                break;
            }
        pendingCode_ = code; pendingText_ = text;
    }
    void build();
};

inline void Host::build() {
    detail::installTraps(thr_);
    inst_.functions = &instIf_; inst_.applicationData = this;
    thr_.interfaceVersion = THREAD_INTERFACE_VERSION;
    threadCtx_.instance = &inst_; threadCtx_.functions = &thr_;
    persistent_.push_back(std::make_unique<Obj>()); persistent_.back()->s = "The NIL object"; thr_.RexxNil = R<_RexxObjectPtr>(persistent_.back().get());
    persistent_.push_back(std::make_unique<Obj>()); persistent_.back()->s = "1"; thr_.RexxTrue = R<_RexxObjectPtr>(persistent_.back().get());
    persistent_.push_back(std::make_unique<Obj>()); persistent_.back()->s = "0"; thr_.RexxFalse = R<_RexxObjectPtr>(persistent_.back().get());
    persistent_.push_back(std::make_unique<Obj>()); persistent_.back()->s = ""; thr_.RexxNullString = R<_RexxStringObject>(persistent_.back().get());

    // ---- strings and numbers ----
    thr_.NewString = [](RexxThreadContext *c, CSTRING d, size_t n) -> RexxStringObject { return R<_RexxStringObject>(H(c).mk(Obj::Str, std::string(d, n))); };
    thr_.NewStringFromAsciiz = [](RexxThreadContext *c, CSTRING d) -> RexxStringObject { return R<_RexxStringObject>(H(c).mk(Obj::Str, d ? d : "")); };
    thr_.StringData = [](RexxThreadContext *, RexxStringObject s) -> CSTRING { return O(s)->s.c_str(); };
    thr_.StringLength = [](RexxThreadContext *, RexxStringObject s) -> size_t { return O(s)->s.size(); };
    thr_.ObjectToStringValue = [](RexxThreadContext *, RexxObjectPtr o) -> CSTRING { return O(o)->s.c_str(); };
    thr_.ObjectToString = [](RexxThreadContext *c, RexxObjectPtr o) -> RexxStringObject { return R<_RexxStringObject>(H(c).mk(Obj::Str, O(o)->s)); };
    thr_.IsString = [](RexxThreadContext *, RexxObjectPtr o) -> logical_t { return O(o)->kind == Obj::Str; };
    thr_.IsStem = [](RexxThreadContext *, RexxObjectPtr o) -> logical_t { return O(o)->kind == Obj::Stem; };
    thr_.IsArray = [](RexxThreadContext *, RexxObjectPtr o) -> logical_t { return O(o)->kind == Obj::Array; };
    thr_.Int32ToObject = [](RexxThreadContext *c, int32_t v) -> RexxObjectPtr { return R<_RexxObjectPtr>(H(c).mk(Obj::Str, fromWhole(v))); };
    thr_.UnsignedInt32ToObject = [](RexxThreadContext *c, uint32_t v) -> RexxObjectPtr { return R<_RexxObjectPtr>(H(c).mk(Obj::Str, fromUnsigned(v))); };
    thr_.Int64ToObject = [](RexxThreadContext *c, int64_t v) -> RexxObjectPtr { return R<_RexxObjectPtr>(H(c).mk(Obj::Str, fromWhole(v))); };
    thr_.UnsignedInt64ToObject = [](RexxThreadContext *c, uint64_t v) -> RexxObjectPtr { return R<_RexxObjectPtr>(H(c).mk(Obj::Str, fromUnsigned(v))); };
    thr_.WholeNumberToObject = [](RexxThreadContext *c, wholenumber_t v) -> RexxObjectPtr { return R<_RexxObjectPtr>(H(c).mk(Obj::Str, fromWhole(v))); };
    thr_.StringSizeToObject = [](RexxThreadContext *c, stringsize_t v) -> RexxObjectPtr { return R<_RexxObjectPtr>(H(c).mk(Obj::Str, fromUnsigned(v))); };
    thr_.DoubleToObject = [](RexxThreadContext *c, double v) -> RexxObjectPtr { return R<_RexxObjectPtr>(H(c).mk(Obj::Str, fromDouble(v, H(c).numeric.digits))); };
    thr_.DoubleToObjectWithPrecision = [](RexxThreadContext *c, double v, size_t digits) -> RexxObjectPtr { return R<_RexxObjectPtr>(H(c).mk(Obj::Str, fromDouble(v, digits))); };
    thr_.LogicalToObject = [](RexxThreadContext *c, logical_t v) -> RexxObjectPtr { return v ? H(c).thr_.RexxTrue : H(c).thr_.RexxFalse; };
    thr_.ObjectToInt32 = [](RexxThreadContext *, RexxObjectPtr o, int32_t *r) -> logical_t {
        long long w; if (O(o)->kind != Obj::Str || !parseWhole(O(o)->s, w) || w < INT32_MIN || w > INT32_MAX) return 0; *r = (int32_t)w; return 1; };
    thr_.ObjectToUnsignedInt32 = [](RexxThreadContext *, RexxObjectPtr o, uint32_t *r) -> logical_t {
        long long w; if (O(o)->kind != Obj::Str || !parseWhole(O(o)->s, w) || w < 0 || w > UINT32_MAX) return 0; *r = (uint32_t)w; return 1; };
    thr_.ObjectToInt64 = [](RexxThreadContext *, RexxObjectPtr o, int64_t *r) -> logical_t {
        long long w; if (O(o)->kind != Obj::Str || !parseWhole(O(o)->s, w)) return 0; *r = w; return 1; };
    thr_.ObjectToWholeNumber = [](RexxThreadContext *, RexxObjectPtr o, wholenumber_t *r) -> logical_t {
        long long w; if (O(o)->kind != Obj::Str || !parseWhole(O(o)->s, w)) return 0; *r = w; return 1; };
    thr_.ObjectToStringSize = [](RexxThreadContext *, RexxObjectPtr o, stringsize_t *r) -> logical_t {
        long long w; if (O(o)->kind != Obj::Str || !parseWhole(O(o)->s, w) || w < 0) return 0; *r = (stringsize_t)w; return 1; };
    thr_.ObjectToDouble = [](RexxThreadContext *, RexxObjectPtr o, double *r) -> logical_t {
        double d; if (O(o)->kind != Obj::Str || !parseDouble(O(o)->s, d)) return 0; *r = d; return 1; };
    thr_.ObjectToLogical = [](RexxThreadContext *, RexxObjectPtr o, logical_t *r) -> logical_t {
        if (O(o)->kind != Obj::Str || (O(o)->s != "0" && O(o)->s != "1")) return 0;
        *r = O(o)->s == "1"; return 1; };
    thr_.ReleaseLocalReference = [](RexxThreadContext *, RexxObjectPtr) {};
    thr_.RequestGlobalReference = [](RexxThreadContext *, RexxObjectPtr o) -> RexxObjectPtr { return o; };
    thr_.ReleaseGlobalReference = [](RexxThreadContext *, RexxObjectPtr) {};

    // ---- stems ----
    thr_.NewStem = [](RexxThreadContext *c, CSTRING name) -> RexxStemObject {
        Host &h = H(c); h.ownStems_.push_back(std::make_unique<MapStem>());
        Obj *o = h.mk(Obj::Stem, name ? name : ""); o->stem = h.ownStems_.back().get(); return R<_RexxStemObject>(o); };
    thr_.SetStemElement = [](RexxThreadContext *, RexxStemObject s, CSTRING tail, RexxObjectPtr v) { O(s)->stem->set(tail, O(v)->s); };
    thr_.GetStemElement = [](RexxThreadContext *c, RexxStemObject s, CSTRING tail) -> RexxObjectPtr {
        auto v = O(s)->stem->get(tail); if (!v) return nullptr; return R<_RexxObjectPtr>(H(c).mk(Obj::Str, *v)); };
    thr_.DropStemElement = [](RexxThreadContext *, RexxStemObject s, CSTRING tail) { O(s)->stem->drop(tail); };
    thr_.SetStemArrayElement = [](RexxThreadContext *, RexxStemObject s, size_t i, RexxObjectPtr v) { O(s)->stem->set(std::to_string(i), O(v)->s); };
    thr_.GetStemArrayElement = [](RexxThreadContext *c, RexxStemObject s, size_t i) -> RexxObjectPtr {
        auto v = O(s)->stem->get(std::to_string(i)); if (!v) return nullptr; return R<_RexxObjectPtr>(H(c).mk(Obj::Str, *v)); };
    thr_.DropStemArrayElement = [](RexxThreadContext *, RexxStemObject s, size_t i) { O(s)->stem->drop(std::to_string(i)); };

    // ---- arrays ----
    thr_.NewArray = [](RexxThreadContext *c, size_t) -> RexxArrayObject { return R<_RexxArrayObject>(H(c).mk(Obj::Array)); };
    thr_.ArrayAt = [](RexxThreadContext *, RexxArrayObject a, size_t i) -> RexxObjectPtr {
        auto &v = O(a)->arr; return (i >= 1 && i <= v.size()) ? R<_RexxObjectPtr>(v[i - 1]) : nullptr; };
    thr_.ArrayPut = [](RexxThreadContext *, RexxArrayObject a, RexxObjectPtr o, size_t i) {
        auto &v = O(a)->arr; if (i == 0) return; if (v.size() < i) v.resize(i, nullptr); v[i - 1] = O(o); };
    thr_.ArrayAppend = [](RexxThreadContext *, RexxArrayObject a, RexxObjectPtr o) -> size_t { O(a)->arr.push_back(O(o)); return O(a)->arr.size(); };
    thr_.ArrayAppendString = [](RexxThreadContext *c, RexxArrayObject a, CSTRING s, size_t n) -> size_t {
        O(a)->arr.push_back(H(c).mk(Obj::Str, std::string(s, n))); return O(a)->arr.size(); };
    thr_.ArraySize = [](RexxThreadContext *, RexxArrayObject a) -> size_t { return O(a)->arr.size(); };
    thr_.ArrayItems = [](RexxThreadContext *, RexxArrayObject a) -> size_t {
        size_t n = 0; for (auto *p : O(a)->arr) if (p) n++; return n; };

    thr_.ArrayOfOne = [](RexxThreadContext *c, RexxObjectPtr a) -> RexxArrayObject { Obj *o = H(c).mk(Obj::Array); o->arr = {O(a)}; return R<_RexxArrayObject>(o); };
    thr_.ArrayOfTwo = [](RexxThreadContext *c, RexxObjectPtr a, RexxObjectPtr b) -> RexxArrayObject { Obj *o = H(c).mk(Obj::Array); o->arr = {O(a), O(b)}; return R<_RexxArrayObject>(o); };
    thr_.ArrayOfThree = [](RexxThreadContext *c, RexxObjectPtr a, RexxObjectPtr b, RexxObjectPtr d) -> RexxArrayObject { Obj *o = H(c).mk(Obj::Array); o->arr = {O(a), O(b), O(d)}; return R<_RexxArrayObject>(o); };
    thr_.ArrayOfFour = [](RexxThreadContext *c, RexxObjectPtr a, RexxObjectPtr b, RexxObjectPtr d, RexxObjectPtr e) -> RexxArrayObject { Obj *o = H(c).mk(Obj::Array); o->arr = {O(a), O(b), O(d), O(e)}; return R<_RexxArrayObject>(o); };

    // ---- conditions ----
    thr_.RaiseException = [](RexxThreadContext *c, size_t n, RexxArrayObject a) {
        std::vector<std::string> subs; for (auto *p : O(a)->arr) subs.push_back(p ? p->s : ""); H(c).raise(n, subs); };
    thr_.RaiseException0 = [](RexxThreadContext *c, size_t n) { H(c).raise(n, {}); };
    thr_.RaiseException1 = [](RexxThreadContext *c, size_t n, RexxObjectPtr a) { H(c).raise(n, {O(a)->s}); };
    thr_.RaiseException2 = [](RexxThreadContext *c, size_t n, RexxObjectPtr a, RexxObjectPtr b) { H(c).raise(n, {O(a)->s, O(b)->s}); };
    thr_.CheckCondition = [](RexxThreadContext *c) -> logical_t { return H(c).pendingCode_.has_value(); };
    thr_.ClearCondition = [](RexxThreadContext *c) { H(c).pendingCode_.reset(); H(c).pendingText_.clear(); };

    // ---- call context ----
    // unimplemented call-context functions fail closed, never null-call
    callIf_.GetArguments = reinterpret_cast<decltype(callIf_.GetArguments)>(&detail::trapCall_GetArguments);
    callIf_.GetArgument = reinterpret_cast<decltype(callIf_.GetArgument)>(&detail::trapCall_GetArgument);
    callIf_.GetRoutineName = reinterpret_cast<decltype(callIf_.GetRoutineName)>(&detail::trapCall_GetRoutineName);
    callIf_.GetRoutine = reinterpret_cast<decltype(callIf_.GetRoutine)>(&detail::trapCall_GetRoutine);
    callIf_.SetContextVariable = reinterpret_cast<decltype(callIf_.SetContextVariable)>(&detail::trapCall_SetContextVariable);
    callIf_.GetContextVariable = reinterpret_cast<decltype(callIf_.GetContextVariable)>(&detail::trapCall_GetContextVariable);
    callIf_.DropContextVariable = reinterpret_cast<decltype(callIf_.DropContextVariable)>(&detail::trapCall_DropContextVariable);
    callIf_.GetAllContextVariables = reinterpret_cast<decltype(callIf_.GetAllContextVariables)>(&detail::trapCall_GetAllContextVariables);
    callIf_.ResolveStemVariable = reinterpret_cast<decltype(callIf_.ResolveStemVariable)>(&detail::trapCall_ResolveStemVariable);
    callIf_.SetContextVariable = [](RexxCallContext *c, CSTRING n, RexxObjectPtr v) { HC(c).varSet(n, O(v)->s); };
    callIf_.GetContextVariable = [](RexxCallContext *c, CSTRING n) -> RexxObjectPtr {
        auto v = HC(c).varGet(n); if (!v) return nullptr; return R<_RexxObjectPtr>(HC(c).mk(Obj::Str, *v)); };
    callIf_.DropContextVariable = [](RexxCallContext *c, CSTRING n) { HC(c).varDrop(n); };
    callIf_.InvalidRoutine = reinterpret_cast<decltype(callIf_.InvalidRoutine)>(&detail::trapCall_InvalidRoutine);
    callIf_.GetContextDigits = reinterpret_cast<decltype(callIf_.GetContextDigits)>(&detail::trapCall_GetContextDigits);
    callIf_.GetContextFuzz = reinterpret_cast<decltype(callIf_.GetContextFuzz)>(&detail::trapCall_GetContextFuzz);
    callIf_.GetContextForm = reinterpret_cast<decltype(callIf_.GetContextForm)>(&detail::trapCall_GetContextForm);
    callIf_.GetCallerContext = reinterpret_cast<decltype(callIf_.GetCallerContext)>(&detail::trapCall_GetCallerContext);
    callIf_.FindContextClass = reinterpret_cast<decltype(callIf_.FindContextClass)>(&detail::trapCall_FindContextClass);
    callIf_.GetContextVariableReference = reinterpret_cast<decltype(callIf_.GetContextVariableReference)>(&detail::trapCall_GetContextVariableReference);
    callIf_.ThrowException = [](RexxCallContext *c, size_t n, RexxArrayObject a) {
        std::vector<std::string> subs; for (auto *p : O(a)->arr) subs.push_back(p ? p->s : ""); HC(c).raise(n, subs); };
    callIf_.ThrowException0 = reinterpret_cast<decltype(callIf_.ThrowException0)>(&detail::trapCall_ThrowException0);
    callIf_.ThrowException1 = reinterpret_cast<decltype(callIf_.ThrowException1)>(&detail::trapCall_ThrowException1);
    callIf_.ThrowException2 = reinterpret_cast<decltype(callIf_.ThrowException2)>(&detail::trapCall_ThrowException2);
    callIf_.ThrowException = reinterpret_cast<decltype(callIf_.ThrowException)>(&detail::trapCall_ThrowException);
    callIf_.ThrowCondition = reinterpret_cast<decltype(callIf_.ThrowCondition)>(&detail::trapCall_ThrowCondition);
    callIf_.interfaceVersion = CALL_INTERFACE_VERSION;
    callIf_.GetRoutineName = [](RexxCallContext *c) -> CSTRING { return HC(c).keep(HC(c).routineName_); };
    callIf_.GetArguments = [](RexxCallContext *c) -> RexxArrayObject {
        Host &h = HC(c); Obj *a = h.mk(Obj::Array); for (auto &x : *h.curArgs_) a->arr.push_back(h.handleFor(x)); return R<_RexxArrayObject>(a); };
    callIf_.GetArgument = [](RexxCallContext *c, size_t i) -> RexxObjectPtr {
        Host &h = HC(c); if (i < 1 || i > h.curArgs_->size() || (*h.curArgs_)[i - 1].omitted) return nullptr;
        return R<_RexxObjectPtr>(h.handleFor((*h.curArgs_)[i - 1])); };
    callIf_.InvalidRoutine = [](RexxCallContext *c) { HC(c).raise(40001, {}); };
    callIf_.ThrowException0 = [](RexxCallContext *c, size_t n) { HC(c).raise(n, {}); };
    callIf_.ThrowException1 = [](RexxCallContext *c, size_t n, RexxObjectPtr a) { HC(c).raise(n, {O(a)->s}); };
    callIf_.ThrowException2 = [](RexxCallContext *c, size_t n, RexxObjectPtr a, RexxObjectPtr b) { HC(c).raise(n, {O(a)->s, O(b)->s}); };
    callIf_.GetContextDigits = [](RexxCallContext *c) -> stringsize_t { return HC(c).numeric.digits; };
    callIf_.GetContextFuzz = [](RexxCallContext *c) -> stringsize_t { return HC(c).numeric.fuzz; };
    callIf_.GetContextForm = [](RexxCallContext *c) -> logical_t { return HC(c).numeric.form; };
    callIf_.ResolveStemVariable = [](RexxCallContext *c, RexxObjectPtr o) -> RexxStemObject {
        Host &h = HC(c);
        if (O(o)->kind == Obj::Stem) return reinterpret_cast<RexxStemObject>(o);
        if (O(o)->kind != Obj::Str) return nullptr;
        std::string n = upper(O(o)->s);
        if (n.empty() || n.find('.') != n.size() - 1) {            // must be a plain stem name "S" or "S."
            if (n.find('.') != std::string::npos) return nullptr;
            n += ".";
        }
        Obj *st = h.mk(Obj::Stem, n); st->stem = h.poolStem(n);
        return R<_RexxStemObject>(st); };
    callCtx_.threadContext = &threadCtx_; callCtx_.functions = &callIf_;
    // all other CallContextInterface slots stay null: a library using one segfaults rather than
    // being ignored; see extlib_callif_traps below for the guarded versions installed next.
}

} // namespace rxext
