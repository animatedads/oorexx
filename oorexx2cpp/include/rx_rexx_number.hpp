#ifndef RX_REXX_NUMBER_HPP
#define RX_REXX_NUMBER_HPP
// Decimal-number engine for the standalone rx2cpp runtime (C++17).
// This is included inside namespace rx, after Value and ActivationNumeric.
// Exact decimal coefficient * 10^exponent; no binary floating point is used
// for Rexx arithmetic or numeric comparison.
using ::boost::multiprecision::cpp_int;

struct RexxDecimal {
    cpp_int coefficient = 0; // signed; trailing decimal zeroes are significant
    int exponent = 0;
};
constexpr int kMaxRexxScale = 400000; // largest power of ten ever materialized (decimalPow10); exponents are not limited by it
constexpr long kMaxRexxExponent = 999999999;   // Numerics::MAX_EXPONENT (MIN_EXPONENT is its negative)
inline cpp_int decimalPow10Compute(int n) {
    cpp_int base = 10, out = 1;
    while (n != 0) {
        if (n & 1) out *= base;
        n >>= 1;
        if (n) base *= base;
    }
    return out;
}
// Powers of ten are needed constantly at large DIGITS (alignment, rounding, digit counts): cached per thread up to 4200.
inline const cpp_int &decimalPow10Ref(int n) {
    static thread_local std::deque<cpp_int> cache;   // deque: references stay valid as it grows
    if (cache.empty()) cache.emplace_back(1);
    while (static_cast<int>(cache.size()) <= n) cache.push_back(cache.back() * 10);
    return cache[static_cast<std::size_t>(n)];
}
inline cpp_int decimalPow10(int n) {
    if (n < 0 || n > kMaxRexxScale)
        throw std::runtime_error("decimal exponent exceeds supported limit");
    if (n <= 4200) return decimalPow10Ref(n);
    return decimalPow10Compute(n);
}
// Fast path: plain integers of at most 9 digits (and at most DIGITS digits) are exact in int64; a result that still fits in DIGITS
// digits needs no rounding (see fitsDigits), anything else takes the full decimal path.
inline bool fitsDigits(std::int64_t r, const ActivationNumeric &ctx) {
    if (ctx.digits >= 19) return true;
    static const std::int64_t pow10[19] = {1LL,10LL,100LL,1000LL,10000LL,100000LL,1000000LL,10000000LL,100000000LL,1000000000LL,
        10000000000LL,100000000000LL,1000000000000LL,10000000000000LL,100000000000000LL,1000000000000000LL,
        10000000000000000LL,100000000000000000LL,1000000000000000000LL};
    return (r < 0 ? -r : r) < pow10[ctx.digits];
}
// The numeric form of a string (RxStr's NumCache, read once and kept with the characters).
//   short plain decimal (smallDecimal): optional sign, digits, at most one '.', at most 20 characters, at most 18
//     significant digits; coef the digits as an integer (signed), exponent minus the digits after the '.'.
//   plain whole number (smallInteger): optional '-', digits only, at most 10 characters, at most 999999999.
constexpr std::uint32_t kNumKnown = NumCache::known, kNumDecimal = NumCache::decimal, kNumInteger = NumCache::integer;
inline std::uint32_t numClassify(const RxStr &str) {
    NumCache &cache = str.numCache();
    const std::string &t = str.str();
    std::uint32_t meta = kNumKnown;
    std::int64_t coef = 0;
    const std::size_t n = t.size();
    if (n != 0 && n <= 20) {
        std::size_t i = 0;
        bool neg = false, plus = false;
        if (t[0] == '-' || t[0] == '+') { neg = t[0] == '-'; plus = !neg; i = 1; }
        std::int64_t c = 0; int e = 0; bool dot = false, digit = false, ok = true; int nd = 0;
        for (; i < n; ++i) {
            const char ch = t[i];
            if (ch >= '0' && ch <= '9') {
                if (c || ch != '0') { if (++nd > 18) { ok = false; break; } }
                c = c * 10 + (ch - '0'); digit = true;
                if (dot) --e;
            } else if (ch == '.' && !dot) dot = true;
            else { ok = false; break; }
        }
        if (ok && digit) {
            coef = neg ? -c : c;
            meta |= kNumDecimal | (static_cast<std::uint32_t>(e + 128) << 8);
            if (!plus && !dot && n <= 10 && c <= 999999999) meta |= kNumInteger;
        }
    }
    cache.coef.store(coef, std::memory_order_relaxed);
    cache.meta.store(meta, std::memory_order_release);
    return meta;
}
inline std::uint32_t numMeta(const Value &v) {
    const std::uint32_t m = v.bytes.numCache().meta.load(std::memory_order_acquire);
    return m ? m : numClassify(v.bytes);
}
inline int numExponent(std::uint32_t meta) { return static_cast<int>((meta >> 8) & 0xff) - 128; }
// 10**n for n in 0..38, and the digit count of a 128-bit magnitude by comparison (no division per digit).
struct Pow10Table {
    unsigned __int128 v[39];
    constexpr Pow10Table() : v() { v[0] = 1; for (int i = 1; i < 39; ++i) v[i] = v[i - 1] * 10; }
};
inline constexpr Pow10Table kPow10{};
inline unsigned __int128 pow10x(int n) { return kPow10.v[n]; }
// digits of a magnitude: from its bit length (log10 2 ~ 1233/4096), corrected by one comparison
inline int digitCount(unsigned __int128 u) {
    const std::uint64_t hi = static_cast<std::uint64_t>(u >> 64), lo = static_cast<std::uint64_t>(u);
    const int bits = hi ? 128 - __builtin_clzll(hi) : 64 - __builtin_clzll(lo | 1);
    const int t = (bits * 1233) >> 12;   // floor(log10(2**bits)) <= digits - 1 + 1
    const int d = t + 1 - (u < kPow10.v[t] ? 1 : 0);
    return d > 0 ? d : 1;   // ("0" has one digit)
}
// A short plain number result, coef * 10**exp in fixed notation (the caller has checked the notation and that it has at
// most 18 digits written out): made as its numeric form, its characters only when asked for (NumCache pending). The
// characters are the ones formatRexxDecimal writes for it; their parse (numClassify) gives back this coef and exponent.
inline Value pendingNumber(std::int64_t coef, int exp) {
    if (coef == 0) exp = 0;
    std::string zeros;
    while (exp > 0) {
        if (coef > 99999999999999999LL || coef < -99999999999999999LL) { zeros.append(static_cast<std::size_t>(exp), '0'); exp = 0; break; }
        coef *= 10; --exp;
    }
    const std::uint64_t u = coef < 0 ? 0 - static_cast<std::uint64_t>(coef) : static_cast<std::uint64_t>(coef);
    const int nd = digitCount(u);
    const int len = (coef < 0 ? 1 : 0) + (exp < 0 ? std::max(nd, -exp + 1) + 1 : nd);
    if (!zeros.empty() || nd > 18 || len > 20) return Value::number(RxStr::plainNumber(coef, exp) + zeros);
    std::uint32_t meta = kNumKnown | kNumDecimal | (static_cast<std::uint32_t>(exp + 128) << 8);
    if (exp == 0 && u <= 999999999) meta |= kNumInteger;
    return Value(Value::PendingTag{}, coef, meta);
}
inline bool smallInteger(const Value &v, const ActivationNumeric &ctx, std::int64_t &out) {
    if (v.isObject() || ctx.digits < 1 || ctx.fuzz != 0) return false;   // NUMERIC FUZZ changes comparisons: full path
    if (!(numMeta(v) & kNumInteger)) return false;
    out = v.bytes.numCache().coef.load(std::memory_order_relaxed);
    return fitsDigits(out, ctx);
}
inline int decimalDigits(const cpp_int &c) {
    const cpp_int n = c < 0 ? -c : c;
    if (n.is_zero() || msb(n) < 63) {
        std::uint64_t u = static_cast<std::uint64_t>(n);
        int d = 1;
        while (u >= 10) { u /= 10; ++d; }
        return d;
    }
    // 2^m <= n < 2^(m+1): the digit count is floor(m*log10 2)+1 or one more.
    const std::size_t m = msb(n);
    int d = static_cast<int>(static_cast<double>(m) * 0.30102999566398120) + 1;
    if (d <= 4200) {
        if (n >= decimalPow10Ref(d)) ++d;
        else if (d > 1 && n < decimalPow10Ref(d - 1)) --d;
        return d;
    }
    return static_cast<int>(n.convert_to<std::string>().size());
}
// The interpreter's whitespace for numbers and non-strict comparison: blank and horizontal tab only (not LF, CR).
inline bool rexxBlank(char c) { return c == ' ' || c == '\t'; }
inline bool tryParseRexxDecimal(const Value &v, RexxDecimal &out, const char *&err) {
    if (v.isObject()) { err = "numeric operation on an object requires message dispatch"; return false; }
    // A short plain decimal: its numeric form (the same coefficient and exponent the scan below gives).
    { const std::uint32_t m = numMeta(v);
      if (m & kNumDecimal) { out.coefficient = v.bytes.numCache().coef.load(std::memory_order_relaxed); out.exponent = numExponent(m); return true; } }
    // No copies: scan the bytes between leading and trailing blanks in place.
    const std::string &src = v.bytes;
    std::size_t i = 0, n = src.size();
    while (i < n && rexxBlank(src[i])) ++i;
    while (n > i && rexxBlank(src[n - 1])) --n;
    if (i == n || n - i > 10000) { err = "invalid Rexx decimal number"; return false; }
    out.exponent = 0;
    bool minus = false, sawDigit = false, dot = false;
    if (src[i] == '+' || src[i] == '-') {
        minus = src[i] == '-'; ++i;
        while (i < n && rexxBlank(src[i])) ++i;   // blanks may follow the sign (' - 123 ')
    }
    const std::size_t digitsStart = i;
    std::size_t ndigits = 0;
    std::uint64_t small = 0;
    for (; i < n; ++i) {
        const char c = src[i];
        if (c >= '0' && c <= '9') {
            if (ndigits < 18) small = small * 10 + static_cast<std::uint64_t>(c - '0');
            ++ndigits; sawDigit = true;
            if (dot) --out.exponent;
        } else if (c == '.' && !dot) dot = true;
        else break;
    }
    const std::size_t digitsEnd = i;
    if (!sawDigit) { err = "invalid Rexx decimal number"; return false; }
    if (i < n) {
        if (src[i] != 'E' && src[i] != 'e') { err = "invalid Rexx decimal number"; return false; }
        ++i;
        bool eneg = false;
        if (i < n && (src[i] == '+' || src[i] == '-')) { eneg = src[i] == '-'; ++i; }
        if (i == n || src[i] < '0' || src[i] > '9')
            { err = "invalid Rexx decimal exponent"; return false; }
        long e = 0;
        bool invalidExponent = false;   // more than 9 nines (addExponentDigit)
        for (; i < n; ++i) {
            if (src[i] < '0' || src[i] > '9')
                { err = "invalid Rexx decimal exponent"; return false; }
            if (!invalidExponent) {
                const long next = e * 10 + (src[i] - '0');
                if (next > kMaxRexxExponent) invalidExponent = true; else e = next;
            }
        }
        // NumberStringBuilder::finish: all zeros is exactly zero, whatever the exponent
        bool nonZero = false;
        for (std::size_t k = digitsStart; k < digitsEnd && !nonZero; ++k) nonZero = src[k] >= '1' && src[k] <= '9';
        if (!nonZero) { out.coefficient = 0; out.exponent = 0; return true; }
        if (invalidExponent) { err = "invalid Rexx decimal exponent"; return false; }
        const long exponent = (eneg ? -e : e) + out.exponent;   // out.exponent holds -decimals here
        // significant digits: leading zeros do not count
        long significant = 0; bool lead = true;
        for (std::size_t k = digitsStart; k < digitsEnd; ++k) {
            if (src[k] == '.') continue;
            if (lead && src[k] == '0') continue;
            lead = false; ++significant;
        }
        if (std::labs(exponent) > kMaxRexxExponent || exponent + significant - 1 > kMaxRexxExponent)
            { err = "invalid Rexx decimal exponent"; return false; }
        out.exponent = static_cast<int>(exponent);
    }
    if (ndigits <= 18) out.coefficient = small;
    else {
        // Eighteen digits at a time: one big multiply-add per chunk instead of one per digit.
        out.coefficient = 0;
        std::uint64_t chunk = 0; int inChunk = 0;
        for (std::size_t k = digitsStart; k < digitsEnd; ++k) {
            if (src[k] == '.') continue;
            chunk = chunk * 10 + static_cast<std::uint64_t>(src[k] - '0');
            if (++inChunk == 18) { out.coefficient *= decimalPow10Ref(18); out.coefficient += chunk; chunk = 0; inChunk = 0; }
        }
        if (inChunk) { out.coefficient *= decimalPow10Ref(inChunk); out.coefficient += chunk; }
    }
    if (minus) out.coefficient = -out.coefficient;
    return true;
}
// NumberString::checkLostDigits / prepareOperatorNumber: an operand with more significant digits than DIGITS raises
// LOSTDIGITS when the activation traps it (otherwise the condition is ignored and the operand is truncated as usual).
inline void checkLostDigits(const RexxDecimal &d, const Value &operand, const ActivationNumeric &ctx);
inline RexxDecimal parseRexxDecimal(const Value &v) {
    RexxDecimal out; const char *err = nullptr;
    if (!tryParseRexxDecimal(v, out, err)) {
        if (v.isObject()) throw std::runtime_error(err);
        // As the interpreter: Error 41.1 Nonnumeric value ("v") used in arithmetic operation.
        SyntaxCondition bad("41.1", "Nonnumeric value (\"" + v.bytes.str() + "\") used in arithmetic operation", false);
        bad.substitutions.push_back(v);
        throw bad;
    }
    return out;
}
// Error 42.3 Arithmetic overflow; divisor must not be zero.
[[noreturn]] inline void divisionByZero() {
    throw SyntaxCondition("42.3", "Arithmetic overflow; divisor must not be zero", false);
}
// NumberStringBase::checkOverflow: an arithmetic result whose adjusted exponent passes MAX_EXPONENT, or whose exponent is
// below MIN_EXPONENT, is Error 42.901 / 42.902.
inline void checkExponentOverflow(const RexxDecimal &v) {
    if (v.coefficient == 0) return;
    const long adjusted = static_cast<long>(v.exponent) + decimalDigits(v.coefficient) - 1;
    if (adjusted > kMaxRexxExponent) {
        SyntaxCondition e("42.901", "Arithmetic overflow; exponent (\"" + std::to_string(adjusted) + "\") exceeds 9 digits", false);
        e.substitutions = {Value::string(std::to_string(adjusted)), Value::string("9")};
        throw e;
    }
    if (v.exponent < -kMaxRexxExponent) {
        SyntaxCondition e("42.902", "Arithmetic underflow; exponent (\"" + std::to_string(v.exponent) + "\") exceeds 9 digits", false);
        e.substitutions = {Value::string(std::to_string(v.exponent)), Value::string("9")};
        throw e;
    }
}
inline void roundRexx(RexxDecimal &v, const ActivationNumeric &context) {
    if (context.digits < 1 || context.digits > 100000 || context.fuzz >= context.digits)
        throw std::runtime_error("unsupported NUMERIC context");
    if (v.coefficient == 0) return;
    const int len = decimalDigits(v.coefficient);
    if (len <= static_cast<int>(context.digits)) return;
    const int discard = len - static_cast<int>(context.digits);
    const cpp_int p = decimalPow10(discard);
    const bool negative = v.coefficient < 0;
    cpp_int n = negative ? -v.coefficient : v.coefficient;
    cpp_int q = n / p;
    const cpp_int rem = n % p;
    if (rem * 2 >= p) ++q; // ooRexx round-half-up, away from zero
    if (negative) q = -q;
    v.coefficient = q;
    v.exponent += discard;
    // Carry out: keep the requested significant zeroes in the result.
    if (decimalDigits(v.coefficient) > static_cast<int>(context.digits)) {
        v.coefficient /= 10;
        ++v.exponent;
    }
}
inline std::string formatRexxDecimal(const RexxDecimal &value, const ActivationNumeric &ctx, bool division = false, bool upstreamRule = false) {
    if (value.coefficient == 0) return "0";
    const bool negative = value.coefficient < 0;
    std::string digits = (negative ? -value.coefficient : value.coefficient).convert_to<std::string>();
    const int adjusted = static_cast<int>(digits.size()) - 1 + value.exponent;
    const int fixedLower = -2 * static_cast<int>(ctx.digits);
    // upstream NumberString::stringValue: exponential when adjusted >= DIGITS or |exponent| > 2*DIGITS.
    // Division keeps its own historical rule; every other result (+ - * ** //) follows upstream.
    bool exponential = (upstreamRule || !division) ? (adjusted >= static_cast<int>(ctx.digits) ||
                                       std::abs(value.exponent) > 2 * static_cast<int>(ctx.digits))
                                    : (adjusted >= static_cast<int>(ctx.digits) ||
                       adjusted < (division ? -static_cast<int>(ctx.digits) - 1 : fixedLower));
    std::string result;
    if (exponential) {
        int suffix = adjusted;
        if (ctx.engineering) {
            // floor division into groups of three, even for negative exponents
            suffix = adjusted >= 0 ? (adjusted / 3) * 3 : -(((-adjusted + 2) / 3) * 3);
        }
        if (std::labs(static_cast<long>(suffix)) > kMaxRexxExponent) {   // stringValue: the adjusted exponent cannot be shown
            SyntaxCondition e(suffix > 0 ? "42.901" : "42.902", std::string(suffix > 0 ? "Arithmetic overflow" : "Arithmetic underflow") +
                              "; exponent (\"" + std::to_string(suffix) + "\") exceeds 9 digits", false);
            e.substitutions = {Value::string(std::to_string(suffix)), Value::string("9")};
            throw e;
        }
        int before = adjusted - suffix + 1;
        if (static_cast<int>(digits.size()) < before)
            digits.append(static_cast<std::size_t>(before - digits.size()), '0');
        result = digits.substr(0, static_cast<std::size_t>(before));
        if (static_cast<int>(digits.size()) > before) result += "." + digits.substr(static_cast<std::size_t>(before));
        result += "E" + std::string(suffix >= 0 ? "+" : "-") + std::to_string(std::abs(suffix));
    } else {
        const int point = static_cast<int>(digits.size()) + value.exponent;
        if (point <= 0) result = "0." + std::string(static_cast<std::size_t>(-point), '0') + digits;
        else if (point >= static_cast<int>(digits.size()))
            result = digits + std::string(static_cast<std::size_t>(point - digits.size()), '0');
        else result = digits.substr(0, static_cast<std::size_t>(point)) + "." + digits.substr(static_cast<std::size_t>(point));
    }
    return (negative ? "-" : "") + result;
}
// Plain short decimals (sign, digits, at most one '.', no blanks or exponent, at most 18 digits): parsed without cpp_int.
// Used only where the result is exact within DIGITS, so no rounding rule is involved.
inline bool smallDecimal(const Value &v, std::int64_t &coef, int &exp) {
    if (v.isObject()) return false;
    const std::uint32_t m = numMeta(v);
    if (!(m & kNumDecimal)) return false;
    coef = v.bytes.numCache().coef.load(std::memory_order_relaxed); exp = numExponent(m);
    return true;
}
inline int smallDigits(unsigned __int128 v) { return digitCount(v); }   // (by comparison: no 128-bit division per digit)
// Exact fixed-notation result (exponent in [-2*DIGITS, 0], significant digits within DIGITS), else nullopt.
inline std::optional<Value> smallDecimalResult(__int128 c, int e, const ActivationNumeric &ctx) {
    if (c == 0) return pendingNumber(0, 0);
    const bool neg = c < 0;
    unsigned __int128 u = neg ? static_cast<unsigned __int128>(-c) : static_cast<unsigned __int128>(c);
    if (e > 0 || e < -2 * static_cast<int>(ctx.digits) || digitCount(u) > static_cast<int>(ctx.digits)) return std::nullopt;
    return pendingNumber(static_cast<std::int64_t>(c), e);   // (digits <= 18: fits)
}
inline std::optional<Value> smallDecimalAdd(const Value &a, const Value &b, bool subtract, const ActivationNumeric &ctx) {
    if (ctx.digits > 18 || ctx.digits < 1) return std::nullopt;
    std::int64_t x, y; int ex, ey;
    if (!smallDecimal(a, x, ex) || !smallDecimal(b, y, ey) || x == 0 || y == 0) return std::nullopt;
    if (smallDigits(static_cast<unsigned __int128>(x < 0 ? -x : x)) > static_cast<int>(ctx.digits) ||
        smallDigits(static_cast<unsigned __int128>(y < 0 ? -y : y)) > static_cast<int>(ctx.digits)) return std::nullopt;
    const int e = std::min(ex, ey);
    if (ex - e > 18 || ey - e > 18) return std::nullopt;
    // ooRexx keeps DIGITS places counted from the larger operand's leading digit: exact only if no place is lost.
    const int xd = ex + smallDigits(static_cast<unsigned __int128>(x < 0 ? -x : x)) - 1;
    const int yd = ey + smallDigits(static_cast<unsigned __int128>(y < 0 ? -y : y)) - 1;
    if (e < std::max(xd, yd) - static_cast<int>(ctx.digits) + 1) return std::nullopt;
    static const std::int64_t p10[19] = {1LL,10LL,100LL,1000LL,10000LL,100000LL,1000000LL,10000000LL,100000000LL,1000000000LL,
        10000000000LL,100000000000LL,1000000000000LL,10000000000000LL,100000000000000LL,1000000000000000LL,
        10000000000000000LL,100000000000000000LL,1000000000000000000LL};
    const __int128 sx = static_cast<__int128>(x) * p10[ex - e], sy = static_cast<__int128>(y) * p10[ey - e];
    return smallDecimalResult(subtract ? sx - sy : sx + sy, e, ctx);
}
inline std::optional<Value> smallDecimalMul(const Value &a, const Value &b, const ActivationNumeric &ctx) {
    if (ctx.digits > 18 || ctx.digits < 1) return std::nullopt;
    std::int64_t x, y; int ex, ey;
    if (!smallDecimal(a, x, ex) || !smallDecimal(b, y, ey)) return std::nullopt;
    if (smallDigits(static_cast<unsigned __int128>(x < 0 ? -x : x)) > static_cast<int>(ctx.digits) ||
        smallDigits(static_cast<unsigned __int128>(y < 0 ? -y : y)) > static_cast<int>(ctx.digits)) return std::nullopt;
    if (x == 0 || y == 0) return std::nullopt;
    return smallDecimalResult(static_cast<__int128>(x) * y, ex + ey, ctx);
}
// Exact relation of two short decimals when their difference is exact under DIGITS (no FUZZ); false = use the full path.
inline bool smallDecimalRelation(const Value &a, const Value &b, const ActivationNumeric &ctx, int &rel) {
    std::int64_t cx, cy; int ex, ey;
    if (ctx.fuzz != 0 || ctx.digits > 18 || !smallDecimal(a, cx, ex) || !smallDecimal(b, cy, ey)) return false;
    const int dx = smallDigits(static_cast<unsigned __int128>(cx < 0 ? -cx : cx));
    const int dy = smallDigits(static_cast<unsigned __int128>(cy < 0 ? -cy : cy));
    if (dx > static_cast<int>(ctx.digits) || dy > static_cast<int>(ctx.digits) || std::abs(ex - ey) > 18) return false;
    // Comparison is subtraction under DIGITS; exact when no place below DIGITS of the larger operand is involved.
    if (std::min(ex, ey) < std::max(ex + dx, ey + dy) - static_cast<int>(ctx.digits)) return false;
    static const std::int64_t p10[19] = {1LL,10LL,100LL,1000LL,10000LL,100000LL,1000000LL,10000000LL,100000000LL,1000000000LL,
        10000000000LL,100000000000LL,1000000000000LL,10000000000000LL,100000000000000LL,1000000000000000LL,
        10000000000000000LL,100000000000000000LL,1000000000000000000LL};
    const int e = std::min(ex, ey);
    const __int128 x = static_cast<__int128>(cx) * p10[ex - e], y = static_cast<__int128>(cy) * p10[ey - e];
    rel = (x > y) - (x < y);
    return true;
}
inline void checkLostDigits(const RexxDecimal &d, const Value &operand, const ActivationNumeric &ctx) {
    if (!lostDigitsArmed || !*lostDigitsArmed || !lostDigitsHook() || d.coefficient == 0) return;
    if (decimalDigits(d.coefficient) > static_cast<int>(ctx.digits)) lostDigitsHook()(operand);
}
inline Value numberResult(RexxDecimal n, const ActivationNumeric &ctx) {
    roundRexx(n, ctx);
    checkExponentOverflow(n);
    return Value::number(formatRexxDecimal(n, ctx));
}
// ooRexx NumberString::addSub, step for step (interpreter/classes/NumberStringMath.cpp): an operand longer than DIGITS
// keeps DIGITS+1 digits (truncated); digits beyond the DIGITS+1 window of the larger operand are dropped; the result is
// rounded to DIGITS (first dropped digit >= 5, counted before leading zeros are stripped). Digits are values 0..9.
namespace oorexx_addsub {
inline std::string digitsOf(const cpp_int &c) {
    std::string d = (c < 0 ? cpp_int(-c) : c).convert_to<std::string>();
    for (char &ch : d) ch = static_cast<char>(ch - '0');
    return d;
}
// truncateToDigits + mathRound: keep DIGITS digits, round on the first dropped one, carry out gives 1 and exponent + 1.
inline void roundTo(std::string &d, long &exp, long digits) {
    if (static_cast<long>(d.size()) <= digits) return;
    exp += static_cast<long>(d.size()) - digits;
    const bool up = d[static_cast<std::size_t>(digits)] >= 5;
    d.resize(static_cast<std::size_t>(digits));
    if (!up) return;
    long i = digits - 1;
    for (; i >= 0; --i) {
        char &c = d[static_cast<std::size_t>(i)];
        if (c == 9) c = 0; else { ++c; break; }
    }
    if (i < 0) { d[0] = 1; exp += 1; }
}
inline RexxDecimal make(const std::string &d, long exp, int sign) {
    std::size_t k = 0;
    while (k + 1 < d.size() && d[k] == 0) ++k;   // stripLeadingZeros
    cpp_int c = 0;
    for (std::size_t i = k; i < d.size(); ++i) c = c * 10 + static_cast<int>(d[i]);
    if (c == 0) return RexxDecimal{0, 0};
    RexxDecimal r{sign < 0 ? cpp_int(-c) : c, static_cast<int>(exp)};
    checkExponentOverflow(r);
    return r;
}
// subtractNumbers: larger - smaller over the digit runs ending at lp / sp; out gets the least significant digit first.
inline void subtractNumbers(const std::string &L, long lp, long adjL, const std::string &S, long sp, long adjS, std::string &out) {
    int borrow = 0;
    while (adjL-- > 0) {
        int sub = sp >= 0 ? S[static_cast<std::size_t>(sp--)] : 0;
        sub = borrow + 10 - sub;
        if (sub == 10) { sub = 0; borrow = 0; } else borrow = -1;
        out.push_back(static_cast<char>(sub));
    }
    while (adjS-- > 0) out.push_back(lp >= 0 ? L[static_cast<std::size_t>(lp--)] : 0);
    while (sp >= 0) {
        int sub = borrow + L[static_cast<std::size_t>(lp--)] - S[static_cast<std::size_t>(sp--)];
        if (sub < 0) { borrow = -1; sub += 10; } else borrow = 0;
        out.push_back(static_cast<char>(sub));
    }
    while (lp >= 0) {
        int sub = borrow + L[static_cast<std::size_t>(lp--)];
        if (sub < 0) { borrow = -1; sub += 10; } else borrow = 0;
        out.push_back(static_cast<char>(sub));
    }
}
inline RexxDecimal addSub(const RexxDecimal &a, const RexxDecimal &b, bool minus, long digits) {
    const long maxLength = digits + 1;
    const std::string ld = digitsOf(a.coefficient), rd = digitsOf(b.coefficient);
    const int leftSign = a.coefficient < 0 ? -1 : (a.coefficient == 0 ? 0 : 1);
    const int rightSign0 = b.coefficient < 0 ? -1 : (b.coefficient == 0 ? 0 : 1);
    long leftExp = a.exponent, rightExp = b.exponent;
    long leftLength = static_cast<long>(ld.size()), rightLength = static_cast<long>(rd.size());
    if (leftLength > maxLength) { leftExp += leftLength - maxLength; leftLength = maxLength; }
    if (rightLength > maxLength) { rightExp += rightLength - maxLength; rightLength = maxLength; }
    const long minExp = std::min(leftExp, rightExp);
    long adjL = leftExp - minExp, adjR = rightExp - minExp;
    // Fast exits: a copy of one (whole) operand, rounded to DIGITS (setupNumber), sign flipped for a subtrahend.
    auto copyOf = [&](const RexxDecimal &v, const std::string &d, bool negate) {
        std::string dd = d; long e = v.exponent;
        roundTo(dd, e, digits);
        int sign = v.coefficient < 0 ? -1 : 1;
        if (negate) sign = -sign;
        return make(dd, e, sign);
    };
    if (leftSign == 0) return rightSign0 == 0 ? RexxDecimal{0, 0} : copyOf(b, rd, minus);
    if (rightSign0 == 0) return copyOf(a, ld, false);
    if (adjL + leftLength > rightLength + digits) return copyOf(a, ld, false);
    if (adjR + rightLength > leftLength + digits) return copyOf(b, rd, minus);
    const int rightSign = minus ? -rightSign0 : rightSign0;
    bool plus = true;
    if (rightSign != leftSign) {
        if (leftLength == rightLength && leftExp == rightExp &&
            ld.compare(0, static_cast<std::size_t>(leftLength), rd, 0, static_cast<std::size_t>(rightLength)) == 0)
            return RexxDecimal{0, 0};
        plus = false;
    }
    long lp = leftLength - 1, rp = rightLength - 1;
    const long adjustedLeftDigits = (leftLength + adjL) - maxLength;
    const long adjustedRightDigits = (rightLength + adjR) - maxLength;
    if (adjustedLeftDigits > 0 || adjustedRightDigits > 0) {
        long adjustDigits = adjustedLeftDigits >= adjustedRightDigits ? adjustedLeftDigits : adjustedRightDigits;
        if (adjL != 0) {
            if (adjustDigits < adjL) { adjL -= adjustDigits; rp -= adjustDigits; rightExp += adjustDigits; rightLength -= adjustDigits; adjustDigits = 0; }
            else { rp -= adjL; rightExp += adjL; rightLength -= adjustDigits; adjustDigits -= adjL; adjL = 0; }
        } else if (adjR != 0) {
            if (adjustDigits < adjR) { adjR -= adjustDigits; lp -= adjustDigits; leftExp += adjustDigits; leftLength -= adjustDigits; adjustDigits = 0; }
            else { lp -= adjR; leftExp += adjR; leftLength -= adjustDigits; adjustDigits -= adjR; adjR = 0; }
        }
        if (adjustDigits) { leftExp += adjustDigits; lp -= adjustDigits; rightExp += adjustDigits; rp -= adjustDigits; }
    }
    std::string out;   // least significant digit first
    long exp = 0; int sign = 0;
    if (plus) {
        int carry = 0;
        sign = leftSign;
        if (adjL != 0) { for (long k = adjL; k-- > 0;) out.push_back(rp >= 0 ? rd[static_cast<std::size_t>(rp--)] : 0); exp = rightExp; }
        else if (adjR != 0) { for (long k = adjR; k-- > 0;) out.push_back(lp >= 0 ? ld[static_cast<std::size_t>(lp--)] : 0); exp = leftExp; }
        else exp = leftExp;
        auto put = [&](int v) { v += carry; if (v >= 10) { carry = 1; v -= 10; } else carry = 0; out.push_back(static_cast<char>(v)); };
        while (lp >= 0 && rp >= 0) put(ld[static_cast<std::size_t>(lp--)] + rd[static_cast<std::size_t>(rp--)]);
        while (lp >= 0) put(ld[static_cast<std::size_t>(lp--)]);
        while (rp >= 0) put(rd[static_cast<std::size_t>(rp--)]);
        if (carry) out.push_back(1);
    } else if (adjL + leftLength > adjR + rightLength) {
        subtractNumbers(ld, lp, adjL, rd, rp, adjR, out); exp = adjL != 0 ? rightExp : leftExp; sign = leftSign;
    } else if (adjL + leftLength < adjR + rightLength) {
        subtractNumbers(rd, rp, adjR, ld, lp, adjL, out); exp = adjL != 0 ? rightExp : leftExp; sign = rightSign;
    } else if (rightLength < leftLength) {
        if (rd.compare(0, static_cast<std::size_t>(rightLength), ld, 0, static_cast<std::size_t>(rightLength)) > 0)
            { subtractNumbers(rd, rp, adjR, ld, lp, adjL, out); sign = rightSign; }
        else { subtractNumbers(ld, lp, adjL, rd, rp, adjR, out); sign = leftSign; }
        exp = leftExp;
    } else {
        const int rc = ld.compare(0, static_cast<std::size_t>(leftLength), rd, 0, static_cast<std::size_t>(leftLength));
        if (rc > 0) { subtractNumbers(ld, lp, adjL, rd, rp, adjR, out); exp = rightExp; sign = leftSign; }
        else if (rc != 0) { subtractNumbers(rd, rp, adjR, ld, lp, adjL, out); exp = rightExp; sign = rightSign; }
        else if (leftLength < rightLength) { subtractNumbers(rd, rp, adjR, ld, lp, adjL, out); exp = rightExp; sign = rightSign; }
        else return RexxDecimal{0, 0};
    }
    std::string d(out.rbegin(), out.rend());
    roundTo(d, exp, digits);   // adjustPrecision: rounds before leading zeros are stripped
    return make(d, exp, sign);
}
}  // namespace oorexx_addsub
// Small operands (DIGITS <= 18; each operand a plain decimal of at most DIGITS significant digits, as smallDecimal reads
// it): the same algorithms as the general path (NumberString::addSub, the multiplication's rounding, roundRexx and
// formatRexxDecimal), on 128-bit integers and fixed buffers instead of cpp_int and digit strings. Anything else (an
// exponential result, a longer operand, LOSTDIGITS) goes to the general path (false).
namespace small_math {
inline int digitsOf(unsigned __int128 u, char *out) {   // most significant first, digit values 0..9; "0" for zero
    char tmp[40]; int n = 0;
    do { tmp[n++] = static_cast<char>(u % 10); u /= 10; } while (u);
    for (int i = 0; i < n; ++i) out[i] = tmp[n - 1 - i];
    return n;
}
inline unsigned __int128 pow10u(int n) { unsigned __int128 p = 1; while (n-- > 0) p *= 10; return p; }
// formatRexxDecimal (not division) for a fixed-notation result; false when it would be exponential.
inline bool format(bool negative, unsigned __int128 u, long exp, const ActivationNumeric &ctx, std::string &out) {
    if (u == 0) { out = "0"; return true; }
    char d[40]; const int n = digitsOf(u, d);
    const long adjusted = n - 1 + exp;
    if (adjusted >= static_cast<long>(ctx.digits) || std::labs(exp) > 2 * static_cast<long>(ctx.digits)) return false;
    out.clear();
    if (negative) out += '-';
    const long point = n + exp;
    if (point <= 0) { out += "0."; out.append(static_cast<std::size_t>(-point), '0'); for (int i = 0; i < n; ++i) out += static_cast<char>('0' + d[i]); }
    else if (point >= n) { for (int i = 0; i < n; ++i) out += static_cast<char>('0' + d[i]); out.append(static_cast<std::size_t>(point - n), '0'); }
    else {
        for (long i = 0; i < point; ++i) out += static_cast<char>('0' + d[i]);
        out += '.';
        for (long i = point; i < n; ++i) out += static_cast<char>('0' + d[i]);
    }
    return true;
}
// roundRexx: DIGITS significant digits, round half up on the magnitude, a carry out drops one more digit.
inline void round(unsigned __int128 &u, long &exp, long digits) {
    const int len = digitCount(u);
    if (len <= digits) return;
    const int discard = len - static_cast<int>(digits);
    const unsigned __int128 p = pow10x(discard);
    unsigned __int128 q = u / p;
    if ((u - q * p) * 2 >= p) ++q;
    exp += discard;
    if (q >= pow10x(static_cast<int>(digits))) { q /= 10; ++exp; }
    u = q;
}
// A result: coef * 10**exp, fixed notation (ok false: exponential, the general path makes it). The caller makes the
// Value (pendingNumber), so it is built once, in place.
struct Fixed { bool ok = false; std::int64_t coef = 0; int exp = 0; };
inline Fixed zero() { return Fixed{true, 0, 0}; }
// format's notation check
inline Fixed fixedResult(bool negative, unsigned __int128 u, long exp, const ActivationNumeric &ctx) {
    if (u == 0) return zero();
    const long adjusted = digitCount(u) - 1 + exp;
    if (adjusted >= static_cast<long>(ctx.digits) || std::labs(exp) > 2 * static_cast<long>(ctx.digits)) return Fixed{};
    const std::int64_t c = static_cast<std::int64_t>(u);   // u < 10**DIGITS <= 10**18
    return Fixed{true, negative ? -c : c, static_cast<int>(exp)};
}
// digits of a 64-bit magnitude, most significant first
inline int digitsOf64(std::uint64_t u, char *out) {
    char tmp[24]; int n = 0;
    do { tmp[n++] = static_cast<char>(u % 10); u /= 10; } while (u);
    for (int i = 0; i < n; ++i) out[i] = tmp[n - 1 - i];
    return n;
}
inline bool operand(const Value &v, const ActivationNumeric &ctx, std::int64_t &c, int &e, int &len) {
    if (!smallDecimal(v, c, e)) return false;
    const std::uint64_t m = static_cast<std::uint64_t>(c < 0 ? -c : c);
    len = smallDigits(m);
    return len <= static_cast<int>(ctx.digits);
}
// numericMul: no operand longer than DIGITS (no guard truncation, no LOSTDIGITS), product rounded (numberResult).
inline Fixed mul(const Value &a, const Value &b, const ActivationNumeric &ctx) {
    if (ctx.digits > 18 || ctx.digits < 1 || ctx.fuzz >= ctx.digits) return Fixed{};
    std::int64_t x, y; int ex, ey, lx, ly;
    if (!operand(a, ctx, x, ex, lx) || !operand(b, ctx, y, ey, ly)) return Fixed{};
    if (x == 0 || y == 0) return Fixed{};
    const bool neg = (x < 0) != (y < 0);
    unsigned __int128 u = static_cast<unsigned __int128>(x < 0 ? -x : x) * static_cast<unsigned __int128>(y < 0 ? -y : y);
    long exp = static_cast<long>(ex) + ey;
    round(u, exp, static_cast<long>(ctx.digits));
    return fixedResult(neg, u, exp, ctx);
}
// oorexx_addsub::addSub for operands of at most DIGITS digits (so never truncated to DIGITS+1 on entry), on 128-bit
// integers instead of digit arrays: the same steps, each as arithmetic on the aligned coefficients.
//   A copy of one operand when the other is zero or too small to reach the result's DIGITS+1 window.
//   Equal magnitudes of opposite sign: 0.
//   Aligned to the smaller exponent; when the aligned operands are longer than DIGITS+1, both lose the same number of
//   low digits (truncated, not rounded: the other operand's padding zeros first), the exponent going up as much.
//   Sum or difference of the magnitudes; its digit positions are the longer aligned operand's (a difference keeps its
//   leading zeros) plus one for a final carry.
//   Rounded to DIGITS counted on those positions (first dropped digit >= 5; nine-carry gives one more exponent), then
//   leading zeros stripped.
// (Truncation with the exponent past the padding of the other operand, the general path's second case, needs an operand
// longer than DIGITS: never here.)
inline Fixed addSub(const Value &a, const Value &b, bool minus, const ActivationNumeric &ctx) {
    if (ctx.digits > 18 || ctx.digits < 1 || ctx.fuzz >= ctx.digits) return Fixed{};
    std::int64_t x, y; int ex, ey, lx, ly;
    if (!operand(a, ctx, x, ex, lx) || !operand(b, ctx, y, ey, ly)) return Fixed{};
    const long digits = static_cast<long>(ctx.digits);
    const std::uint64_t ux = static_cast<std::uint64_t>(x < 0 ? -x : x), uy = static_cast<std::uint64_t>(y < 0 ? -y : y);
    const int leftSign = x < 0 ? -1 : (x == 0 ? 0 : 1);
    const int rightSign0 = y < 0 ? -1 : (y == 0 ? 0 : 1);
    const int rightSign = minus ? -rightSign0 : rightSign0;
    if (leftSign == 0) return rightSign0 == 0 ? zero() : fixedResult(rightSign < 0, uy, ey, ctx);
    if (rightSign0 == 0) return fixedResult(leftSign < 0, ux, ex, ctx);
    const long minExp = std::min(ex, ey);
    const long adjL = ex - minExp, adjR = ey - minExp;
    if (adjL > 36 || adjR > 36) return Fixed{};   // (operands far apart: the general path)
    if (adjL + lx > ly + digits) return fixedResult(leftSign < 0, ux, ex, ctx);
    if (adjR + ly > lx + digits) return fixedResult(rightSign < 0, uy, ey, ctx);
    if (rightSign != leftSign && lx == ly && ex == ey && ux == uy) return zero();
    unsigned __int128 A = static_cast<unsigned __int128>(ux) * kPow10.v[adjL], B = static_cast<unsigned __int128>(uy) * kPow10.v[adjR];
    long positions = std::max(lx + adjL, ly + adjR), exp = minExp;
    const long over = positions - (digits + 1);
    if (over > 0) { A /= kPow10.v[over]; B /= kPow10.v[over]; exp += over; positions -= over; }
    unsigned __int128 S;
    int sign;
    if (rightSign == leftSign) {
        S = A + B; sign = leftSign;
        if (S >= kPow10.v[positions]) ++positions;   // carry out
    } else if (A >= B) { S = A - B; sign = leftSign; }
    else { S = B - A; sign = rightSign; }
    if (positions > digits) {   // roundTo, on the positions (leading zeros of a difference included)
        const long drop = positions - digits;
        const unsigned __int128 p = kPow10.v[drop];
        unsigned __int128 q = S / p;
        if ((S - q * p) * 2 >= p) ++q;
        exp += drop;
        if (q == kPow10.v[digits]) { q = kPow10.v[digits - 1]; ++exp; }
        S = q;
    }
    if (S == 0) return zero();
    return fixedResult(sign < 0, S, exp, ctx);
}
}  // namespace small_math
// NumberString::numberValue (signed) / unsignedNumberValue (unsigned): a whole number under DIGITS (first excluded digit
// >= 5 carries), at most validMaxWhole[min(DIGITS, 18)] = 10**min(DIGITS, 18) - 1. Their quirks are kept: a value that
// reduces to 0 or 1 (all decimals) is returned unsigned.
inline bool oorexxWholeNumber(const RexxDecimal &v, long numDigits, bool isSigned, std::int64_t &out) {
    if (v.coefficient == 0) { out = 0; return true; }
    const bool neg = v.coefficient < 0;
    if (neg && !isSigned) return false;
    const std::string d = oorexx_addsub::digitsOf(v.coefficient);
    const long digitsCount = static_cast<long>(d.size());
    long length = digitsCount, exp = v.exponent;
    const long maxDigits = numDigits > 18 ? 18 : numDigits;
    const std::uint64_t maxValue = static_cast<std::uint64_t>(decimalPow10(static_cast<int>(maxDigits)) - 1);
    bool carry = false;
    auto build = [&](long intLength, long e) -> bool {   // createUnsignedValue
        if (e + intLength > 18) return false;
        std::uint64_t value = 0;
        for (long i = 0; i < intLength; ++i) value = value * 10 + static_cast<std::uint64_t>(d[static_cast<std::size_t>(i)]);
        if (carry) value += 1;
        for (long k = 0; k < e; ++k) value *= 10;
        if (value > maxValue) return false;
        out = neg ? -static_cast<std::int64_t>(value) : static_cast<std::int64_t>(value);
        return true;
    };
    if (length <= numDigits && exp >= 0) return build(length, exp);
    // checkIntegerDigits
    if (length > numDigits) {
        exp += length - numDigits;
        length = numDigits;
        if (d[static_cast<std::size_t>(numDigits)] >= 5) carry = true;
    }
    if (exp < 0) {
        long decimalPos = -exp;
        char compare = 0;
        if (carry) { if (decimalPos > length) return false; compare = 9; }
        long start = 0;
        if (decimalPos >= length) decimalPos = length; else start = length + exp;
        for (long i = 0; i < decimalPos; ++i) if (d[static_cast<std::size_t>(start + i)] != compare) return false;
    }
    if (-exp >= (isSigned ? length : digitsCount)) { out = carry ? 1 : 0; return true; }
    if (exp < 0) return build(length + exp, 0);
    return build(length, exp);
}
inline Value numericAddSub(const Value &a, const Value &b, bool minus, const ActivationNumeric &ctx) {
    if (ctx.digits < 1 || ctx.digits > 100000 || ctx.fuzz >= ctx.digits) throw std::runtime_error("unsupported NUMERIC context");
    const RexxDecimal x = parseRexxDecimal(a);   // the receiver first, as the interpreter reports it (41.1 on the left operand)
    const RexxDecimal y = parseRexxDecimal(b);
    checkLostDigits(x, a, ctx); checkLostDigits(y, b, ctx);
    return Value::number(formatRexxDecimal(oorexx_addsub::addSub(x, y, minus, ctx.digits), ctx));
}
inline Value numericAdd(const Value &a, const Value &b, const ActivationNumeric &ctx) {
    { std::int64_t p, q; if (smallInteger(a, ctx, p) && smallInteger(b, ctx, q) && fitsDigits(p + q, ctx)) return pendingNumber(p + q, 0); }
    if (const small_math::Fixed r = small_math::addSub(a, b, false, ctx); r.ok) return pendingNumber(r.coef, r.exp);
    return numericAddSub(a, b, false, ctx);
}
inline Value numericSub(const Value &a, const Value &b, const ActivationNumeric &ctx) {
    { std::int64_t p, q; if (smallInteger(a, ctx, p) && smallInteger(b, ctx, q) && fitsDigits(p - q, ctx)) return pendingNumber(p - q, 0); }
    if (const small_math::Fixed r = small_math::addSub(a, b, true, ctx); r.ok) return pendingNumber(r.coef, r.exp);
    return numericAddSub(a, b, true, ctx);
}
inline void truncateGuardDigits(RexxDecimal &v, const ActivationNumeric &ctx) {
    const int extra = decimalDigits(v.coefficient) - static_cast<int>(ctx.digits) - 1;
    if (extra > 0) {
        v.coefficient /= decimalPow10(extra); // truncate towards zero; guard digit is retained
        v.exponent += extra;
    }
}
inline Value numericMul(const Value &a, const Value &b, const ActivationNumeric &ctx) {
    { std::int64_t p, q; if (smallInteger(a, ctx, p) && smallInteger(b, ctx, q) && fitsDigits(p * q, ctx)) return pendingNumber(p * q, 0); }
    if (const small_math::Fixed r = small_math::mul(a, b, ctx); r.ok) return pendingNumber(r.coef, r.exp);
    RexxDecimal x = parseRexxDecimal(a), y = parseRexxDecimal(b);
    checkLostDigits(x, a, ctx); checkLostDigits(y, b, ctx);
    // ooRexx uses one guard digit of operand precision in multiplication.
    truncateGuardDigits(x, ctx); truncateGuardDigits(y, ctx);
    return numberResult({x.coefficient * y.coefficient, x.exponent + y.exponent}, ctx);
}
// checkNumber(DIGITS): an operand longer than DIGITS is truncated (not rounded) to DIGITS+1 digits.
inline void chopOperand(RexxDecimal &v, const ActivationNumeric &ctx) {
    const int len = decimalDigits(v.coefficient), keep = static_cast<int>(ctx.digits) + 1;
    if (v.coefficient != 0 && len > keep) {
        v.coefficient /= decimalPow10(len - keep);
        v.exponent += len - keep;
    }
}
inline Value numericDiv(const Value &a, const Value &b, const ActivationNumeric &ctx) {
    RexxDecimal x = parseRexxDecimal(a), y = parseRexxDecimal(b);
    checkLostDigits(x, a, ctx); checkLostDigits(y, b, ctx);
    if (y.coefficient == 0) divisionByZero();
    chopOperand(x, ctx); chopOperand(y, ctx);
    if (x.coefficient == 0) return Value::number("0");
    const bool negative = (x.coefficient < 0) != (y.coefficient < 0);
    cpp_int numer = x.coefficient < 0 ? -x.coefficient : x.coefficient;
    cpp_int denom = y.coefficient < 0 ? -y.coefficient : y.coefficient;
    const int lenN = decimalDigits(numer), lenD = decimalDigits(denom);
    int magnitude = lenN - lenD;
    if (magnitude >= 0) {
        if (numer < denom * decimalPow10(magnitude)) --magnitude;
    } else if (numer * decimalPow10(-magnitude) < denom) --magnitude;
    // Generate d+1 significant digits, with an additional guard supplied by remainder.
    const int shift = static_cast<int>(ctx.digits) - magnitude;
    cpp_int q, r;
    if (shift >= 0) { numer *= decimalPow10(shift); q = numer / denom; r = numer % denom; }
    else { denom *= decimalPow10(-shift); q = numer / denom; r = numer % denom; }
    // q has up to d+1 decimal digits; its final digit is the rounding guard.
    cpp_int rounded = q / 10;
    if ((q % 10) >= 5) ++rounded;
    int exp = x.exponent - y.exponent + magnitude - static_cast<int>(ctx.digits) + 1;
    // Division results are normalized: unlike * and +, source decimal
    // fractional zeroes are not significant in the quotient.
    while (rounded != 0 && rounded % 10 == 0) { rounded /= 10; ++exp; }
    if (negative) rounded = -rounded;
    RexxDecimal output{rounded, exp};
    roundRexx(output, ctx);
    checkExponentOverflow(output);
    return Value::number(formatRexxDecimal(output, ctx));
}
// NumberString::comp: different signs decide; operands both within DIGITS-FUZZ (aligned) compare exactly; otherwise the
// sign of their difference under DIGITS-FUZZ (addSub).
inline int numericRelationDecimal(RexxDecimal x, RexxDecimal y, const ActivationNumeric &ctx) {
    const int sx = x.coefficient < 0 ? -1 : (x.coefficient == 0 ? 0 : 1);
    const int sy = y.coefficient < 0 ? -1 : (y.coefficient == 0 ? 0 : 1);
    if (sx != sy) return sx < sy ? -1 : 1;
    if (sx == 0) return 0;
    const long minExp = std::min(x.exponent, y.exponent);
    const long lenL = decimalDigits(x.coefficient) + (x.exponent - minExp);
    const long lenR = decimalDigits(y.coefficient) + (y.exponent - minExp);
    const long digits = static_cast<long>(ctx.digits) - static_cast<long>(ctx.fuzz);
    if (lenL <= digits && lenR <= digits) {
        const cpp_int xc = x.coefficient * decimalPow10(static_cast<int>(x.exponent - minExp));
        const cpp_int yc = y.coefficient * decimalPow10(static_cast<int>(y.exponent - minExp));
        return (xc > yc) - (xc < yc);
    }
    const RexxDecimal diff = oorexx_addsub::addSub(x, y, true, digits);
    return (diff.coefficient > 0) - (diff.coefficient < 0);
}
inline int numericRelation(const Value &a, const Value &b, const ActivationNumeric &ctx) {
    const RexxDecimal x = parseRexxDecimal(a);
    const RexxDecimal y = parseRexxDecimal(b);
    return numericRelationDecimal(x, y, ctx);
}
inline bool numericString(const Value &v) {
    RexxDecimal d; const char *err = nullptr;
    return tryParseRexxDecimal(v, d, err);
}
// Comparison operators, decoded once from the selector text.
enum class CmpOp { Eq, Ne, StrictEq, StrictNe, Lt, Le, Gt, Ge, SLt, SLe, SGt, SGe, None };
inline CmpOp cmpOpOf(const char *op, std::size_t n) {
    const char a = n > 0 ? op[0] : 0, b = n > 1 ? op[1] : 0, c = n > 2 ? op[2] : 0;
    switch (n) {
    case 1:
        if (a == '=') return CmpOp::Eq;
        if (a == '<') return CmpOp::Lt;
        if (a == '>') return CmpOp::Gt;
        break;
    case 2:
        if (a == '=' && b == '=') return CmpOp::StrictEq;
        if ((a == '\\' && b == '=') || (a == '<' && b == '>') || (a == '>' && b == '<')) return CmpOp::Ne;
        if ((a == '<' && b == '=') || (a == '\\' && b == '>')) return CmpOp::Le;
        if ((a == '>' && b == '=') || (a == '\\' && b == '<')) return CmpOp::Ge;
        if (a == '<' && b == '<') return CmpOp::SLt;
        if (a == '>' && b == '>') return CmpOp::SGt;
        break;
    case 3:
        if (a == '\\' && b == '=' && c == '=') return CmpOp::StrictNe;
        if ((a == '<' && b == '<' && c == '=') || (a == '\\' && b == '>' && c == '>')) return CmpOp::SLe;
        if ((a == '>' && b == '>' && c == '=') || (a == '\\' && b == '<' && c == '<')) return CmpOp::SGe;
        break;
    }
    return CmpOp::None;
}
// "1" or "0", made as a number (its characters when asked for)
inline Value truthValue(bool b) {
    return Value(Value::PendingTag{}, b ? 1 : 0, kNumKnown | kNumDecimal | kNumInteger | (128u << 8));
}
// Non-strict string comparison: leading/trailing blanks ignored, the shorter string padded with blanks.
inline int rexxPaddedCompare(const std::string &a, const std::string &b) {
    std::size_t ai = 0, an = a.size(), bi = 0, bn = b.size();
    while (ai < an && rexxBlank(a[ai])) ++ai;
    while (an > ai && rexxBlank(a[an - 1])) --an;
    while (bi < bn && rexxBlank(b[bi])) ++bi;
    while (bn > bi && rexxBlank(b[bn - 1])) --bn;
    const std::size_t la = an - ai, lb = bn - bi, len = std::max(la, lb);
    for (std::size_t k = 0; k < len; ++k) {
        const unsigned char ca = k < la ? static_cast<unsigned char>(a[ai + k]) : ' ';
        const unsigned char cb = k < lb ? static_cast<unsigned char>(b[bi + k]) : ' ';
        if (ca != cb) return ca < cb ? -1 : 1;
    }
    return 0;
}
inline Value numericCompare(const Value &a, CmpOp op, const Value &b, const ActivationNumeric &ctx) {
    // A right-hand object is never silently compared as its (empty) byte string.
    if (a.isObject() || b.isObject()) throw std::runtime_error("comparison with an object operand requires message dispatch");
    switch (op) {
    case CmpOp::StrictEq: return truthValue(a.bytes == b.bytes);
    case CmpOp::StrictNe: return truthValue(a.bytes != b.bytes);
    case CmpOp::SLt: return truthValue(a.bytes < b.bytes);
    case CmpOp::SLe: return truthValue(a.bytes <= b.bytes);
    case CmpOp::SGt: return truthValue(a.bytes > b.bytes);
    case CmpOp::SGe: return truthValue(a.bytes >= b.bytes);
    case CmpOp::None: throw std::runtime_error("unknown decimal comparison operator");
    default: break;
    }
    int rel;
    RexxDecimal dx, dy; const char *perr = nullptr; std::int64_t sp, sq;
    if (smallInteger(a, ctx, sp) && smallInteger(b, ctx, sq)) rel = (sp > sq) - (sp < sq);
    else if (smallDecimalRelation(a, b, ctx, rel)) {}
    else if (tryParseRexxDecimal(a, dx, perr) && tryParseRexxDecimal(b, dy, perr)) {
        checkLostDigits(dx, a, ctx); checkLostDigits(dy, b, ctx);
        rel = numericRelationDecimal(dx, dy, ctx);
    }
    else rel = rexxPaddedCompare(a.bytes, b.bytes);
    switch (op) {
    case CmpOp::Eq: return truthValue(rel == 0);
    case CmpOp::Ne: return truthValue(rel != 0);
    case CmpOp::Lt: return truthValue(rel < 0);
    case CmpOp::Le: return truthValue(rel <= 0);
    case CmpOp::Gt: return truthValue(rel > 0);
    default: return truthValue(rel >= 0);
    }
}
inline Value numericCompare(const Value &a, const std::string &op, const Value &b, const ActivationNumeric &ctx) {
    return numericCompare(a, cmpOpOf(op.data(), op.size()), b, ctx);
}
inline Value numericWholeDivide(const Value &a, const Value &b, const ActivationNumeric &ctx) {
    RexxDecimal x = parseRexxDecimal(a), y = parseRexxDecimal(b);
    checkLostDigits(x, a, ctx); checkLostDigits(y, b, ctx);
    if (y.coefficient == 0) divisionByZero();
    if (x.coefficient == 0) return Value::number("0");
    chopOperand(x, ctx); chopOperand(y, ctx);
    // Magnitudes far apart (exponents up to 999999999): the quotient is 0, or has more than DIGITS digits; decided
    // without aligning the operands.
    const long magX = static_cast<long>(x.exponent) + decimalDigits(x.coefficient);
    const long magY = static_cast<long>(y.exponent) + decimalDigits(y.coefficient);
    if (magX < magY) return Value::number("0");
    if (magX - magY > static_cast<long>(ctx.digits) + 1)
        throw SyntaxCondition("26.11", "Result of % operation did not result in a whole number", false);
    const int e = std::min(x.exponent, y.exponent);
    const cpp_int xc = x.coefficient * decimalPow10(x.exponent - e);
    const cpp_int yc = y.coefficient * decimalPow10(y.exponent - e);
    const cpp_int quotient = xc / yc;                       // truncates toward zero
    if (quotient != 0 && decimalDigits(quotient) > static_cast<int>(ctx.digits))
        throw SyntaxCondition("26.11", "Result of % operation did not result in a whole number", false);
    return numberResult({quotient, 0}, ctx);
}
// x // y : remainder of the truncated integer quotient (sign of the dividend).
inline Value numericRemainder(const Value &a, const Value &b, const ActivationNumeric &ctx) {
    RexxDecimal x = parseRexxDecimal(a), y = parseRexxDecimal(b);
    checkLostDigits(x, a, ctx); checkLostDigits(y, b, ctx);
    if (y.coefficient == 0) divisionByZero();
    if (x.coefficient == 0) return Value::number("0");
    chopOperand(x, ctx); chopOperand(y, ctx);
    {   // magnitudes far apart: |x| < |y| gives x itself; a quotient of more than DIGITS digits is the error (see %)
        const long magX = static_cast<long>(x.exponent) + decimalDigits(x.coefficient);
        const long magY = static_cast<long>(y.exponent) + decimalDigits(y.coefficient);
        if (magX < magY) return numberResult(x, ctx);
        if (magX - magY > static_cast<long>(ctx.digits) + 1)
            throw SyntaxCondition("26.12", "Result of // operation did not result in a whole number", false);
    }
    const int e = std::min(x.exponent, y.exponent);
    cpp_int xc = x.coefficient * decimalPow10(x.exponent - e);
    cpp_int yc = y.coefficient * decimalPow10(y.exponent - e);
    const cpp_int quotient = xc / yc;                       // truncates toward zero
    if (decimalDigits(quotient) > static_cast<int>(ctx.digits))
        throw SyntaxCondition("26.12", "Result of // operation did not result in a whole number", false);
    if (quotient == 0) return numberResult(x, ctx);          // |x| < |y|: the dividend itself
    return numberResult({xc - quotient * yc, e}, ctx);
}
// x ** n : integer power, ooRexx algorithm (left-to-right binary powering at DIGITS+len(n)+1).
inline Value numericPower(const Value &a, const Value &b, const ActivationNumeric &ctx) {
    // As the interpreter: Error 26.8 Operand to the right of the power operator (**) must be a whole number; found "b".
    auto notWhole = [&b]() {
        SyntaxCondition bad("26.8", "Operand to the right of the power operator (**) must be a whole number; found \"" +
                            (b.isObject() ? std::string() : b.bytes.str()) + "\"", false);
        bad.substitutions.push_back(b);
        throw bad;
    };
    RexxDecimal n;
    { const char *err = nullptr; if (b.isObject() || !tryParseRexxDecimal(b, n, err)) notWhole(); }
    // powerObj->numberValue(powerValue, DIGITS): a whole number within DIGITS (10 is not one under DIGITS 1).
    std::int64_t powerValue = 0;
    if (!oorexxWholeNumber(n, static_cast<long>(ctx.digits), true, powerValue)) notWhole();
    const bool negativePower = powerValue < 0;
    const std::uint64_t power = static_cast<std::uint64_t>(negativePower ? -powerValue : powerValue);
    const int digits = static_cast<int>(ctx.digits);
    RexxDecimal left = parseRexxDecimal(a);
    checkLostDigits(left, a, ctx);
    // operand truncated (not rounded) to digits+1 digits
    {
        const int len = decimalDigits(left.coefficient);
        if (left.coefficient != 0 && len > digits + 1) {
            left.coefficient /= decimalPow10(len - (digits + 1));
            left.exponent += len - (digits + 1);
        }
    }
    if (left.coefficient == 0) {
        if (negativePower) throw SyntaxCondition("42.903", "Arithmetic underflow; zero raised to a negative power", false);
        return Value::number(power == 0 ? "1" : "0");
    }
    // NumberString::power: the result's exponent magnitude is known in advance; too large is Error 42.1.
    if (std::labs(static_cast<long>(left.exponent) + decimalDigits(left.coefficient) - 1) * static_cast<long double>(power) >
        static_cast<long double>(kMaxRexxExponent)) {
        const std::string lhs = a.isObject() ? std::string() : a.bytes.str(), rhs = b.isObject() ? std::string() : b.bytes.str();
        SyntaxCondition e("42.1", "Arithmetic overflow detected at:  \"" + lhs + "**" + rhs + "\"", false);
        e.substitutions = {a, Value::string("**"), b};
        throw e;
    }
    if (power == 0) return Value::number("1");
    int extra = 0;
    for (std::uint64_t t = power; t != 0; t /= 10) ++extra;
    ActivationNumeric work = ctx;
    work.digits = static_cast<std::size_t>(digits + extra + 1);
    work.fuzz = 0;
    RexxDecimal acc = left;
    int top = 63;
    while (!((power >> top) & 1)) --top;
    for (int bit = top - 1; bit >= 0; --bit) {
        acc = {acc.coefficient * acc.coefficient, acc.exponent * 2};
        roundRexx(acc, work);
        if ((power >> bit) & 1) {
            acc = {acc.coefficient * left.coefficient, acc.exponent + left.exponent};
            roundRexx(acc, work);
        }
    }
    if (negativePower) {
        // dividePower: 1 / acc produces WORKING DIGITS+1 significant digits, truncated; rounding happens once at the end.
        const int keep = digits + extra + 2;
        const int lenA = decimalDigits(acc.coefficient);
        const int shift = keep + lenA;                       // enough scale for >= keep quotient digits
        cpp_int q = decimalPow10(shift) / acc.coefficient;
        int qe = -shift - acc.exponent;
        const int lenQ = decimalDigits(q);
        if (lenQ > keep) { q /= decimalPow10(lenQ - keep); qe += lenQ - keep; }
        acc = {q, qe};
    }
    roundRexx(acc, ctx);
    checkExponentOverflow(acc);
    while (acc.coefficient != 0 && acc.coefficient % 10 == 0) { acc.coefficient /= 10; ++acc.exponent; }
    return Value::number(formatRexxDecimal(acc, ctx, false, true));
}
inline bool withinNumeric(const Value &current, const Value &limit, const Value &step,
                          const ActivationNumeric &ctx) {
    std::int64_t c, l, st;
    if (smallInteger(step, ctx, st) && smallInteger(current, ctx, c) && smallInteger(limit, ctx, l)) {
        if (st == 0) throw std::runtime_error("DO BY 0");
        return st > 0 ? c <= l : c >= l;
    }
    static const Value zero = Value::number("0");
    int direction, comparison;
    if (!smallDecimalRelation(step, zero, ctx, direction)) direction = numericRelation(step, zero, ctx);
    if (!direction) throw std::runtime_error("DO BY 0");
    if (!smallDecimalRelation(current, limit, ctx, comparison)) comparison = numericRelation(current, limit, ctx);
    return direction > 0 ? comparison <= 0 : comparison >= 0;
}
// requestUnsignedNumber under the current DIGITS: a number that rounds (at DIGITS) to a non-negative whole number.
// requestUnsignedNumber under the current DIGITS.
inline bool numericSettingValue(const Value &v, const ActivationNumeric &ctx, std::uint64_t &out) {
    RexxDecimal d; const char *err = nullptr;
    if (v.isObject() || !tryParseRexxDecimal(v, d, err)) return false;
    std::int64_t n = 0;
    if (!oorexxWholeNumber(d, static_cast<long>(ctx.digits), false, n)) return false;
    out = static_cast<std::uint64_t>(n);
    return true;
}
inline Value requestString(const Value &v);
// (an object operand of NUMERIC DIGITS / FUZZ / FORM VALUE gives its string value: RexxObject::requestString)
inline void setNumericDigits(ActivationNumeric &ctx, const Value &in) {
    const Value v = in.isObject() ? requestString(in) : in;
    std::uint64_t n = 0;
    if (!numericSettingValue(v, ctx, n) || n < 1) {
        SyntaxCondition bad("26.5", "DIGITS value must be a positive whole number; found \"" + v.bytes.str() + "\"", false);
        bad.substitutions.push_back(v); throw bad;
    }
    if (n <= ctx.fuzz) {
        SyntaxCondition bad("33.1", "Value of NUMERIC DIGITS (\"" + std::to_string(n) + "\") must exceed value of NUMERIC FUZZ (\"" +
                            std::to_string(ctx.fuzz) + "\")", false);
        bad.substitutions.push_back(Value::string(std::to_string(n)));
        bad.substitutions.push_back(Value::string(std::to_string(ctx.fuzz)));
        throw bad;
    }
    // (any whole number the interpreter takes: 999999999 is accepted; arithmetic then works to that precision)
    ctx.digits = static_cast<std::size_t>(n);
}
inline void setNumericFuzz(ActivationNumeric &ctx, const Value &in) {
    const Value v = in.isObject() ? requestString(in) : in;
    std::uint64_t n = 0;
    if (!numericSettingValue(v, ctx, n)) {
        SyntaxCondition bad("26.6", "FUZZ value must be zero or a positive whole number; found \"" + v.bytes.str() + "\"", false);
        bad.substitutions.push_back(v); throw bad;
    }
    if (n >= ctx.digits) {
        SyntaxCondition bad("33.1", "Value of NUMERIC DIGITS (\"" + std::to_string(ctx.digits) + "\") must exceed value of NUMERIC FUZZ (\"" +
                            std::to_string(n) + "\")", false);
        bad.substitutions.push_back(Value::string(std::to_string(ctx.digits)));
        bad.substitutions.push_back(Value::string(std::to_string(n)));
        throw bad;
    }
    ctx.fuzz = static_cast<std::size_t>(n);
}
inline void setNumericForm(ActivationNumeric &ctx, bool engineering) {
    ctx.engineering = engineering;
}
// NUMERIC FORM VALUE expr: exactly SCIENTIFIC or ENGINEERING (upper case), else 25.11 with the value, as interpreted.
inline void setNumericFormValue(ActivationNumeric &ctx, const Value &in) {
    const Value v = in.isObject() ? requestString(in) : in;
    if (!v.isObject() && v.bytes == "ENGINEERING") { setNumericForm(ctx, true); return; }
    if (!v.isObject() && v.bytes == "SCIENTIFIC") { setNumericForm(ctx, false); return; }
    SyntaxCondition bad("25.11", "NUMERIC FORM must be followed by one of the keywords SCIENTIFIC or ENGINEERING", false);
    bad.substitutions.push_back(v);
    throw bad;
}
struct ScopedNumericActivation {
    ActivationNumeric &context;
    ActivationNumeric previous;
    explicit ScopedNumericActivation(ActivationNumeric &ctx):context(ctx),previous(ctx) {}
    ~ScopedNumericActivation() { context = previous; }
    ScopedNumericActivation(const ScopedNumericActivation &) = delete;
    ScopedNumericActivation &operator=(const ScopedNumericActivation &) = delete;
};
// ForLoop::setup: a DO / LOOP repetition count (forKeyword false: DO exprr) or FOR count, a whole number >= 0 under
// DIGITS after a prefix plus; anything else is 26.2 / 26.3 with the value.
inline std::uint64_t loopCount(const Value &in, bool forKeyword, const ActivationNumeric &ctx) {
    const Value v = in.isObject() ? requestString(in) : in;   // an object's string value (a stem: its default value)
    auto bad = [&]() {
        const std::string found = v.isObject() ? v.object->display() : v.bytes.str();
        SyntaxCondition e(forKeyword ? "26.3" : "26.2",
                          std::string(forKeyword ? "Value of FOR expression" : "Value of repetition count expression") +
                          " in DO or LOOP instruction must be zero or a positive whole number; found \"" + found + "\"", false);
        e.substitutions.push_back(v);
        throw e;
    };
    if (v.isObject()) bad();
    RexxDecimal d; const char *err = nullptr;
    if (!tryParseRexxDecimal(v, d, err)) bad();
    roundRexx(d, ctx);                                   // the prefix plus
    std::int64_t count = 0;
    if (!oorexxWholeNumber(d, static_cast<long>(ctx.digits), true, count) || count < 0) bad();
    return static_cast<std::uint64_t>(count);
}
#endif
