#pragma once
// SysSleep is a RexxUtil external routine, not a BUILTIN() in ooRexx.
// This independent adapter must be selected only AFTER internal, package,
// registered, and ::REQUIRES LIBRARY routine resolution.
// Linux/POSIX semantics from ooRexx RexxUtilCommon.cpp + SysThread.cpp.
#include "minirexx_runtime.hpp"
#include <cerrno>
#include <charconv>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <ctime>
#include <limits>
#include <optional>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace rxbif_external {
using Slot = std::optional<rx::Value>;
enum class ErrorKind { Missing=901, NonNumeric=902, Range=907, TooMany=922, ObjectUnqualified=0 };
class ArgumentError final : public std::runtime_error {
public:
    const ErrorKind kind;
    explicit ArgumentError(ErrorKind k)
        : std::runtime_error(k==ErrorKind::ObjectUnqualified
            ? "SysSleep: non-scalar argument requires live Rexx object conversion"
            : "SysSleep: invalid RexxUtil routine argument"), kind(k) {}
    int rexxMajor() const noexcept { return 88; }
    int rexxMinor() const noexcept { return static_cast<int>(kind); }
};
using Sleeper = int (*)(std::uint64_t);

// Preserve one POSIX nanosleep and the errno result: ooRexx does not retry EINTR.
inline int posixLongSleep(std::uint64_t microseconds) {
    timespec rq{};
    rq.tv_sec = static_cast<time_t>(microseconds / 1000000ULL);
    rq.tv_nsec = static_cast<long>(microseconds % 1000000ULL) * 1000L;
    timespec remain{};
    return ::nanosleep(&rq, &remain) == -1 ? errno : 0;
}
inline bool numericByte(unsigned char c) { return c>='0'&&c<='9'; }
inline bool whitespace(unsigned char c) { return c==' '||c=='\t'; }

// Narrow scalar analogue of RexxUtil ObjectToDouble. Error distinctions
// are preserved; arbitrary Rexx objects belong to the hosted activation.
inline double secondsFromString(const std::string& raw) {
    std::size_t a=0,b=raw.size();
    while(a<b && whitespace(static_cast<unsigned char>(raw[a])))++a;
    while(b>a && whitespace(static_cast<unsigned char>(raw[b-1])))--b;
    if(a==b) throw ArgumentError(ErrorKind::NonNumeric);
    bool negative=false, separatedSign=false;
    if(raw[a]=='+'||raw[a]=='-') {
        negative=raw[a]=='-';++a;
        while(a<b && whitespace(static_cast<unsigned char>(raw[a]))) { separatedSign=true; ++a; }
    }
    const auto digitsStart=a;
    bool found=false, nonzero=false;
    while(a<b && numericByte(static_cast<unsigned char>(raw[a]))) {
        found=true;nonzero|=raw[a]!='0';++a;
    }
    if(a<b && raw[a]=='.') {
        ++a;
        while(a<b && numericByte(static_cast<unsigned char>(raw[a]))) {
            found=true;nonzero|=raw[a]!='0';++a;
        }
    }
    if(!found) throw ArgumentError(ErrorKind::NonNumeric);
    if(a<b && (raw[a]=='E'||raw[a]=='e')) {
        ++a;
        if(a<b && (raw[a]=='+'||raw[a]=='-')) ++a;
        const auto begin=a;
        while(a<b && numericByte(static_cast<unsigned char>(raw[a]))) ++a;
        if(begin==a) throw ArgumentError(ErrorKind::NonNumeric);
    }
    if(a!=b)throw ArgumentError(ErrorKind::NonNumeric);
    // ooRexx accepts an exact zero mantissa even with a huge exponent.
    if(!nonzero || separatedSign) return 0.0;
    // Data is now verified ASCII decimal; create a normalized string without
    // blanks between leading sign and mantissa, which Rexx allows.
    std::string text(raw.substr(digitsStart,b-digitsStart));
    if(negative)text.insert(text.begin(),'-');
    double seconds=0.0;
    const auto conversion=std::from_chars(text.data(),text.data()+text.size(),
                                           seconds,std::chars_format::general);
    if(conversion.ptr!=text.data()+text.size() ||
       conversion.ec==std::errc::invalid_argument)
        throw ArgumentError(ErrorKind::NonNumeric);
    if(conversion.ec==std::errc::result_out_of_range) {
        // from_chars reports *both* underflow and overflow as out_of_range.
        // ooRexx accepts underflow to zero but rejects overflow to infinity.
        errno=0;
        char* end=nullptr;
        seconds=std::strtod(text.c_str(),&end);
        if(end!=text.c_str()+text.size())
            throw ArgumentError(ErrorKind::NonNumeric);
    }
    if(!std::isfinite(seconds))throw ArgumentError(ErrorKind::NonNumeric);
    return seconds;
}

inline rx::Value sysSleep(const std::vector<Slot>& args, Sleeper sleep=posixLongSleep) {
    if(args.empty() || !args[0]) throw ArgumentError(ErrorKind::Missing);
    if(args.size()!=1) throw ArgumentError(ErrorKind::TooMany);
    if(args[0]->isObject())throw ArgumentError(ErrorKind::ObjectUnqualified);
    const double seconds=secondsFromString(args[0]->bytes);
    if(seconds<0.0 || seconds>2147483.0)
        throw ArgumentError(ErrorKind::Range);
    // Source implementation converts seconds to integer microseconds, truncating.
    const std::uint64_t microseconds=static_cast<std::uint64_t>(seconds*1000000.0);
    if(!sleep)throw std::invalid_argument("SysSleep: no sleep provider");
    return rx::Value::string(std::to_string(sleep(microseconds)));
}
// External-routine registry seam; callers must resolve internal/package/
// registered-library overrides before admitting the RexxUtil default.
inline bool isRexxUtilRoutine(const std::string& name) {
    if(name.size()!=8)return false;
    constexpr char literal[]="SYSSLEEP";
    for(std::size_t i=0;i<8;++i) {
        unsigned char c=static_cast<unsigned char>(name[i]);
        if(c>='a'&&c<='z')c=static_cast<unsigned char>(c-'a'+'A');
        if(c!=static_cast<unsigned char>(literal[i]))return false;
    }
    return true;
}
inline rx::Value invokeRexxUtil(const std::string& name,const std::vector<Slot>& args,
                                Sleeper sleep=posixLongSleep) {
    if(!isRexxUtilRoutine(name))throw std::invalid_argument("unknown native RexxUtil routine");
    return sysSleep(args,sleep);
}
} // namespace rxbif_external
