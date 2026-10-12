#pragma once
#ifdef RX2CPP_KERNEL
#include "rx_kernel_bif.h"
#endif
/* BIF v0.11 is a separately maintained add-on.  The compiled Rexx
   activation supplies its own variable provider on each BIF invocation.
   This deliberately narrow provider supports simple symbols, numeric literal
   constants and current rx2cpp compound/stem semantics. It does NOT claim
   the full interpreter's variable retriever, selectors or object ABI. */
#include "rxbif_breadth.hpp"
#include "rxbif_variables.hpp"
#include <cctype>
#ifdef RX2CPP_BIF_ISOLATED
#include "rxbif_oorexx_bridge.hpp"
#include <cstdlib>
#include <memory>
#endif
#include "rx_object_bridge.hpp"
namespace rx {
struct BifRuntime {
    rxbif::Context native;
#ifdef RX2CPP_BIF_ISOLATED
    std::unique_ptr<rxbif_breadth::IsolatedOoRexx> isolated;
#endif
    rxbif_breadth::Context dispatch;
    BifRuntime() : native(), dispatch(native,
#ifdef RX2CPP_BIF_ISOLATED
        [this](const std::string& name,
               const std::vector<rxbif_breadth::Slot>& args,
               const rxbif_breadth::NumericContext& numeric) -> Value {
            const char* program=std::getenv("RX2CPP_BIF_ISOLATED_SCRIPT");
            if (!program || !*program)
                throw std::runtime_error("RX2CPP_BIF_ISOLATED_SCRIPT is not configured");
            if (!isolated) isolated=std::make_unique<rxbif_breadth::IsolatedOoRexx>(program);
            return isolated->call(name,args,numeric);
        },
#elif defined(RX2CPP_HOST_API)
        [](const std::string& name,
           const std::vector<rxbif_breadth::Slot>& args,
           const rxbif_breadth::NumericContext& numeric) -> Value {
            std::vector<std::pair<bool, std::string>> in;
            for (const auto& slot : args) {
                if (slot && slot->isObject()) throw std::runtime_error("BIF " + name + ": object arguments need the interpreter");
                in.emplace_back(static_cast<bool>(slot), slot ? slot->bytes : std::string());
            }
            return Value::string(rxobj::callBif(name, in, numeric.digits, numeric.fuzz,
                                                numeric.form == rxbif_breadth::NumericForm::Engineering));
        },
#else
        rxbif_breadth::Handler{},
#endif
        std::nullopt) {}
};

using BifSlot = rxbif_breadth::Slot;
inline rxbif_breadth::NumericContext frameNumeric(const Variables& vars) {
    return {vars.numeric.digits, vars.numeric.fuzz,
        vars.numeric.engineering ? rxbif_breadth::NumericForm::Engineering
                                 : rxbif_breadth::NumericForm::Scientific};
}
inline std::string symbolUpper(const std::string& in) {
    std::string out=in;
    for (char& c : out) c=static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
    return out;
}
inline bool basicSymbolPart(const std::string& s) {
    if(s.empty()) return false;
    const auto initial=[](unsigned char c) {return (c>='A'&&c<='Z') || (c>='a'&&c<='z') || c=='_';};
    const auto rest=[&](unsigned char c) {return initial(c)||(c>='0'&&c<='9');};
    if(!initial(static_cast<unsigned char>(s.front()))) return false;
    for(char c:s) if(!rest(static_cast<unsigned char>(c))) return false;
    return true;
}
inline bool decimalLiteral(const std::string& s) {
    if(s.empty()) return false;
    // Rexx constant strings: only unambiguous decimal literals in this subset.
    std::size_t i=0;
    bool digit=false, dot=false;
    for (;i<s.size();++i) {
        const unsigned char c=static_cast<unsigned char>(s[i]);
        if(c>='0'&&c<='9') {digit=true;continue;}
        if(c=='.'&&!dot) {dot=true;continue;}
        return false;
    }
    return digit;
}
// Returns false for symbolic forms not representable by the current lexer.
// Valid numeric and leading-dot constants are deliberately not assignable.
inline bool splitBifSymbol(const std::string& raw, std::string& canonical,
                           bool& literal) {
    canonical.clear(); literal=false;
    if(decimalLiteral(raw)) {literal=true;canonical=raw;return true;}
    if(raw.size()>1 && raw[0]=='.' && basicSymbolPart(raw.substr(1))) {
        literal=true; canonical=symbolUpper(raw); return true;
    }
    if(raw.empty()) return false;
    const auto dot=raw.find('.');
    if(dot==std::string::npos) {
        if(!basicSymbolPart(raw)) return false;
        canonical=symbolUpper(raw);return true;
    }
    if(!basicSymbolPart(raw.substr(0,dot))) return false;
    canonical=symbolUpper(raw.substr(0,dot));canonical+='.';
    std::size_t start=dot+1;
    while(start<raw.size()) {
        auto end=raw.find('.',start);
        std::string part=raw.substr(start,end==std::string::npos?std::string::npos:end-start);
        if(!part.empty()) {
            if(!basicSymbolPart(part)&& !(part[0]>='0'&&part[0]<='9')) return false;
            // Only uppercase source-symbol spelling; substituted tail values
            // are supplied unchanged by compoundKey in the variable provider.
            canonical+=symbolUpper(part);
        }
        if(end==std::string::npos) break;
        canonical+='.';start=end+1;
    }
    return true;
}
inline rxbif_variables::Reply frameVariableReply(Variables& vars,
                 const rxbif_variables::Request& req,
                 const rxbif_breadth::NumericContext&) {
    using namespace rxbif_variables;
    // External selector namespaces are not the caller's local pool. No
    // automatic .environment or process-environment mutation is safe here.
    if(req.selector) throw std::runtime_error("BIF VALUE: external selector not qualified");
    std::string symbol;
    bool literal=false;
    if(!splitBifSymbol(req.name,symbol,literal))
        return {SymbolKind::Invalid,false,std::nullopt};
    if(literal) {
        if(req.action==Action::Exchange)
            throw std::runtime_error("BIF VALUE: numeric/literal symbol cannot be assigned");
        if(req.action==Action::Fetch && !decimalLiteral(req.name))
            throw std::runtime_error("BIF VALUE: object-valued constant requires qualified ABI");
        return {SymbolKind::Literal,false,
                req.action==Action::Fetch ? BifSlot{Value::string(req.name)} : std::nullopt};
    }
    const std::string resolved=compoundSymbol(symbol)?compoundKey(vars,symbol):symbol;
    const Value* previous=lookup(vars,resolved);
    if (!previous && compoundSymbol(symbol)) {
        const std::string stem=symbol.substr(0,symbol.find('.')+1);
        previous=lookup(vars,stem);
    }
    if(req.action==Action::Classify)
        return {SymbolKind::Assignable,previous!=nullptr,std::nullopt};
    if(previous && previous->isObject())
        throw std::runtime_error("BIF VALUE: object prior cannot cross scalar ABI");
    const Value prior=previous?*previous:Value::string(resolved);
    if(req.action==Action::Exchange) {
        if(!req.replacement || req.replacement->isObject())
            throw std::runtime_error("BIF VALUE: invalid replacement");
        // Preflight the old result and the new object before changing anything.
        setSymbol(vars,symbol,*req.replacement);
    }
    return {SymbolKind::Assignable,previous!=nullptr,BifSlot{prior}};
}
inline const Value* slotPtr(const Value& v){ return &v; }
inline const Value* slotPtr(const std::optional<Value>& v){ return v?&*v:nullptr; }
// ARG([n[,option]]) over the activation's argument list (compiled-in; no interpreter activation needed).
template <class Vec>
inline Value argBif(const std::vector<Value>& args, const Vec& a) {
    auto text=[&](std::size_t i)->std::string {
        if(i>=a.size()) return std::string();
        const Value* v=slotPtr(a[i]);
        if(!v) return std::string();
        if(v->isObject()) throw std::runtime_error("BIF ARG: invalid arguments");
        return v->bytes;
    };
    std::size_t count=args.size();
    if(a.empty()) return Value::string(std::to_string(count));
    const std::string ns=text(0);
    if(ns.empty()||ns.find_first_not_of("0123456789")!=std::string::npos||ns=="0"||ns.find_first_not_of('0')==std::string::npos)
        throw std::runtime_error("BIF ARG: argument 1 must be a positive whole number");
    const std::size_t n=std::stoul(ns);
    std::string opt=a.size()>1?text(1):std::string();
    if(opt.empty()) return n<=count?args[n-1]:Value::string("");
    const char o=static_cast<char>(std::toupper(static_cast<unsigned char>(opt[0])));
    const bool exists=n<=count;
    if(o=='E') return Value::string(exists?"1":"0");
    if(o=='O') return Value::string(exists?"0":"1");
    throw std::runtime_error("BIF ARG: option must be E or O");
}
// ARG over an argument list with omitted slots (native package methods and routines): ARG() is the position of the
// last argument given, ARG(n) of an omitted slot is the null string, and E/O test whether slot n was given.
inline Value argSlotValue(const std::optional<Value>& v) { return *v; }
inline Value argSlotValue(const std::optional<std::string>& v) { return Value::string(*v); }
template <class Slot>
inline Value argBifSlots(const std::vector<Slot>& args, const std::vector<BifSlot>& a) {
    std::size_t count=args.size();
    while(count>0 && !args[count-1]) --count;
    if(a.empty()) return Value::string(std::to_string(count));
    const Value* nv=slotPtr(a[0]);
    if(!nv || nv->isObject()) throw std::runtime_error("BIF ARG: argument 1 must be a positive whole number");
    const std::string& ns=nv->bytes;
    if(ns.empty()||ns.find_first_not_of("0123456789")!=std::string::npos||ns.find_first_not_of('0')==std::string::npos)
        throw std::runtime_error("BIF ARG: argument 1 must be a positive whole number");
    const std::size_t n=std::stoul(ns);
    const bool exists=n<=args.size() && args[n-1];
    const Value* ov=a.size()>1?slotPtr(a[1]):nullptr;
    if(!ov || ov->bytes.empty()) return exists?argSlotValue(args[n-1]):Value::string("");
    if(ov->isObject()) throw std::runtime_error("BIF ARG: option must be E or O");
    const char o=static_cast<char>(std::toupper(static_cast<unsigned char>(ov->bytes[0])));
    if(o=='E') return Value::string(exists?"1":"0");
    if(o=='O') return Value::string(exists?"0":"1");
    if(o=='A') throw std::runtime_error("BIF ARG: option A is not implemented in compiled code");
    throw std::runtime_error("BIF ARG: option must be A, E or O");
}
// FORMAT(number[,before[,after]]) in fixed notation; exponent forms are not implemented here (fail closed).
inline Value formatBifFixed(const std::vector<BifSlot>& a, const ActivationNumeric& num) {
    auto intArg=[&](std::size_t i, long dflt, bool& given)->long {
        given = i<a.size() && a[i];
        if(!given) return dflt;
        if(a[i]->isObject()) throw std::runtime_error("BIF FORMAT: invalid arguments");
        const std::string& t=a[i]->bytes; std::size_t k=0; long v=0;
        if(t.empty()) throw std::runtime_error("BIF FORMAT: argument must be a whole number");
        for(;k<t.size();++k){ if(t[k]<'0'||t[k]>'9') throw std::runtime_error("BIF FORMAT: argument must be a whole number"); v=v*10+(t[k]-'0'); }
        return v;
    };
    if(a.empty() || a.size()>5 || !a[0] || a[0]->isObject()) throw std::runtime_error("BIF FORMAT: invalid arguments");
    bool gb=false, ga=false, ge=false, gt=false;
    const long before=intArg(1,0,gb), after=intArg(2,0,ga);
    intArg(3,0,ge); intArg(4,0,gt);
    if(ge||gt) throw std::runtime_error("BIF FORMAT: exponent arguments are not implemented");
    RexxDecimal d=parseRexxDecimal(*a[0]);
    roundRexx(d,num);
    if(!gb && !ga) return numberResult(d,num);
    if(ga) {
        const int want=-static_cast<int>(after);
        if(d.exponent<want) {                       // round off excess decimals, half up
            const cpp_int p=decimalPow10(want-d.exponent);
            const bool neg=d.coefficient<0; cpp_int n=neg?-d.coefficient:d.coefficient;
            cpp_int q=n/p; if((n%p)*2>=p) ++q;
            d.coefficient=neg?-q:q; d.exponent=want;
        }
    }
    const bool neg=d.coefficient<0;
    std::string digits=(neg?-d.coefficient:d.coefficient).convert_to<std::string>();
    if(d.coefficient==0) digits="0";
    std::string ip, fp;
    if(d.exponent>=0) { ip=(digits=="0")?"0":digits+std::string(d.exponent,'0'); }
    else {
        const std::size_t f=static_cast<std::size_t>(-d.exponent);
        if(digits.size()<=f) digits=std::string(f-digits.size()+1,'0')+digits;
        ip=digits.substr(0,digits.size()-f); fp=digits.substr(digits.size()-f);
    }
    if(ga) { if(fp.size()<static_cast<std::size_t>(after)) fp+=std::string(after-fp.size(),'0'); }
    else { while(!fp.empty()&&fp.back()=='0') fp.pop_back(); }
    bool zero=true; for(char c:ip+fp) if(c!='0') zero=false;
    std::string out=(neg&&!zero?"-":"")+ip;
    if(!fp.empty()) out+="."+fp;
    if(gb) {
        const std::size_t lead=out.find('.')==std::string::npos?out.size():out.find('.');
        if(lead>static_cast<std::size_t>(before)) throw std::runtime_error("BIF FORMAT: number does not fit in BEFORE digits");
        out=std::string(before-lead,' ')+out;
    }
    return Value::string(out);
}
// Exact native paths for the commonest pure string BIFs. Only the plain, unambiguous form is taken (all arguments present and
// strings, counts written as plain digits, no whitespace other than blanks for the word functions); anything else returns
// nullopt and goes the full catalogue route, which owns validation and error text.
inline bool quickCount(const BifSlot &slot, std::size_t &out, bool positive) {
    if (!slot || slot->isObject()) return false;
    const std::string &t = slot->bytes;
    if (t.empty() || t.size() > 9) return false;
    std::size_t v = 0;
    for (char c : t) { if (c < '0' || c > '9') return false; v = v * 10 + static_cast<std::size_t>(c - '0'); }
    if (positive && v == 0) return false;
    out = v; return true;
}
inline bool quickText(const BifSlot &slot) { return slot && !slot->isObject(); }
inline bool quickPad(const std::vector<BifSlot> &a, std::size_t i, char &pad) {
    pad = ' ';
    if (a.size() <= i) return true;
    if (!quickText(a[i]) || a[i]->bytes.size() != 1) return false;
    pad = a[i]->bytes[0]; return true;
}
inline bool quickBlanksOnly(const std::string &s) {
    for (char c : s) if (c == '\t' || c == '\n' || c == '\r' || c == '\v' || c == '\f') return false;
    return true;
}
inline std::optional<Value> quickBif(const std::string &name, const std::vector<BifSlot> &a) {
    if (name.empty() || a.empty() || !quickText(a[0])) return std::nullopt;
    const std::string &s = a[0]->bytes;
    switch (name[0]) {
    case 'L':
        if (name == "LENGTH" && a.size() == 1) return fromInteger(static_cast<std::int64_t>(s.size()));
        if (name == "LEFT" && (a.size() == 2 || a.size() == 3)) {
            std::size_t n; char pad;
            if (!quickCount(a[1], n, false) || !quickPad(a, 2, pad)) return std::nullopt;
            std::string out = s.substr(0, std::min(n, s.size()));
            out.resize(n, pad);
            return Value(std::move(out));
        }
        break;
    case 'R':
        if (name == "RIGHT" && (a.size() == 2 || a.size() == 3)) {
            std::size_t n; char pad;
            if (!quickCount(a[1], n, false) || !quickPad(a, 2, pad)) return std::nullopt;
            if (n <= s.size()) return Value(s.substr(s.size() - n));
            return Value(std::string(n - s.size(), pad) + s);
        }
        break;
    case 'S':
        if (name == "SUBSTR" && a.size() >= 2 && a.size() <= 4) {
            std::size_t start, len; char pad;
            if (!quickCount(a[1], start, true) || !quickPad(a, 3, pad)) return std::nullopt;
            const std::size_t from = start - 1;
            if (a.size() == 2) return Value(from < s.size() ? s.substr(from) : std::string());
            if (!quickCount(a[2], len, false)) return std::nullopt;
            std::string out = from < s.size() ? s.substr(from, len) : std::string();
            out.resize(len, pad);
            return Value(std::move(out));
        }
        break;
    case 'W':
        if ((name == "WORD" && a.size() == 2) || (name == "WORDS" && a.size() == 1)) {
            if (!quickBlanksOnly(s)) return std::nullopt;
            std::size_t want = 0;
            if (a.size() == 2 && !quickCount(a[1], want, true)) return std::nullopt;
            std::size_t i = 0, count = 0;
            while (true) {
                while (i < s.size() && s[i] == ' ') ++i;
                if (i >= s.size()) break;
                const std::size_t b = i;
                while (i < s.size() && s[i] != ' ') ++i;
                if (++count == want) return Value(s.substr(b, i - b));
            }
            if (a.size() == 1) return fromInteger(static_cast<std::int64_t>(count));
            return Value(std::string());
        }
        break;
    default: break;
    }
    return std::nullopt;
}
inline Value dispatchBif(BifRuntime& bif, Variables& vars, const std::string& name,
                         const std::vector<BifSlot>& slots) {
    if(auto quick=quickBif(name,slots)) return std::move(*quick);
    if(name=="TRACE" || name=="ADDRESS") {   // language state owned by the compiled program, not by a BIF
        if(slots.size()>1 || (slots.size()==1 && (!slots[0] || slots[0]->isObject())))
            throw std::runtime_error("BIF "+name+": invalid arguments");
        if(name=="TRACE") return Value::string(slots.empty() ? traceSetting() : traceSet(*slots[0]));
        return Value::string(slots.empty() ? addressEnvironment() : addressSet(*slots[0]));
    }
    if(name=="SYMBOL" || name=="VAR" || name=="VALUE") {
        rxbif_variables::VariableRouter router(bif.native,
            [&vars]{return frameNumeric(vars);},
            [&vars](const rxbif_variables::Request& req,
                    const rxbif_breadth::NumericContext& numbers) {
                return frameVariableReply(vars,req,numbers);
            });
        return router.invoke(name,slots);
    }
#ifndef RX2CPP_KERNEL
    if(name=="FORMAT") return formatBifFixed(slots, vars.numeric);
#endif
#ifdef RX2CPP_KERNEL
    // The compiled-in ooRexx kernel runs the REAL handler: validation, defaults, omitted arguments and error text included.
    if(rxkernel::handles(name)) {
        bool crossable=true;
        std::vector<std::string> raw; std::vector<bool> present;
        for(const auto& slot:slots) {
            if(slot && slot->isObject()) { crossable=false; break; }
            raw.push_back(slot ? slot->bytes : std::string()); present.push_back(static_cast<bool>(slot));
        }
        if(crossable) {
            std::string out,code,text;
            if(rxkernel::call(name,raw,present,out,code,text)) return Value::string(out);
            throw SyntaxCondition(code,text,false);
        }
    }
#endif
    // Supplier captures the CURRENT activation, including nested PROCEDURE.
    // A per-call context avoids retained references to expired routine locals.
    rxbif_breadth::Context current(bif.native,bif.dispatch.chainback,
                                    std::nullopt,[&vars]{return frameNumeric(vars);});
    return rxbif_breadth::invoke(name,slots,current);
}
inline void dispatchBifInstruction(Variables& vars, BifRuntime& bif,
                                   const std::string& name,
                                   const std::vector<BifSlot>& args) {
    set(vars,"RESULT",dispatchBif(bif,vars,name,args));
}
} // namespace rx

