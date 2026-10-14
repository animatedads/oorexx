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
constexpr int kMaxRexxScale = 400000; // bounded standalone subset; fail closed
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
inline bool smallInteger(const Value &v, const ActivationNumeric &ctx, std::int64_t &out) {
    if (v.isObject() || ctx.digits < 1 || ctx.fuzz != 0) return false;   // NUMERIC FUZZ changes comparisons: full path
    const std::string &s = v.bytes;
    std::size_t i = 0, n = s.size();
    if (n == 0 || n > 10) return false;
    bool neg = false;
    if (s[0] == '-') { neg = true; i = 1; }
    if (i >= n) return false;
    std::int64_t r = 0;
    for (; i < n; ++i) { if (s[i] < '0' || s[i] > '9') return false; r = r * 10 + (s[i] - '0'); }
    if (r > 999999999) return false;
    out = neg ? -r : r;
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
    // No copies: scan the bytes between leading and trailing blanks in place.
    const std::string &src = v.bytes;
    std::size_t i = 0, n = src.size();
    while (i < n && rexxBlank(src[i])) ++i;
    while (n > i && rexxBlank(src[n - 1])) --n;
    if (i == n || n - i > 10000) { err = "invalid Rexx decimal number"; return false; }
    out.exponent = 0;
    bool minus = false, sawDigit = false, dot = false;
    if (src[i] == '+' || src[i] == '-') { minus = src[i] == '-'; ++i; }
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
        int e = 0;
        for (; i < n; ++i) {
            if (src[i] < '0' || src[i] > '9')
                { err = "invalid Rexx decimal exponent"; return false; }
            // A valid exponent beyond this subset's range (ooRexx allows up to 999999999): not "not a number".
            if (e > kMaxRexxScale) {
                for (; i < n; ++i) if (src[i] < '0' || src[i] > '9') { err = "invalid Rexx decimal exponent"; return false; }
                err = "decimal exponent outside supported range"; return false;
            }
            e = e * 10 + (src[i] - '0');
        }
        out.exponent += eneg ? -e : e;
    }
    if (out.exponent < -kMaxRexxScale || out.exponent > kMaxRexxScale)
        { err = "decimal exponent outside supported range"; return false; }
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
    if (value.exponent < -kMaxRexxScale || value.exponent > kMaxRexxScale)
        throw std::runtime_error("decimal exponent outside supported range");
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
    const std::string &t = v.bytes;
    std::size_t i = 0, n = t.size();
    if (n == 0 || n > 20) return false;
    bool neg = false;
    if (t[0] == '-' || t[0] == '+') { neg = t[0] == '-'; i = 1; }
    std::int64_t c = 0; int e = 0; bool dot = false, digit = false; int nd = 0;
    for (; i < n; ++i) {
        const char ch = t[i];
        if (ch >= '0' && ch <= '9') {
            if (c || ch != '0') { if (++nd > 18) return false; }
            c = c * 10 + (ch - '0'); digit = true;
            if (dot) --e;
        } else if (ch == '.' && !dot) dot = true;
        else return false;
    }
    if (!digit) return false;
    coef = neg ? -c : c; exp = e;
    return true;
}
inline int smallDigits(unsigned __int128 v) { int d = 1; while (v >= 10) { v /= 10; ++d; } return d; }
// Exact fixed-notation result (exponent in [-2*DIGITS, 0], significant digits within DIGITS), else nullopt.
inline std::optional<Value> smallDecimalResult(__int128 c, int e, const ActivationNumeric &ctx) {
    if (c == 0) return Value::number("0");
    const bool neg = c < 0;
    unsigned __int128 u = neg ? static_cast<unsigned __int128>(-c) : static_cast<unsigned __int128>(c);
    if (e > 0 || e < -2 * static_cast<int>(ctx.digits) || smallDigits(u) > static_cast<int>(ctx.digits)) return std::nullopt;
    char buf[64]; int k = 0;
    const int frac = -e;
    int pos = 0;
    do { buf[k++] = static_cast<char>('0' + static_cast<int>(u % 10)); u /= 10; ++pos; if (pos == frac && frac > 0) buf[k++] = '.'; } while (u || pos < frac);
    if (frac > 0 && pos == frac) buf[k++] = '0';
    std::string out; out.reserve(static_cast<std::size_t>(k) + 1);
    if (neg) out += '-';
    while (k) out += buf[--k];
    return Value::number(out);
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
inline Value numberResult(RexxDecimal n, const ActivationNumeric &ctx) {
    roundRexx(n, ctx);
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
    if (exp < -kMaxRexxScale || exp > kMaxRexxScale) throw std::runtime_error("decimal exponent outside supported range");
    return RexxDecimal{sign < 0 ? cpp_int(-c) : c, static_cast<int>(exp)};
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
    return Value::number(formatRexxDecimal(oorexx_addsub::addSub(parseRexxDecimal(a), parseRexxDecimal(b), minus, ctx.digits), ctx));
}
inline Value numericAdd(const Value &a, const Value &b, const ActivationNumeric &ctx) {
    { std::int64_t p, q; if (smallInteger(a, ctx, p) && smallInteger(b, ctx, q) && fitsDigits(p + q, ctx)) return Value::number(std::to_string(p + q)); }
    if (auto quick = smallDecimalAdd(a, b, false, ctx)) return std::move(*quick);
    return numericAddSub(a, b, false, ctx);
}
inline Value numericSub(const Value &a, const Value &b, const ActivationNumeric &ctx) {
    { std::int64_t p, q; if (smallInteger(a, ctx, p) && smallInteger(b, ctx, q) && fitsDigits(p - q, ctx)) return Value::number(std::to_string(p - q)); }
    if (auto quick = smallDecimalAdd(a, b, true, ctx)) return std::move(*quick);
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
    { std::int64_t p, q; if (smallInteger(a, ctx, p) && smallInteger(b, ctx, q) && fitsDigits(p * q, ctx)) return Value::number(std::to_string(p * q)); }
    if (auto quick = smallDecimalMul(a, b, ctx)) return std::move(*quick);
    RexxDecimal x = parseRexxDecimal(a), y = parseRexxDecimal(b);
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
    return numericRelationDecimal(parseRexxDecimal(a), parseRexxDecimal(b), ctx);
}
inline bool numericString(const Value &v) {
    RexxDecimal d; const char *err = nullptr;
    return tryParseRexxDecimal(v, d, err);
}
// Comparison operators, decoded once from the selector text.
enum class CmpOp { Eq, Ne, StrictEq, StrictNe, Lt, Le, Gt, Ge, SLt, SLe, SGt, SGe, None };
inline CmpOp cmpOpOf(const char *op, std::size_t n) {
    auto is = [&](const char *t) { return std::strlen(t) == n && std::memcmp(op, t, n) == 0; };
    if (is("=")) return CmpOp::Eq;
    if (is("\\=") || is("<>") || is("><")) return CmpOp::Ne;
    if (is("==")) return CmpOp::StrictEq;
    if (is("\\==")) return CmpOp::StrictNe;
    if (is("<")) return CmpOp::Lt;
    if (is("<=") || is("\\>")) return CmpOp::Le;
    if (is(">")) return CmpOp::Gt;
    if (is(">=") || is("\\<")) return CmpOp::Ge;
    if (is("<<")) return CmpOp::SLt;
    if (is("<<=") || is("\\>>")) return CmpOp::SLe;
    if (is(">>")) return CmpOp::SGt;
    if (is(">>=") || is("\\<<")) return CmpOp::SGe;
    return CmpOp::None;
}
inline Value truthValue(bool b) { return Value::string(b ? "1" : "0"); }
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
    else if (tryParseRexxDecimal(a, dx, perr) && tryParseRexxDecimal(b, dy, perr)) rel = numericRelationDecimal(dx, dy, ctx);
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
    if (y.coefficient == 0) divisionByZero();
    if (x.coefficient == 0) return Value::number("0");
    chopOperand(x, ctx); chopOperand(y, ctx);
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
    if (y.coefficient == 0) divisionByZero();
    if (x.coefficient == 0) return Value::number("0");
    chopOperand(x, ctx); chopOperand(y, ctx);
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
inline void setNumericDigits(ActivationNumeric &ctx, const Value &v) {
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
    if (n > 100000) throw std::runtime_error("NUMERIC DIGITS outside supported range 1..100000");
    ctx.digits = static_cast<std::size_t>(n);
}
inline void setNumericFuzz(ActivationNumeric &ctx, const Value &v) {
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
inline void setNumericFormValue(ActivationNumeric &ctx, const Value &v) {
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
#endif
