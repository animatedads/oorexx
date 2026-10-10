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
inline cpp_int decimalPow10(int n) {
    if (n < 0 || n > kMaxRexxScale)
        throw std::runtime_error("decimal exponent exceeds supported limit");
    cpp_int base = 10, out = 1;
    while (n != 0) {
        if (n & 1) out *= base;
        n >>= 1;
        if (n) base *= base;
    }
    return out;
}
inline int decimalDigits(const cpp_int &c) {
    const cpp_int n = c < 0 ? -c : c;
    return static_cast<int>(n.convert_to<std::string>().size());
}
inline RexxDecimal parseRexxDecimal(const Value &v) {
    if (v.isObject()) throw std::runtime_error("numeric operation on an object requires message dispatch");
    const std::string s = trim(v.bytes);
    if (s.empty() || s.size() > 10000) throw std::runtime_error("invalid Rexx decimal number");
    RexxDecimal out;
    std::size_t i = 0;
    bool minus = false, sawDigit = false, dot = false;
    if (s[i] == '+' || s[i] == '-') { minus = s[i] == '-'; ++i; }
    std::string digits;
    for (; i < s.size(); ++i) {
        if (s[i] >= '0' && s[i] <= '9') {
            digits += s[i]; sawDigit = true;
            if (dot) --out.exponent;
        } else if (s[i] == '.' && !dot) dot = true;
        else break;
    }
    if (!sawDigit) throw std::runtime_error("invalid Rexx decimal number");
    if (i < s.size()) {
        if (s[i] != 'E' && s[i] != 'e') throw std::runtime_error("invalid Rexx decimal number");
        ++i;
        bool eneg = false;
        if (i < s.size() && (s[i] == '+' || s[i] == '-')) { eneg = s[i] == '-'; ++i; }
        if (i == s.size() || s[i] < '0' || s[i] > '9')
            throw std::runtime_error("invalid Rexx decimal exponent");
        int e = 0;
        for (; i < s.size(); ++i) {
            if (s[i] < '0' || s[i] > '9' || e > kMaxRexxScale)
                throw std::runtime_error("invalid Rexx decimal exponent");
            e = e * 10 + (s[i] - '0');
        }
        out.exponent += eneg ? -e : e;
    }
    if (out.exponent < -kMaxRexxScale || out.exponent > kMaxRexxScale)
        throw std::runtime_error("decimal exponent outside supported range");
    for (char c : digits) out.coefficient = out.coefficient * 10 + (c - '0');
    if (minus) out.coefficient = -out.coefficient;
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
    // upstream NumberString::stringValue: exponential when adjusted >= DIGITS or |exponent| > 2*DIGITS
    bool exponential = upstreamRule ? (adjusted >= static_cast<int>(ctx.digits) ||
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
inline Value numberResult(RexxDecimal n, const ActivationNumeric &ctx) {
    roundRexx(n, ctx);
    return Value::number(formatRexxDecimal(n, ctx));
}
inline Value numericAdd(const Value &a, const Value &b, const ActivationNumeric &ctx) {
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
    if (guardContribution) {
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
inline int numericRelation(const Value &a, const Value &b, const ActivationNumeric &ctx) {
    RexxDecimal x = parseRexxDecimal(a), y = parseRexxDecimal(b);
    // FUZZ affects comparison precision, not computation precision.
    ActivationNumeric cmp = ctx;
    cmp.digits -= cmp.fuzz;
    cmp.fuzz = 0;
    roundRexx(x, cmp);
    roundRexx(y, cmp);
    const int e = std::min(x.exponent, y.exponent);
    x.coefficient *= decimalPow10(x.exponent - e);
    y.coefficient *= decimalPow10(y.exponent - e);
    return (x.coefficient > y.coefficient) - (x.coefficient < y.coefficient);
}
inline bool numericString(const Value &v) {
    try { (void)parseRexxDecimal(v); return true; } catch (const std::runtime_error &) { return false; }
}
inline Value numericCompare(const Value &a, const std::string &op, const Value &b,
                            const ActivationNumeric &ctx) {
    // A right-hand object is never silently compared as its (empty) byte string.
    if (a.isObject() || b.isObject()) throw std::runtime_error("comparison with an object operand requires message dispatch");
    if (op == "==") return fromInteger(a.bytes == b.bytes);
    if (op == "\\==") return fromInteger(a.bytes != b.bytes);
    int rel;
    if (numericString(a) && numericString(b)) rel = numericRelation(a, b, ctx);
    else { const std::string as = trim(a.bytes), bs = trim(b.bytes); rel = (as > bs) - (as < bs); }
    if (op == "=") return fromInteger(rel == 0);
    if (op == "\\=" || op == "<>" || op == "><") return fromInteger(rel != 0);
    if (op == "<") return fromInteger(rel < 0);
    if (op == "<=") return fromInteger(rel <= 0);
    if (op == ">") return fromInteger(rel > 0);
    if (op == ">=") return fromInteger(rel >= 0);
    throw std::runtime_error("unknown decimal comparison operator");
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
    const int direction = numericRelation(step, Value::number("0"), ctx);
    if (!direction) throw std::runtime_error("DO BY 0");
    const int comparison = numericRelation(current, limit, ctx);
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
