#pragma once
// X2D native numeric subset: Rexx grouped hex, optional nibble width,
// caller NUMERIC DIGITS and signed two's-complement result.
#include <cstddef>
#include <string>
#include <vector>
#include <stdexcept>
#include <utility>
#include <limits>

namespace rxbif_x2d {
enum class Status { Value, InvalidHex, InvalidWidth, Precision, Unsupported };
struct Result { Status status; std::string decimal; };
inline int nibble(unsigned char c) {
    if(c>='0'&&c<='9')return c-'0';
    if(c>='A'&&c<='F')return c-'A'+10;
    if(c>='a'&&c<='f')return c-'a'+10;
    return -1;
}
// Rexx hex grouping: first run may be odd; subsequent runs are even.
inline Result run(const std::string& source, bool specified, std::size_t width, std::size_t precision) {
    // ooRexx short-circuits width zero *before* validating hex source.
    if(specified && width==0)return {Status::Value,"0"};
    if(!precision || precision>4096 || source.size()>8192)
        return {Status::Unsupported,{}};
    std::vector<unsigned char> hex;
    hex.reserve(source.size());
    bool inSpace=false, sawSpace=false;
    unsigned remainder=0;
    if(!source.empty() && (source[0]==' '||source[0]=='\t'))return {Status::InvalidHex,{}};
    for(unsigned char c:source){
        int v=nibble(c);
        if(v>=0){hex.push_back(static_cast<unsigned char>(v));inSpace=false;}
        else if(c==' '||c=='\t'){
            if(!sawSpace){sawSpace=true;remainder=hex.size()%2;}
            else if(hex.size()%2!=remainder)return {Status::InvalidHex,{}};
            inSpace=true;
        } else return {Status::InvalidHex,{}};
    }
    if(inSpace || (sawSpace && hex.size()%2!=remainder))return {Status::InvalidHex,{}};
    const bool neg=specified && width<=hex.size() && (hex[hex.size()-width]&8)!=0;
    // Width trims leftmost nibbles; a larger width pads zero and is unsigned.
    if(specified && width<hex.size())hex.erase(hex.begin(),hex.end()-static_cast<std::ptrdiff_t>(width));
    if(neg){
        // Two's complement only in the selected nibble width.
        unsigned carry=1;
        for(std::size_t i=hex.size();i>0;--i){
            const unsigned v=(15U-hex[i-1])+carry;
            hex[i-1]=static_cast<unsigned char>(v&15U);
            carry=v>>4U;
        }
    }
    // Base-16 -> exact decimal. Bounded by caller NUMERIC DIGITS, never float.
    std::string decimal="0";
    for(unsigned v:hex){
        unsigned carry=v;
        for(std::size_t j=decimal.size();j>0;--j){
            const unsigned n=static_cast<unsigned>(decimal[j-1]-'0')*16U+carry;
            decimal[j-1]=static_cast<char>('0'+n%10U);carry=n/10U;
        }
        while(carry){decimal.insert(decimal.begin(),static_cast<char>('0'+carry%10U));carry/=10U;}
        if(decimal.size()>precision)return {Status::Precision,{}};
    }
    if(neg && decimal!="0")decimal.insert(decimal.begin(),'-');
    return {Status::Value,std::move(decimal)};
}
// The Rexx optional-integer conversion accepts noncanonical numeric forms.
// Only strict ASCII digits are qualified in this native subset; other inputs
// remain interpreter-owned, rather than being guessed from text.
enum class WidthKind { Canonical, Invalid, Unqualified };
struct Width { WidthKind kind; std::size_t value; };
inline Width parseWidth(const std::string& text) {
    if(text.empty())return {WidthKind::Invalid,0};
    std::size_t result=0;
    bool digitsOnly=true;
    for(unsigned char c:text) {
        if(c<'0'||c>'9'){digitsOnly=false;break;}
        const unsigned v=c-'0';
        if(result>(std::numeric_limits<std::size_t>::max()-v)/10)
            return {WidthKind::Unqualified,0};
        result=result*10+v;
    }
    if(digitsOnly)return {WidthKind::Canonical,result};
    // NumberString can convert forms like +1, 1.0 or 1E0 to an integer,
    // but doing so requires Rexx's whole-number precision semantics.
    // Check lexical numeric validity here; malformed names never fallback.
    std::size_t i=0,end=text.size();
    while(i<end && (text[i]==' '||text[i]=='\t'))++i;
    while(end>i && (text[end-1]==' '||text[end-1]=='\t'))--end;
    if(i==end)return {WidthKind::Invalid,0};
    bool negative=false;
    if(text[i]=='+'||text[i]=='-') {
        negative=text[i]=='-';++i;
        while(i<end && (text[i]==' '||text[i]=='\t'))++i;
    }
    bool found=false,nonzero=false;
    while(i<end && text[i]>='0'&&text[i]<='9') {
        found=true;nonzero|=text[i]!='0';++i;
    }
    if(i<end && text[i]=='.') {
        ++i;
        while(i<end && text[i]>='0'&&text[i]<='9') {
            found=true;nonzero|=text[i]!='0';++i;
        }
    }
    if(!found)return {WidthKind::Invalid,0};
    if(i<end && (text[i]=='e'||text[i]=='E')) {
        ++i;if(i<end && (text[i]=='+'||text[i]=='-'))++i;
        const std::size_t begin=i;
        while(i<end && text[i]>='0'&&text[i]<='9')++i;
        if(begin==i)return {WidthKind::Invalid,0};
    }
    if(i!=end || (negative && nonzero))return {WidthKind::Invalid,0};
    return {WidthKind::Unqualified,0};
}
} // namespace rxbif_x2d
