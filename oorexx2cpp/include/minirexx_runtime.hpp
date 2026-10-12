#ifndef MINIREXX_RUNTIME_HPP
#define MINIREXX_RUNTIME_HPP
// Tiny standalone execution support for the intentionally restricted rx2cpp proof.
// Copyright (c) 2026. SPDX-License-Identifier: MIT
// NOT the ooRexx runtime, nor an implementation of the complete Rexx semantics.
#include <boost/multiprecision/cpp_int.hpp>
#include <algorithm>
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
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

namespace rx {
// The interpreter implements operators as messages to the LEFT operand.
// All ooRexx instances inherit .Object's comparison methods. The native
// prototype mirrors its identity-based defaults here, while keeping each
// operator an independently overridable virtual message. The prototype
// does not yet compile ::class or method declarations.
struct ObjectDispatch;
struct Value {
    std::string bytes;
    std::shared_ptr<ObjectDispatch> object;
    explicit Value(std::string v) : bytes(std::move(v)) {}
    explicit Value(std::shared_ptr<ObjectDispatch> target) : object(std::move(target)) {
        if (!object) throw std::invalid_argument("null ooRexx object");
    }
    static Value string(const std::string &s) { return Value(s); }
    static Value number(const std::string &s) { return Value(s); }
    static Value fromObject(std::shared_ptr<ObjectDispatch> target) {
        return Value(std::move(target));
    }
    bool isObject() const { return static_cast<bool>(object); }
};
// No result is different from returning .nil or any other object.
using MessageResult = std::optional<Value>;
// Thrown when an object has no such method (ooRexx error 97.1); any other failure keeps its own type.
struct NoMethod : std::runtime_error {
    using std::runtime_error::runtime_error;
};
struct ObjectDispatch {
    virtual MessageResult sendMessage(const std::string &selector,
                                      const std::vector<Value> &args) {
        if (args.size() == 1 &&
            (selector == "=" || selector == "\\=" || selector == "==" || selector == "\\==" ||
             selector == "<>" || selector == "><" || selector == "<" || selector == ">" ||
             selector == "<=" || selector == ">="))
            return sendBinary(selector, args.front());
        throw NoMethod("unhandled object message: " + selector);
    }
    virtual ~ObjectDispatch() = default;
    // .Object defines =, ==, \=, \==, <>, >< using object identity.
    // Each is a distinct overridable method, not a synthesized negation.
    // More specialised classes (e.g. .String) provide their own comparators.
    virtual Value sendBinary(const std::string &selector, const Value &rhs) {
        const bool same = rhs.isObject() && rhs.object.get() == this;
        if (selector == "=" || selector == "==") return Value::string(same ? "1" : "0");
        if (selector == "\\=" || selector == "\\==" || selector == "<>" || selector == "><")
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
struct NilObject final : ObjectDispatch {
    std::string display() const override { return "The NIL object"; }
    MessageResult sendMessage(const std::string &selector,
                              const std::vector<Value> &args) override {
        std::string canonical = selector;
        std::transform(canonical.begin(), canonical.end(), canonical.begin(),
                       [](unsigned char c) { return static_cast<char>(std::toupper(c)); });
        if (canonical == "STRING" && args.empty()) return Value::string(display());
        return ObjectDispatch::sendMessage(canonical, args);
    }
};
inline Value nil() {
    static const std::shared_ptr<ObjectDispatch> singleton = std::make_shared<NilObject>();
    return Value::fromObject(singleton);
}

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
        if (selector == "[]" && args.size() == 1) {
            const auto at = elements.find(index(args[0]));
            if (at == elements.end()) throw std::runtime_error("undefined array element is not yet supported");
            return at->second;
        }
        if (selector == "[]=" && args.size() == 2) {
            auto at = index(args[1]);
            elements.insert_or_assign(at, args[0]);
            if (at > last) last = at;
            return std::nullopt;
        }
        if (selector == "APPEND" && args.size() == 1) {
            if (last == std::numeric_limits<std::size_t>::max())
                throw std::runtime_error("array index overflow");
            elements.insert_or_assign(++last, args[0]);
            return Value::string(std::to_string(last));
        }
        if (selector == "MAKESTRING" && args.size() <= 2) {
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
        if (selector == "NEW" && args.empty())
            return Value::fromObject(std::make_shared<ArrayObject>());
        if (selector == "OF") {
            auto array = std::make_shared<ArrayObject>();
            for (const auto &arg : args) array->sendMessage("APPEND", {arg});
            return Value::fromObject(array);
        }
        throw std::runtime_error("unsupported .ARRAY class constructor");
    }
};
// LOOP value OVER .Array iterates in index order; sparse/other collections
// fail closed until their own ITERATOR semantics are implemented.
inline std::vector<Value> arrayItems(const Value &collection) {
    if (!collection.isObject()) throw std::runtime_error("LOOP OVER requires a collection object");
    auto array = std::dynamic_pointer_cast<ArrayObject>(collection.object);
    if (!array) throw std::runtime_error("LOOP OVER non-Array iterable unsupported");
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
struct ExposedNames {
    static constexpr unsigned inlineMax = 6;
    const char *lit[inlineMax]; std::size_t litLen[inlineMax]; unsigned n = 0;
    std::vector<std::string> extra;
    bool empty() const { return n == 0 && extra.empty(); }
    void add(const char *name) {
        if (n < inlineMax) { lit[n] = name; litLen[n] = std::strlen(name); ++n; } else extra.emplace_back(name);
    }
    void add(const std::string &name) { extra.push_back(name); }
    template <typename F> bool any(F &&test) const {
        for (unsigned i = 0; i < n; i++) if (test(lit[i], litLen[i])) return true;
        for (const auto &e : extra) if (test(e.c_str(), e.size())) return true;
        return false;
    }
};
struct Variables : std::unordered_map<std::string, Value> {
    ActivationNumeric numeric;
    Variables *outer = nullptr;
    ExposedNames exposed;
    Variables() = default;
    Variables(Variables &caller, std::vector<std::string> names) : numeric(caller.numeric), outer(&caller) {
        for (auto &n : names) exposed.add(n);
    }
    Variables(Variables &caller, std::initializer_list<const char *> names) : numeric(caller.numeric), outer(&caller) {
        for (const char *n : names) exposed.add(n);
    }
    bool isExposed(const std::string &name) const {
        const std::size_t len = name.size();
        const char *text = name.data();
        return exposed.any([&](const char *e, std::size_t elen) {
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
        if (selector == "NEW") {
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
    auto blank = [](unsigned char c) { return c == ' ' || c == '\t' || c == '\r' || c == '\n'; };
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
    if (s[0] == '+' || s[0] == '-') { minus = s[0] == '-'; ++i; }
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
inline Value fromInteger(std::int64_t x) { return Value::number(std::to_string(x)); }
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
inline const Value *lookup(const Variables &vars, const std::string &name) {
    const Variables &owner = variableOwner(vars, name);
    auto found = owner.find(name);
    return found == owner.end() ? nullptr : &found->second;
}
// TRACE / ADDRESS state (per thread). A compiled program has no trace output: settings that stay quiet are accepted,
// settings that would print trace lines are refused loudly instead of silently ignored.
inline std::string &traceSetting() { static thread_local std::string s = "N"; return s; }
inline std::string &addressEnvironment() { static thread_local std::string s = "sh"; return s; }
inline std::string traceSet(const Value &v) {
    const std::string old = traceSetting();
    std::string t = v.bytes;
    std::size_t i = 0;
    while (i < t.size() && (t[i] == '?' || t[i] == ' ' || (t[i] >= '0' && t[i] <= '9'))) ++i;
    if (i >= t.size()) { traceSetting() = "N"; return old; }
    const char c = static_cast<char>(std::toupper(static_cast<unsigned char>(t[i])));
    if (c != 'O' && c != 'N' && c != 'F' && c != 'E')
        throw std::runtime_error(std::string("TRACE setting '") + c + "' would produce trace output; not supported in compiled programs");
    traceSetting() = std::string(1, c);
    return old;
}
inline std::string addressSet(const Value &v) {
    const std::string old = addressEnvironment();
    addressEnvironment() = v.bytes;
    return old;
}
// SIGNAL ON NOVALUE: while a TrapState has the trap armed, reading an unset variable raises NOVALUE.
struct NoValueCondition : std::runtime_error {
    std::string variable;
    explicit NoValueCondition(std::string name) : std::runtime_error("NOVALUE: " + name), variable(std::move(name)) {}
};
inline thread_local const bool *novalueArmed = nullptr;
inline Value get(const Variables &vars, const std::string &name) {
    const Value *v = lookup(vars, name);
    if (v) return *v;
    if (novalueArmed && *novalueArmed) throw NoValueCondition(name);
    return Value::string(name);
}
inline void set(Variables &vars, const std::string &name, Value value) {
    variableOwner(vars, name).insert_or_assign(name, std::move(value));
}
inline void drop(Variables &vars, const std::string &name) {
    variableOwner(vars, name).erase(name);
}
inline void resetStem(Variables &vars, const std::string &stem) {
    auto &owner = variableOwner(vars, stem);
    for (auto it = owner.begin(); it != owner.end();) {
        if (it->first.size() > stem.size() &&
            it->first.compare(0, stem.size(), stem) == 0) it = owner.erase(it);
        else ++it;
    }
}

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
    SyntaxCondition(std::string c, const std::string &text, bool skip)
        : std::runtime_error("Error " + c + ": " + text), code(std::move(c)), skipInternalTraps(skip) {}
};
struct ProgramExit { int code; };
// The interpreter's process status for an uncaught SYNTAX error is 256 minus the error number
// (98 -> 158, 42 -> 214, 93 -> 163).  Runtime errors that carry no "Error N" prefix keep status 2.
inline int uncaughtStatus(const std::string &what) {
    if (what.compare(0, 6, "Error ") == 0) {
        const int n = std::atoi(what.c_str() + 6);
        if (n > 0 && n < 100) return (256 - n) & 255;
    }
    return 2;
}           // EXIT executed inside an internal routine
[[noreturn]] inline void raiseSyntax(const std::string &code, const std::vector<Value> &args, bool localTrap) {
    std::string text;
    for (std::size_t i = 0; i < args.size(); ++i) { if (i) text += ' '; text += args[i].bytes; }
    throw SyntaxCondition(code, text, !localTrap);
}
struct TrapState {
    bool syntaxOn = false;
    std::string syntaxLabel;
    bool novalueOn = false;
    std::string novalueLabel;
    TrapState() = default;
    TrapState(const TrapState &) = delete;
    TrapState &operator=(const TrapState &) = delete;
    ~TrapState() { if (novalueArmed == &novalueOn) novalueArmed = nullptr; }
    void on(const std::string &condition, const std::string &label) {
        if (condition == "SYNTAX") { syntaxOn = true; syntaxLabel = label; }
        if (condition == "NOVALUE") { novalueOn = true; novalueLabel = label; novalueArmed = &novalueOn; }
    }
    void off(const std::string &condition) {
        if (condition == "SYNTAX") syntaxOn = false;
        if (condition == "NOVALUE") { novalueOn = false; if (novalueArmed == &novalueOn) novalueArmed = nullptr; }
    }
    // Rexx disables the trap when it fires.
    bool take(std::string &label, const std::exception &error, bool topLevel) {
        if (dynamic_cast<const NoValueCondition *>(&error)) {
            if (!novalueOn) return false;
            novalueOn = false; if (novalueArmed == &novalueOn) novalueArmed = nullptr;
            label = novalueLabel; return true;
        }
        if (!syntaxOn) return false;
        const auto *raised = dynamic_cast<const SyntaxCondition *>(&error);
        if (raised && raised->skipInternalTraps && !topLevel) return false;
        syntaxOn = false; label = syntaxLabel; return true;
    }
};
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
    if (bv == 0.0L) throw std::runtime_error("division by zero");
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
        const std::string as = trim(a.bytes), bs = trim(b.bytes);
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
        (selector == "+" || selector == "-" || selector == "*" || selector == "/" ||
         selector == "=" || selector == "\\=" || selector == "==" || selector == "\\==" ||
         selector == "<>" || selector == "><" || selector == "<" || selector == ">" ||
         selector == "<=" || selector == ">="))
        return sendBinary(receiver, selector, args.front());
    if (selector == "COPIES" && args.size() == 1) {
        const auto repetitions = integer(args[0]);
        if (repetitions < 0 || repetitions > 1000000 ||
            (!s.empty() && static_cast<std::size_t>(repetitions) > (1 << 24) / s.size()))
            throw std::runtime_error("COPIES count exceeds native limit");
        std::string out;
        out.reserve(s.size() * static_cast<std::size_t>(repetitions));
        for (std::int64_t i = 0; i < repetitions; ++i) out += s;
        return Value::string(out);
    }
    if (selector == "LENGTH" && args.empty()) return fromInteger(static_cast<std::int64_t>(s.size()));
    if (selector == "REVERSE" && args.empty())
        return Value::string(std::string(s.rbegin(), s.rend()));
    if ((selector == "UPPER" || selector == "LOWER") && args.empty()) {
        std::string output = s;
        // Deliberately ASCII-only; locale-sensitive mappings are not yet qualified.
        for (char &ch : output) {
            unsigned char c = static_cast<unsigned char>(ch);
            if (selector == "UPPER" && c >= 'a' && c <= 'z') ch = static_cast<char>(c - 32);
            if (selector == "LOWER" && c >= 'A' && c <= 'Z') ch = static_cast<char>(c + 32);
        }
        return Value::string(output);
    }
    if (selector == "COPIES" && args.size() == 1) {
        auto n = integer(args[0]);
        if (n < 0 || (n > 0 && static_cast<std::uint64_t>(n) >
            std::numeric_limits<std::size_t>::max() / (s.empty() ? 1 : s.size())))
            throw std::runtime_error("COPIES argument outside supported range");
        std::string output;
        output.reserve(s.size() * static_cast<std::size_t>(n));
        for (std::int64_t i = 0; i < n; ++i) output += s;
        return Value::string(output);
    }
    if (selector == "SUBSTR" && (args.size() == 1 || args.size() == 2)) {
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
    throw std::runtime_error("unsupported string message: " + selector);
}
inline Value messageValue(const Value &receiver, const std::string &selector,
                          const std::vector<Value> &args, bool cascade) {
    const MessageResult outcome = sendMessage(receiver, selector, args);
    if (cascade) return receiver;
    if (!outcome) throw std::runtime_error("message " + selector + " did not return a result");
    return *outcome;
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
    if (b == 0) throw std::runtime_error("division by zero in %");
    return fromInteger(a / b);
}
inline Value logicalOr(const Value &lhs, const Value &rhs) {
    // Evaluate and validate BOTH operands, even if the left operand is true.
    const bool left = condition(lhs);
    const bool right = condition(rhs);
    return fromInteger(left || right ? 1 : 0);
}
inline Value sendBinary(const Value &lhs, const std::string &selector, const Value &rhs,
                        const ActivationNumeric &numeric) {
    if (lhs.isObject()) return lhs.object->sendBinary(selector, rhs);
    if (selector == "|") return logicalOr(lhs, rhs);
    if (selector == "&" || selector == "&&") {
        // Both operands were already evaluated (Rexx never short-circuits) and must be exactly 0 or 1.
        if (rhs.isObject()) throw std::runtime_error("object operand in logical operator is not implemented");
        const bool l = condition(lhs), r = condition(rhs);
        const bool out = selector == "&" ? (l && r) : (l != r);
        return Value::string(out ? "1" : "0");
    }
    if (selector == "||") {
        // Rexx concatenation joins the exact character strings, with no numeric normalisation.
        if (rhs.isObject()) throw std::runtime_error("object operand in || is not implemented");
        return Value::string(lhs.bytes + rhs.bytes);
    }
    if (selector == " ") {
        // Blank concatenation: exactly one blank between the operands.
        if (rhs.isObject()) throw std::runtime_error("object operand in blank concatenation is not implemented");
        return Value::string(lhs.bytes + " " + rhs.bytes);
    }
    if (selector == "+") return numericAdd(lhs, rhs, numeric);
    if (selector == "-") return numericSub(lhs, rhs, numeric);
    if (selector == "*") return numericMul(lhs, rhs, numeric);
    if (selector == "/") return numericDiv(lhs, rhs, numeric);
    if (selector == "%") return numericWholeDivide(lhs, rhs, numeric);
    if (selector == "//") return numericRemainder(lhs, rhs, numeric);
    if (selector == "**") return numericPower(lhs, rhs, numeric);
    if (selector == "=" || selector == "\\=" || selector == "==" || selector == "\\==" ||
        selector == "<>" || selector == "><" || selector == "<" || selector == "<=" ||
        selector == ">" || selector == ">=")
        return numericCompare(lhs, selector, rhs, numeric);
    throw std::runtime_error("unknown binary operator message: " + selector);
}
inline Value sendBinary(const Value &lhs, const std::string &selector, const Value &rhs) {
    return sendBinary(lhs, selector, rhs, ActivationNumeric{});
}
inline Value sendUnary(const std::string &selector, const Value &operand, const ActivationNumeric &numeric) {
    if (operand.isObject()) return operand.object->sendUnary(selector);
    if (selector == "+") return numberResult(parseRexxDecimal(operand), numeric);
    if (selector == "-") {
        RexxDecimal result = parseRexxDecimal(operand);
        result.coefficient = -result.coefficient;
        return numberResult(result, numeric);
    }
    if (selector == "\\") return Value::string(condition(operand) ? "0" : "1");
    throw std::runtime_error("unknown unary operator message: " + selector);
}
inline Value sendUnary(const std::string &selector, const Value &operand) {
    return sendUnary(selector, operand, ActivationNumeric{});
}
inline bool condition(const Value &v) {
    // Rexx logical conditions must be exactly 0 or 1, not generic C++ truthiness.
    if (v.isObject()) throw std::runtime_error("object truth conversion not implemented");
    // ooRexx accepts exactly "0" or "1": padded (" 1 "), zero-led ("01") and empty values are
    // SYNTAX 34.1 in the reference interpreter (verified with IF and with & | &&), so no trimming.
    if (v.bytes == "0") return false;
    if (v.bytes == "1") return true;
    throw std::runtime_error("logical value must be exactly 0 or 1");
}
inline bool within(std::int64_t current, std::int64_t limit, std::int64_t step) {
    if (step == 0) throw std::runtime_error("DO BY 0 unsupported");
    return step > 0 ? current <= limit : current >= limit;
}
inline void say(const std::vector<Value> &items) {
    bool first = true;
    for (const auto &item : items) {
        if (!first) std::cout << ' ';
        first = false;
        std::cout << (item.isObject() ? item.object->display() : item.bytes);
    }
    std::cout << '\n';
}
} // namespace rx
#endif
