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
inline bool rexxBlank(char c) { return c == ' ' || c == '\t' || c == '\r' || c == '\n'; }
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
            if (src[i] < '0' || src[i] > '9' || e > kMaxRexxScale)
                { err = "invalid Rexx decimal exponent"; return false; }
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
    if (!tryParseRexxDecimal(v, out, err)) throw std::runtime_error(err);
    return out;
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
inline Value numericAdd(const Value &a, const Value &b, const ActivationNumeric &ctx) {
    { std::int64_t p, q; if (smallInteger(a, ctx, p) && smallInteger(b, ctx, q) && fitsDigits(p + q, ctx)) return Value::number(std::to_string(p + q)); }
    if (auto quick = smallDecimalAdd(a, b, false, ctx)) return std::move(*quick);
    RexxDecimal x = parseRexxDecimal(a), y = parseRexxDecimal(b);
    // Rexx addition normalizes operands to the current significant-digit
    // context, unlike multiplication, which carries additional guard digits.
    const bool xRounded = decimalDigits(x.coefficient) > static_cast<int>(ctx.digits);
    const bool yRounded = decimalDigits(y.coefficient) > static_cast<int>(ctx.digits);
    roundRexx(x, ctx);
    roundRexx(y, ctx);
    auto magnitude = [](const RexxDecimal &v) {
        return v.coefficient == 0 ? -100000 : v.exponent + decimalDigits(v.coefficient) - 1;
    };
    const int xd = magnitude(x), yd = magnitude(y);
    if (xd - yd > static_cast<int>(ctx.digits) ||
        (xd - yd == static_cast<int>(ctx.digits) &&
         (xRounded || (x.exponent > 0 && decimalDigits(x.coefficient) == static_cast<int>(ctx.digits)))))
        return Value::number(formatRexxDecimal(x, ctx));
    if (yd - xd > static_cast<int>(ctx.digits) ||
        (yd - xd == static_cast<int>(ctx.digits) &&
         (yRounded || (y.exponent > 0 && decimalDigits(y.coefficient) == static_cast<int>(ctx.digits)))))
        return Value::number(formatRexxDecimal(y, ctx));
    const bool guardContribution = (xd - yd == static_cast<int>(ctx.digits)) ||
                                   (yd - xd == static_cast<int>(ctx.digits));
    const int e = std::min(x.exponent, y.exponent);
    x.coefficient *= decimalPow10(x.exponent - e);
    y.coefficient *= decimalPow10(y.exponent - e);
    RexxDecimal sum{x.coefficient + y.coefficient, e};
    if (sum.coefficient == 0) return Value::number("0");
    RexxDecimal rounded = sum;
    // ooRexx keeps DIGITS places counted from the larger operand's leading digit (plus a guard digit), so the sum is
    // rounded at that place even when cancellation shortens it: 123456789 - 99999999.9 = 23456789 (DIGITS 9).
    {
        // Guard-place rounding uses the exponent of the DOMINANT operand.
        // Rounding the result's newly shortened mantissa would turn
        // 1.0 - 0.0001 (DIGITS 4) into 0.9999 instead of Rexx's 1.000.
        const int place = std::max(xd, yd) - static_cast<int>(ctx.digits) + 1;
        if (place > rounded.exponent) {
            cpp_int divisor = decimalPow10(place - rounded.exponent);
            cpp_int q = rounded.coefficient / divisor;
            const cpp_int rem = rounded.coefficient % divisor;
            if ((rem < 0 ? -rem : rem) * 2 >= divisor)
                q += rounded.coefficient < 0 ? -1 : 1;
            rounded.coefficient = q;
            rounded.exponent = place;
        }
    }
    roundRexx(rounded, ctx);
    auto equalNumber = [](const RexxDecimal &one, const RexxDecimal &two) {
        const int shift = std::min(one.exponent, two.exponent);
        return one.coefficient * decimalPow10(one.exponent-shift) ==
               two.coefficient * decimalPow10(two.exponent-shift);
    };
    // An operand too small to affect DIGITS cannot invent additional zeroes.
    // Preserve the larger operand's existing significant places.
    if (!guardContribution && equalNumber(rounded, parseRexxDecimal(a))) {
        RexxDecimal source = parseRexxDecimal(a);
        roundRexx(source, ctx);
        return Value::number(formatRexxDecimal(source, ctx));
    }
    if (!guardContribution && equalNumber(rounded, parseRexxDecimal(b))) {
        RexxDecimal source = parseRexxDecimal(b);
        roundRexx(source, ctx);
        return Value::number(formatRexxDecimal(source, ctx));
    }
    return Value::number(formatRexxDecimal(rounded, ctx));
}
inline Value numericSub(const Value &a, const Value &b, const ActivationNumeric &ctx) {
    { std::int64_t p, q; if (smallInteger(a, ctx, p) && smallInteger(b, ctx, q) && fitsDigits(p - q, ctx)) return Value::number(std::to_string(p - q)); }
    if (auto quick = smallDecimalAdd(a, b, true, ctx)) return std::move(*quick);
    RexxDecimal y = parseRexxDecimal(b);
    y.coefficient = -y.coefficient;
    return numericAdd(a, Value::number(formatRexxDecimal(y, ctx)), ctx);
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
inline Value numericDiv(const Value &a, const Value &b, const ActivationNumeric &ctx) {
    RexxDecimal x = parseRexxDecimal(a), y = parseRexxDecimal(b);
    if (y.coefficient == 0) throw std::runtime_error("division by zero");
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
    const bool exactQuotient = (r == 0); // Do not force exponential form for exact small quotients.
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
    return Value::number(formatRexxDecimal(output, ctx, !exactQuotient));
}
inline int numericRelationDecimal(RexxDecimal x, RexxDecimal y, const ActivationNumeric &ctx) {
    // FUZZ affects comparison precision, not computation precision.
    ActivationNumeric cmp = ctx;
    cmp.digits -= cmp.fuzz;
    cmp.fuzz = 0;
    roundRexx(x, cmp);
    roundRexx(y, cmp);
    // ooRexx compares by subtraction under DIGITS-FUZZ: the difference is rounded at the place DIGITS below the larger
    // operand's leading digit, so 1000 = 999.9 under DIGITS 4.
    auto lead = [](const RexxDecimal &v) { return v.coefficient == 0 ? INT_MIN / 2 : v.exponent + decimalDigits(v.coefficient) - 1; };
    const int place = std::max(lead(x), lead(y)) - static_cast<int>(cmp.digits) + 1;
    const int e = std::min(x.exponent, y.exponent);
    x.coefficient *= decimalPow10(x.exponent - e);
    y.coefficient *= decimalPow10(y.exponent - e);
    cpp_int diff = x.coefficient - y.coefficient;
    if (diff != 0 && place > e && place - e <= 2 * kMaxRexxScale) {
        const cpp_int divisor = decimalPow10(place - e);
        const cpp_int mag = diff < 0 ? cpp_int(-diff) : diff;
        cpp_int q = mag / divisor;
        if ((mag % divisor) * 2 >= divisor) ++q;
        if (q == 0) return 0;
    }
    return (diff > 0) - (diff < 0);
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
    roundRexx(x, ctx); roundRexx(y, ctx);
    roundRexx(x, ctx); roundRexx(y, ctx);
    if (y.coefficient == 0) throw std::runtime_error("division by zero");
    if (x.exponent >= 0) x.coefficient *= decimalPow10(x.exponent);
    else y.coefficient *= decimalPow10(-x.exponent);
    if (y.exponent >= 0) y.coefficient *= decimalPow10(y.exponent);
    else x.coefficient *= decimalPow10(-y.exponent);
    const cpp_int quotient = x.coefficient / y.coefficient;
    if (decimalDigits(quotient) > static_cast<int>(ctx.digits))
        throw std::runtime_error("whole division result exceeds NUMERIC DIGITS");
    return numberResult({quotient, 0}, ctx);
}
// x // y : remainder of the truncated integer quotient (sign of the dividend).
inline Value numericRemainder(const Value &a, const Value &b, const ActivationNumeric &ctx) {
    RexxDecimal x = parseRexxDecimal(a), y = parseRexxDecimal(b);
    if (y.coefficient == 0) throw std::runtime_error("division by zero");
    if (x.coefficient == 0) return Value::number("0");
    // ooRexx checkNumber(): an operand longer than DIGITS is TRUNCATED (not rounded) to DIGITS+1 digits.
    auto chop = [&](RexxDecimal &v) {
        const int len = decimalDigits(v.coefficient), keep = static_cast<int>(ctx.digits) + 1;
        if (len > static_cast<int>(ctx.digits) && len > keep) {
            v.coefficient /= decimalPow10(len - keep);
            v.exponent += len - keep;
        }
    };
    chop(x); chop(y);
    const int e = std::min(x.exponent, y.exponent);
    cpp_int xc = x.coefficient * decimalPow10(x.exponent - e);
    cpp_int yc = y.coefficient * decimalPow10(y.exponent - e);
    const cpp_int quotient = xc / yc;                       // truncates toward zero
    if (decimalDigits(quotient) > static_cast<int>(ctx.digits))
        throw std::runtime_error("Error 26.12: Result of // operation did not result in a whole number");
    if (quotient == 0) return numberResult(x, ctx);          // |x| < |y|: the dividend itself
    return numberResult({xc - quotient * yc, e}, ctx);
}
// x ** n : integer power, ooRexx algorithm (left-to-right binary powering at DIGITS+len(n)+1).
inline Value numericPower(const Value &a, const Value &b, const ActivationNumeric &ctx) {
    RexxDecimal n = parseRexxDecimal(b);
    // exponent must be a whole number
    if (n.exponent < 0) {
        cpp_int p = decimalPow10(-n.exponent);
        if (n.coefficient % p != 0) throw std::runtime_error("Error 26.3: power must be a whole number");
        n.coefficient /= p; n.exponent = 0;
    } else n.coefficient *= decimalPow10(n.exponent);
    if (decimalDigits(n.coefficient) > 9) throw std::runtime_error("Error 26.3: power must be a whole number");
    const bool negativePower = n.coefficient < 0;
    const std::uint64_t power = static_cast<std::uint64_t>(negativePower ? -n.coefficient : n.coefficient);
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
        if (negativePower) throw std::runtime_error("Error 42.3: arithmetic overflow in power");
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
inline void setNumericDigits(ActivationNumeric &ctx, const Value &v) {
    const auto n = integer(v);
    if (n < 1 || n > 100000) throw std::runtime_error("NUMERIC DIGITS outside supported range 1..100000");
    if (ctx.fuzz >= static_cast<std::size_t>(n)) throw std::runtime_error("NUMERIC FUZZ must be less than DIGITS");
    ctx.digits = static_cast<std::size_t>(n);
}
inline void setNumericFuzz(ActivationNumeric &ctx, const Value &v) {
    const auto n = integer(v);
    if (n < 0 || static_cast<std::size_t>(n) >= ctx.digits) throw std::runtime_error("NUMERIC FUZZ must be 0..DIGITS-1");
    ctx.fuzz = static_cast<std::size_t>(n);
}
inline void setNumericForm(ActivationNumeric &ctx, bool engineering) {
    ctx.engineering = engineering;
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
