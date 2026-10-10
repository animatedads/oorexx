#pragma once
// Native SIGN numeric scanner for ooRexx ASCII/Linux numeric strings.
// No floating point, heap allocation, or interpreter call on this path.
// The representation is inspected bytewise and a sign is reported only for
// decimal forms accepted by the qualified ooRexx numeric grammar.
#include <string>

namespace rxbif_sign {
enum class Status { Valid, Invalid, UnqualifiedRange };
struct Parsed { Status status; int sign; };
inline bool digit(unsigned char c) { return c >= '0' && c <= '9'; }
inline bool blank(unsigned char c) { return c == ' ' || c == '\t'; }
inline Parsed parse(const std::string &s) {
    std::size_t i=0, end=s.size();
    while (i<end && blank(static_cast<unsigned char>(s[i]))) ++i;
    while (end>i && blank(static_cast<unsigned char>(s[end-1]))) --end;
    if (i==end) return {Status::Invalid,0};
    int polarity=1;
    if (s[i]=='+' || s[i]=='-') { polarity = (s[i]=='-' ? -1 : 1); ++i;
        while (i<end && blank(static_cast<unsigned char>(s[i]))) ++i; }
    bool foundDigit=false, nonzero=false;
    while (i<end && digit(static_cast<unsigned char>(s[i]))) {
        foundDigit=true; nonzero |= s[i]!='0'; ++i;
    }
    if (i<end && s[i]=='.') {
        ++i;
        while (i<end && digit(static_cast<unsigned char>(s[i]))) {
            foundDigit=true; nonzero |= s[i]!='0'; ++i;
        }
    }
    if (!foundDigit) return {Status::Invalid,0};
    unsigned exponent=0;
    bool exponentOverflow=false;
    if (i<end && (s[i]=='e' || s[i]=='E')) {
        ++i;
        if (i<end && (s[i]=='+' || s[i]=='-')) ++i;
        if (i==end || !digit(static_cast<unsigned char>(s[i]))) return {Status::Invalid,0};
        // ooRexx 5.3 exponent parser has a maximum absolute exponent of
        // 999999999; prevent overflow while reading arbitrarily long input.
        while (i<end && digit(static_cast<unsigned char>(s[i]))) {
            const unsigned n=static_cast<unsigned>(s[i]-'0');
            if (exponent > (999999999U-n)/10U) exponentOverflow=true;
            if (!exponentOverflow) exponent=exponent*10U+n;
            ++i;
        }
    }
    if (i!=end) return {Status::Invalid,0};
    // Zero stays zero even with a huge syntactically valid exponent.
    if (!nonzero) return {Status::Valid,0};
    if (exponentOverflow) return {Status::Invalid,0};
    // Near Rexx MAX_EXPONENT, the number of significant digits changes
    // whether a normalized number is in range. Do not guess here.
    if (exponent >= 999000000U) return {Status::UnqualifiedRange,0};
    return {Status::Valid, nonzero ? polarity : 0};
}
} // namespace rxbif_sign