#ifdef RX2CPP_HOST_API
namespace rx {
/* Exact fast paths for the radix conversions that crypto-style code runs millions of times: unsigned values that fit in 128 bits and
   in the caller's NUMERIC DIGITS. Anything else (signed, wide, malformed) returns nullopt and is decided by the interpreter. */
inline std::string u128ToDecimal(unsigned __int128 v) {
    if (v == 0) return "0";
    std::string out;
    while (v) { out.insert(out.begin(), static_cast<char>('0' + static_cast<int>(v % 10))); v /= 10; }
    return out;
}
inline std::optional<unsigned __int128> decimalToU128(const std::string &t) {
    if (t.empty() || t.size() > 38 || t.find_first_not_of("0123456789") != std::string::npos) return std::nullopt;
    unsigned __int128 v = 0;
    for (char c : t) v = v * 10 + static_cast<unsigned>(c - '0');
    return v;
}
inline std::optional<std::string> fastRadix(const std::string &name, const Value &recv, const std::vector<Value> &args, std::size_t digits) {
    for (const Value &a : args) if (a.isObject()) return std::nullopt;
    const std::string &r = recv.bytes;
    static const char *hexd = "0123456789ABCDEF";
    if (name == "C2D" && args.empty()) {
        if (r.size() > 16) return std::nullopt;
        unsigned __int128 v = 0;
        for (unsigned char c : r) v = (v << 8) | c;
        std::string d = u128ToDecimal(v);
        if (d.size() > digits) return std::nullopt;
        return d;
    }
    if (name == "D2C" && args.size() == 1) {
        auto v = decimalToU128(r);
        auto len = decimalToU128(args[0].bytes);
        if (!v || !len || *len > 16 || *len == 0 || r.size() > digits) return std::nullopt;
        unsigned bytes = static_cast<unsigned>(*len);
        std::string raw(bytes, '\0');
        unsigned __int128 x = *v;
        for (unsigned i = 0; i < bytes; i++) { raw[bytes - 1 - i] = static_cast<char>(x & 0xFF); x >>= 8; }
        return raw;
    }
    if (name == "D2X" && args.size() == 1) {   // the length counts hexadecimal digits
        auto v = decimalToU128(r);
        auto len = decimalToU128(args[0].bytes);
        if (!v || !len || *len > 32 || *len == 0 || r.size() > digits) return std::nullopt;
        unsigned nibbles = static_cast<unsigned>(*len);
        std::string hex(nibbles, '0');
        unsigned __int128 x = *v;
        for (unsigned i = 0; i < nibbles; i++) { hex[nibbles - 1 - i] = hexd[static_cast<unsigned>(x & 15)]; x >>= 4; }
        return hex;
    }
    if (name == "X2D" && args.empty()) {
        if (r.empty() || r.size() > 32) return std::nullopt;
        unsigned __int128 v = 0;
        for (char c : r) {
            int d;
            if (c >= '0' && c <= '9') d = c - '0'; else if (c >= 'a' && c <= 'f') d = c - 'a' + 10; else if (c >= 'A' && c <= 'F') d = c - 'A' + 10; else return std::nullopt;
            v = (v << 4) | static_cast<unsigned>(d);
        }
        std::string d = u128ToDecimal(v);
        if (d.size() > digits) return std::nullopt;
        return d;
    }
    return std::nullopt;
}
}
#endif

