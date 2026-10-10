#pragma once
// Fast scalar TRUNC: decimal string arithmetic, per-call NUMERIC DIGITS.
// Native subset has explicit size/exponent limits and typed unsupported status.
// Correctness: round to activation precision *before* decimal truncation.
#include <algorithm>
#include <cstddef>
#include <string>
#include <string_view>

namespace rxbif_trunc {
enum class Status { Valid, Invalid, Unsupported };
struct Output { Status status; std::string bytes; };
inline bool dec(unsigned char c) { return c >= '0' && c <= '9'; }
inline bool blank(unsigned char c) { return c == ' ' || c == '\t'; }
// Only canonical unsigned decimal counts are handled without numeric
// coercion. Other syntactically valid Rexx numeric strings are deliberately
// deferred to the real activation, which may round them under NUMERIC DIGITS.
enum class PlacesKind { Canonical, NumericOther, Invalid };
struct Places { PlacesKind kind; std::size_t count; };
inline Places parsePlaces(const std::string &s) {
    std::size_t a=0,b=s.size();
    while(a<b && blank(static_cast<unsigned char>(s[a])))++a;
    while(b>a && blank(static_cast<unsigned char>(s[b-1])))--b;
    if(a==b)return {PlacesKind::Invalid,0};
    bool canonical=a==0 && b==s.size();
    bool negative=false;
    if(s[a]=='+' || s[a]=='-') {
        negative=s[a]=='-';canonical=false;++a;
        while(a<b && blank(static_cast<unsigned char>(s[a])))++a;
    }
    const std::size_t begin=a;
    std::size_t result=0;
    while(a<b && dec(static_cast<unsigned char>(s[a]))) {
        if(result<=4096)result=result*10+(s[a]-'0');
        ++a;
    }
    bool found=a>begin;
    const bool onlyIntegerPart=found;
    bool hasFractionOrExponent=false;
    if(a<b && s[a]=='.') {
        hasFractionOrExponent=true; canonical=false;++a;
        while(a<b && dec(static_cast<unsigned char>(s[a]))) { found=true;++a; }
    }
    if(!found)return {PlacesKind::Invalid,0};
    if(a<b && (s[a]=='e'||s[a]=='E')) {
        hasFractionOrExponent=true; canonical=false;++a;
        if(a<b && (s[a]=='+'||s[a]=='-'))++a;
        const auto expStart=a;
        while(a<b && dec(static_cast<unsigned char>(s[a])))++a;
        if(a==expStart)return {PlacesKind::Invalid,0};
    }
    if(a!=b)return {PlacesKind::Invalid,0};
    if(negative && onlyIntegerPart && !hasFractionOrExponent && result!=0)
        return {PlacesKind::Invalid,0};
    if(!canonical || result>4096)return {PlacesKind::NumericOther,0};
    return {PlacesKind::Canonical,result};
}
inline Output run(const std::string& original, std::size_t precision,
                  std::size_t decimals) {
    constexpr std::size_t cap=8192;
    if (!precision || precision>4096 || decimals>4096 || original.size()>8192)
        return {Status::Unsupported,{}};
    std::size_t left=0,right=original.size();
    while(left<right && blank(static_cast<unsigned char>(original[left]))) ++left;
    while(right>left && blank(static_cast<unsigned char>(original[right-1]))) --right;
    if(left==right) return {Status::Invalid,{}};
    int polarity=1;
    if(original[left]=='+' || original[left]=='-') {
        if(original[left]=='-') polarity=-1;
        ++left;
        while(left<right && blank(static_cast<unsigned char>(original[left]))) ++left;
    }
    std::string digits;
    digits.reserve(right-left);
    std::size_t whole=0;bool seen=false;
    while(left<right && dec(static_cast<unsigned char>(original[left]))) {
        digits.push_back(original[left++]); ++whole;seen=true;
    }
    if(left<right && original[left]=='.') {
        ++left;
        while(left<right && dec(static_cast<unsigned char>(original[left]))) {
            digits.push_back(original[left++]);seen=true;
        }
    }
    if(!seen) return {Status::Invalid,{}};
    long long exponent=0;bool expNegative=false;
    bool hugeExponent=false;
    if(left<right && (original[left]=='e'||original[left]=='E')) {
        ++left;
        if(left<right && (original[left]=='+' || original[left]=='-'))
            expNegative=original[left++]=='-';
        if(left==right || !dec(static_cast<unsigned char>(original[left])))
            return {Status::Invalid,{}};
        for(;left<right && dec(static_cast<unsigned char>(original[left]));++left) {
            const int v=original[left]-'0';
            if(exponent>1000000) hugeExponent=true;
            if(!hugeExponent) exponent=exponent*10+v;
        }
    }
    if(left!=right) return {Status::Invalid,{}};
    if(hugeExponent) return {Status::Unsupported,{}};
    if(expNegative)exponent=-exponent;
    const auto first=digits.find_first_not_of('0');
    const std::size_t total=decimals?decimals+2:1;
    if(total>cap) return {Status::Unsupported,{}};
    if(first==std::string::npos) {
        if(decimals==0)return {Status::Valid,"0"};
        return {Status::Valid,"0."+std::string(decimals,'0')};
    }
    // Index 0 of the significant digits lies at this decimal-power position.
    long long pos=static_cast<long long>(whole) + exponent - static_cast<long long>(first);
    digits.erase(0,first);
    // Normalize insignificant trailing zeros before significant-digit rounding.
    while(digits.size()>1 && digits.back()=='0')digits.pop_back();
    if(digits.size()>precision) {
        bool up=digits[precision]>='5';
        digits.resize(precision);
        if(up) {
            std::size_t n=digits.size();
            while(n && digits[n-1]=='9')digits[--n]='0';
            if(n)++digits[n-1];
            else {digits.insert(digits.begin(),'1');++pos;}
        }
    }
    // A TRUNC result is expanded fixed decimal, never scientific notation.
    // Bound output allocations, and defer very large / very small exponents.
    if(pos > static_cast<long long>(cap)-static_cast<long long>(decimals)-2 ||
       pos < -static_cast<long long>(cap)) return {Status::Unsupported,{}};
    std::string out;
    if(pos<=0)out="0";
    else {
        const std::size_t before=static_cast<std::size_t>(pos);
        out=digits.substr(0,before);
        if(before>digits.size())out.append(before-digits.size(),'0');
    }
    if(decimals) {
        out.push_back('.');
        for(std::size_t j=0;j<decimals;++j) {
            const long long index=pos+static_cast<long long>(j);
            out.push_back(index>=0 && index<static_cast<long long>(digits.size())
                    ? digits[static_cast<std::size_t>(index)] : '0');
        }
    }
    bool nonzero=false;
    for(char c : out) if(c>='1'&&c<='9') { nonzero=true;break; }
    if(polarity<0 && nonzero) out.insert(out.begin(),'-');
    if(out.size()>cap)return {Status::Unsupported,{}};
    return {Status::Valid,std::move(out)};
}
} // namespace rxbif_trunc
