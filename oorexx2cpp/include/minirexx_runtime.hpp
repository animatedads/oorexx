#ifndef MINIREXX_RUNTIME_HPP
#define MINIREXX_RUNTIME_HPP
// Tiny standalone execution support for the intentionally restricted rx2cpp proof.
// Copyright (c) 2026. SPDX-License-Identifier: MIT
// NOT the ooRexx runtime, nor an implementation of the complete Rexx semantics.
#include <boost/multiprecision/cpp_int.hpp>
#include <algorithm>
#include <array>
#include <thread>
#include <cctype>
#include <cerrno>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <sstream>
#include <cstdint>
#include <iostream>
#include <functional>
#include <limits>
#include <memory>
#include <optional>
#include <atomic>
#include <mutex>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>
#include <deque>
#include <random>

namespace rx {
// s == "literal" without strlen at run time: the literal's length is known, so a different length is one comparison
// (selector and built-in name tests run on every message and every built-in call).
template <std::size_t N> inline bool eqLit(const std::string &s, const char (&lit)[N]) {
    return s.size() == N - 1 && std::memcmp(s.data(), lit, N - 1) == 0;
}
// The interpreter implements operators as messages to the LEFT operand.
// All ooRexx instances inherit .Object's comparison methods. The native
// prototype mirrors its identity-based defaults here, while keeping each
// operator an independently overridable virtual message. The prototype
// does not yet compile ::class or method declarations.
struct ObjectDispatch;
struct StemObject;
// ooRexx strings are immutable objects passed by reference. RxStr gives Value the same cost model: a string longer
// than the inline limit lives in one shared buffer, so copying a Value (BIF argument, assignment, PARSE source,
// message argument) copies a pointer, not the bytes. A writer that finds the buffer shared takes its own copy first.
// Short strings stay inline (no allocation), as std::string's small-string storage did before.
// Interpreter memory pressure. Compiled strings live outside the interpreter's heap, so a compiled loop that churns
// large strings would never let the interpreter collect garbage (weak references, UNINIT): each string above the
// inline limit is counted, and every pressureLimit bytes the interpreter is asked to collect (see the object bridge).
inline void (*&collectHook())() { static void (*hook)() = nullptr; return hook; }
inline void notePressure(std::size_t bytes) {
    static constexpr std::size_t pressureLimit = std::size_t(8) << 20;
    static thread_local std::size_t pending = 0;
    if (!collectHook()) return;
    pending += bytes;
    if (pending >= pressureLimit) { pending = 0; collectHook()(); }
}
// The numeric form of a string, kept with it as RexxString keeps its NumberString (RexxString::numberString): parsed
// once, then every arithmetic operation, comparison and whole-number conversion on the same value (a variable, an array
// item, a copy of either) uses it instead of reading the characters again. Only short plain numbers are kept (what
// rx_rexx_number.hpp's smallDecimal / smallInteger accept: at most 20 characters, at most 18 significant digits, no
// blanks or exponent); any other string is marked as not one. Arithmetic results are classified when they are made
// (Value::number), so a result stored in a variable or a collection already carries it.
// meta: 0 not known yet; else bit 0 known, bit 1 a short plain decimal (coef, exponent), bit 2 a plain whole number as
// smallInteger reads it (value coef), bits 8..15 the exponent + 128. Atomic so a string shared between threads (a
// constant, a value in a shared object) can be classified by either: coef is written before meta (release).
// The other direction, as NumberString makes its string only when asked (NumberString::stringValue): an arithmetic
// result is made as its numeric form only (pending, bit 3) and its characters are written the first time anything reads
// them (str(), and everything built on it). Only results whose characters the parse above gives back exactly: fixed
// notation, exponent <= 0 (a whole number's trailing zeros are digits of coef), at most 18 digits and 20 characters.
// Bit 4: another thread is writing the characters.
struct NumCache {
    static constexpr std::uint32_t known = 1, decimal = 2, integer = 4, pending = 8, busy = 16;
    static constexpr std::uint32_t notNumber = 32;   // the characters are no Rexx number at all (tryParseRexxDecimal)
    // a whole number whose characters are exactly coef's digits (as arithmetic writes them: no leading zero, no sign
    // but '-', not -0): copying the number is copying the characters
    static constexpr std::uint32_t canonical = 64;
    std::atomic<std::int64_t> coef{0};
    std::atomic<std::uint32_t> meta{0};
    NumCache() = default;
    NumCache(const NumCache &o) noexcept { copyFrom(o); }
    NumCache &operator=(const NumCache &o) noexcept { if (this != &o) copyFrom(o); return *this; }
    void copyFrom(const NumCache &o) noexcept {
        const std::uint32_t m = o.meta.load(std::memory_order_acquire);
        coef.store(o.coef.load(std::memory_order_relaxed), std::memory_order_relaxed);
        meta.store(m, std::memory_order_relaxed);
    }
    void reset() noexcept { meta.store(0, std::memory_order_relaxed); }
};
class RxStr {
public:
    static constexpr std::size_t inlineLimit = 15;   // (std::string keeps up to 15 characters without allocating)
    using size_type = std::string::size_type;
    static constexpr size_type npos = std::string::npos;
    RxStr() = default;
    // A pending number is copied as its numeric form (its characters may be being written by another thread).
    RxStr(const RxStr &o) : RxStr(o, o.num_.meta.load(std::memory_order_acquire)) {}
    RxStr &operator=(const RxStr &o) { if (this != &o) copyFrom(o); return *this; }
    // A moved-from string is empty: its numeric form goes with the characters.
    RxStr(RxStr &&o) noexcept : small_(std::move(o.small_)), big_(std::move(o.big_)), num_(o.num_) { o.small_.clear(); o.num_.reset(); }
    RxStr &operator=(RxStr &&o) noexcept {
        if (this != &o) {
            // (a number made by arithmetic has no characters yet, nor has the variable it replaces: nothing to move)
            if (o.small_.empty()) small_.clear(); else { small_ = std::move(o.small_); o.small_.clear(); }
            if (big_ || o.big_) big_ = std::move(o.big_);
            num_ = o.num_; o.num_.reset();
        }
        return *this;
    }
    RxStr(const std::string &v) { put(std::string(v)); }
    RxStr(std::string &&v) : RxStr(std::move(v), v.size() <= inlineLimit) {}
    RxStr(const char *v) { put(std::string(v)); }
    RxStr &operator=(const std::string &v) { big_.reset(); put(std::string(v)); return *this; }
    RxStr &operator=(std::string &&v) { big_.reset(); put(std::move(v)); return *this; }
    RxStr &operator=(const char *v) { big_.reset(); put(std::string(v)); return *this; }
    __attribute__((always_inline)) const std::string &str() const {
        if (__builtin_expect(num_.meta.load(std::memory_order_acquire) & NumCache::pending, 0)) materialize();
        return big_ ? *big_ : small_;
    }
    // A number made as its numeric form only (see NumCache): the caller has checked it is one (rx_rexx_number.hpp
    // pendingNumber).
    __attribute__((always_inline)) void setPendingNumber(std::int64_t coef, std::uint32_t meta) {   // meta: the classification, exponent included
        if (big_) big_.reset();
        small_.clear();
        if (meta & NumCache::integer) meta |= NumCache::canonical;   // (written as plainNumber writes it)
        num_.coef.store(coef, std::memory_order_relaxed);
        num_.meta.store(meta | NumCache::pending, std::memory_order_release);
    }
    // The characters of a short plain number: digits of |coef|, a '.' before the last -exp of them (exp <= 0).
    static std::string plainNumber(std::int64_t coef, int exp) {
        char d[24]; int n = 0;
        std::uint64_t u = coef < 0 ? 0 - static_cast<std::uint64_t>(coef) : static_cast<std::uint64_t>(coef);
        do { d[n++] = static_cast<char>('0' + u % 10); u /= 10; } while (u);
        char out[48]; int k = 0;
        if (coef < 0) out[k++] = '-';
        const int point = n + exp;   // digits before the '.'
        if (exp == 0) { while (n) out[k++] = d[--n]; }
        else if (point <= 0) { out[k++] = '0'; out[k++] = '.'; for (int i = 0; i < -point; ++i) out[k++] = '0'; while (n) out[k++] = d[--n]; }
        else { for (int i = 0; i < point; ++i) out[k++] = d[--n]; out[k++] = '.'; while (n) out[k++] = d[--n]; }
        return std::string(out, static_cast<std::size_t>(k));
    }
    operator const std::string &() const { return str(); }
    // The numeric form (rx_rexx_number.hpp numMeta fills it); const: it is a cache of the characters.
    NumCache &numCache() const { return num_; }
    // Write access: unshare first. The characters may change: the numeric form is dropped.
    std::string &mut() {
        str();
        num_.reset();
        if (big_) {
            if (big_.use_count() != 1) big_ = std::make_shared<std::string>(*big_);
            return *big_;
        }
        return small_;
    }
    bool shared() const { return big_ && big_.use_count() > 1; }
    size_type size() const { return str().size(); }
    size_type length() const { return str().size(); }
    bool empty() const { return str().empty(); }
    const char *data() const { return str().data(); }
    const char *c_str() const { return str().c_str(); }
    char operator[](size_type i) const { return str()[i]; }
    char front() const { return str().front(); }
    char back() const { return str().back(); }
    std::string::const_iterator begin() const { return str().begin(); }
    std::string::const_iterator end() const { return str().end(); }
    std::string substr(size_type pos = 0, size_type n = npos) const { return str().substr(pos, n); }
    template <class... A> size_type find(A &&...a) const { return str().find(std::forward<A>(a)...); }
    template <class... A> size_type rfind(A &&...a) const { return str().rfind(std::forward<A>(a)...); }
    template <class... A> size_type find_first_of(A &&...a) const { return str().find_first_of(std::forward<A>(a)...); }
    template <class... A> size_type find_last_of(A &&...a) const { return str().find_last_of(std::forward<A>(a)...); }
    template <class... A> size_type find_first_not_of(A &&...a) const { return str().find_first_not_of(std::forward<A>(a)...); }
    template <class... A> size_type find_last_not_of(A &&...a) const { return str().find_last_not_of(std::forward<A>(a)...); }
    template <class... A> int compare(A &&...a) const { return str().compare(std::forward<A>(a)...); }
    template <class... A> RxStr &assign(A &&...a) { std::string t; t.assign(std::forward<A>(a)...); return *this = std::move(t); }
    template <class... A> RxStr &append(A &&...a) { mut().append(std::forward<A>(a)...); return *this; }
    template <class... A> RxStr &insert(A &&...a) { mut().insert(std::forward<A>(a)...); return *this; }
    template <class T> RxStr &operator+=(const T &t) { mut() += t; return *this; }
    void push_back(char c) { mut().push_back(c); }
    void clear() { big_.reset(); small_.clear(); num_.reset(); }
    void reserve(size_type n) { mut().reserve(n); }
    void resize(size_type n, char c = '\0') { mut().resize(n, c); }
private:
    void put(std::string &&v) {
        num_.reset();
        if (v.size() > inlineLimit) { notePressure(v.capacity()); small_.clear(); big_ = std::make_shared<std::string>(std::move(v)); }
        else small_ = std::move(v);
    }
    // Copy construction on one reading of the source's state: a pending number as its numeric form (its characters may
    // be being written), anything else with its characters (stable once the state says so).
    RxStr(const RxStr &o, std::uint32_t m)
        : small_((m & NumCache::pending) ? std::string() : o.small_),
          big_((m & NumCache::pending) ? std::shared_ptr<std::string>() : o.big_) {
        num_.coef.store(o.num_.coef.load(std::memory_order_relaxed), std::memory_order_relaxed);
        num_.meta.store(m & ~NumCache::busy, std::memory_order_relaxed);
    }
    // (built in place: a short string moved straight into small_, a longer one into its shared buffer)
    RxStr(std::string &&v, bool inlined) : small_(inlined ? std::move(v) : std::string()) {
        if (!inlined) { notePressure(v.capacity()); big_ = std::make_shared<std::string>(std::move(v)); }
    }
    void copyFrom(const RxStr &o) {
        const std::uint32_t m = o.num_.meta.load(std::memory_order_acquire);
        if (m & NumCache::pending) {
            big_.reset(); small_.clear();
            num_.coef.store(o.num_.coef.load(std::memory_order_relaxed), std::memory_order_relaxed);
            num_.meta.store(m & ~NumCache::busy, std::memory_order_relaxed);
            // (written by now after all: its characters are there to copy, the pending bit stays off)
            if (o.num_.meta.load(std::memory_order_acquire) & NumCache::pending) return;
        }
        small_ = o.small_; big_ = o.big_;
        num_.copyFrom(o.num_);
    }
    // Writes a pending number's characters (once; a second thread waits for the first).
    __attribute__((noinline, cold)) void materialize() const {
        std::uint32_t m = num_.meta.load(std::memory_order_acquire);
        while (m & NumCache::pending) {
            if (!(m & NumCache::busy) &&
                num_.meta.compare_exchange_weak(m, m | NumCache::busy, std::memory_order_acquire)) {
                small_ = plainNumber(num_.coef.load(std::memory_order_relaxed), static_cast<int>((m >> 8) & 0xff) - 128);
                num_.meta.store(m & ~(NumCache::pending | NumCache::busy), std::memory_order_release);
                return;
            }
            m = num_.meta.load(std::memory_order_acquire);
        }
    }
    mutable std::string small_;   // (written once by materialize for a pending number)
    std::shared_ptr<std::string> big_;
    mutable NumCache num_;
};
// Classifies a string's numeric form now (rx_rexx_number.hpp): used for arithmetic results.
inline std::uint32_t numClassify(const RxStr &s);
inline bool operator==(const RxStr &a, const RxStr &b) {
    return (a.size() == b.size()) && (a.data() == b.data() || a.str() == b.str());
}
inline bool operator==(const RxStr &a, const std::string &b) { return a.str() == b; }
inline bool operator==(const std::string &a, const RxStr &b) { return a == b.str(); }
inline bool operator==(const RxStr &a, const char *b) { return a.str() == b; }
inline bool operator!=(const RxStr &a, const RxStr &b) { return !(a == b); }
inline bool operator!=(const RxStr &a, const std::string &b) { return a.str() != b; }
inline bool operator!=(const std::string &a, const RxStr &b) { return a != b.str(); }
inline bool operator!=(const RxStr &a, const char *b) { return a.str() != b; }
inline bool operator<(const RxStr &a, const RxStr &b) { return a.str() < b.str(); }
inline bool operator>(const RxStr &a, const RxStr &b) { return a.str() > b.str(); }
inline bool operator<=(const RxStr &a, const RxStr &b) { return a.str() <= b.str(); }
inline bool operator>=(const RxStr &a, const RxStr &b) { return a.str() >= b.str(); }
inline std::string operator+(const RxStr &a, const std::string &b) { return a.str() + b; }
inline std::string operator+(const std::string &a, const RxStr &b) { return a + b.str(); }
inline std::string operator+(const RxStr &a, const char *b) { return a.str() + b; }
inline std::string operator+(const char *a, const RxStr &b) { return a + b.str(); }
inline std::string operator+(const RxStr &a, char b) { return a.str() + b; }
inline std::string operator+(const RxStr &a, const RxStr &b) { return a.str() + b.str(); }
inline std::ostream &operator<<(std::ostream &o, const RxStr &a) { return o << a.str(); }
struct Value {
    RxStr bytes;
    std::shared_ptr<ObjectDispatch> object;
    explicit Value(std::string v) : bytes(std::move(v)) {}
    // A pending number (rx_rexx_number.hpp pendingNumber): no characters yet.
    struct PendingTag {};
    Value(PendingTag, std::int64_t coef, std::uint32_t meta) { bytes.setPendingNumber(coef, meta); }
    explicit Value(std::shared_ptr<ObjectDispatch> target) : object(std::move(target)) {
        if (!object) throw std::invalid_argument("null ooRexx object");
    }
    static Value string(const std::string &s) { return Value(s); }
    static Value number(const std::string &s) { Value v(s); numClassify(v.bytes); return v; }
    static Value fromObject(std::shared_ptr<ObjectDispatch> target) {
        return Value(std::move(target));
    }
    bool isObject() const { return static_cast<bool>(object); }
    Value(const Value &) = default;
    Value(Value &&) noexcept = default;
    Value &operator=(const Value &) = default;
    Value &operator=(Value &&o) noexcept {
        if (this != &o) { bytes = std::move(o.bytes); if (object || o.object) object = std::move(o.object); }
        return *this;
    }
};
// No result is different from returning .nil or any other object.
using MessageResult = std::optional<Value>;
// Thrown when an object has no such method (ooRexx error 97.1); any other failure keeps its own type.
struct NoMethod : std::runtime_error {
    using std::runtime_error::runtime_error;
    std::shared_ptr<ObjectDispatch> conditionObject;   // the interpreter's condition object, when it raised the error (97.1)
    std::vector<Value> substitutions;                  // its ADDITIONAL values
};
// The key a compiled class's dispatch switches on (RxHybridCppEmitter dispatch): the name's length, first character and
// fourth (or last) character. Names of one class rarely share it; one comparison then confirms the name.
inline std::uint32_t selectorKey(const std::string &s) {
    const std::size_t n = s.size();
    if (n == 0) return 0;
    return static_cast<std::uint32_t>(n & 0xFFFF) | static_cast<std::uint32_t>(static_cast<unsigned char>(s[0])) << 16 |
           static_cast<std::uint32_t>(static_cast<unsigned char>(s[n >= 4 ? 3 : n - 1])) << 24;
}
struct ObjectDispatch {
    virtual MessageResult sendMessage(const std::string &selector,
                                      const std::vector<Value> &args) {
        if (args.size() == 1 &&
            (rx::eqLit(selector, "=") || rx::eqLit(selector, "\\=") || rx::eqLit(selector, "==") || rx::eqLit(selector, "\\==") ||
             rx::eqLit(selector, "<>") || rx::eqLit(selector, "><") || rx::eqLit(selector, "<") || rx::eqLit(selector, ">") ||
             rx::eqLit(selector, "<=") || rx::eqLit(selector, ">=")))
            return sendBinary(selector, args.front());
        throw NoMethod("unhandled object message: " + selector);
    }
    virtual ~ObjectDispatch() = default;
    // Cycle collection (the native library's collector, native_package_template.cpp.in collectCycles): the values a
    // container holds, and dropping them all (a container found unreachable: its references are what keep a cycle).
    virtual void gcValues(const std::function<void(const Value &)> &) const {}
    virtual void gcClear() {}
    // Whether the collector follows this object's values (a native container or a compiled object's reference), and,
    // for a compiled object's reference (NativeInstanceRef), its instance state: answered without a dynamic_cast.
    virtual bool gcFollowed() const { return false; }
    virtual void *gcRefState() const { return nullptr; }
    // The collector's bookkeeping: the number of the collection that last met this object, and its node there.
    mutable std::uint64_t gcMark = 0;
    mutable std::uint32_t gcIndex = 0;
    // True when the object has no MAKESTRING method (a Stem): its string value comes from STRING, with NOSTRING.
    virtual bool noMakeString() const { return false; }
    // True for an object of a class that is not built in (RexxInternalObject::isBaseClass false): its string value is
    // asked for with REQUEST('STRING'), which the class may override, then STRING (RexxInternalObject::requestString).
    virtual bool requestsString() const { return false; }
    virtual bool isNilObject() const { return false; }
    // The compiled stem object behind this (rx_compound_symbols.hpp), without a dynamic_cast.
    virtual StemObject *asStem() { return nullptr; }
    // receiver[index] and receiver[index] = value with one index, done without the message when the object answers them
    // itself exactly as its [] / []= methods would (a native Array): false = send the message. indexAt sets slot to
    // the item, or to nullptr for .nil; indexPut takes the value only when it returns true.
    virtual bool indexAt(const Value &, const Value *&) { return false; }
    virtual bool indexPut(Value &, const Value &) { return false; }
    // .Object defines =, ==, \=, \==, <>, >< using object identity.
    // Each is a distinct overridable method, not a synthesized negation.
    // More specialised classes (e.g. .String) provide their own comparators.
    virtual Value sendBinary(const std::string &selector, const Value &rhs) {
        const bool same = rhs.isObject() && rhs.object.get() == this;
        if (rx::eqLit(selector, "=") || rx::eqLit(selector, "==")) return Value::string(same ? "1" : "0");
        if (rx::eqLit(selector, "\\=") || rx::eqLit(selector, "\\==") || rx::eqLit(selector, "<>") || rx::eqLit(selector, "><"))
            return Value::string(same ? "0" : "1");
        throw std::runtime_error("unhandled binary operator message: " + selector);
    }
    virtual Value sendUnary(const std::string &selector) {
        throw std::runtime_error("unhandled unary operator message: " + selector);
    }
    virtual std::string display() const {
        throw std::runtime_error("object has no display conversion");
    }
};
// ooRexx .NIL is one live singleton object, not a C++ null result.
// Unimplemented .Object messages must reject rather than approximate.
// With a host interpreter (library mode) any other .NIL message goes to the interpreter's own .NIL (CLASS, ISNIL, ...).
using NilMessageFallback = MessageResult (*)(const std::string &, const std::vector<Value> &);
inline NilMessageFallback &nilMessageFallback() { static NilMessageFallback f = nullptr; return f; }
struct NilObject final : ObjectDispatch {
    std::string display() const override { return "The NIL object"; }
    bool isNilObject() const override { return true; }
    MessageResult sendMessage(const std::string &selector,
                              const std::vector<Value> &args) override {
        std::string canonical = selector;
        std::transform(canonical.begin(), canonical.end(), canonical.begin(),
                       [](unsigned char c) { return static_cast<char>(std::toupper(c)); });
        if (rx::eqLit(canonical, "STRING") && args.empty()) return Value::string(display());
        // .nil is an instance of .Object: Object's ISNIL (RexxObject::isNilRexx: this == TheNilObject)
        if (rx::eqLit(canonical, "ISNIL") && args.empty()) return Value::string("1");
        if (nilMessageFallback()) return nilMessageFallback()(canonical, args);
        return ObjectDispatch::sendMessage(canonical, args);
    }
    // Object's concatenation operators (||, blank, abuttal) use the string value.
    Value sendBinary(const std::string &selector, const Value &rhs) override {
        if (rx::eqLit(selector, "||") || rx::eqLit(selector, "") || rx::eqLit(selector, " ")) {
            const std::string right = rhs.isObject() ? rhs.object->display() : rhs.bytes.str();
            return Value::string(display() + (rx::eqLit(selector, " ") ? " " : "") + right);
        }
        // Object's comparisons are identity (RexxObject::equal / strictEqual / notEqual): .nil is equal only to .nil
        // itself (this singleton, or the interpreter's .NIL wrapped: isNilObject); a string or any other object is not
        const bool positive = rx::eqLit(selector, "==") || rx::eqLit(selector, "=");
        if (positive || rx::eqLit(selector, "\\==") || rx::eqLit(selector, "\\=") || rx::eqLit(selector, "<>") || rx::eqLit(selector, "><")) {
            const bool same = rhs.isObject() && rhs.object->isNilObject();
            return Value::string(same == positive ? "1" : "0");
        }
        return ObjectDispatch::sendBinary(selector, rhs);
    }
};
// A method or routine that ends without a result (bare RETURN, end of the code, FORWARD to a method that returned
// nothing) returns noResult(): the flag tells the entry point to hand the interpreter no result, as interpreted
// (RESULT dropped; an expression using it raises the interpreter's own error). Read and cleared right after the call.
inline bool &noResultPending();   // (in the thread's ThreadState, below)
inline Value noResult();
inline Value nil() {
    static const std::shared_ptr<ObjectDispatch> singleton = std::make_shared<NilObject>();
    return Value::fromObject(singleton);
}
inline Value noResult() { noResultPending() = true; return Value::string(std::string()); }
// Per-activation state of the built-ins, as RexxActivation keeps it.
//   Stream table (LINEIN, CHAROUT, STREAM, ...): qualified name -> stream object. Every method activation has its own,
//   made on first use; internal routines and compiled package routines called from compiled code share their caller's.
//   A routine called by the interpreter starts one of its own (the interpreted caller's is not reachable from here).
//   RANDOM seed: every method and routine activation has its own (internal routines use their caller's), started from
//   the thread's seed source as Activity::getRandomSeed does.
struct MethodTraps;
// NOTREADY raised by a stream built-in in an activation that traps it (SIGNAL ON NOTREADY / ANY): the interpreter's
// condition object (an EnvObject) travels to the trap.
// (Also NOSTRING / LOSTDIGITS under SIGNAL ON ANY: name says which.)
struct NotReadyCondition : std::runtime_error {
    std::shared_ptr<ObjectDispatch> conditionObject;
    std::string name;
    explicit NotReadyCondition(std::shared_ptr<ObjectDispatch> o, std::string n = "NOTREADY")
        : std::runtime_error(n), conditionObject(std::move(o)), name(std::move(n)) {}
};
// A message send to an interpreter object while the running compiled activation traps conditions the interpreter
// raises (see rx_object_bridge.hpp trappedSend); nullopt: send it the ordinary way.
inline std::optional<std::optional<Value>> (*&trappedSendHook())(void *, const std::string &, const std::vector<Value> &) {
    static std::optional<std::optional<Value>> (*hook)(void *, const std::string &, const std::vector<Value> &) = nullptr;
    return hook;
}
// How compiled code is about to call a compiled package routine (SUBROUTINE / FUNCTION), for its PARSE SOURCE.
// A thread's activation state in one thread-local object: one lookup (a call into the TLS resolver, in a shared library)
// where an activation saves and sets several of them.
struct ActivationScope;
struct ThreadState {
    std::string pendingCallType;
    std::string trace = "N", address = "sh", alternate = "sh";
    ActivationScope *scope = nullptr;
    // SIGNAL ON NOVALUE (or ANY) of the running activation: reading an unset variable raises NOVALUE while *novalueArmed.
    const bool *novalueArmed = nullptr;
    // SIGNAL ON LOSTDIGITS (or ANY) of the running activation: an arithmetic operand longer than DIGITS raises LOSTDIGITS.
    const bool *lostDigitsArmed = nullptr;
    // The compiled method running on this thread, as SELF sends see it (compiled_registry.hpp detail::currentSender), and
    // its native instance (the native library's currentState); whether it returned no value (noResultPending). Kept here
    // with the rest so that a method call reaches all of them through one thread-local lookup.
    void *currentSender = nullptr;
    void *currentState = nullptr;
    bool noResultPending = false;
};
// (reached through a plain pointer: a thread_local with a constructor is checked for its initialisation at every use, a
// second thread-local lookup; the pointer needs none, and the state is made once per thread)
__attribute__((noinline)) inline ThreadState *makeThreadState() {
    static thread_local std::unique_ptr<ThreadState> owner;   // (frees it when the thread ends)
    owner = std::make_unique<ThreadState>();
    return owner.get();
}
inline ThreadState &threadState() {
    static thread_local ThreadState *t = nullptr;
    if (__builtin_expect(t == nullptr, 0)) t = makeThreadState();
    return *t;
}
inline bool &noResultPending() { return threadState().noResultPending; }
inline std::string &pendingCallType() { return threadState().pendingCallType; }
// The clock of an activation (RexxActivation::getTime / getElapsed): one time stamp per clause, read at the first
// TIME / DATE of the clause; the elapsed-time origin of TIME('E') / TIME('R'). Microseconds since 0001-01-01.
struct ClauseClock {
    bool valid = false;
    std::int64_t utc = 0, local = 0, offset = 0;
    std::int64_t elapsed = 0;
    bool elapsedReset = false;
};
inline std::string &traceSetting();
inline std::string &addressEnvironment();
inline std::string &alternateEnvironment();
// Raises the LOSTDIGITS condition for an operand (set by the object bridge: the condition object is the interpreter's).
inline void (*&lostDigitsHook())(const Value &) { static void (*hook)(const Value &) = nullptr; return hook; }
struct ActivationScope {
    enum Kind { Method, Routine };
    std::string savedTrace;         // TRACE is a setting of the activation: a new one starts at N, the caller's comes back
    const bool *savedNovalue;       // so is SIGNAL ON NOVALUE: a new activation starts without it
    const bool *savedLostDigits;    // and SIGNAL ON LOSTDIGITS
    std::string savedAddress, savedAlternate;   // and ADDRESS: a new activation starts in the default environment
    ClauseClock clockState;
    Kind kind;
    MethodTraps *traps = nullptr;   // the SIGNAL ON state of the running activation (method body or internal routine)
    std::optional<int> returnStatus;   // .RS: 0 / 1 (ERROR) / -1 (FAILURE) after a command, none before
    std::string callType;           // a routine's: SUBROUTINE / FUNCTION, '' when the interpreter called it
    std::unique_ptr<std::unordered_map<std::string, Value>> table;
    bool seeded = false;
    std::uint64_t seed = 0;
    // The security manager of the activation (RexxActivation settings.securityManager: its code's package's when the
    // activation starts): set by the object bridge (securityHook), the interpreter's SecurityManager wrapper or null.
    void *security = nullptr;
    static void *(*&securityHook())() { static void *(*hook)() = nullptr; return hook; }
    ActivationScope *saved;
    static ActivationScope *&current() { return threadState().scope; }
    explicit ActivationScope(Kind k = Method) : ActivationScope(k, threadState()) {}
    // TRACE N and ADDRESS sh / sh, the settings a new activation starts with. Most callers run with them, so they are
    // saved (and given back) only when the caller has others: `settings`.
    static bool defaultSettings(const ThreadState &t) {
        return t.trace.size() == 1 && t.trace[0] == 'N' && t.address.size() == 2 && t.address[0] == 's' &&
               t.address[1] == 'h' && t.alternate.size() == 2 && t.alternate[0] == 's' && t.alternate[1] == 'h';
    }
    static void startSettings(ThreadState &t) { t.trace.assign(1, 'N'); t.address.assign("sh", 2); t.alternate.assign("sh", 2); }
    bool settings = false;
    ActivationScope(Kind k, ThreadState &t) : kind(k), saved(t.scope) {
        if (securityHook()) security = securityHook()();
        if (!t.pendingCallType.empty()) callType = std::exchange(t.pendingCallType, std::string());
        t.scope = this;
        savedNovalue = std::exchange(t.novalueArmed, nullptr);
        savedLostDigits = std::exchange(t.lostDigitsArmed, nullptr);
        if (!defaultSettings(t)) {
            settings = true;
            savedTrace = std::move(t.trace); savedAddress = std::move(t.address); savedAlternate = std::move(t.alternate);
            startSettings(t);
        }
    }
    // A new clause begins (compiled before every statement that calls TIME or DATE): the next one reads the clock again.
    static void clauseBoundary() { if (ActivationScope *s = current()) s->clockState.valid = false; else outsideClock().valid = false; }
    static ClauseClock &outsideClock() { static thread_local ClauseClock c; return c; }
    static ClauseClock &clock() { ActivationScope *s = current(); return s ? s->clockState : outsideClock(); }
    // PARSE SOURCE call type of the running package routine.
    static std::string routineCallType() {
        ActivationScope *s = current();
        if (!s || s->kind != Routine || s->callType.empty())
            throw std::runtime_error("PARSE SOURCE: the call type of a compiled routine called by the interpreter is not known");
        return s->callType;
    }
    ~ActivationScope() {
        ThreadState &t = threadState();
        t.scope = saved; t.novalueArmed = savedNovalue; t.lostDigitsArmed = savedLostDigits;
        if (settings) { t.trace = std::move(savedTrace); t.address = std::move(savedAddress); t.alternate = std::move(savedAlternate); }
        else if (!defaultSettings(t)) startSettings(t);
    }
    ActivationScope(const ActivationScope &) = delete;
    ActivationScope &operator=(const ActivationScope &) = delete;
    static std::unordered_map<std::string, Value> &streams() {
        static thread_local std::unordered_map<std::string, Value> outside;   // no compiled activation on this thread
        ActivationScope *s = current();
        while (s && s->kind == Routine && s->saved) s = s->saved;
        if (!s) return outside;
        if (!s->table) s->table = std::make_unique<std::unordered_map<std::string, Value>>();
        return *s->table;
    }
    // Activity::generateRandomNumberSeed / getRandomSeed: a per-thread source, a new value for each activation.
    static std::uint64_t activitySeed() {
        static thread_local std::uint64_t source = [] {
            std::random_device device;
            std::uint64_t v = 0;
            for (int i = 0; i < 4; ++i) v = v << 16 ^ device();
            return v;
        }();
        static thread_local std::mt19937 rng{std::random_device{}()};
        source = source << 16 ^ (rng() & 0x7fffffff);
        return source;
    }
    static std::uint64_t &randomSeed() {
        static thread_local bool outsideSeeded = false;
        static thread_local std::uint64_t outsideSeed = 0;
        ActivationScope *s = current();
        if (!s) {
            if (!outsideSeeded) { outsideSeed = activitySeed(); outsideSeeded = true; }
            return outsideSeed;
        }
        if (!s->seeded) { s->seed = activitySeed(); s->seeded = true; }
        return s->seed;
    }
};
using StreamScope = ActivationScope;
// An internal routine call works on a copy of its caller's clock (RexxActivation settings are copied for INTERNALCALL):
// TIME('R') there does not reset the caller's elapsed time; the caller's clause time stamp is kept.
// An internal routine call: the routine runs with a copy of the caller's settings - the clause clock, TRACE and the
// ADDRESS environments - and the caller's come back when it returns (RexxActivation INTERNALCALL settings copy).
struct InternalCallClock {
    ClauseClock saved;
    std::string savedTrace, savedAddress, savedAlternate;
    InternalCallClock() : InternalCallClock(threadState()) {}
    explicit InternalCallClock(ThreadState &t) : saved(ActivationScope::clock()), savedTrace(t.trace), savedAddress(t.address),
                                                 savedAlternate(t.alternate) { ActivationScope::clock().valid = false; }
    ~InternalCallClock() {
        ThreadState &t = threadState();
        ActivationScope::clock() = saved;
        t.trace = std::move(savedTrace); t.address = std::move(savedAddress); t.alternate = std::move(savedAlternate);
    }
    InternalCallClock(const InternalCallClock &) = delete;
    InternalCallClock &operator=(const InternalCallClock &) = delete;
};
/* Small native .ARRAY subset. Index operations use ooRexx message selectors
   [] and []= (value FIRST, index SECOND); no C++ indexing semantics leak in.
   Uninitialised elements and multidimensional arrays are unsupported. */
struct ArrayObject final : ObjectDispatch {
    std::unordered_map<std::size_t, Value> elements;
    std::size_t last = 0;
    static std::size_t index(const Value &v) {
        if (v.isObject() || v.bytes.empty() ||
            v.bytes.find_first_not_of("0123456789") != std::string::npos)
            throw std::runtime_error("array index must be positive whole number");
        std::size_t n = 0;
        for (char c : v.bytes) {
            std::size_t d = static_cast<std::size_t>(c - '0');
            if (n > (std::numeric_limits<std::size_t>::max() - d) / 10)
                throw std::runtime_error("array index overflow");
            n = n * 10 + d;
        }
        if (n == 0) throw std::runtime_error("array index must be positive");
        return n;
    }
    MessageResult sendMessage(const std::string &selector,
                              const std::vector<Value> &args) override {
        if (rx::eqLit(selector, "[]") && args.size() == 1) {
            const auto at = elements.find(index(args[0]));
            if (at == elements.end()) throw std::runtime_error("undefined array element is not yet supported");
            return at->second;
        }
        if (rx::eqLit(selector, "[]=") && args.size() == 2) {
            auto at = index(args[1]);
            elements.insert_or_assign(at, args[0]);
            if (at > last) last = at;
            return std::nullopt;
        }
        if (rx::eqLit(selector, "APPEND") && args.size() == 1) {
            if (last == std::numeric_limits<std::size_t>::max())
                throw std::runtime_error("array index overflow");
            elements.insert_or_assign(++last, args[0]);
            return Value::string(std::to_string(last));
        }
        if (rx::eqLit(selector, "MAKESTRING") && args.size() <= 2) {
            const std::string format = args.empty() ? "L" : args[0].bytes;
            const std::string separator = args.size() == 2 ? args[1].bytes : " ";
            if (format != "L")
                throw std::runtime_error("only .Array~makeString('L') is implemented");
            std::string result;
            for (std::size_t i = 1; i <= last; ++i) {
                const auto item = elements.find(i);
                if (item == elements.end())
                    throw std::runtime_error("sparse Array~makeString unsupported");
                if (item->second.isObject())
                    throw std::runtime_error("object Array~makeString conversion unsupported");
                if (i > 1) result += separator;
                result += item->second.bytes;
            }
            return Value::string(result);
        }
        return ObjectDispatch::sendMessage(selector, args);
    }
};
struct ArrayClass final : ObjectDispatch {
    MessageResult sendMessage(const std::string &selector,
                              const std::vector<Value> &args) override {
        if (rx::eqLit(selector, "NEW") && args.empty())
            return Value::fromObject(std::make_shared<ArrayObject>());
        if (rx::eqLit(selector, "OF")) {
            auto array = std::make_shared<ArrayObject>();
            for (const auto &arg : args) array->sendMessage("APPEND", {arg});
            return Value::fromObject(array);
        }
        throw std::runtime_error("unsupported .ARRAY class constructor");
    }
};
// When the hosted interpreter is linked, collections are the interpreter's own (they cross freely into hosted code);
// otherwise the native subset.
using HostedClassLookup = Value (*)(const std::string &);
inline HostedClassLookup &hostedClassLookup() { static HostedClassLookup f = nullptr; return f; }
inline Value arrayClass() {
    if (hostedClassLookup()) return hostedClassLookup()("ARRAY");
    static const Value native = Value::fromObject(std::make_shared<ArrayClass>());
    return native;
}
// LOOP value OVER .Array iterates in index order; sparse/other collections
// fail closed until their own ITERATOR semantics are implemented.
// A native collection that can hand DO ... OVER its items directly (nullopt: ask it for MAKEARRAY as usual).
struct ItemSnapshot {
    virtual std::optional<std::vector<Value>> snapshotItems() = 0;
    virtual ~ItemSnapshot() = default;
};
inline std::vector<Value> arrayItems(const Value &collection) {
    if (!collection.isObject()) throw std::runtime_error("LOOP OVER requires a collection object");
    if (auto *snapshot = dynamic_cast<ItemSnapshot *>(collection.object.get()))
        if (auto items = snapshot->snapshotItems()) return std::move(*items);
    auto array = std::dynamic_pointer_cast<ArrayObject>(collection.object);
    if (!array) {
        // Any other collection (interpreter objects included): DO ... OVER iterates its MAKEARRAY, as ooRexx does.
        MessageResult made = collection.object->sendMessage("MAKEARRAY", {});
        if (!made || !made->isObject()) throw std::runtime_error("LOOP OVER: MAKEARRAY did not return an array");
        if (auto native = std::dynamic_pointer_cast<ArrayObject>(made->object)) return arrayItems(*made);
        MessageResult count = made->object->sendMessage("ITEMS", {});
        if (!count || count->isObject()) throw std::runtime_error("LOOP OVER: ITEMS did not return a number");
        std::vector<Value> items;
        const std::int64_t n = std::stoll(count->bytes);
        for (std::int64_t i = 1; i <= n; ++i) {
            MessageResult item = made->object->sendMessage("[]", {Value::string(std::to_string(i))});
            items.push_back(item ? *item : nil());
        }
        return items;
    }
    std::vector<Value> items;
    for (std::size_t i = 1; i <= array->last; ++i) {
        const auto it = array->elements.find(i);
        if (it == array->elements.end()) throw std::runtime_error("LOOP OVER sparse Array unsupported");
        items.push_back(it->second);
    }
    return items;
}
// An activation owns one variable pool; PROCEDURE creates a fresh pool with
// explicit live aliases to the caller's pool. The alias owner is resolved at
// every access (including recursive calls), never copied back on RETURN.
// Numeric settings belong to the calling activation. The language compiler
// currently supports only defaults; fields permit future NUMERIC instructions
// to mutate the right scope without a BIF-specific static snapshot.
struct ActivationNumeric {
    std::size_t digits = 9;
    std::size_t fuzz = 0;
    bool engineering = false;
};
// The NUMERIC settings of the innermost running compiled method on this thread (null outside one). Messages that go to the
// interpreter (String methods such as C2D) run under the caller's settings, so the bridge reads them from here.
inline thread_local const ActivationNumeric *currentNumeric = nullptr;
struct NumericScope {
    const ActivationNumeric *previous;
    explicit NumericScope(const ActivationNumeric &n) : previous(currentNumeric) { currentNumeric = &n; }
    ~NumericScope() { currentNumeric = previous; }
};
// The names a method EXPOSEs. A method has a handful, written as string literals: they are kept as pointers (no allocation per call);
// names that are not literals go to an overflow vector.
// The EXPOSE list of a method or a PROCEDURE EXPOSE, made once (a static of the compiled code): a new activation
// points at it, with nothing to copy. Each simple name has a key (length, first and fourth character: selectorKey),
// compared before the characters; stems ("S.", which expose every compound symbol under them) are kept apart.
struct ExposeTable {
    struct Entry { const char *name; std::uint32_t len; std::uint32_t key; };
    std::vector<Entry> names, stems;
    static std::uint32_t keyOf(const char *t, std::size_t len) {
        return static_cast<std::uint32_t>(len & 0xffff) | static_cast<std::uint32_t>(len ? static_cast<unsigned char>(t[0]) : 0) << 16 |
               static_cast<std::uint32_t>(len ? static_cast<unsigned char>(t[len >= 4 ? 3 : len - 1]) : 0) << 24;
    }
    explicit ExposeTable(std::initializer_list<const char *> list) {
        for (const char *n : list) {
            const std::size_t len = std::strlen(n);
            (len > 0 && n[len - 1] == '.' ? stems : names).push_back(Entry{n, static_cast<std::uint32_t>(len), keyOf(n, len)});
        }
    }
    bool empty() const { return names.empty() && stems.empty(); }
    bool contains(const char *text, std::size_t len) const {
        const std::uint32_t key = keyOf(text, len);
        for (const Entry &e : names) if (e.key == key && std::memcmp(e.name, text, len) == 0) return true;
        for (const Entry &e : stems) if (len >= e.len && std::memcmp(text, e.name, e.len) == 0) return true;   // the stem, or a compound under it
        return false;
    }
};
struct ExposedNames {
    static constexpr unsigned inlineMax = 6;
    const char *lit[inlineMax]; std::size_t litLen[inlineMax]; unsigned n = 0;
    std::vector<std::string> extra;
    const ExposeTable *table = nullptr;
    bool empty() const { return n == 0 && extra.empty() && (!table || table->empty()); }
    void add(const char *name) {
        if (n < inlineMax) { lit[n] = name; litLen[n] = std::strlen(name); ++n; } else extra.emplace_back(name);
    }
    void add(const std::string &name) { extra.push_back(name); }
    // every name, the table's and the added ones
    template <typename F> bool any(F &&test) const {
        if (table) {
            for (const auto &e : table->names) if (test(e.name, std::size_t(e.len))) return true;
            for (const auto &e : table->stems) if (test(e.name, std::size_t(e.len))) return true;
        }
        return anyAdded(test);
    }
    template <typename F> bool anyAdded(F &&test) const {
        for (unsigned i = 0; i < n; i++) if (test(lit[i], litLen[i])) return true;
        for (const auto &e : extra) if (test(e.c_str(), e.size())) return true;
        return false;
    }
};
// Every variable pool has a process-unique id, never copied: a compiled variable slot (VarSlot) remembers which pool it
// resolved against, so a pool freed and reallocated at the same address can never satisfy a stale slot.
inline std::atomic<std::uint64_t> &variablePoolCounter() { static std::atomic<std::uint64_t> c{1}; return c; }
struct PoolId {
    std::uint64_t value = variablePoolCounter().fetch_add(1, std::memory_order_relaxed);
    PoolId() = default;
    PoolId(const PoolId &) : PoolId() {}
    PoolId &operator=(const PoolId &) { value = variablePoolCounter().fetch_add(1, std::memory_order_relaxed); return *this; }
};
// Bumped by every erase of a simple variable from any pool (DROP, INTERPRET sync): a slot holding a pointer to a map
// node is valid only while the generation it saw is current. Insertions and rehash keep node addresses, so they need no bump.
inline std::atomic<std::uint64_t> &variableEraseGeneration() { static std::atomic<std::uint64_t> g{1}; return g; }
inline void variablesErased() { variableEraseGeneration().fetch_add(1, std::memory_order_release); }
// The simple variable names of one compiled body, in its slot order (RxHybridMethod~useLocalSlots): a static of the
// generated code. A name is found by its key (length, first and fourth character: Tom Dyer's key) in a small
// open-addressed table, then compared.
struct FrameNames {
    std::vector<const char *> names;
    std::vector<std::uint32_t> lens, keys;
    std::vector<int> table;   // slot numbers by key, -1 empty
    std::size_t mask = 0;
    static std::uint32_t keyOf(const char *t, std::size_t len) {
        return static_cast<std::uint32_t>(len & 0xffff) | static_cast<std::uint32_t>(len ? static_cast<unsigned char>(t[0]) : 0) << 16 |
               static_cast<std::uint32_t>(len ? static_cast<unsigned char>(t[len >= 4 ? 3 : len - 1]) : 0) << 24;
    }
    static std::size_t spread(std::uint32_t key) { return static_cast<std::size_t>((key * 0x9E3779B1u) >> 7); }
    FrameNames() = default;
    FrameNames(std::initializer_list<const char *> list) {
        for (const char *n : list) {
            const std::size_t len = std::strlen(n);
            names.push_back(n); lens.push_back(static_cast<std::uint32_t>(len)); keys.push_back(keyOf(n, len));
        }
        std::size_t size = 8;
        while (size < names.size() * 2) size *= 2;
        table.assign(size, -1);
        mask = size - 1;
        for (std::size_t k = 0; k < names.size(); ++k) {
            std::size_t i = spread(keys[k]) & mask;
            while (table[i] >= 0) i = (i + 1) & mask;
            table[i] = static_cast<int>(k);
        }
    }
    int find(const char *t, std::size_t len) const {
        if (names.empty()) return -1;
        const std::uint32_t key = keyOf(t, len);
        for (std::size_t i = spread(key) & mask; table[i] >= 0; i = (i + 1) & mask) {
            const int k = table[i];
            if (keys[k] == key && std::memcmp(names[k], t, len) == 0) return k;
        }
        return -1;
    }
};
struct Variables : std::unordered_map<std::string, Value> {
    PoolId poolId;
    ActivationNumeric numeric;
    Variables *outer = nullptr;
    ExposedNames exposed;
    // The activation's frame (rx::Frame): the simple variables of the compiled body, by slot number, kept in place of
    // map entries. frame[k] is the storage of slot k's variable (its own, or the owner's for a PROCEDURE EXPOSE name),
    // or null when it is kept by name (a stem, an EXPOSEd name). frameOwn: this pool's own storage.
    std::optional<Value> **frame = nullptr;
    std::optional<Value> *frameOwn = nullptr;
    std::size_t frameSize = 0;
    const FrameNames *frameNames = nullptr;
    Variables() = default;
    // (a copy has no frame: the frame belongs to the activation; its variables are copied by name)
    Variables(const Variables &o) : std::unordered_map<std::string, Value>(o), poolId(o.poolId), numeric(o.numeric),
                                    outer(o.outer), exposed(o.exposed) { copyFrameOf(o); }
    Variables &operator=(const Variables &o) {
        if (this != &o) {
            std::unordered_map<std::string, Value>::operator=(o);
            poolId = o.poolId; numeric = o.numeric; outer = o.outer; exposed = o.exposed;
            frame = nullptr; frameOwn = nullptr; frameSize = 0; frameNames = nullptr;
            copyFrameOf(o);
        }
        return *this;
    }
    void copyFrameOf(const Variables &o) {
        if (!o.frame || !o.frameNames) return;
        for (std::size_t k = 0; k < o.frameSize && k < o.frameNames->names.size(); ++k)
            if (o.frame[k] == o.frameOwn + k && *o.frame[k])
                insert_or_assign(std::string(o.frameNames->names[k], o.frameNames->lens[k]), **o.frame[k]);
    }
    Variables(Variables &caller, std::vector<std::string> names) : numeric(caller.numeric), outer(&caller) {
        for (auto &n : names) exposed.add(n);
    }
    Variables(Variables &caller, std::initializer_list<const char *> names) : numeric(caller.numeric), outer(&caller) {
        for (const char *n : names) exposed.add(n);
    }
    Variables(Variables &caller, const ExposeTable &table) : numeric(caller.numeric), outer(&caller) { exposed.table = &table; }
    bool isExposed(const std::string &name) const { return isExposed(name.data(), name.size()); }
    bool isExposed(const char *text, std::size_t len) const {
        if (exposed.table && exposed.table->contains(text, len)) return true;
        return exposed.anyAdded([&](const char *e, std::size_t elen) {
            if (elen == len && std::memcmp(e, text, len) == 0) return true;
            // a stem exposed as "STEM." exposes every compound symbol under it
            return elen > 0 && e[elen - 1] == '.' && len > elen && std::memcmp(text, e, elen) == 0;
        });
    }
};
// Standalone native class subset. Each object owns a variable scope, while
// each compiled method gets a fresh activation that aliases EXPOSEd fields.
// Methods remain first-class message selectors; no interpreter is embedded.
struct NativeClass;
struct NativeInstance final : ObjectDispatch {
    std::shared_ptr<NativeClass> definingClass;
    Variables fields;
    explicit NativeInstance(std::shared_ptr<NativeClass> cls) : definingClass(std::move(cls)) {}
    MessageResult sendMessage(const std::string &selector,
                              const std::vector<Value> &args) override;
};
struct NativeClass final : ObjectDispatch, std::enable_shared_from_this<NativeClass> {
    using Method = std::function<MessageResult(NativeInstance &, const std::vector<Value> &)>;
    std::unordered_map<std::string, Method> methods;
    std::unordered_set<std::string> attributes;
    MessageResult sendMessage(const std::string &selector,
                              const std::vector<Value> &args) override {
        if (rx::eqLit(selector, "NEW")) {
            auto instance = std::make_shared<NativeInstance>(shared_from_this());
            auto found = methods.find("INIT");
            if (found != methods.end()) found->second(*instance, args);
            else if (!args.empty()) throw std::runtime_error("class without INIT rejects NEW arguments");
            return Value::fromObject(instance);
        }
        return ObjectDispatch::sendMessage(selector, args);
    }
};
inline MessageResult NativeInstance::sendMessage(const std::string &selector,
                                                  const std::vector<Value> &args) {
    // This strict native subset declares only unquoted ooRexx method names.
    // Their selectors are case-insensitive, including quoted send spellings.
    std::string canonical = selector;
    std::transform(canonical.begin(), canonical.end(), canonical.begin(),
                   [](unsigned char c) { return static_cast<char>(std::toupper(c)); });
    const auto method = definingClass->methods.find(canonical);
    if (method != definingClass->methods.end()) return method->second(*this, args);
    if (definingClass->attributes.count(canonical) && args.empty()) {
        const auto found = fields.find(canonical);
        return found == fields.end() ? Value::string(canonical) : found->second;
    }
    if (canonical.size() > 1 && canonical.back() == '=' && args.size() == 1) {
        const std::string field = canonical.substr(0, canonical.size() - 1);
        if (definingClass->attributes.count(field)) {
            fields.insert_or_assign(field, args.front());
            return std::nullopt;
        }
    }
    return ObjectDispatch::sendMessage(selector, args);
}
// Internal routine invocations always receive the CURRENT caller scope.
// Nested calls without PROCEDURE share it; PROCEDURE creates an isolated
// variable pool, potentially exposing bindings back to the caller.
using RoutineRegistry = std::unordered_map<std::string,
    std::function<MessageResult(Variables &, const std::vector<Value>&)>>;
inline MessageResult invokeInternal(Variables &vars, RoutineRegistry &registry,
                                   const std::string &name, const std::vector<Value> &args) {
    auto found = registry.find(name);
    if (found == registry.end()) throw std::runtime_error("unknown internal routine: " + name);
    return found->second(vars, args);
}
inline Value internalRoutineValue(Variables &vars, RoutineRegistry &registry,
                                  const std::string &name, const std::vector<Value> &args) {
    auto returned = invokeInternal(vars, registry, name, args);
    if (!returned) throw std::runtime_error("internal routine did not return a value: " + name);
    return *returned;
}

inline std::string trim(std::string s) {
    auto blank = [](unsigned char c) { return c == ' ' || c == '\t'; };  // the interpreter's whitespace: blank, tab
    std::size_t b = 0, e = s.size();
    while (b < e && blank(static_cast<unsigned char>(s[b]))) ++b;
    while (e > b && blank(static_cast<unsigned char>(s[e - 1]))) --e;
    return s.substr(b, e - b);
}
// Integer literals and whole-number arithmetic are checked signed 64-bit.
// Division uses an initial nine-significant-digit decimal subset; not a
// complete implementation of NUMERIC DIGITS, FUZZ, FORM, or decimal contexts.
inline bool tryInteger(const Value &v, std::int64_t &out) {
    if (v.isObject()) return false;
    const std::string s = trim(v.bytes);
    if (s.empty()) return false;
    std::size_t i = 0;
    bool minus = false;
    if (s[0] == '+' || s[0] == '-') { minus = s[0] == '-'; ++i; while (i < s.size() && (s[i] == ' ' || s[i] == '\t')) ++i; }
    if (i == s.size()) return false;
    std::uint64_t mag = 0;
    const std::uint64_t limit = minus ? (std::uint64_t(1) << 63)
                                       : std::uint64_t(std::numeric_limits<std::int64_t>::max());
    for (; i < s.size(); ++i) {
        unsigned char c = static_cast<unsigned char>(s[i]);
        if (c < '0' || c > '9') return false;
        std::uint64_t d = c - '0';
        if (mag > (limit - d) / 10) return false;
        mag = mag * 10 + d;
    }
    if (minus && mag == (std::uint64_t(1) << 63)) out = std::numeric_limits<std::int64_t>::min();
    else out = minus ? -static_cast<std::int64_t>(mag) : static_cast<std::int64_t>(mag);
    return true;
}
inline std::int64_t integer(const Value &v) {
    std::int64_t out;
    if (!tryInteger(v, out)) throw std::runtime_error("non-integer or out-of-range value");
    return out;
}
// Repetition DO count is evaluated once.  Decimal contexts are not yet
// generally implemented, so require a nonnegative exact integral value.
inline std::int64_t repeatCount(const Value &v) {
    const std::int64_t count = integer(v);
    if (count < 0) throw std::runtime_error("DO repetition count must be nonnegative");
    return count;
}
inline Value pendingNumber(std::int64_t coef, int exp);   // (rx_rexx_number.hpp)
inline Value fromInteger(std::int64_t x) { return pendingNumber(x, 0); }   // (its characters: std::to_string(x))
// The current pool can redirect named variables and whole stems through
// exposure chains. All symbol accesses must pass this boundary.
inline Variables &variableOwner(Variables &vars, const std::string &name) {
    if (vars.outer && vars.isExposed(name)) return variableOwner(*vars.outer, name);
    return vars;
}
inline const Variables &variableOwner(const Variables &vars, const std::string &name) {
    if (vars.outer && vars.isExposed(name)) return variableOwner(*vars.outer, name);
    return vars;
}
// The frame storage of a simple variable of this pool (its own or, for a PROCEDURE EXPOSE name, the owner's), or null
// when the pool keeps it by name.
inline std::optional<Value> *frameEntry(const Variables &pool, const char *name, std::size_t len) {
    if (!pool.frame) return nullptr;
    const int k = pool.frameNames->find(name, len);
    return (k >= 0 && static_cast<std::size_t>(k) < pool.frameSize) ? pool.frame[k] : nullptr;
}
inline std::optional<Value> *frameEntry(const Variables &pool, const std::string &name) { return frameEntry(pool, name.data(), name.size()); }
inline const Value *lookup(const Variables &vars, const std::string &name) {
    const Variables &owner = variableOwner(vars, name);
    if (std::optional<Value> *f = frameEntry(owner, name)) return *f ? &**f : nullptr;
    auto found = owner.find(name);
    return found == owner.end() ? nullptr : &found->second;
}
// Every variable of this pool itself (not the exposed ones of another pool): (name, value), its frame's included.
template <typename F> void forEachVariable(const Variables &vars, F &&each) {
    for (const auto &kv : vars) each(kv.first, kv.second);
    if (!vars.frame) return;
    for (std::size_t k = 0; k < vars.frameSize && k < vars.frameNames->names.size(); ++k)
        if (vars.frame[k] == vars.frameOwn + k && *vars.frame[k])
            each(std::string(vars.frameNames->names[k], vars.frameNames->lens[k]), **vars.frame[k]);
}
// TRACE / ADDRESS state (per thread). A compiled program has no trace output: settings that stay quiet are accepted,
// settings that would print trace lines are refused loudly instead of silently ignored.
inline std::string &traceSetting() { return threadState().trace; }
inline std::string &addressEnvironment() { return threadState().address; }
[[noreturn]] inline void raiseTraceDebug();
inline std::string traceSet(const Value &v) {
    const std::string old = traceSetting();
    std::string t = v.bytes;
    {   // a numeric TRACE (a debug skip count) is valid only in interactive debugging (RexxActivation::debugSkip): 24.901
        std::size_t b = t.find_first_not_of(' '), e = t.find_last_not_of(' ');
        if (b != std::string::npos) {
            std::string n = t.substr(b, e - b + 1);
            if (!n.empty() && (n[0] == '+' || n[0] == '-')) n.erase(0, 1);
            if (!n.empty() && n.find_first_not_of("0123456789") == std::string::npos)
                raiseTraceDebug();
        }
    }
    std::size_t i = 0;
    while (i < t.size() && (t[i] == '?' || t[i] == ' ' || (t[i] >= '0' && t[i] <= '9'))) ++i;
    if (i >= t.size()) { traceSetting() = "N"; return old; }
    const char c = static_cast<char>(std::toupper(static_cast<unsigned char>(t[i])));
    if (c != 'O' && c != 'N' && c != 'F' && c != 'E')
        throw std::runtime_error(std::string("TRACE setting '") + c + "' would produce trace output; not supported in compiled programs");
    traceSetting() = std::string(1, c);
    return old;
}
// ADDRESS env (no command) makes env current and the previous one the alternate; a bare ADDRESS swaps them.
inline std::string &alternateEnvironment() { return threadState().alternate; }
inline Value requestString(const Value &v);
[[noreturn]] inline void raiseAddressName(const std::string &name);
inline std::string addressSet(const Value &in) {
    const Value v = in.isObject() ? requestString(in) : in;
    // SystemInterpreter::validateAddressName (Unix): at most 250 characters, else 29.1
    if (v.bytes.size() > 250) raiseAddressName(v.bytes);
    const std::string old = addressEnvironment();
    alternateEnvironment() = old;
    addressEnvironment() = v.bytes;
    return old;
}
inline void addressToggle() { std::swap(addressEnvironment(), alternateEnvironment()); }
// SIGNAL ON NOVALUE: while a TrapState has the trap armed, reading an unset variable raises NOVALUE.
struct NoValueCondition : std::runtime_error {
    std::string variable;
    explicit NoValueCondition(std::string name) : std::runtime_error("NOVALUE: " + name), variable(std::move(name)) {}
};
inline Value get(const Variables &vars, const std::string &name) {
    const Value *v = lookup(vars, name);
    if (v) return *v;
    if (const bool *armed = threadState().novalueArmed; armed && *armed) throw NoValueCondition(name);
    return Value::string(name);
}
inline void set(Variables &vars, const std::string &name, Value value) {
    Variables &owner = variableOwner(vars, name);
    if (std::optional<Value> *f = frameEntry(owner, name)) { if (*f) **f = std::move(value); else f->emplace(std::move(value)); return; }
    owner.insert_or_assign(name, std::move(value));
}
// An EXPOSEd variable after a SELF send (the method may have changed the object variable): the object's value, or no
// value when it has none (never its name: an unset variable stays unset, VAR() 0, no NOVALUE).
inline void drop(Variables &vars, const std::string &name);
inline void refreshField(Variables &vars, const Variables &fields, const std::string &name) {
    if (const Value *v = lookup(fields, name)) { if (&variableOwner(vars, name) != &fields) set(vars, name, *v); }
    else if (&variableOwner(vars, name) != &fields) drop(vars, name);
}
inline void drop(Variables &vars, const std::string &name) {
    // Slots cache simple variables and stem variables ("S."): erasing a compound entry ("S.1") cannot invalidate one.
    const std::size_t dot = name.find('.');
    Variables &owner = variableOwner(vars, name);
    if (std::optional<Value> *f = frameEntry(owner, name)) { f->reset(); return; }   // (no slot caches a frame entry)
    if (owner.erase(name) && (dot == std::string::npos || dot + 1 == name.size())) variablesErased();
}
inline void resetStem(Variables &vars, const std::string &stem) {
    // Only compound entries (names containing '.') are erased here, and slots never cache those: no generation bump.
    auto &owner = variableOwner(vars, stem);
    for (auto it = owner.begin(); it != owner.end();) {
        if (it->first.size() > stem.size() &&
            it->first.compare(0, stem.size(), stem) == 0) it = owner.erase(it);
        else ++it;
    }
}
// A compiled access site for one simple (non-compound) variable name. The compiler gives each site its own thread-local
// cache: the map node is found once per (pool, erase generation) and then read/written directly. Every miss goes the
// ordinary name-keyed way (EXPOSE aliasing, NOVALUE), so semantics are those of get()/set().
struct VarSlot {
    std::uint64_t pool;
    std::uint64_t gen;
    Value *node;
    // A variable found in the pool's EXPOSE owner (an object variable kept by name: a stem): remembered by that owner, so
    // the next activation of the same method on the same object (another pool, the same EXPOSE list) finds it at once.
    const void *viaTable;
    __attribute__((always_inline)) Value *resolve(const Variables &vars) {
        if (node && gen == variableEraseGeneration().load(std::memory_order_acquire) &&
            (pool == vars.poolId.value || (viaTable && vars.outer && vars.outer->poolId.value == pool &&
                                           vars.exposed.table == viaTable && vars.exposed.n == 0 && vars.exposed.extra.empty())))
            return node;
        return nullptr;
    }
    void remember(const Variables &vars, std::uint64_t g, Value *p) { pool = vars.poolId.value; gen = g; node = p; viaTable = nullptr; }
    void remember(const Variables &vars, const Variables &owner, std::uint64_t g, Value *p) {
        // (by the owner when the name came from the pool's static EXPOSE list straight to its outer pool)
        if (&owner == vars.outer && vars.exposed.table && vars.exposed.n == 0 && vars.exposed.extra.empty()) {
            pool = owner.poolId.value; gen = g; node = p; viaTable = vars.exposed.table;
        }
        else remember(vars, g, p);
    }
    __attribute__((always_inline)) Value get(const Variables &vars, const char *name) {
        if (Value *p = resolve(vars)) return *p;
        return getSlow(vars, name);
    }
    __attribute__((noinline)) Value getSlow(const Variables &vars, const char *name) {
        const std::uint64_t g = variableEraseGeneration().load(std::memory_order_acquire);
        const std::string key(name);
        const Variables &owner = variableOwner(vars, key);
        if (std::optional<Value> *f = frameEntry(owner, key)) {
            if (*f) return **f;
            if (const bool *armed = threadState().novalueArmed; armed && *armed) throw NoValueCondition(name);
            return Value::string(name);
        }
        auto found = owner.find(key);
        if (found == owner.end()) {
            if (const bool *armed = threadState().novalueArmed; armed && *armed) throw NoValueCondition(name);
            return Value::string(name);
        }
        remember(vars, owner, g, const_cast<Value *>(&found->second));
        return found->second;
    }
    // The variable's value in place (nullptr when it has none): the caller reads it without a copy.
    __attribute__((always_inline)) const Value *find(const Variables &vars, const char *name) {
        if (Value *p = resolve(vars)) return p;
        return findSlow(vars, name);
    }
    __attribute__((noinline)) const Value *findSlow(const Variables &vars, const char *name) {
        const std::uint64_t g = variableEraseGeneration().load(std::memory_order_acquire);
        const std::string key(name);
        const Variables &owner = variableOwner(vars, key);
        if (std::optional<Value> *f = frameEntry(owner, key)) return *f ? &**f : nullptr;
        auto found = owner.find(key);
        if (found == owner.end()) return nullptr;
        remember(vars, owner, g, const_cast<Value *>(&found->second));
        return &found->second;
    }
    __attribute__((always_inline)) void set(Variables &vars, const char *name, Value value) {
        if (Value *p = resolve(vars)) { *p = std::move(value); return; }
        setSlow(vars, name, std::move(value));
    }
    __attribute__((noinline)) void setSlow(Variables &vars, const char *name, Value value) {
        const std::uint64_t g = variableEraseGeneration().load(std::memory_order_acquire);
        std::string key(name);
        Variables &owner = variableOwner(vars, key);
        if (std::optional<Value> *f = frameEntry(owner, key)) { if (*f) **f = std::move(value); else f->emplace(std::move(value)); return; }
        auto r = owner.insert_or_assign(std::move(key), std::move(value));
        remember(vars, owner, g, &r.first->second);
    }
};
// One slot per compiled access site and thread; the slot is zero-initialised (trivial), so no guard is needed.
#define RX_VGET(N) ([&]() -> ::rx::Value { static thread_local ::rx::VarSlot _rxSlot; return _rxSlot.get(vars, N); }())
// A variable's value by reference (message receivers); an unset variable yields its name (NOVALUE rules of get()).
#define RX_VREF(N) ([&]() -> const ::rx::Value & { static thread_local ::rx::VarSlot _rxSlot; if (const ::rx::Value *_rxP = _rxSlot.find(vars, N)) return *_rxP; static thread_local ::rx::Value _rxUnset = ::rx::Value::string(std::string()); _rxUnset = _rxSlot.get(vars, N); return _rxUnset; }())
// A compound symbol's tail variable: an unset one is its name, with no NOVALUE (only the compound's own value can raise it).
#define RX_VTAIL(N) ([&]() -> ::rx::Value { static thread_local ::rx::VarSlot _rxSlot; if (const ::rx::Value *_rxP = _rxSlot.find(vars, N)) return *_rxP; return ::rx::Value::string(N); }())
#define RX_VSET(N, ...) ([&]() { static thread_local ::rx::VarSlot _rxSlot; _rxSlot.set(vars, N, __VA_ARGS__); }())
// The same accesses through the activation's own slot table (rx::LocalSlots _rxL, one slot per variable name of the
// method body, numbered by the compiler: RxHybridMethod~useLocalSlots): no thread-local storage, and every access site
// of one name shares the slot. The slot is checked against the pool and erase generation as before, so semantics are
// those of get()/set() (EXPOSE, PROCEDURE pools, DROP).
// nr / nk: the native registers (RxNative.cls): nk[k] says nr[k] is the whole number the variable of slot k holds now
// (1; 2: and its characters are exactly that number's digits, NumCache canonical).
// An unset variable's value: its name, or the NOVALUE condition when it is trapped (get()).
__attribute__((noinline)) inline Value unsetVariable(const char *name) {
    if (const bool *armed = threadState().novalueArmed; armed && *armed) throw NoValueCondition(name);
    return Value::string(name);
}
template <std::size_t K> struct LocalSlots {
    VarSlot s[K]; std::int64_t nr[K]; std::uint8_t nk[K];
    static constexpr std::size_t size = K;
    // Slot k's variable in the pool's frame (rx::Frame), or null: then the slot finds it by name, as before.
    static __attribute__((always_inline)) std::optional<Value> *frameOf(std::size_t k, const Variables &vars) {
        return (vars.frame && k < vars.frameSize) ? vars.frame[k] : nullptr;
    }
    __attribute__((always_inline)) Value get(std::size_t k, const Variables &vars, const char *name) {
        if (std::optional<Value> *f = frameOf(k, vars)) return *f ? **f : unsetVariable(name);
        return s[k].get(vars, name);
    }
    __attribute__((always_inline)) const Value *find(std::size_t k, const Variables &vars, const char *name) {
        if (std::optional<Value> *f = frameOf(k, vars)) return *f ? &**f : nullptr;
        return s[k].find(vars, name);
    }
    __attribute__((always_inline)) Value *resolve(std::size_t k, const Variables &vars) {
        if (std::optional<Value> *f = frameOf(k, vars)) return *f ? &**f : nullptr;
        return s[k].resolve(vars);
    }
    __attribute__((always_inline)) void set(std::size_t k, Variables &vars, const char *name, Value value) {
        if (std::optional<Value> *f = frameOf(k, vars)) { if (*f) **f = std::move(value); else f->emplace(std::move(value)); return; }
        s[k].set(vars, name, std::move(value));
    }
    // An internal routine runs the same body with the same table: its pool (a PROCEDURE pool, gone when it returns)
    // replaces the caller's cached variables. The caller keeps its slots across the call (SlotsKept) when the table is
    // small enough to copy cheaply; a kept slot is still checked against the pool and the erase generation when used.
    static constexpr bool keepAcrossCalls = K <= 64;
};
// The frame of one activation (a method's pool, or a PROCEDURE pool of one of its internal routines): the body's simple
// variables kept by slot number instead of by name (no map node, no hashing, no string per first use). A stem's own
// variable ("S.") is in the frame too; its compound entries ("S.1") stay by name. An EXPOSEd name is its owner's frame
// entry when the owner has one (the object's FieldFrame, the caller's frame), else by name. Every by-name access (VALUE, VAR, SYMBOL, DROP, INTERPRET, PARSE, a PROCEDURE EXPOSE chain)
// finds a frame variable through the pool's FrameNames, so it is the same variable everywhere.
template <std::size_t K> struct Frame {
    static constexpr std::size_t inlineMax = 16;
    Variables &vars;
    std::optional<Value> inl[K <= inlineMax ? K : 1];
    std::unique_ptr<std::optional<Value>[]> big;
    std::optional<Value> *at[K];
    Frame(Variables &v, const FrameNames &names) : vars(v) {
        std::optional<Value> *own = inl;
        if (K > inlineMax) { big.reset(new std::optional<Value>[K]); own = big.get(); }
        const std::size_t count = std::min(K, names.names.size());
        for (std::size_t k = 0; k < K; ++k) at[k] = nullptr;
        for (std::size_t k = 0; k < count; ++k) {
            const char *name = names.names[k];
            const std::size_t len = names.lens[k];
            if (len == 0) continue;
            if (v.outer && v.isExposed(name, len)) {
                // the owner's (an EXPOSEd object variable is by name; a PROCEDURE EXPOSE name the caller's frame entry)
                const Variables *owner = v.outer;
                while (owner->outer && owner->isExposed(name, len)) owner = owner->outer;
                at[k] = frameEntry(*owner, name, len);
                continue;
            }
            at[k] = own + k;
        }
        // (variables set by name before the frame (the method's arguments): moved into it; no slot has cached them)
        for (auto it = v.begin(); it != v.end();) {
            const int k = names.find(it->first.data(), it->first.size());
            if (k >= 0 && static_cast<std::size_t>(k) < K && at[k] == own + k) { own[k].emplace(std::move(it->second)); it = v.erase(it); }
            else ++it;
        }
        v.frame = at; v.frameOwn = own; v.frameSize = K; v.frameNames = &names;
    }
    ~Frame() { vars.frame = nullptr; vars.frameOwn = nullptr; vars.frameSize = 0; vars.frameNames = nullptr; }
    Frame(const Frame &) = delete;
    Frame &operator=(const Frame &) = delete;
};
// The object variables of a compiled class scope (its EXPOSEd simple names) kept in place, as a frame that lives as long as
// the object: a method's frame finds an EXPOSEd name there (Frame: the owner's frame entry), so it reads and writes the
// object variable directly (a stem: its stem variable; its compound entries stay by name). Names no method of the class
// EXPOSEs stay by name.
template <std::size_t N> struct FieldFrame {
    std::optional<Value> own[N];
    std::optional<Value> *at[N];
    FieldFrame(Variables &fields, const FrameNames &names) {
        for (std::size_t k = 0; k < N; ++k) {
            at[k] = (k >= names.names.size() || names.lens[k] == 0) ? nullptr : own + k;
        }
        fields.frame = at; fields.frameOwn = own; fields.frameSize = N; fields.frameNames = &names;
    }
    // (the values are taken out first, then released: a value's release may run code that looks at this object)
    void clear() {
        std::vector<Value> gone;
        for (auto &v : own) if (v) { gone.push_back(std::move(*v)); v.reset(); }
    }
    FieldFrame(const FieldFrame &) = delete;
    FieldFrame &operator=(const FieldFrame &) = delete;
};
template <std::size_t K, bool Keep = LocalSlots<K>::keepAcrossCalls> struct SlotsKept {
    LocalSlots<K> &table; VarSlot saved[K];
    explicit SlotsKept(LocalSlots<K> &t) : table(t) { std::memcpy(static_cast<void *>(saved), static_cast<const void *>(t.s), sizeof saved); }
    ~SlotsKept() { std::memcpy(static_cast<void *>(table.s), static_cast<const void *>(saved), sizeof saved); }
};
template <std::size_t K> struct SlotsKept<K, false> { explicit SlotsKept(LocalSlots<K> &) {} };
template <std::size_t K> inline SlotsKept<K> keepSlots(LocalSlots<K> &t) { return SlotsKept<K>(t); }
// A stem variable's own entry ("S."), or null: what compiled S.tail checks for its stem object (rx::stemGet1).
#define RX_VSTEM(N) ([&]() -> const ::rx::Value * { static thread_local ::rx::VarSlot _rxSlot; return _rxSlot.find(vars, N); }())
#define RX_VSTEMK(K, N) (_rxL.find(K, vars, N))
#define RX_VGETK(K, N) (_rxL.get(K, vars, N))
#define RX_VREFK(K, N) ([&]() -> const ::rx::Value & { if (const ::rx::Value *_rxP = _rxL.find(K, vars, N)) return *_rxP; static thread_local ::rx::Value _rxUnset = ::rx::Value::string(std::string()); _rxUnset = _rxL.get(K, vars, N); return _rxUnset; }())
#define RX_VTAILK(K, N) ([&]() -> const ::rx::Value & { if (const ::rx::Value *_rxP = _rxL.find(K, vars, N)) return *_rxP; static thread_local ::rx::Value _rxName = ::rx::Value::string(N); return _rxName; }())
#define RX_VSETK(K, N, ...) (_rxL.set(K, vars, N, __VA_ARGS__))


// USE ARG drops an omitted target instead of assigning the empty string;
// PARSE ARG deliberately has different missing-argument semantics.
inline void useArgument(Variables &vars, const std::vector<Value> &args,
                        const std::string &name, std::size_t index) {
    if (index >= args.size()) drop(vars, name);
    else set(vars, name, args[index]);
}
// SYNTAX conditions: RAISE SYNTAX / runtime errors, trapped by SIGNAL ON SYNTAX.
// ooRexx 5.3 quirk (verified): a plain RAISE SYNTAX (no RETURN option) raised inside an internal
// routine is NOT trapped by SIGNAL ON SYNTAX of any internal routine; only the program's top-level
// trap sees it. RAISE ... RETURN is trapped locally. Genuine runtime errors are trapped by the nearest trap.
struct SyntaxCondition : std::runtime_error {
    std::string code;
    bool skipInternalTraps;
    std::vector<Value> substitutions;   // RAISE SYNTAX ... ARRAY/ADDITIONAL values, kept for the interpreter's message
    std::shared_ptr<ObjectDispatch> conditionObject;   // the interpreter's condition object, when it raised the error
    SyntaxCondition(std::string c, const std::string &text, bool skip)
        : std::runtime_error("Error " + c + ": " + text), code(std::move(c)), skipInternalTraps(skip) {}
};
[[noreturn]] inline void raiseAddressName(const std::string &name) {
    SyntaxCondition e("29.1", "Environment name exceeds 250 characters; found \"" + name + "\"", false);
    e.substitutions = {Value::string("250"), Value::string(name)};
    throw e;
}
[[noreturn]] inline void raiseTraceDebug() {
    throw SyntaxCondition("24.901", "Numeric TRACE requests are valid only from interactive debugging", false);
}
// SIGNAL label in compiled code: leaves every active loop of the activation, as Rexx does.
struct SignalJump { int target; std::size_t line; };
struct ProgramExit { int code; };
// EXIT inside an internal routine of a compiled method leaves the method (with its value, or no result).
struct MethodExit { std::optional<Value> value; };
// A flag set for a scope and given back after it (compiled internal calls: _rxExitByReturn).
struct FlagScope {
    bool &flag; bool saved;
    FlagScope(bool &f, bool v) : flag(f), saved(f) { f = v; }
    ~FlagScope() { flag = saved; }
    FlagScope(const FlagScope &) = delete;
    FlagScope &operator=(const FlagScope &) = delete;
};
// The interpreter's process status for an uncaught SYNTAX error is 256 minus the error number
// (98 -> 158, 42 -> 214, 93 -> 163).  Runtime errors that carry no "Error N" prefix keep status 2.
inline int uncaughtStatus(const std::string &what) {
    if (what.compare(0, 6, "Error ") == 0) {
        const int n = std::atoi(what.c_str() + 6);
        if (n > 0 && n < 100) return (256 - n) & 255;
    }
    return 2;
}           // EXIT executed inside an internal routine
// RAISE ... ADDITIONAL(value): an array's items, or a string's lines (the interpreter applies MAKEARRAY).
inline std::vector<Value> additionalItems(const Value &v) {
    std::vector<Value> out;
    if (v.isObject()) {
        MessageResult items = v.object->sendMessage("MAKEARRAY", {});
        if (items && items->isObject()) {
            MessageResult n = items->object->sendMessage("ITEMS", {});
            const long count = n && !n->isObject() ? std::stol(n->bytes) : 0;
            for (long i = 1; i <= count; ++i) {
                MessageResult item = items->object->sendMessage("[]", {Value::string(std::to_string(i))});
                out.push_back(item ? *item : Value::string(""));
            }
            return out;
        }
        out.push_back(v);
        return out;
    }
    const std::string &s = v.bytes;
    std::size_t start = 0;
    while (start <= s.size()) {
        std::size_t nl = s.find('\n', start);
        std::string line = s.substr(start, nl == std::string::npos ? std::string::npos : nl - start);
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (nl == std::string::npos) { if (!line.empty() || out.empty()) out.push_back(Value::string(line)); break; }
        out.push_back(Value::string(line));
        start = nl + 1;
    }
    return out;
}
// RAISE of a condition other than SYNTAX: the activation ends and the condition is raised in its caller.
struct RaiseToCaller {
    std::string name;
    std::optional<Value> rc, description, additional, result;
    bool exitForm = false;    // RAISE without RETURN (EXIT): an internal routine's ends the method / routine (raiseExit)
    bool delivered = false;   // reached the caller, which traps it (raisedInCaller)
};
// RAISE SYNTAX expr: Interpreter::messageNumber - major 1..99, minor 0..999 (else 33.904); the code is major.minor.
// exitForm (no RETURN): from an internal routine the error is raised in the method / routine / program (raiseExit),
// so only that level's trap sees it.
[[noreturn]] inline void raiseSyntaxCode(const Value &code, const std::vector<Value> &args, bool exitForm = false) {
    auto bad = []() { throw SyntaxCondition("33.904", "Incorrect expression result following SYNTAX keyword of RAISE instruction", false); };
    if (code.isObject()) bad();
    const std::string c = code.bytes.str();
    const std::size_t dot = c.find('.');
    auto whole = [](const std::string &t, long &out) {
        std::size_t i = 0, n = t.size();
        while (i < n && t[i] == ' ') ++i;
        while (n > i && t[n - 1] == ' ') --n;
        if (i == n || n - i > 9 || t.find_first_not_of("0123456789", i) < n) return false;
        out = std::stol(t.substr(i, n - i));
        return true;
    };
    long major = 0, minor = 0;
    if (!whole(c.substr(0, dot), major) || major < 1 || major >= 100) bad();
    if (dot != std::string::npos && (!whole(c.substr(dot + 1), minor) || minor < 0 || minor >= 1000)) bad();
    SyntaxCondition condition(std::to_string(major) + "." + std::to_string(minor), std::string(), exitForm);
    condition.substitutions = args;
    throw condition;
}
[[noreturn]] inline void raiseSyntax(const std::string &code, const std::vector<Value> &args, bool localTrap) {
    std::string text;
    for (std::size_t i = 0; i < args.size(); ++i) { if (i) text += ' '; text += args[i].bytes; }
    SyntaxCondition condition(code, text, !localTrap);
    condition.substitutions = args;
    throw condition;
}
struct TrapState {
    bool syntaxOn = false;
    std::string syntaxLabel;
    bool novalueOn = false;
    std::string novalueLabel;
    TrapState() = default;
    TrapState(const TrapState &) = delete;
    TrapState &operator=(const TrapState &) = delete;
    ~TrapState() { ThreadState &t = threadState(); if (t.novalueArmed == &novalueOn) t.novalueArmed = nullptr; }
    void on(const std::string &condition, const std::string &label) {
        if (condition == "SYNTAX") { syntaxOn = true; syntaxLabel = label; }
        if (condition == "NOVALUE") { novalueOn = true; novalueLabel = label; threadState().novalueArmed = &novalueOn; }
    }
    void off(const std::string &condition) {
        if (condition == "SYNTAX") syntaxOn = false;
        if (condition == "NOVALUE") { novalueOn = false; ThreadState &t = threadState(); if (t.novalueArmed == &novalueOn) t.novalueArmed = nullptr; }
    }
    // Rexx disables the trap when it fires.
    bool take(std::string &label, const std::exception &error, bool topLevel) {
        if (dynamic_cast<const NoValueCondition *>(&error)) {
            if (!novalueOn) return false;
            novalueOn = false; { ThreadState &t = threadState(); if (t.novalueArmed == &novalueOn) t.novalueArmed = nullptr; }
            label = novalueLabel; return true;
        }
        if (!syntaxOn) return false;
        const auto *raised = dynamic_cast<const SyntaxCondition *>(&error);
        if (raised && raised->skipInternalTraps && !topLevel) return false;
        syntaxOn = false; label = syntaxLabel; return true;
    }
};
// A trapped SYNTAX condition sets RC to the error number (the part before the period), as the interpreter does.
inline void setSyntaxTrapRc(Variables &vars, const std::exception &error) {
    const auto *raised = dynamic_cast<const SyntaxCondition *>(&error);
    if (!raised) return;
    const std::string &c = raised->code;
    const std::size_t dot = c.find('.');
    if (dot == std::string::npos || dot == 0 || c.find_first_not_of("0123456789.") != std::string::npos) return;
    set(vars, "RC", Value::number(c.substr(0, dot)));
}
// USE STRICT ARG: exact argument-count contract (ooRexx 5.3 Error 40.3 / 40.4);
// optional arguments carry a constant default.
struct StrictArg { const char *name; bool required; const char *defaultValue; };
inline void useStrictArguments(Variables &vars, const std::vector<Value> &args,
                               const std::string &routine, std::initializer_list<StrictArg> spec) {
    std::size_t minimum = 0;
    for (const auto &a : spec) if (a.required) ++minimum;
    if (args.size() < minimum)
        throw std::runtime_error("Error 40.3: Not enough arguments in invocation of " + routine +
                                 "; minimum expected is " + std::to_string(minimum) + ".");
    if (args.size() > spec.size())
        throw std::runtime_error("Error 40.4: Too many arguments in invocation of " + routine +
                                 "; maximum expected is " + std::to_string(spec.size()) + ".");
    std::size_t i = 0;
    for (const auto &a : spec) {
        if (i < args.size()) set(vars, a.name, args[i]);
        else set(vars, a.name, Value::string(a.defaultValue));
        ++i;
    }
}
#include "rx_rexx_number.hpp"
#include "rx_compound_symbols.hpp"
#include "rx_parse_template.hpp"
#include "rx_parse_context.hpp"
inline Value add(const Value &a, const Value &b) {
    std::int64_t out;
    if (__builtin_add_overflow(integer(a), integer(b), &out)) throw std::runtime_error("integer overflow in +");
    return fromInteger(out);
}
inline Value sub(const Value &a, const Value &b) {
    std::int64_t out;
    if (__builtin_sub_overflow(integer(a), integer(b), &out)) throw std::runtime_error("integer overflow in -");
    return fromInteger(out);
}
inline Value mul(const Value &a, const Value &b) {
    std::int64_t out;
    if (__builtin_mul_overflow(integer(a), integer(b), &out)) throw std::runtime_error("integer overflow in *");
    return fromInteger(out);
}
// Strict decimal conversion for numeric result comparison and division.
// Never silently interpret a nonnumeric Rexx symbol as zero.
inline bool tryDecimal(const Value &v, long double &out) {
    if (v.isObject()) return false;
    const std::string s = trim(v.bytes);
    if (s.empty()) return false;
    bool seenDigit = false, seenDot = false, seenExp = false;
    std::size_t i = 0;
    if (s[i] == '+' || s[i] == '-') ++i;
    for (; i < s.size(); ++i) {
        char c = s[i];
        if (c >= '0' && c <= '9') { seenDigit = true; continue; }
        if (c == '.' && !seenDot && !seenExp) { seenDot = true; continue; }
        if ((c == 'e' || c == 'E') && !seenExp && seenDigit) {
            seenExp = true;
            if (i + 1 < s.size() && (s[i + 1] == '+' || s[i + 1] == '-')) ++i;
            if (i + 1 >= s.size() || s[i + 1] < '0' || s[i + 1] > '9') return false;
            continue;
        }
        return false;
    }
    if (!seenDigit) return false;
    errno = 0;
    char *end = nullptr;
    out = std::strtold(s.c_str(), &end);
    return errno != ERANGE && end && *end == '\0' && std::isfinite(out);
}
// This deliberately narrow division adapter rounds results to the default
// nine significant digits. ooRexx's full decimal arithmetic still requires
// an arbitrary-precision decimal backend and context propagation.
inline Value divide(const Value &a, const Value &b) {
    long double av, bv;
    if (!tryDecimal(a, av) || !tryDecimal(b, bv))
        throw std::runtime_error("division requires numeric operands");
    if (bv == 0.0L) throw SyntaxCondition("42.3", "Arithmetic overflow; divisor must not be zero", false);
    const long double quotient = av / bv;
    if (!std::isfinite(quotient)) throw std::runtime_error("division overflow");
    std::ostringstream out;
    out << std::setprecision(9) << quotient;
    return Value::number(out.str());
}
inline int exitCode(const Value &v) {
    const std::int64_t result = integer(v);
    if (result < std::numeric_limits<int>::min() || result > std::numeric_limits<int>::max())
        throw std::runtime_error("EXIT status outside native integer range");
    return static_cast<int>(result);
}
// A return from a top-level interpreted program may be a string value.
// The ooRexx CLI maps a non-numeric string return to process status zero.
// This does NOT model object-returning routine/method calls.
inline int programReturnCode(const Value &v) {
    std::int64_t code = 0;
    if (!tryInteger(v, code)) return 0;
    return exitCode(v);
}
inline Value neg(const Value &a) { return sub(fromInteger(0), a); }
inline Value pos(const Value &a) { return fromInteger(integer(a)); }
inline Value compare(const Value &a, const std::string &op, const Value &b) {
    // A built-in string cannot silently compare an unconverted object pointer.
    // Object-to-string coercion will be a separately implemented ruleset.
    if (a.isObject() || b.isObject())
        throw std::runtime_error("built-in/object comparison not implemented");
    if (op == "==") return fromInteger(a.bytes == b.bytes);
    if (op == "\\==") return fromInteger(a.bytes != b.bytes);
    std::int64_t ai, bi;
    long double ad, bd;
    int rel;
    if (tryInteger(a, ai) && tryInteger(b, bi)) rel = (ai > bi) - (ai < bi);
    else if (tryDecimal(a, ad) && tryDecimal(b, bd))
        rel = (ad > bd) - (ad < bd);
    else {
        // Non-strict: blanks/tabs stripped, then the shorter string padded with blanks (as the interpreter).
        std::string as = trim(a.bytes), bs = trim(b.bytes);
        if (as.size() < bs.size()) as.append(bs.size() - as.size(), ' ');
        else if (bs.size() < as.size()) bs.append(as.size() - bs.size(), ' ');
        rel = (as > bs) - (as < bs);
    }
    if (op == "=") return fromInteger(rel == 0);
    if (op == "\\=" || op == "<>" || op == "><") return fromInteger(rel != 0);
    if (op == "<") return fromInteger(rel < 0);
    if (op == "<=") return fromInteger(rel <= 0);
    if (op == ">") return fromInteger(rel > 0);
    if (op == ">=") return fromInteger(rel >= 0);
    throw std::runtime_error("compiler bug: unsupported comparison operator");
}
// Exact quoted operator selectors, e.g. x~'='(y), use the same virtual
// operator dispatch as infix expression syntax. The unquoted x~=(y) is not
// valid ooRexx syntax in the reference interpreter (selector must be named).
inline Value sendBinary(const Value &lhs, const std::string &selector, const Value &rhs);
// Standalone ooRexx message instructions set RESULT, or DROP it if the
// called method returns no value. In expressions, no result is an error.
// Cascade (~~) is always the receiver object, even for a no-result method.
// The caller's local variables own RESULT; no global interpreter state.
// With a host interpreter (library mode) a string message the native subset does not cover goes to the interpreter's own String class.
using StringMessageFallback = MessageResult (*)(const Value &, const std::string &, const std::vector<Value> &);
inline StringMessageFallback &stringMessageFallback() { static StringMessageFallback f = nullptr; return f; }
inline MessageResult sendStringBuiltin(const Value &receiver, const std::string &selector, const std::vector<Value> &args);
using StringMessageExtension = std::optional<MessageResult> (*)(const Value &, const std::string &, const std::vector<Value> &);
inline StringMessageExtension &stringBifExtension() { static StringMessageExtension f = nullptr; return f; }
inline StringMessageExtension &stringHostExtension() { static StringMessageExtension f = nullptr; return f; }
// ::REQUIRES "x" LIBRARY for a library that declares native classes: loaded by the hosted interpreter when it is linked.
using ClassLibraryLoader = bool (*)(const std::string &);
inline ClassLibraryLoader &classLibraryLoader() { static ClassLibraryLoader f = nullptr; return f; }
inline MessageResult sendMessage(const Value &receiver, const std::string &selector,
                                 const std::vector<Value> &args) {
    if (receiver.isObject()) return receiver.object->sendMessage(selector, args);
    // Library mode: the interpreter is the authority for String methods (native exact paths first, in the hook); no throw-and-retry.
    if (stringMessageFallback()) return stringMessageFallback()(receiver, selector, args);
    return sendStringBuiltin(receiver, selector, args);
}
inline MessageResult sendStringBuiltin(const Value &receiver, const std::string &selector,
                                       const std::vector<Value> &args) {
    const std::string &s = receiver.bytes;
    if (args.size() == 1 &&
        (rx::eqLit(selector, "+") || rx::eqLit(selector, "-") || rx::eqLit(selector, "*") || rx::eqLit(selector, "/") ||
         rx::eqLit(selector, "=") || rx::eqLit(selector, "\\=") || rx::eqLit(selector, "==") || rx::eqLit(selector, "\\==") ||
         rx::eqLit(selector, "<>") || rx::eqLit(selector, "><") || rx::eqLit(selector, "<") || rx::eqLit(selector, ">") ||
         rx::eqLit(selector, "<=") || rx::eqLit(selector, ">=")))
        return sendBinary(receiver, selector, args.front());
    if (rx::eqLit(selector, "COPIES") && args.size() == 1) {
        const auto repetitions = integer(args[0]);
        if (repetitions < 0 || repetitions > 1000000 ||
            (!s.empty() && static_cast<std::size_t>(repetitions) > (1 << 24) / s.size()))
            throw std::runtime_error("COPIES count exceeds native limit");
        std::string out;
        out.reserve(s.size() * static_cast<std::size_t>(repetitions));
        for (std::int64_t i = 0; i < repetitions; ++i) out += s;
        return Value::string(out);
    }
    if (rx::eqLit(selector, "LENGTH") && args.empty()) return fromInteger(static_cast<std::int64_t>(s.size()));
    if (rx::eqLit(selector, "REVERSE") && args.empty())
        return Value::string(std::string(s.rbegin(), s.rend()));
    if ((rx::eqLit(selector, "UPPER") || rx::eqLit(selector, "LOWER")) && args.empty()) {
        std::string output = s;
        // Deliberately ASCII-only; locale-sensitive mappings are not yet qualified.
        for (char &ch : output) {
            unsigned char c = static_cast<unsigned char>(ch);
            if (rx::eqLit(selector, "UPPER") && c >= 'a' && c <= 'z') ch = static_cast<char>(c - 32);
            if (rx::eqLit(selector, "LOWER") && c >= 'A' && c <= 'Z') ch = static_cast<char>(c + 32);
        }
        return Value::string(output);
    }
    if (rx::eqLit(selector, "COPIES") && args.size() == 1) {
        auto n = integer(args[0]);
        if (n < 0 || (n > 0 && static_cast<std::uint64_t>(n) >
            std::numeric_limits<std::size_t>::max() / (s.empty() ? 1 : s.size())))
            throw std::runtime_error("COPIES argument outside supported range");
        std::string output;
        output.reserve(s.size() * static_cast<std::size_t>(n));
        for (std::int64_t i = 0; i < n; ++i) output += s;
        return Value::string(output);
    }
    if (rx::eqLit(selector, "SUBSTR") && (args.size() == 1 || args.size() == 2)) {
        auto start = integer(args[0]);
        if (start < 1) throw std::runtime_error("SUBSTR position must be positive");
        std::size_t offset = static_cast<std::uint64_t>(start) > s.size()
            ? s.size() : static_cast<std::size_t>(start - 1);
        if (args.size() == 1) return Value::string(s.substr(offset));
        auto count = integer(args[1]);
        if (count < 0) throw std::runtime_error("SUBSTR length must be nonnegative");
        // Basic in-range subset only; pad semantics are a future rule.
        if (static_cast<std::uint64_t>(count) > s.size() - offset)
            throw std::runtime_error("SUBSTR padding semantics not implemented");
        return Value::string(s.substr(offset, static_cast<std::size_t>(count)));
    }
    // String methods the native subset lacks: the BIF of the same name (when linked), then the hosted interpreter's
    // own String class (when linked). Each returns nullopt when it does not handle the message.
    if (stringBifExtension())
        if (auto r = stringBifExtension()(receiver, selector, args)) return std::move(*r);
    if (stringHostExtension())
        if (auto r = stringHostExtension()(receiver, selector, args)) return std::move(*r);
    throw std::runtime_error("unsupported string message: " + selector);
}
inline Value messageValue(const Value &receiver, const std::string &selector,
                          const std::vector<Value> &args, bool cascade) {
    MessageResult outcome = sendMessage(receiver, selector, args);
    if (cascade) return receiver;
    if (!outcome) {
        // Error 91.999 (Error_No_result_object_message), as the interpreter reports a message used for its value
        SyntaxCondition e("91.999", "Message \"" + selector + "\" did not return a result", false);
        e.substitutions.push_back(Value::string(selector));
        throw e;
    }
    return std::move(*outcome);
}
// receiver[index] (one index): the object's own answer when it has one (ObjectDispatch::indexAt), else the message.
inline Value indexValue(const Value &receiver, const Value &index) {
    const Value *slot = nullptr;
    if (receiver.isObject() && receiver.object->indexAt(index, slot)) return slot ? *slot : nil();
    static const std::string selector("[]");
    std::vector<Value> args;
    args.push_back(index);
    return messageValue(receiver, selector, args, false);
}
// receiver[index] = value (one index): []=(value, index), the same way.
inline void indexAssign(const Value &receiver, Value value, const Value &index) {
    if (receiver.isObject() && receiver.object->indexPut(value, index)) return;
    static const std::string selector("[]=");
    std::vector<Value> args;
    args.reserve(2);
    args.push_back(std::move(value));
    args.push_back(index);
    (void)sendMessage(receiver, selector, args);
}
inline void messageInstruction(Variables &vars, const Value &receiver,
                               const std::string &selector, const std::vector<Value> &args,
                               bool cascade) {
    const MessageResult outcome = sendMessage(receiver, selector, args);
    if (cascade) { set(vars, "RESULT", receiver); return; }
    if (outcome) set(vars, "RESULT", *outcome);
    else drop(vars, "RESULT");
}
// Constrained native Rexx BIF adaptor.  This is deliberately not std::abs:
// it preserves Rexx Value objects and refuses numerics outside the qualified
// signed-64-bit subset.  Decimal/NUMERIC contexts require a separate backend.
inline MessageResult callBuiltin(const std::string &name, const std::vector<Value> &args) {
    if (args.size() != 1) throw std::runtime_error("built-in argument count invalid: " + name);
    if (name == "ABS") {
        const auto n = integer(args[0]);
        if (n == std::numeric_limits<std::int64_t>::min())
            throw std::runtime_error("ABS integer overflow: decimal arithmetic not implemented");
        const std::int64_t magnitude = n < 0 ? -n : n;
        // Under the default NUMERIC DIGITS 9 context, values beyond nine
        // significant integer digits may round or be formatted in exponent
        // form.  Refuse them until a real decimal-context backend exists.
        if (magnitude > 999999999)
            throw std::runtime_error("ABS exceeds supported NUMERIC DIGITS 9 integer subset");
        return fromInteger(magnitude);
    }
    if (name == "LENGTH") {
        if (args[0].isObject())
            throw std::runtime_error("LENGTH object argument requires interpreter dispatch");
        if (args[0].bytes.size() > static_cast<std::size_t>(std::numeric_limits<std::int64_t>::max()))
            throw std::runtime_error("LENGTH outside supported range");
        return fromInteger(static_cast<std::int64_t>(args[0].bytes.size()));
    }
    throw std::runtime_error("unsupported Rexx built-in: " + name);
}
// CALL sets RESULT in the current invocation frame.  An absent return
// drops it; an actual .nil or empty-string return would NOT be absence.
inline void callInstruction(Variables &vars, const std::string &name,
                            const std::vector<Value> &args) {
    MessageResult returned = callBuiltin(name, args);
    if (returned) set(vars, "RESULT", *returned);
    else drop(vars, "RESULT");
}
// A CALL instruction updates RESULT, while an expression-level routine call
// does not. This deliberately uses the current variables pool as specified
// for internal routines without PROCEDURE.
inline void callInternalInstruction(Variables &vars, RoutineRegistry &registry,
                                    const std::string &name, const std::vector<Value> &args) {
    auto result = invokeInternal(vars, registry, name, args);
    if (result) set(vars, "RESULT", *result);
    else drop(vars, "RESULT");
}
// Expression-level BIF dispatch never changes RESULT.
inline Value builtinValue(const std::string &name, const std::vector<Value> &args) {
    MessageResult returned = callBuiltin(name, args);
    if (!returned) throw std::runtime_error("function " + name + " returned no result");
    return *returned;
}
inline bool condition(const Value &v);
/* Rexx numeric context default is DIGITS 9. No general decimal context has
   been implemented here; do not mistake wide C++ integer division for Rexx %. */
inline Value wholeDivide9(const Value &lhs, const Value &rhs) {
    const std::int64_t a = integer(lhs), b = integer(rhs);
    constexpr std::int64_t maxDefault = 999999999;
    if (a < -maxDefault || a > maxDefault || b < -maxDefault || b > maxDefault)
        throw std::runtime_error("% outside qualified default NUMERIC DIGITS 9 subset");
    if (b == 0) throw SyntaxCondition("42.3", "Arithmetic overflow; divisor must not be zero", false);
    return fromInteger(a / b);
}
inline Value logicalOr(const Value &lhs, const Value &rhs) {
    // Evaluate and validate BOTH operands, even if the left operand is true.
    const bool left = condition(lhs);
    const bool right = condition(rhs);
    return fromInteger(left || right ? 1 : 0);
}
// Operator dispatch on the selector bytes (switch on the first character), no string temporaries.
// ooRexx REQUEST('STRING'): an object used where a string is needed answers MAKESTRING, else its STRING method.
// RexxObject::requestString: MAKESTRING when the object has it; otherwise STRING, and the NOSTRING condition is raised
// in the running activation (trapped there, or ignored: noStringHook).
inline void (*&noStringHook())(const Value &text, const Value &object) { static void (*hook)(const Value &, const Value &) = nullptr; return hook; }
inline Value requestString(const Value &v) {
    if (!v.isObject()) return v;
    MessageResult r;
    bool viaString = v.object->noMakeString();
    if (v.object->requestsString()) {
        r = v.object->sendMessage("REQUEST", {Value::string("STRING")});
        if (!r || (r->isObject() && r->object->isNilObject())) { r = v.object->sendMessage("STRING", {}); viaString = true; }
    }
    else if (viaString) r = v.object->sendMessage("STRING", {});
    else {
        try { r = v.object->sendMessage("MAKESTRING", {}); }
        catch (const NoMethod &) { r = v.object->sendMessage("STRING", {}); viaString = true; }
    }
    if (!r) throw std::runtime_error("object has no string value");
    Value text = r->isObject() ? Value::string(r->object->display()) : *r;
    if (viaString && noStringHook()) noStringHook()(text, v);
    return text;
}
inline Value sendBinaryOp(const Value &lhs, const char *sel, std::size_t n, const Value &rhs,
                          const ActivationNumeric &numeric) {
    // (the receiver held while its method runs: an operand may be a variable's value read in place, and the method
    // could assign that variable)
    if (lhs.isObject()) { const std::shared_ptr<ObjectDispatch> receiver = lhs.object; return receiver->sendBinary(std::string(sel, n), rhs); }
    // A string receiver with an object argument (s = obj, s || obj, 1 + obj): the String method requests the
    // argument's string value, as the interpreter's String class does.
    // A string compared with .nil: the String (and NumberString) comparison methods answer without asking .nil for a
    // string (StringClass.cpp CompareOperator, notEqual, primitiveIsEqual): false, and true for \= <> >< \==; no
    // MAKESTRING, no NOSTRING.
    if (rhs.isObject() && rhs.object->isNilObject() && n >= 1 && n <= 3) {
        const std::string op(sel, n);
        if (op == "\\=" || op == "<>" || op == "><" || op == "\\==") return Value::string("1");
        if (op == "=" || op == "==" || op == ">" || op == "<" || op == ">=" || op == "<=" || op == "\\<" || op == "\\>" ||
            op == ">>" || op == "<<" || op == ">>=" || op == "<<=" || op == "\\<<" || op == "\\>>")
            return Value::string("0");
    }
    if (rhs.isObject()) { const Value argument = rhs; return sendBinaryOp(lhs, sel, n, requestString(argument), numeric); }
    const char c0 = n ? sel[0] : '\0', c1 = n > 1 ? sel[1] : '\0';
    switch (c0) {
    case ' ':
        if (n == 1) {
            // Blank concatenation: exactly one blank between the operands.
            if (rhs.isObject()) throw std::runtime_error("object operand in blank concatenation is not implemented");
            std::string out; out.reserve(lhs.bytes.size() + 1 + rhs.bytes.size());
            out += lhs.bytes; out += ' '; out += rhs.bytes;
            return Value(std::move(out));
        }
        break;
    case '|':
        if (n == 1) return logicalOr(lhs, rhs);
        if (n == 2 && c1 == '|') {
            // Rexx concatenation joins the exact character strings, with no numeric normalisation.
            if (rhs.isObject()) throw std::runtime_error("object operand in || is not implemented");
            std::string out; out.reserve(lhs.bytes.size() + rhs.bytes.size());
            out += lhs.bytes; out += rhs.bytes;
            return Value(std::move(out));
        }
        break;
    case '&':
        if (n == 1 || (n == 2 && c1 == '&')) {
            // Both operands were already evaluated (Rexx never short-circuits) and must be exactly 0 or 1.
            if (rhs.isObject()) throw std::runtime_error("object operand in logical operator is not implemented");
            const bool l = condition(lhs), r = condition(rhs);
            return Value::string((n == 1 ? (l && r) : (l != r)) ? "1" : "0");
        }
        break;
    case '+': if (n == 1) return numericAdd(lhs, rhs, numeric); break;
    case '-': if (n == 1) return numericSub(lhs, rhs, numeric); break;
    case '*':
        if (n == 1) return numericMul(lhs, rhs, numeric);
        if (n == 2 && c1 == '*') return numericPower(lhs, rhs, numeric);
        break;
    case '/':
        if (n == 1) return numericDiv(lhs, rhs, numeric);
        if (n == 2 && c1 == '/') return numericRemainder(lhs, rhs, numeric);
        break;
    case '%': if (n == 1) return numericWholeDivide(lhs, rhs, numeric); break;
    default: {
        const CmpOp op = cmpOpOf(sel, n);
        if (op != CmpOp::None) return numericCompare(lhs, op, rhs, numeric);
    }
    }
    throw std::runtime_error("unknown binary operator message: " + std::string(sel, n));
}
inline Value sendBinary(const Value &lhs, const std::string &selector, const Value &rhs,
                        const ActivationNumeric &numeric) {
    return sendBinaryOp(lhs, selector.data(), selector.size(), rhs, numeric);
}
inline Value sendBinary(const Value &lhs, const char *selector, const Value &rhs, const ActivationNumeric &numeric) {
    return sendBinaryOp(lhs, selector, std::strlen(selector), rhs, numeric);
}
inline Value sendBinary(const Value &lhs, const std::string &selector, const Value &rhs) {
    return sendBinary(lhs, selector, rhs, currentNumeric ? *currentNumeric : ActivationNumeric{});
}
inline Value sendUnary(const std::string &selector, const Value &operand, const ActivationNumeric &numeric) {
    if (operand.isObject()) return operand.object->sendUnary(selector);
    // + / - of a short plain number of at most DIGITS digits: nothing to round, so the result is the operand's numeric
    // form (sign changed), fixed notation when formatRexxDecimal would write it so
    if ((rx::eqLit(selector, "-") || rx::eqLit(selector, "+")) && numeric.digits <= 18 && numeric.digits >= 1) {
        std::int64_t c; int e;
        if (smallDecimal(operand, c, e)) {
            const int nd = digitCount(static_cast<unsigned __int128>(c < 0 ? -c : c));
            if (nd <= static_cast<int>(numeric.digits) &&
                (c == 0 || (nd - 1 + e < static_cast<int>(numeric.digits) && -e <= 2 * static_cast<int>(numeric.digits))))
                return pendingNumber(rx::eqLit(selector, "-") ? -c : c, e);
        }
    }
    if (rx::eqLit(selector, "+")) {
        const RexxDecimal d = parseRexxDecimal(operand);
        checkLostDigits(d, operand, numeric);
        return numberResult(d, numeric);
    }
    if (rx::eqLit(selector, "-")) {
        RexxDecimal result = parseRexxDecimal(operand);
        checkLostDigits(result, operand, numeric);
        result.coefficient = -result.coefficient;
        return numberResult(result, numeric);
    }
    if (rx::eqLit(selector, "\\")) return truthValue(!condition(operand));
    throw std::runtime_error("unknown unary operator message: " + selector);
}
inline Value sendUnary(const std::string &selector, const Value &operand) {
    return sendUnary(selector, operand, currentNumeric ? *currentNumeric : ActivationNumeric{});
}
// Where a logical value is required (RexxObject::truthValue's error code): 34.1 IF, 34.2 WHEN, 34.3 WHILE, 34.4 UNTIL,
// 34.6 an element of a logical list, 34.901 a logical operator or method (& | && \), 34.905 a SELECT CASE comparison.
enum class Truth { If, When, While, Until, List, Method, Case, Guard };
[[noreturn]] inline void badLogicalValue(const Value &v, Truth where) {
    static const char *const codes[] = {"34.1", "34.2", "34.3", "34.4", "34.6", "34.901", "34.905", "34.902"};
    static const char *const lead[] = {"Value of expression following IF keyword", "Value of expression following WHEN keyword",
                                       "Value of expression following WHILE keyword", "Value of expression following UNTIL keyword",
                                       "Value of logical list expression element", "Logical value", "SELECT CASE comparison result",
                                       "Value of expression following GUARD keyword"};
    const int k = static_cast<int>(where);
    const std::string found = v.isObject() ? v.object->display() : v.bytes.str();
    SyntaxCondition e(codes[k], std::string(lead[k]) + " must be exactly \"0\" or \"1\"; found \"" + found + "\"", false);
    e.substitutions.push_back(v);
    throw e;
}
inline bool condition(const Value &v, Truth where) {
    // Rexx logical conditions must be exactly 0 or 1, not generic C++ truthiness.
    // an object: its string value (RexxInternalObject::truthValue: requestString, NOSTRING when only STRING gives one)
    if (v.isObject()) {
        const Value s = requestString(v);
        if (s.isObject()) badLogicalValue(s, where);
        return condition(s, where);
    }
    // a number made by arithmetic or a comparison: its characters are exactly its digits
    { const std::uint32_t m = v.bytes.numCache().meta.load(std::memory_order_acquire);
      if ((m & NumCache::pending) && (m & NumCache::integer)) {
          const std::int64_t c = v.bytes.numCache().coef.load(std::memory_order_relaxed);
          if (c == 0) return false;
          if (c == 1) return true;
      } }
    // ooRexx accepts exactly "0" or "1": padded (" 1 "), zero-led ("01") and empty values are errors, so no trimming.
    if (v.bytes == "0") return false;
    if (v.bytes == "1") return true;
    badLogicalValue(v, where);
}
inline bool condition(const Value &v) { return condition(v, Truth::Method); }
// rx::condition(stemGet1(...), where) without copying the element
template <typename T>
inline bool stemCondition1(const Value *stemVar, const Variables &vars, const char *stem, const T &tail, Truth where) {
    if (stemVar && stemVar->isObject())
        if (StemObject *so = stemVar->object->asStem()) {
            std::size_t i = 0;
            bool r = false;
            if (!so->remote && denseTailValue(tail, i) && so->withIndex(i, [&](const Value &v) { r = condition(v, where); })) return r;
        }
    return condition(stemGet1(stemVar, vars, stem, tail), where);
}
// v.bytes == "1" (a loop's TO / FOR test), without writing the characters of a number made by a comparison.
inline bool isOne(const Value &v) {
    const std::uint32_t m = v.bytes.numCache().meta.load(std::memory_order_acquire);
    if ((m & NumCache::pending) && (m & NumCache::integer)) return v.bytes.numCache().coef.load(std::memory_order_relaxed) == 1;
    return v.bytes == "1";
}
// Operators whose selector is known when the program is compiled (OperatorRules, StmtDo). Two plain whole numbers
// (NumCache integer: at most 9 digits, within DIGITS) are added, subtracted or multiplied as machine integers and the
// result is made as its numeric form, as numericAdd / numericSub / numericMul make it; a comparison of two strings is
// made as a C++ bool. Anything else (an object operand, a decimal, a longer number) is the message sendBinaryOp sends:
// the operand's own method for an object, the String class's otherwise.
namespace fastop {
__attribute__((always_inline)) inline bool wholeNumbers(const Value &a, const Value &b, const ActivationNumeric &n,
                                                        std::int64_t &p, std::int64_t &q) {
    if (a.isObject() || b.isObject() || n.digits < 9) return false;
    if (!(numMeta(a) & numMeta(b) & kNumInteger)) return false;
    p = a.bytes.numCache().coef.load(std::memory_order_relaxed);
    q = b.bytes.numCache().coef.load(std::memory_order_relaxed);
    return true;
}
}  // namespace fastop
inline Value opAdd(const Value &a, const Value &b, const ActivationNumeric &n) {
    std::int64_t p, q;
    if (fastop::wholeNumbers(a, b, n, p, q)) { const std::int64_t r = p + q; if (n.digits >= 10 || fitsDigits(r, n)) return intResult(r); }
    return sendBinaryOp(a, "+", 1, b, n);
}
inline Value opSub(const Value &a, const Value &b, const ActivationNumeric &n) {
    std::int64_t p, q;
    if (fastop::wholeNumbers(a, b, n, p, q)) { const std::int64_t r = p - q; if (n.digits >= 10 || fitsDigits(r, n)) return intResult(r); }
    return sendBinaryOp(a, "-", 1, b, n);
}
inline Value opMul(const Value &a, const Value &b, const ActivationNumeric &n) {
    std::int64_t p, q;
    if (fastop::wholeNumbers(a, b, n, p, q)) { const std::int64_t r = p * q; if (n.digits >= 18 || fitsDigits(r, n)) return intResult(r); }
    return sendBinaryOp(a, "*", 1, b, n);
}
inline Value opIntDiv(const Value &a, const Value &b, const ActivationNumeric &n) {
    std::int64_t p, q;
    if (fastop::wholeNumbers(a, b, n, p, q) && q != 0) return intResult(p / q);   // (numericWholeDivide's whole-number path)
    if (!a.isObject() && !b.isObject()) return numericWholeDivide(a, b, n);
    return sendBinaryOp(a, "%", 1, b, n);
}
inline Value opRem(const Value &a, const Value &b, const ActivationNumeric &n) {
    std::int64_t p, q;
    if (fastop::wholeNumbers(a, b, n, p, q) && q != 0) return intResult(p % q);   // (numericRemainder's whole-number path)
    if (!a.isObject() && !b.isObject()) return numericRemainder(a, b, n);
    return sendBinaryOp(a, "//", 2, b, n);
}
inline Value opDiv(const Value &a, const Value &b, const ActivationNumeric &n) {
    if (!a.isObject() && !b.isObject()) return numericDiv(a, b, n);
    return sendBinaryOp(a, "/", 1, b, n);
}
// a comparison as a value ("1" / "0"); sel is the selector as written (an object's method is looked up by it)
inline Value opCmp(const Value &a, CmpOp op, const char *sel, const Value &b, const ActivationNumeric &n) {
    if (!a.isObject() && !b.isObject()) return truthValue(compareStrings(a, op, b, n));
    return sendBinaryOp(a, sel, std::strlen(sel), b, n);
}
// a comparison that is a whole IF / WHEN / WHILE / UNTIL condition: rx::condition(opCmp(...), where) without the value
inline bool cmpTest(const Value &a, CmpOp op, const char *sel, const Value &b, const ActivationNumeric &n, Truth where) {
    if (!a.isObject() && !b.isObject()) return compareStrings(a, op, b, n);
    return condition(sendBinaryOp(a, sel, std::strlen(sel), b, n), where);
}
// a controlled loop's TO test: rx::isOne(sendBinary(control, ">" or "<", limit))
inline bool loopPast(const Value &control, bool down, const Value &limit, const ActivationNumeric &n) {
    if (!control.isObject() && !limit.isObject()) {
        std::int64_t p, q;
        if (fastop::wholeNumbers(control, limit, n, p, q) && n.fuzz == 0) return down ? p < q : p > q;
        return compareStrings(control, down ? CmpOp::Lt : CmpOp::Gt, limit, n);
    }
    return isOne(sendBinaryOp(control, down ? "<" : ">", 1, limit, n));
}
// A controlled loop run on a machine integer (StmtDo): when the start, BY and TO values are plain whole numbers (and
// DIGITS is at least 9) the loop keeps its control value as n, writes it to the variable as a number made by arithmetic
// (the characters only when read), and tests n against TO. Every pass first checks that the variable still holds n
// (loopHolds: nothing assigned it, or assigned a string with the same numeric form, which + and the TO test treat
// alike); otherwise, or when the next value leaves the plain whole-number range or NUMERIC changes, the loop goes on
// with the message path (opAdd / loopPast) from the variable's value, for good.
inline bool loopInts(const Value &start, const Value &by, const Value *to, const ActivationNumeric &n,
                     std::int64_t &cur, std::int64_t &step, std::int64_t &limit) {
    if (n.digits < 9 || start.isObject() || by.isObject() || (to && to->isObject())) return false;
    if (!(numMeta(start) & numMeta(by) & kNumInteger)) return false;
    if (to && !(numMeta(*to) & kNumInteger)) return false;
    cur = start.bytes.numCache().coef.load(std::memory_order_relaxed);
    step = by.bytes.numCache().coef.load(std::memory_order_relaxed);
    limit = to ? to->bytes.numCache().coef.load(std::memory_order_relaxed) : 0;
    return true;
}
inline Value *loopHolds(const Value &v, std::int64_t cur) {
    if (v.isObject()) return nullptr;
    const NumCache &c = v.bytes.numCache();
    if (!(c.meta.load(std::memory_order_acquire) & kNumInteger) || c.coef.load(std::memory_order_relaxed) != cur) return nullptr;
    return const_cast<Value *>(&v);
}
// the next control value, when it is still a plain whole number under DIGITS >= 9
inline bool loopStep(std::int64_t &cur, std::int64_t step, const ActivationNumeric &n) {
    const std::int64_t next = cur + step;
    if (n.digits < 9 || next > 999999999 || next < -999999999) return false;
    cur = next;
    return true;
}
__attribute__((always_inline)) inline void loopStore(Value &v, std::int64_t cur) {
    v.bytes.setPendingNumber(cur, kNumKnown | kNumDecimal | kNumInteger | (128u << 8));
}
// Native registers (rules/RxNative.cls). A simple variable read and written by whole-number arithmetic is kept as a
// machine integer in the activation's slot table (nr[k], valid while nk[k]) as well as in its variable: every native
// write also writes the variable (as a number made by arithmetic), so anything else that reads it (a BIF, SAY, a
// called routine, INTERPRET, a condition handler) reads the variable as before. Anything that may write a variable
// without the register knowing clears the register: a generic assignment its own, and a call, a message, any other
// instruction, a label (SIGNAL / an internal routine entered) or a CALL ON handler all of them; the next native read
// loads it again from the variable. A native expression is only whole numbers (at most 9 digits, as NumCache integer)
// under DIGITS >= 9 and FUZZ 0, with + - * % // and exact /, unary - +, the non-strict comparisons, and & | && \ of
// comparison results: any operand or result outside that sets ok false and the statement runs as before.
inline bool nOn(const ActivationNumeric &n) { return n.digits >= 9 && n.fuzz == 0; }
__attribute__((noinline)) inline std::int64_t nLoad(const Value *p, std::uint8_t &valid, std::int64_t &reg, bool &ok) {
    std::uint32_t m;
    if (p && !p->isObject() && ((m = numMeta(*p)) & kNumInteger)) {
        reg = p->bytes.numCache().coef.load(std::memory_order_relaxed);
        valid = (m & NumCache::canonical) ? 2 : 1;
        return reg;
    }
    ok = false;
    return 0;
}
template <std::size_t K> __attribute__((always_inline)) inline std::int64_t nGet(LocalSlots<K> &L, std::size_t k, const Variables &vars,
                                                                                 const char *name, bool &ok) {
    if (L.nk[k]) return L.nr[k];
    return nLoad(L.find(k, vars, name), L.nk[k], L.nr[k], ok);
}
// a variable read as the whole value of V = Y: only when Y's characters are its number's own (then writing the number
// to V gives V the same characters)
template <std::size_t K> __attribute__((always_inline)) inline std::int64_t nGetCanonical(LocalSlots<K> &L, std::size_t k, const Variables &vars,
                                                                                          const char *name, bool &ok) {
    const std::int64_t r = nGet(L, k, vars, name, ok);
    if (L.nk[k] != 2) ok = false;
    return r;
}
template <std::size_t K> __attribute__((always_inline)) inline void nSet(LocalSlots<K> &L, std::size_t k, Variables &vars, const char *name, std::int64_t r) {
    L.nr[k] = r; L.nk[k] = 2;
    if (Value *p = L.resolve(k, vars); p && !p->isObject()) { p->bytes.setPendingNumber(r, kNumKnown | kNumDecimal | kNumInteger | (128u << 8)); return; }
    L.set(k, vars, name, intResult(r));
}
template <std::size_t K> inline void nPut(LocalSlots<K> &L, std::size_t k, std::int64_t r) { L.nr[k] = r; L.nk[k] = 2; }
// X = Y (Y a simple variable): X's variable now holds Y's value, so X's register is Y's (valid or not)
template <std::size_t K> inline void nCopy(LocalSlots<K> &L, std::size_t to, std::size_t from) { L.nr[to] = L.nr[from]; L.nk[to] = L.nk[from]; }
template <std::size_t K> inline void nInv(LocalSlots<K> &L, std::size_t k) { L.nk[k] = 0; }
template <std::size_t K> inline void nInvAll(LocalSlots<K> &L) { std::memset(L.nk, 0, sizeof L.nk); }
template <std::size_t K, typename T> inline T nAfter(LocalSlots<K> &L, T v) { nInvAll(L); return v; }
// the whole-number operations (results kept within NumCache integer: at most 9 digits)
inline std::int64_t nRange(bool &ok, std::int64_t r) { if (r > 999999999 || r < -999999999) { ok = false; return 0; } return r; }
inline std::int64_t nAdd(bool &ok, std::int64_t a, std::int64_t b) { return nRange(ok, a + b); }
inline std::int64_t nSub(bool &ok, std::int64_t a, std::int64_t b) { return nRange(ok, a - b); }
inline std::int64_t nMul(bool &ok, std::int64_t a, std::int64_t b) { return nRange(ok, a * b); }
inline std::int64_t nIntDiv(bool &ok, std::int64_t a, std::int64_t b) { if (b == 0) { ok = false; return 0; } return a / b; }
inline std::int64_t nRem(bool &ok, std::int64_t a, std::int64_t b) { if (b == 0) { ok = false; return 0; } return a % b; }
inline std::int64_t nDiv(bool &ok, std::int64_t a, std::int64_t b) { if (b == 0 || a % b != 0) { ok = false; return 0; } return a / b; }
#define RX_NGETK(K, N) (::rx::nGet(_rxL, K, vars, N, _rxOk))
#define RX_NCANONK(K, N) (::rx::nGetCanonical(_rxL, K, vars, N, _rxOk))
#define RX_NSETK(K, N, R) (::rx::nSet(_rxL, K, vars, N, R))
#define RX_NPUTK(K, N, R) (::rx::nPut(_rxL, K, R))
#define RX_NHOLDSK(K, N, R) (_rxL.nk[K] != 0 && _rxL.nr[K] == (R))
#define RX_NINVK(K, N) (::rx::nInv(_rxL, K))
#define RX_NFROMK(K, N) K
#define RX_NCOPYK(K, N, FROM) (::rx::nCopy(_rxL, K, FROM))
#define RX_NINV_ALL (::rx::nInvAll(_rxL))
#define RX_NAFTER(...) (::rx::nAfter(_rxL, (__VA_ARGS__)))
inline bool within(std::int64_t current, std::int64_t limit, std::int64_t step) {
    if (step == 0) throw std::runtime_error("DO BY 0 unsupported");
    return step > 0 ? current <= limit : current >= limit;
}
// SAY output: standard output, or (in a native library) the interpreter's .OUTPUT, as Activity::sayOutput does.
inline void (*&sayHook())(const std::string &) { static void (*hook)(const std::string &) = nullptr; return hook; }
inline void say(const std::vector<Value> &items) {
    if (sayHook()) {
        std::string line;
        bool first = true;
        for (const auto &item : items) {
            if (!first) line += ' ';
            first = false;
            line += item.isObject() ? item.object->display() : item.bytes.str();
        }
        sayHook()(line);
        return;
    }
    bool first = true;
    for (const auto &item : items) {
        if (!first) std::cout << ' ';
        first = false;
        std::cout << (item.isObject() ? item.object->display() : item.bytes.str());
    }
    std::cout << '\n';
}
} // namespace rx
#endif