#ifdef RX2CPP_HOST_API
namespace rx {
/* String messages that are exactly a BIF with the receiver as first argument (s~c2d == C2D(s)) run in the shared native BIF
   engine under the caller's NUMERIC settings; anything the native subset does not cover goes on to the interpreter. */
struct NotNativeBif {};
inline StringMessageFallback &hostStringBifPrevious() { static StringMessageFallback f = nullptr; return f; }
// The hot byte-string methods, done in place: no name lookup, no argument slots. Each follows ooRexx exactly for the shapes accepted
// (plain digit arguments, no pad character); every other shape returns nullopt and takes the general engine.
inline bool plainCount(const Value &v, std::size_t &out) {
    if (v.isObject() || v.bytes.empty() || v.bytes.size() > 9 || v.bytes.find_first_not_of("0123456789") != std::string::npos) return false;
    out = static_cast<std::size_t>(std::stoul(v.bytes));
    return true;
}
inline std::optional<std::string> quickStringBif(const std::string &name, const Value &receiver, const std::vector<Value> &args) {
    const std::string &s = receiver.bytes;
    switch (name.size()) {
    case 6:
        if (name == "LENGTH" && args.empty()) return std::to_string(s.size());
        if (name == "BITXOR" || name == "BITAND") {
            if (args.size() != 1 || args[0].isObject()) return std::nullopt;
            const std::string &t = args[0].bytes;
            const std::string &longer = s.size() >= t.size() ? s : t;
            const std::size_t m = s.size() < t.size() ? s.size() : t.size();
            std::string r = longer;                       // BITXOR keeps the longer operand's tail; BITAND likewise (no pad)
            if (name == "BITXOR") for (std::size_t i = 0; i < m; i++) r[i] = static_cast<char>(s[i] ^ t[i]);
            else for (std::size_t i = 0; i < m; i++) r[i] = static_cast<char>(s[i] & t[i]);
            return r;
        }
        return std::nullopt;
    default: break;
    }
    if (name == "BITOR" && args.size() == 1 && !args[0].isObject()) {
        const std::string &t = args[0].bytes;
        const std::string &longer = s.size() >= t.size() ? s : t;
        const std::size_t m = s.size() < t.size() ? s.size() : t.size();
        std::string r = longer;
        for (std::size_t i = 0; i < m; i++) r[i] = static_cast<char>(s[i] | t[i]);
        return r;
    }
    if (name == "REVERSE" && args.empty()) return std::string(s.rbegin(), s.rend());
    if (name == "SUBSTR" && (args.size() == 1 || args.size() == 2)) {
        std::size_t n, len = 0;
        if (!plainCount(args[0], n) || n < 1) return std::nullopt;
        const std::size_t start = n - 1, avail = start < s.size() ? s.size() - start : 0;
        if (args.size() == 1) return s.substr(start < s.size() ? start : s.size());
        if (!plainCount(args[1], len)) return std::nullopt;
        const std::size_t take = len < avail ? len : avail;
        return (avail ? s.substr(start, take) : std::string()) + std::string(len - take, ' ');
    }
    if ((name == "LEFT" || name == "RIGHT") && args.size() == 1) {
        std::size_t len;
        if (!plainCount(args[0], len)) return std::nullopt;
        if (name == "LEFT") return len <= s.size() ? s.substr(0, len) : s + std::string(len - s.size(), ' ');
        return len <= s.size() ? s.substr(s.size() - len) : std::string(len - s.size(), ' ') + s;
    }
    if (name == "C2X" && args.empty()) {
        static const char hex[] = "0123456789ABCDEF";
        std::string r; r.reserve(s.size() * 2);
        for (unsigned char c : s) { r.push_back(hex[c >> 4]); r.push_back(hex[c & 15]); }
        return r;
    }
    return std::nullopt;
}
inline MessageResult hostStringBif(const Value &receiver, const std::string &selector, const std::vector<Value> &args) {
    static const std::unordered_set<std::string> mirrored{
        "C2D","C2X","X2C","X2D","D2C","D2X","B2X","X2B","LENGTH","SUBSTR","LEFT","RIGHT","CENTER","CENTRE","REVERSE","TRANSLATE",
        "BITAND","BITOR","BITXOR","STRIP","WORD","WORDS","SUBWORD","WORDINDEX","WORDLENGTH","SPACE","COPIES","COMPARE","DELSTR",
        "DELWORD","DATATYPE","VERIFY","ABBREV","ABS","SIGN","TRUNC","UPPER","LOWER"};
    std::string name = selector;
    for (char &c : name) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
    auto fallback = [&]() -> MessageResult { return hostStringBifPrevious()(receiver, selector, args); };
    if (name == "C2D" || name == "D2C" || name == "X2D" || name == "D2X") {
        const ActivationNumeric def0;
        const ActivationNumeric &n0 = currentNumeric ? *currentNumeric : def0;
        if (auto fast = fastRadix(name, receiver, args, n0.digits)) return MessageResult(Value::string(*fast));
    }
    if (auto quick = quickStringBif(name, receiver, args)) return MessageResult(Value::string(*quick));
    if (name == "SUBCHAR" && args.size() == 1 && !args[0].isObject() && !args[0].bytes.empty() && args[0].bytes.size() < 10 &&
        args[0].bytes.find_first_not_of("0123456789") == std::string::npos) {
        const unsigned long n = std::stoul(args[0].bytes);   // SUBCHAR(n): the n-th character, "" beyond the end
        if (n >= 1) return MessageResult(Value::string(n <= receiver.bytes.size() ? std::string(1, receiver.bytes[n - 1]) : std::string()));
    }
    if (!mirrored.count(name)) return fallback();
    std::vector<rxbif_breadth::Slot> slots;
    slots.emplace_back(receiver);
    for (const Value &a : args) {
        if (a.isObject()) {
            if (dynamic_cast<EnvObject *>(a.object.get()) && static_cast<EnvObject *>(a.object.get())->handle == nullptr) slots.emplace_back(std::nullopt);
            else return fallback();
        } else slots.emplace_back(a);
    }
    static thread_local rxbif::Context native;
    const ActivationNumeric def;
    const ActivationNumeric &n = currentNumeric ? *currentNumeric : def;
    auto numeric = [&n]() -> rxbif_breadth::NumericContext {
        return {n.digits, n.fuzz, n.engineering ? rxbif_breadth::NumericForm::Engineering : rxbif_breadth::NumericForm::Scientific};
    };
    rxbif_breadth::Handler refuse = [](const std::string &, const std::vector<rxbif_breadth::Slot> &,
                                       const rxbif_breadth::NumericContext &) -> Value { throw NotNativeBif(); };
    rxbif_breadth::Context ctx(native, refuse, std::nullopt, numeric);
    try { return MessageResult(rxbif_breadth::invoke(name, slots, ctx)); }
    catch (const NotNativeBif &) { return fallback(); }
    catch (const SyntaxCondition &) { throw; }
    catch (const std::runtime_error &) { return fallback(); }   // the native subset cannot do this one: the interpreter decides
}
inline const bool hostStringBifInstalled = (hostStringBifPrevious() = stringMessageFallback(), stringMessageFallback() = &hostStringBif, true);
}
#endif
