/* rx2cpp standalone built-in function pack, v0.4. SPDX-License-Identifier: MIT.
   Based on behavioral review of ooRexx BuiltinFunctions.cpp and the delegated
   StringClass/StringUtil/RexxDateTime semantics, NOT copied native interpreter
   implementation. Traced to ooRexx/ooRexx GitHub master blob
   05ea58114e9e5b59a1cceebf8dd418b78058d342. See CLOCK_SEMANTICS.md and README.md.
   This conservative native subset rejects cases not yet qualified. */
#include "rxbif.hpp"
#include "rxbif_sign.hpp"
#include <array>
#include <cstdint>
#include <ctime>
#include <iomanip>
#include <limits>
#include <sstream>
#include <stdexcept>

namespace rxbif {
namespace {
const std::vector<Signature> kSpecs = {
    {"SIGN",1,1}, {"ABBREV",2,3}, {"B2X",1,1}, {"BITAND",1,3}, {"BITOR",1,3}, {"BITXOR",1,3}, {"C2X",1,1}, {"CENTER",2,3}, {"CENTRE",2,3},
    {"CHANGESTR",3,4}, {"COMPARE",2,3}, {"COPIES",2,2}, {"COUNTSTR",2,2},
    {"DATE",0,5}, {"DELSTR",1,3}, {"DELWORD",2,3}, {"INSERT",2,5},
    {"LASTPOS",2,4}, {"LEFT",2,3}, {"LOWER",1,3}, {"OVERLAY",2,5},
    {"POS",2,4}, {"REVERSE",1,1}, {"RIGHT",2,3}, {"SPACE",1,3},
    {"STRIP",1,3}, {"SUBSTR",2,4}, {"SUBWORD",2,3}, {"TIME",0,3},
    {"UPPER",1,3}, {"WORD",2,2}, {"WORDINDEX",2,2}, {"WORDLENGTH",2,2},
    {"WORDPOS",2,3}, {"WORDS",1,1}, {"X2B",1,1}, {"X2C",1,1}
};
[[noreturn]] void bad(const std::string &n, const std::string &why) {
    // Only intentionally unimplemented native *subsets* are retriable.
    // This list is deliberately exact/auditable: invalid options, malformed
    // input, quota failures and C++ errors must never run a second time.
    const bool unsupported =
        why == "string conversion requires an unbridged object" ||
        why == "unsupported numeric representation requiring Rexx NUMERIC context" ||
        why == "unsupported input style" ||
        why == "unsupported input time style" ||
        why == "implementation not yet available" ||
        why == "bit-group layout not yet qualified" ||
        why == "hex-group layout not yet qualified" ||
        why == "odd length hex: require qualified hex pairs";
    const std::string diagnostic = "BIF " + n + ": " + why;
    if (unsupported) throw NativeSubsetUnsupported(diagnostic);
    throw std::runtime_error(diagnostic);
}
const std::string &str(const std::vector<rx::Value> &a, size_t i, const std::string &n) {
    if (i >= a.size() || a[i].isObject()) bad(n,"string conversion requires an unbridged object");
    return a[i].bytes;
}
// Numeric parameters in this add-on require exact positive / nonnegative
// integers, like ooRexx's required_integer validations. No silent truncation.
// A noncanonical numeric token can still denote a whole number in ooRexx,
// e.g. 2.0 or 2E0. Parsing those correctly requires the caller's NUMERIC
// context and arbitrary-precision handling; they are a *coverage gap*, not an
// invalid argument. Truly malformed or negative indices must never retry.
bool numericForm(const std::string &input) {
    const auto first=input.find_first_not_of(" \t");
    if(first==std::string::npos)return false;
    const auto last=input.find_last_not_of(" \t");
    size_t i=first;
    bool negative=false;
    if(input[i]=='+'||input[i]=='-'){negative=input[i]=='-';++i;}
    std::string digits;
    size_t fractional=0;
    while(i<=last&&input[i]>='0'&&input[i]<='9')digits+=input[i++];
    if(i<=last&&input[i]=='.'){
        ++i;
        while(i<=last&&input[i]>='0'&&input[i]<='9'){
            digits+=input[i++];++fractional;
        }
    }
    if(digits.empty())return false;
    long long exponent=0;
    if(i<=last&&(input[i]=='e'||input[i]=='E')){
        ++i;bool negExponent=false;
        if(i<=last&&(input[i]=='+'||input[i]=='-'))negExponent=input[i++]=='-';
        size_t exponentDigits=0;
        while(i<=last&&input[i]>='0'&&input[i]<='9'){
            // Saturate safely; huge exponents are delegated, not parsed here.
            exponent=std::min(1000000LL,exponent*10+input[i++]-'0');
            ++exponentDigits;
        }
        if(exponentDigits==0)return false;
        if(negExponent)exponent=-exponent;
    }
    if(i!=last+1)return false;
    const bool nonzero=digits.find_first_not_of('0')!=std::string::npos;
    if(negative&&nonzero)return false; // below every admitted min bound
    const long long shift=exponent-static_cast<long long>(fractional);
    if(shift>=0)return true;
    const size_t needed=static_cast<size_t>(-shift);
    if(needed>digits.size())return !nonzero;
    return digits.find_first_not_of('0',digits.size()-needed)==std::string::npos;
}
std::int64_t integer(const std::vector<rx::Value> &a, size_t i, const std::string &n, std::int64_t min=0) {
    if (i >= a.size()) bad(n,"required number missing");
    std::int64_t x=0;
    if (!rx::tryInteger(a[i], x)) {
        if (!a[i].isObject() && numericForm(a[i].bytes))
            bad(n,"unsupported numeric representation requiring Rexx NUMERIC context");
        bad(n,"invalid numeric integer argument");
    }
    if(x<min)bad(n,"integer argument outside allowed range");
    return x;
}
size_t count(const std::vector<rx::Value> &a, size_t i, const std::string &n, std::int64_t min=0) {
    auto x=integer(a,i,n,min);
    if (static_cast<std::uint64_t>(x)>std::numeric_limits<size_t>::max()) bad(n,"size overflow");
    return static_cast<size_t>(x);
}
size_t len(const std::string &s){return s.size();}
rx::Value sv(std::string s){return rx::Value::string(s);}
rx::Value iv(size_t x){
    if(x > static_cast<size_t>(std::numeric_limits<std::int64_t>::max())) bad("RESULT", "length overflow");
    return rx::fromInteger(static_cast<std::int64_t>(x));
}
std::string repeat(const std::string &s, size_t n,const std::string &f) {
    if(s.size() && n>std::numeric_limits<size_t>::max()/s.size()) bad(f,"size overflow");
    if(s.size()*n>100000000) bad(f,"allocation exceeds qualified limit (100 MB)");
    std::string out; out.reserve(s.size()*n);
    for(size_t i=0;i<n;i++)out+=s;
    return out;
}
std::string pad(const std::vector<rx::Value> &a,size_t i,const std::string &n,char def=' ') {
    if(i>=a.size()) return std::string(1,def);
    std::string s=str(a,i,n);
    if(s.size()!=1) bad(n,"pad must be one byte");
    return s;
}
bool ws(char c){return c==' ' || c=='\t';}
struct Word {size_t pos;size_t size;};
std::vector<Word> words(const std::string &s){
    std::vector<Word> w;
    for(size_t i=0;i<s.size();){
        while(i<s.size()&&ws(s[i]))++i;
        size_t b=i;
        while(i<s.size()&&!ws(s[i]))++i;
        if(i>b) w.push_back({b,i-b});
    }
    return w;
}
std::string wordAt(const std::string &s, const std::vector<Word> &w, size_t n){
    if(!n || n>w.size())return "";
    auto z=w[n-1];return s.substr(z.pos,z.size);
}
char caseMode(const std::string &s,const std::string &f) {
    if(s.empty())bad(f,"empty option");
    char c=s[0]; if(c>='a'&&c<='z')c-=32;return c;
}
std::string formatNum(int x,int width) {std::ostringstream os;os<<std::setfill('0')<<std::setw(width)<<x;return os.str();}
struct Date {int y,m,d,h=0,mi=0,s=0,us=0;};
bool leap(int y){return y%4==0 && (y%100!=0 || y%400==0);}
int dim(int y,int m){const int d[]={0,31,28,31,30,31,30,31,31,30,31,30,31};return m>=1&&m<=12?d[m]+(m==2&&leap(y)):0;}
bool valid(const Date &d){return d.y>=1&&d.y<=9999&&d.m>=1&&d.m<=12&&d.d>=1&&d.d<=dim(d.y,d.m) && d.h>=0&&d.h<24&&d.mi>=0&&d.mi<60&&d.s>=0&&d.s<60 && d.us>=0&&d.us<1000000;}
// Gregorian inverse conversions, with 0001-01-01 == Rexx base day 1.
std::int64_t unixDays(int y,unsigned m,unsigned d){
    y-=m<=2; const int era=(y>=0?y:y-399)/400; const unsigned yoe=static_cast<unsigned>(y-era*400);
    const unsigned doy=(153*(m+(m>2?-3:9))+2)/5+d-1;
    const unsigned yrea=yoe*365+yoe/4-yoe/100+doy;
    return era*146097+static_cast<int>(yrea)-719468;
}
Date fromUnixDays(std::int64_t z){
    z+=719468;const std::int64_t era=(z>=0?z:z-146096)/146097;
    const unsigned doe=static_cast<unsigned>(z-era*146097);
    const unsigned yoe=(doe-doe/1460+doe/36524-doe/146096)/365;
    int y=static_cast<int>(yoe)+static_cast<int>(era)*400;
    const unsigned doy=doe-(365*yoe+yoe/4-yoe/100);
    const unsigned mp=(5*doy+2)/153;
    const unsigned d=doy-(153*mp+2)/5+1;
    const unsigned m=mp+(mp<10?3:-9);y+=(m<=2);
    return {y,static_cast<int>(m),static_cast<int>(d)};
}
int yearDay(const Date &d){int x=d.d;for(int m=1;m<d.m;m++)x+=dim(d.y,m);return x;}
std::int64_t baseDay(const Date &d){return unixDays(d.y,d.m,d.d)+719162;}
std::int64_t baseMicros(const Date &d){return baseDay(d)*86400000000LL+ ((d.h*60LL+d.mi)*60LL+d.s)*1000000LL+d.us;}
std::int64_t unixSeconds(const Date &d,std::int64_t offsetUs){(void)offsetUs;return unixDays(d.y,d.m,d.d)*86400LL+ d.h*3600LL+d.mi*60LL+d.s;}
Date fromBaseMicros(std::int64_t val){
    if(val<0)bad("DATE/TIME","negative base time");
    Date d=fromUnixDays(val/86400000000LL-719162);
    auto z=val%86400000000LL; d.h=static_cast<int>(z/3600000000LL);z%=3600000000LL;
    d.mi=static_cast<int>(z/60000000LL);z%=60000000LL;d.s=static_cast<int>(z/1000000LL);d.us=static_cast<int>(z%1000000LL);
    if(!valid(d))bad("DATE/TIME","base time outside supported calendar");
    return d;
}
Date fromUnixSeconds(std::int64_t epoch,std::int64_t offsetUs){
    (void)offsetUs; // ooRexx T/F input conversion retains the timestamp fields; O reports the activation zone.
    auto days=epoch/86400LL,remaining=epoch%86400LL;
    if(remaining<0){--days;remaining+=86400;}
    Date d=fromUnixDays(days);
    d.h=static_cast<int>(remaining/3600);d.mi=static_cast<int>(remaining/60%60);d.s=static_cast<int>(remaining%60);
    if(!valid(d))bad("DATE/TIME","tick value outside supported calendar");
    return d;
}
std::int64_t parseWhole(const std::string &s,const std::string &who){
    if(s.empty())bad(who,"empty numeric input");
    std::int64_t x=0;
    if(!rx::tryInteger(sv(s),x))bad(who,"invalid numeric input");
    return x;
}
int dec(const std::string &s,size_t pos,size_t n){
    if(pos+n>s.size() || n==0)return -1;
    int x=0;for(size_t i=pos;i<pos+n;i++){if(s[i]<'0'||s[i]>'9')return -1;x=x*10+s[i]-'0';}return x;
}
std::vector<std::string> split(const std::string &s,char delim){
    std::vector<std::string> out;size_t prev=0;
    for(size_t i=0;i<s.size();i++)if(s[i]==delim){out.push_back(s.substr(prev,i-prev));prev=i+1;}
    out.push_back(s.substr(prev));return out;
}
char separatorOption(const std::string &sep,const std::string &name){
    if(sep.size()>1 || (!sep.empty() && ((sep[0]>='0'&&sep[0]<='9') ||
       (sep[0]>='a'&&sep[0]<='z') ||(sep[0]>='A'&&sep[0]<='Z'))))bad(name,"separator must be empty or single non-alphanumeric byte");
    return sep.empty()?'\0':sep[0];
}
int shortYear(int yy,int nowYear){
    // ooRexx uses a sliding century window (roughly 50 years either side).
    const int century=nowYear/100*100;
    int year=century+yy;
    if(year<nowYear-50)year+=100;
    if(year>nowYear+49)year-=100;
    return year;
}
Date parseDate(const std::string &src,char style,Date now,std::int64_t offsetUs,bool customSep,char sep){
    Date d{0,0,0};
    if(style=='B'){const auto b=parseWhole(src,"DATE");if(b<0||b>3652058)bad("DATE","invalid base date");d=fromUnixDays(b-719162);}
    else if(style=='F')d=fromBaseMicros(parseWhole(src,"DATE"));
    else if(style=='T')d=fromUnixSeconds(parseWhole(src,"DATE"),offsetUs);
    else if(style=='D'){
        auto day=parseWhole(src,"DATE");
        if(day<1||day>365+static_cast<int>(leap(now.y)))bad("DATE","invalid day-of-year");
        d=fromUnixDays(unixDays(now.y,1,1)+day-1);
    }
    else if(style=='S' && !customSep && src.size()==8){d={dec(src,0,4),dec(src,4,2),dec(src,6,2)};}
    else if(style=='I' || style=='S' || style=='E'|| style=='U'|| style=='O'){
        const char used=customSep?sep:(style=='I'?'-':'/');
        if(used=='\0'){
            if(src.size()==8){d={dec(src,0,4),dec(src,4,2),dec(src,6,2)};}
            else if(src.size()==6 && (style=='E'||style=='U'||style=='O')){
                const int a=dec(src,0,2),b=dec(src,2,2),y=shortYear(dec(src,4,2),now.y);
                d=style=='E'?Date{y,b,a}:style=='U'?Date{y,a,b}:Date{shortYear(a,now.y),b,dec(src,4,2)};
            } else bad("DATE","invalid compact date");
        }else{
            auto f=split(src,used);
            if(f.size()!=3)bad("DATE","date must have three fields");
            if(style=='I'||style=='S'){
                if(f[0].size()!=4||f[1].size()!=2||f[2].size()!=2)bad("DATE","invalid ISO/standard field widths");
                d={dec(f[0],0,4),dec(f[1],0,2),dec(f[2],0,2)};
            }else{
                if(f[0].size()!=2||f[1].size()!=2||f[2].size()!=2)bad("DATE","invalid short-date field widths");
                int a=dec(f[0],0,2),b=dec(f[1],0,2),c=dec(f[2],0,2);
                if(style=='E')d={shortYear(c,now.y),b,a};
                if(style=='U')d={shortYear(c,now.y),a,b};
                if(style=='O')d={shortYear(a,now.y),b,c};
            }
        }
    }
    else if(style=='N'){
        // Canonical normal-date form. The real interpreter also accepts
        // certain localized variants; reject those until qualified.
        const char used=customSep?sep:' ';
        if(used=='\0')bad("DATE","normal input requires a separator");
        auto f=split(src,used); if(f.size()!=3||f[1].size()!=3)bad("DATE","invalid normal-date fields");
        static const char*mons[]={"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"};
        int m=0;std::string mid=f[1];for(auto &c:mid)if(c>='a'&&c<='z')c-=32;
        for(int i=0;i<12;i++){std::string cmp=mons[i];for(auto &c:cmp)if(c>='a'&&c<='z')c-=32;if(cmp==mid)m=i+1;}
        d={dec(f[2],0,f[2].size()),m,dec(f[0],0,f[0].size())};
    }else bad("DATE","unsupported input style");
    if(!valid(d))bad("DATE","invalid calendar date");
    return d;
}
Date nowDate(const Context &c){
    const auto time=std::chrono::system_clock::to_time_t(c.activationTime);
    std::tm t{};
#ifdef _WIN32
    if(localtime_s(&t,&time)!=0)bad("DATE/TIME","local clock conversion failed");
#else
    if(!localtime_r(&time,&t))bad("DATE/TIME","local clock conversion failed");
#endif
    Date d{t.tm_year+1900,t.tm_mon+1,t.tm_mday,t.tm_hour,t.tm_min,t.tm_sec,0};
    auto micros=std::chrono::duration_cast<std::chrono::microseconds>(c.activationTime.time_since_epoch()).count();
    d.us=static_cast<int>((micros%1000000+1000000)%1000000);return d;
}
std::int64_t localOffsetMicroseconds(const Context &c){
    // Offset of the captured activation instant, never of a parsed historical date.
    auto d=nowDate(c);auto utc=std::chrono::duration_cast<std::chrono::seconds>(c.activationTime.time_since_epoch()).count();
    return (unixDays(d.y,d.m,d.d)*86400LL+d.h*3600LL+d.mi*60LL+d.s-utc)*1000000LL;
}
std::string dateFormat(const Date &d,char style,bool customSep,char separator,std::int64_t tz){
    static const char*mon[]={"","January","February","March","April","May","June","July","August","September","October","November","December"};
    static const char*wd[]={"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"};
    const auto two=formatNum(d.y%100,2);
    if(customSep && std::string("EINOSU").find(style)==std::string::npos)bad("DATE","separator incompatible with output style");
    const std::string se=(customSep && separator!='\0')?std::string(1,separator):"";
    const std::string is=customSep?se:"-", slash=customSep?se:"/", normal=customSep?se:" ";
    switch(style){
      case 'I':return formatNum(d.y,4)+is+formatNum(d.m,2)+is+formatNum(d.d,2);
      case 'S':return formatNum(d.y,4)+se+formatNum(d.m,2)+se+formatNum(d.d,2);
      case 'N':return std::to_string(d.d)+normal+std::string(mon[d.m]).substr(0,3)+normal+formatNum(d.y,4);
      case 'O':return two+slash+formatNum(d.m,2)+slash+formatNum(d.d,2);
      case 'U':return formatNum(d.m,2)+slash+formatNum(d.d,2)+slash+two;
      case 'E':return formatNum(d.d,2)+slash+formatNum(d.m,2)+slash+two;
      case 'M':return mon[d.m];
      case 'L':return std::to_string(d.d)+" "+mon[d.m]+" "+formatNum(d.y,4);
      case 'W':return wd[((unixDays(d.y,d.m,d.d)+4)%7+7)%7];
      case 'B':return std::to_string(baseDay(d));
      case 'F':return std::to_string(baseMicros(d));
      case 'T':return std::to_string(unixSeconds(d,tz));
      case 'D':return std::to_string(yearDay(d));
      default:bad("DATE","invalid output style");
    }
}
Date parseTime(const std::string &src,char style,Date d,std::int64_t tz){
    d.y=1;d.m=1;d.d=1;d.h=d.mi=d.s=d.us=0;
    if(style=='N' && src.size()==8 && src[2]==':'&&src[5]==':'){
        d.h=dec(src,0,2);d.mi=dec(src,3,2);d.s=dec(src,6,2);
    } else if(style=='L' && src.size()>=10 && src.size()<=15 && src[2]==':'&&src[5]==':'&&src[8]=='.'){
        d.h=dec(src,0,2);d.mi=dec(src,3,2);d.s=dec(src,6,2);
        std::string frac=src.substr(9); if(frac.empty()||frac.size()>6)bad("TIME","invalid fractional seconds");
        while(frac.size()<6)frac+='0';
        d.us=dec(frac,0,6);
    } else if(style=='C'){
        // Standard civil-format parser: 12-hour clock with am/pm suffix.
        if(src.size()<5||src.size()>7)bad("TIME","invalid civil time");
        std::string low=src;for(auto &c:low)if(c>='A'&&c<='Z')c+=32;
        if(low.substr(low.size()-2)!="am" && low.substr(low.size()-2)!="pm")bad("TIME","invalid civil suffix");
        std::string hhmm=low.substr(0,low.size()-2);
        auto colon=hhmm.find(':'); if(colon==std::string::npos||colon<1||colon>2||hhmm.size()-colon!=3)bad("TIME","invalid civil digits");
        auto h=dec(hhmm,0,colon);auto mi=dec(hhmm,colon+1,2);
        if(h<1||h>12||mi>59)bad("TIME","invalid civil clock");
        d.h=h%12+(low.substr(low.size()-2)=="pm"?12:0);d.mi=mi;
    }else if(style=='H'||style=='M'||style=='S'){
        auto n=parseWhole(src,"TIME");
        if(n<0||n>(style=='H'?23:(style=='M'?1439:86399)))bad("TIME","numeric input out of range");
        d.h=style=='H'?static_cast<int>(n):style=='M'?static_cast<int>(n/60):static_cast<int>(n/3600);
        d.mi=style=='H'?0:style=='M'?static_cast<int>(n%60):static_cast<int>(n/60%60);
        d.s=style=='S'?static_cast<int>(n%60):0;
    }else if(style=='F')d=fromBaseMicros(parseWhole(src,"TIME"));
    else if(style=='T')d=fromUnixSeconds(parseWhole(src,"TIME"),tz);
    else bad("TIME","unsupported input time style");
    if(!valid(d))bad("TIME","invalid time");
    return d;
}
std::string timeFormat(const Date &d,char style,std::int64_t tz){
    const auto hh=formatNum(d.h,2)+":"+formatNum(d.mi,2);
    switch(style){
      case 'N':return hh+":"+formatNum(d.s,2);
      case 'L':return hh+":"+formatNum(d.s,2)+"."+formatNum(d.us,6);
      case 'C':return std::to_string((d.h+11)%12+1)+":"+formatNum(d.mi,2)+(d.h<12?"am":"pm");
      case 'H':return std::to_string(d.h);
      case 'M':return std::to_string(d.h*60+d.mi);
      case 'S':return std::to_string(d.h*3600+d.mi*60+d.s);
      case 'F':return std::to_string(baseMicros(d));
      case 'T':return std::to_string(unixSeconds(d,tz));
      case 'O':return std::to_string(tz);
      default:bad("TIME","invalid output time style");
    }
}
} // namespace
const std::vector<Signature>& signatures(){return kSpecs;}
rx::Value invoke(const std::string &name,const std::vector<rx::Value> &a,Context &c){
    const Signature *spec=nullptr;
    for(const auto &s:kSpecs)if(name==s.name){spec=&s;break;}
    if(!spec)bad(name,"not in add-on registry");
    if(a.size()<spec->minArgs||a.size()>spec->maxArgs)bad(name,"incorrect argument count");
    const auto get=[&](size_t i)->const std::string&{return str(a,i,name);};
    const auto ct=[&](size_t i,std::int64_t mi=0)->size_t{return count(a,i,name,mi);};
    if(name=="SIGN") {
        const auto result=rxbif_sign::parse(get(0));
        if(result.status==rxbif_sign::Status::UnqualifiedRange)
            throw NativeSubsetUnsupported("BIF SIGN: exponent boundary requires ooRexx numeric normalization");
        if(result.status!=rxbif_sign::Status::Valid)bad(name,"invalid numeric argument");
        return sv(result.sign==0 ? "0" : result.sign>0 ? "1" : "-1");
    }
    if(name=="DATE"){
        const char style=a.empty()?'N':caseMode(get(0),name);
        Date now=nowDate(c),d=now;
        const auto tz=localOffsetMicroseconds(c);
        bool outputSep=a.size()>=4;
        char sep=outputSep?separatorOption(get(3),name):'\0';
            if(a.size()>=2){
            char in=a.size()>=3?caseMode(get(2),name):'N';
            bool inSep=a.size()==5;
            char ins=inSep?separatorOption(get(4),name):'\0';
            if(inSep && std::string("EINOSU").find(in)==std::string::npos)bad(name,"input separator invalid for input style");
            d=parseDate(get(1),in,now,tz,inSep,ins);
        }
        return sv(dateFormat(d,style,outputSep,sep,tz));
    }
    if(name=="TIME"){
        const char style=a.empty()?'N':caseMode(get(0),name);
        const auto tz=localOffsetMicroseconds(c);
        if((style=='E'||style=='R') && a.size()>1)bad(name,"elapsed format not valid with input time");
        if(style=='E'||style=='R'){
            const auto us=std::chrono::duration_cast<std::chrono::microseconds>(
                std::chrono::steady_clock::now()-c.elapsedStart).count();
            const auto delta=std::max<std::int64_t>(0,us);
            if(style=='R')c.elapsedStart=std::chrono::steady_clock::now();
            if(delta==0)return sv("0");
            return sv(std::to_string(delta/1000000)+"."+formatNum(static_cast<int>(delta%1000000),6));
        }
        Date d=nowDate(c);
        if(a.size()>=2){
            const char in=a.size()==3?caseMode(get(2),name):'N';
            d=parseTime(get(1),in,d,tz);
        }
        return sv(timeFormat(d,style,tz));
    }
    if(name=="REVERSE")return sv(std::string(get(0).rbegin(),get(0).rend()));
    if(name=="COPIES")return sv(repeat(get(0),ct(1),name));
    if(name=="UPPER"||name=="LOWER"){
        std::string s=get(0); size_t start=a.size()>=2?ct(1,1)-1:0;
        size_t n=a.size()>=3?ct(2):s.size();
        if(start<s.size()){
            n=std::min(n,s.size()-start);
            for(size_t i=start;i<start+n;i++){
                if(name=="UPPER"&&s[i]>='a'&&s[i]<='z')s[i]-=32;
                if(name=="LOWER"&&s[i]>='A'&&s[i]<='Z')s[i]+=32;
            }
        }
        return sv(s);
    }
    if(name=="SUBSTR"){
        const auto &s=get(0);auto b=ct(1,1)-1;
        size_t n=a.size()>=3?ct(2):b<s.size()?s.size()-b:0;
        const char p=pad(a,3,name)[0];
        std::string out=b<s.size()?s.substr(b,std::min(n,s.size()-b)):"";
        if(a.size()>=3)out+=repeat(std::string(1,p),n-out.size(),name);
        return sv(out);
    }
    if(name=="LEFT"||name=="RIGHT"||name=="CENTER"||name=="CENTRE"){
        const auto &s=get(0); const size_t n=ct(1);
        if(n>100000000)bad(name,"excessive width");
        const char p=pad(a,2,name)[0];
        if(name=="LEFT")return sv(s.substr(0,n)+repeat(std::string(1,p),n>len(s)?n-len(s):0,name));
        if(name=="RIGHT")return sv((n>=len(s)?repeat(std::string(1,p),n-len(s),name):"")+s.substr(len(s)>n?len(s)-n:0));
        if(n<len(s)){size_t b=(len(s)-n)/2;return sv(s.substr(b,n));}
        size_t delta=n-len(s),left=delta/2,right=delta-left;
        return sv(repeat(std::string(1,p),left,name)+s+repeat(std::string(1,p),right,name));
    }
    if(name=="STRIP"){
        auto s=get(0); char opt=a.size()>=2?caseMode(get(1),name):'B';
        if(opt!='B'&&opt!='L'&&opt!='T')bad(name,"option must be B, L, T");
        char p=pad(a,2,name)[0];size_t b=0,e=s.size();
        if(opt!='T')while(b<e&&s[b]==p)b++;
        if(opt!='L')while(e>b&&s[e-1]==p)e--;
        return sv(s.substr(b,e-b));
    }
    if(name=="SPACE"){
        auto s=get(0);auto w=words(s);size_t n=a.size()>=2?ct(1):1;
        char p=pad(a,2,name)[0]; std::string sep=repeat(std::string(1,p),n,name),out;
        for(size_t i=0;i<w.size();i++){if(i)out+=sep;out+=s.substr(w[i].pos,w[i].size);}
        return sv(out);
    }
    if(name=="WORDS")return iv(words(get(0)).size());
    if(name=="WORD"||name=="WORDINDEX"||name=="WORDLENGTH"){
        const auto &s=get(0);auto w=words(s);size_t n=ct(1,1);
        if(name=="WORD")return sv(wordAt(s,w,n));
        if(n>w.size())return iv(0);
        return iv(name=="WORDINDEX"?w[n-1].pos+1:w[n-1].size);
    }
    if(name=="SUBWORD"||name=="DELWORD"){
        const auto &s=get(0);auto w=words(s);auto first=ct(1,1);
        const auto n=a.size()>=3?ct(2):std::numeric_limits<size_t>::max();
        if(first>w.size())return sv(name=="SUBWORD"?"":s);
        size_t last=std::min(w.size(),first-1+std::min(n,w.size()-first+1));
        if(name=="SUBWORD"){
            if(!n)return sv("");
            return sv(s.substr(w[first-1].pos,w[last-1].pos+w[last-1].size-w[first-1].pos));
        }
        if(!n)return sv(s);
        size_t from=w[first-1].pos;
        // DELWORD removes inter-word spacing but keeps all prefix to the first deleted word.
        size_t to=last==w.size()?s.size():w[last].pos;
        return sv(s.substr(0,from)+s.substr(to));
    }
    if(name=="WORDPOS"){
        const auto phrase=get(0);const auto &s=get(1);auto w=words(s),p=words(phrase);
        const auto start=a.size()>=3?ct(2,1):1;
        if(p.empty())return iv(0);
        for(size_t k=start-1;k+p.size()<=w.size();k++){
            bool match=true;
            for(size_t i=0;i<p.size();i++)if(s.compare(w[k+i].pos,w[k+i].size,phrase,p[i].pos,p[i].size)!=0){match=false;break;}
            if(match)return iv(k+1);
        }return iv(0);
    }
    if(name=="POS"||name=="LASTPOS"){
        const auto &needle=get(0),&hay=get(1);
        // Every argument is validated before any result is decided (BUILTIN(POS) / BUILTIN(LASTPOS)).
        const size_t start=a.size()>=3?ct(2,1):
            (name=="POS"?1:hay.size());
        const size_t range=a.size()==4?ct(3):0;
        if(needle.empty())return iv(0);
        if(name=="POS"){
            const size_t from=start-1;
            if(from>=hay.size())return iv(0);
            if(a.size()==4){
                const size_t span=range;
                if(span==0||needle.size()>span)return iv(0);
                const size_t end=from+std::min(span,hay.size()-from);
                const size_t found=hay.find(needle,from);
                return iv(found==std::string::npos||found>end-needle.size()?0:found+1);
            }
            const size_t found=hay.find(needle,from);
            return iv(found==std::string::npos?0:found+1);
        }
        // In ooRexx, LASTPOS 'start' is the rightmost allowable *ending*
        // character of the match. 'range' bounds the search window backwards.
        const size_t end=std::min(start,hay.size());
        if(end<needle.size())return iv(0);
        const size_t span=a.size()==4?range:end;
        if(span<needle.size())return iv(0);
        const size_t begin=end-std::min(end,span);
        const size_t found=hay.rfind(needle,end-needle.size());
        return iv(found==std::string::npos||found<begin?0:found+1);
    }
    if(name=="ABBREV"){
        const auto &s=get(0),&abb=get(1);const auto min=a.size()==3?ct(2):0;
        return iv(abb.size()>=min&&abb.size()<=s.size()&&s.compare(0,abb.size(),abb)==0);
    }
    if(name=="COMPARE"){
        const auto &x=get(0),&y=get(1);char p=pad(a,2,name)[0];
        for(size_t i=0;i<std::max(x.size(),y.size());i++){
            char a1=i<x.size()?x[i]:p,b1=i<y.size()?y[i]:p;
            if(a1!=b1)return iv(i+1);
        }return iv(0);
    }
    if(name=="COUNTSTR"||name=="CHANGESTR"){
        const auto &needle=get(0),&src=get(1);
        if(needle.empty())return name=="COUNTSTR"?iv(0):sv(src);
        const size_t limit=name=="CHANGESTR"&&a.size()==4?ct(3):std::numeric_limits<size_t>::max();
        const std::string repl=name=="CHANGESTR"?get(2):"";
        size_t hits=0,p=0;std::string out;
        while(p<src.size()){
            auto at=src.find(needle,p);
            if(at==std::string::npos||hits>=limit)break;
            if(name=="CHANGESTR"){out+=src.substr(p,at-p);out+=repl;}
            ++hits;p=at+needle.size();
        }
        if(name=="COUNTSTR")return iv(hits);
        return sv(out+src.substr(p));
    }
    if(name=="DELSTR"){
        const auto &s=get(0);size_t start=a.size()>=2?ct(1,1)-1:0;
        size_t n=a.size()>=3?ct(2):std::numeric_limits<size_t>::max();
        if(start>=s.size())return sv(s);
        return sv(s.substr(0,start)+s.substr(start+std::min(n,s.size()-start)));
    }
    if(name=="INSERT"){
        const auto &part=get(0),&s=get(1);size_t at=a.size()>=3?ct(2):0;
        size_t n=a.size()>=4?ct(3):part.size();char p=pad(a,4,name)[0];
        if(at>100000000||n>100000000)bad(name,"size limit");
        const std::string fill=repeat(std::string(1,p),at>s.size()?at-s.size():0,name);
        const std::string insert=part.substr(0,n)+repeat(std::string(1,p),n>part.size()?n-part.size():0,name);
        return sv(s.substr(0,at)+fill+insert+s.substr(std::min(at,s.size())));
    }
    if(name=="OVERLAY"){
        const auto &part=get(0),&s=get(1);size_t at=a.size()>=3?ct(2,1)-1:0;
        size_t n=a.size()>=4?ct(3):part.size();char p=pad(a,4,name)[0];
        if(at>100000000||n>100000000)bad(name,"size limit");
        std::string out=s;
        if(at>out.size())out+=repeat(std::string(1,p),at-out.size(),name);
        const std::string overlay=part.substr(0,n)+repeat(std::string(1,p),n>part.size()?n-part.size():0,name);
        out.replace(at,std::min(n,out.size()-at),overlay);return sv(out);
    }
    // Byte-oriented logical operations following the RexxString bit* delegate.
    // Missing second operand is an identity operation; absent pad is the
    // operator's identity byte, so surplus bytes remain unchanged.
    if(name=="BITAND"||name=="BITOR"||name=="BITXOR"){
        const std::string &first=get(0);
        if(a.size()==1) return sv(first);
        const std::string &second=get(1);
        unsigned char identity=name=="BITAND"?0xff:0x00;
        unsigned char fill=a.size()==3?static_cast<unsigned char>(pad(a,2,name)[0]):identity;
        if(first.size()>100000000 || second.size()>100000000)bad(name,"qualified size limit");
        std::string out;out.reserve(std::max(first.size(),second.size()));
        for(size_t i=0;i<std::max(first.size(),second.size());++i){
            unsigned char x=i<first.size()?static_cast<unsigned char>(first[i]):fill;
            unsigned char y=i<second.size()?static_cast<unsigned char>(second[i]):fill;
            unsigned char z=name=="BITAND"?static_cast<unsigned char>(x & y):
                (name=="BITOR"?static_cast<unsigned char>(x | y):static_cast<unsigned char>(x ^ y));
            out.push_back(static_cast<char>(z));
        }
        return sv(out);
    }
    if(name=="B2X"){
        const auto &input=get(0);
        if(input.size()>100000000)bad(name,"qualified input size limit");
        if(input.empty())return sv("");
        // No separated bit-groups in this subset; only [01]+ is admitted.
        for(char ch:input)if(ch!='0'&&ch!='1')bad(name,"bit-group layout not yet qualified");
        const size_t padding=(4-input.size()%4)%4;
        static constexpr char hex[]="0123456789ABCDEF";
        std::string out;out.reserve((input.size()+3)/4);
        unsigned value=0;unsigned bitcount=0;
        for(size_t i=0;i<padding;++i){value<<=1;++bitcount;}
        for(char ch:input){value=(value<<1)+static_cast<unsigned>(ch-'0');if(++bitcount==4){out+=hex[value];value=0;bitcount=0;}}
        return sv(out);
    }
    if(name=="X2B"){
        const auto &input=get(0);
        if(input.size()>25000000)bad(name,"qualified output size limit");
        static constexpr char b[]="00000000000100100011010001010110011110001001101010111100110111101111";
        (void)b; // decoded using the explicit high-to-low bit loop below
        std::string out;out.reserve(input.size()*4);
        for(char ch:input){
            unsigned value=0;
            if(ch>='0'&&ch<='9')value=static_cast<unsigned>(ch-'0');
            else if(ch>='A'&&ch<='F')value=static_cast<unsigned>(ch-'A'+10);
            else if(ch>='a'&&ch<='f')value=static_cast<unsigned>(ch-'a'+10);
            else bad(name,"hex-group layout not yet qualified");
            for(int j=3;j>=0;--j)out+=(value & (1u<<j))?'1':'0';
        }
        return sv(out);
    }
    if(name=="C2X"){
        static const char*h="0123456789ABCDEF";const auto &s=get(0);std::string out;out.reserve(s.size()*2);
        for(unsigned char ch:s){out+=h[ch>>4];out+=h[ch&15];}return sv(out);
    }
    if(name=="X2C"){
        const auto &s=get(0);std::string cleaned;
        for(char ch:s){if(ws(ch))continue;
            if(!((ch>='0'&&ch<='9')||(ch>='A'&&ch<='F')||(ch>='a'&&ch<='f')))bad(name,"invalid hex character");
            cleaned+=ch;
        }
        if(cleaned.size()%2!=0)bad(name,"odd length hex: require qualified hex pairs");
        std::string out;
        for(size_t i=0;i<cleaned.size();i+=2)out+=static_cast<char>(std::stoi(cleaned.substr(i,2),nullptr,16));
        return sv(out);
    }
    bad(name,"implementation not yet available");
}
} // namespace rxbif
