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
#include <cstring>
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
                in.emplace_back(static_cast<bool>(slot), slot ? slot->bytes.str() : std::string());
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
// LanguageParser::scanSymbol: what kind of symbol a string is (SYMBOL, VAR and VALUE classify their name with it).
enum class SymbolScan { Bad, LiteralDot, Numeric, Literal, Name, Stem, Compound };
inline SymbolScan scanSymbol(const std::string &s) {
    const std::size_t n = s.size();
    if (n == 0 || n > 250) return SymbolScan::Bad;
    auto symbolChar = [](unsigned char c) {
        return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '.' || c == '!' ||
               c == '?' || c == '_';
    };
    auto digit = [](unsigned char c) { return c >= '0' && c <= '9'; };
    std::size_t compound = 0, i = 0;
    bool haveExponent = false;
    while (i < n && symbolChar(static_cast<unsigned char>(s[i]))) { if (s[i] == '.') ++compound; ++i; }
    if (i < n) {
        if (i + 1 >= n) return SymbolScan::Bad;
        if (s[i] != '-' && s[i] != '+') return SymbolScan::Bad;
        if (i == 0 || std::toupper(static_cast<unsigned char>(s[i - 1])) != 'E') return SymbolScan::Bad;
        for (std::size_t k = i + 1; k < n; ++k) if (!digit(static_cast<unsigned char>(s[k]))) return SymbolScan::Bad;
        haveExponent = true;
    }
    if (s[0] == '.' || digit(static_cast<unsigned char>(s[0]))) {
        if (compound == 1 && n == 1) return SymbolScan::LiteralDot;
        if (compound > 1) return haveExponent ? SymbolScan::Bad : SymbolScan::Literal;
        std::size_t k = 0;
        while (k < n && (digit(static_cast<unsigned char>(s[k])) || s[k] == '.')) ++k;
        if (k >= n) return SymbolScan::Numeric;
        if (std::toupper(static_cast<unsigned char>(s[k])) == 'E') {
            ++k;
            if (k < n && (s[k] == '-' || s[k] == '+')) return SymbolScan::Numeric;
            while (k < n) { if (!digit(static_cast<unsigned char>(s[k]))) return SymbolScan::Literal; ++k; }
            return SymbolScan::Numeric;
        }
        return SymbolScan::Literal;
    }
    if (compound == 0) return SymbolScan::Name;
    if (compound == 1 && s[n - 1] == '.') return SymbolScan::Stem;
    return SymbolScan::Compound;
}
// VariableDictionary::getVariableRetriever: the upper-case name; false for a string that is not a symbol. literal: a
// constant symbol (its value is its upper-case name). An environment symbol (.name) is the interpreter's (see
// dispatchBifNative).
inline bool splitBifSymbol(const std::string& raw, std::string& canonical, bool& literal) {
    canonical = symbolUpper(raw);
    literal = false;
    switch (scanSymbol(canonical)) {
    case SymbolScan::Bad: return false;
    case SymbolScan::LiteralDot: case SymbolScan::Numeric: case SymbolScan::Literal: literal = true; return true;
    default: return true;
    }
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
        return {SymbolKind::Literal,false,
                req.action==Action::Fetch ? BifSlot{Value::string(symbol)} : std::nullopt};
    }
    const std::string resolved=compoundSymbol(symbol)?compoundKey(vars,symbol):symbol;
    const Value* previous=lookup(vars,resolved);
    std::optional<Value> boundElement;
    if (compoundSymbol(symbol) && symbol.find('.')+1 < symbol.size()) {   // a compound variable (stem plus tail)
        const std::string stem=symbol.substr(0,symbol.find('.')+1);
        // A stem object (bound stem): the element's own state (set, default, or DROPped), its value for VALUE.
        if (StemObject *bound=boundStem(vars,stem)) {
            const std::string tail=resolved.substr(stem.size());
            if (bound->has(tail)) { boundElement=bound->get(tail); previous=&*boundElement; }
            else previous=nullptr;
        }
        else if (!previous) previous=lookup(vars,stem);   // the stem's default value
    }
    if(req.action==Action::Classify) {
        // A stem variable exists once the stem is in use: EXPOSEd (an object's stem always exists), or any of its
        // compound variables set (the interpreter also creates it on a mere reference; that case is not tracked).
        bool assigned=previous!=nullptr;
        if(!assigned && !symbol.empty() && symbol.back()=='.' && symbol.find('.')==symbol.size()-1) {
            assigned=vars.isExposed(symbol);
            for(const auto& entry:vars) if(!assigned && entry.first.size()>symbol.size() &&
                                          entry.first.compare(0,symbol.size(),symbol)==0) assigned=true;
        }
        return {SymbolKind::Assignable,assigned,std::nullopt};
    }
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
// ARG([n [,option]]) on this activation's own arguments: A (an Array of arguments n.., holes kept), E, O, N; only the
// first letter of the option counts; errors 40.4 / 40.5 / 40.12 / 40.14 / 40.904 with the interpreter's substitutions.
inline Value argBifSlots(const std::vector<Slot>& args, const std::vector<BifSlot>& a) {
    auto fail=[](const char *code, const char *text, std::vector<Value> subs) {
        SyntaxCondition c(code, text, false); c.substitutions=std::move(subs); throw c;
    };
    const Value argName=Value::string("ARG");
    std::size_t count=args.size();
    while(count>0 && !args[count-1]) --count;
    if(a.empty()) return Value::string(std::to_string(count));
    if(a.size()>2) fail("40.4","Too many arguments in invocation of ARG",{argName,Value::string("2")});
    if(!a[0]) fail("40.5","Missing argument in invocation of ARG",{argName,Value::string("1")});
    const Value &nv=*a[0];
    RexxDecimal d; const char *perr=nullptr;
    if(nv.isObject() || !tryParseRexxDecimal(nv,d,perr)) fail("40.12","ARG argument must be a whole number",{argName,Value::string("1"),nv});
    cpp_int value=d.coefficient;
    if(d.exponent>40) value*=decimalPow10Compute(40);           // beyond any argument count either way (exponents reach 999999999)
    else if(d.exponent>0) value*=decimalPow10Compute(d.exponent);
    else if(d.exponent<0) {
        if(-d.exponent>decimalDigits(d.coefficient)) fail("40.12","ARG argument must be a whole number",{argName,Value::string("1"),nv});
        const cpp_int p=decimalPow10Compute(-d.exponent);
        if(value % p != 0) fail("40.12","ARG argument must be a whole number",{argName,Value::string("1"),nv});
        value/=p;
    }
    if(value<=0) fail("40.14","ARG argument must be positive",{argName,Value::string("1"),nv});
    const std::size_t n = value > cpp_int(args.size()+1) ? args.size()+1 : static_cast<std::size_t>(value);
    const bool exists=n<=args.size() && args[n-1];
    char o='N';
    if(a.size()>1 && a[1]) {
        const Value &ov=*a[1];
        const std::string text=ov.isObject() ? ov.object->display() : ov.bytes.str();
        const char c=text.empty() ? '\0' : static_cast<char>(std::toupper(static_cast<unsigned char>(text[0])));
        if(c!='A' && c!='E' && c!='N' && c!='O') fail("40.904","ARG argument must be one of AENO",{argName,Value::string("2"),Value::string("AENO"),Value::string(text)});
        o=c;
    }
    if(o=='E') return Value::string(exists?"1":"0");
    if(o=='O') return Value::string(exists?"0":"1");
    if(o=='N') return exists?argSlotValue(args[n-1]):Value::string("");
#ifdef RX2CPP_HOST_API
    // A: the arguments from n to the last one that exists, as an Array (omitted ones stay empty slots).
    const std::size_t size = n<=count ? count-n+1 : 0;
    Value array=envClass("ARRAY");
    MessageResult made=array.object->sendMessage("NEW",{Value::string(std::to_string(size))});
    if(!made) throw std::runtime_error("cannot create the ARG array");
    for(std::size_t i=0;i<size;++i)
        if(args[n-1+i]) made->object->sendMessage("PUT",{argSlotValue(args[n-1+i]),Value::string(std::to_string(i+1))});
    return *made;
#else
    throw std::runtime_error("BIF ARG: option A is not implemented in compiled programs");
#endif
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
        if(d.exponent<want && want-d.exponent>decimalDigits(d.coefficient)+1) { d.coefficient=0; d.exponent=want; }   // below half a unit
        else if(d.exponent<want) {                  // round off excess decimals, half up
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
// The arguments are pointers (nullptr: omitted), so a compiled call site with its arguments at hand (rx::bifDirect)
// and the argument-vector route (quickBif) run this same code.
inline bool quickCount(const Value *slot, std::size_t &out, bool positive) {
    if (!slot || slot->isObject()) return false;
    {   // a number made by arithmetic: its characters are its digits (no sign, no leading zero), not written out here
        const std::uint32_t m = slot->bytes.numCache().meta.load(std::memory_order_acquire);
        if ((m & NumCache::pending) && (m & NumCache::integer)) {
            const std::int64_t c = slot->bytes.numCache().coef.load(std::memory_order_relaxed);
            if (c < 0 || (positive && c == 0)) return false;
            out = static_cast<std::size_t>(c); return true;
        }
    }
    const std::string &t = slot->bytes;
    if (t.empty() || t.size() > 9) return false;
    std::size_t v = 0;
    for (char c : t) { if (c < '0' || c > '9') return false; v = v * 10 + static_cast<std::size_t>(c - '0'); }
    if (positive && v == 0) return false;
    out = v; return true;
}
inline bool quickText(const Value *slot) { return slot && !slot->isObject(); }
inline bool quickPad(const Value *const *a, std::size_t n, std::size_t i, char &pad) {
    pad = ' ';
    if (n <= i) return true;
    if (!quickText(a[i]) || a[i]->bytes.size() != 1) return false;
    pad = a[i]->bytes[0]; return true;
}
inline bool quickBlanksOnly(const std::string &s) {
    for (char c : s) if (c == '\t' || c == '\n' || c == '\r' || c == '\v' || c == '\f') return false;
    return true;
}
// The commonest built-ins by a code fixed when compiled (rx::bifDirect) or found from the name (quickBif).
enum class QuickBif { None, Length, Lastpos, Left, Pos, Right, Substr, Word, Words };
inline QuickBif quickBifOf(const std::string &name) {
    if (name.empty()) return QuickBif::None;
    switch (name[0]) {
    case 'L':
        if (rx::eqLit(name, "LENGTH")) return QuickBif::Length;
        if (rx::eqLit(name, "LASTPOS")) return QuickBif::Lastpos;
        if (rx::eqLit(name, "LEFT")) return QuickBif::Left;
        break;
    case 'P': if (rx::eqLit(name, "POS")) return QuickBif::Pos; break;
    case 'R': if (rx::eqLit(name, "RIGHT")) return QuickBif::Right; break;
    case 'S': if (rx::eqLit(name, "SUBSTR")) return QuickBif::Substr; break;
    case 'W':
        if (rx::eqLit(name, "WORD")) return QuickBif::Word;
        if (rx::eqLit(name, "WORDS")) return QuickBif::Words;
        break;
    default: break;
    }
    return QuickBif::None;
}
inline std::optional<Value> quickBif(QuickBif which, const Value *const *a, std::size_t n) {
    if (which == QuickBif::None || n == 0 || !quickText(a[0])) return std::nullopt;
    const std::string &s = a[0]->bytes;
    switch (which) {
    case QuickBif::Length:
        if (n == 1) return fromInteger(static_cast<std::int64_t>(s.size()));
        break;
    case QuickBif::Lastpos:
        if (n == 2 || n == 3) {
            if (!quickText(a[1])) return std::nullopt;
            const std::string &hay = a[1]->bytes;
            std::size_t start = hay.size();
            if (n == 3 && !quickCount(a[2], start, true)) return std::nullopt;
            if (s.empty() || s.size() > hay.size()) return fromInteger(0);
            // The match must END at or before position start.
            const std::size_t lastStart = std::min(start, hay.size()) >= s.size() ? std::min(start, hay.size()) - s.size() : std::string::npos;
            if (lastStart == std::string::npos) return fromInteger(0);
            const auto at = hay.rfind(s, lastStart);
            return fromInteger(at == std::string::npos ? 0 : static_cast<std::int64_t>(at + 1));
        }
        break;
    case QuickBif::Left:
        if (n == 2 || n == 3) {
            std::size_t len; char pad;
            if (!quickCount(a[1], len, false) || !quickPad(a, n, 2, pad)) return std::nullopt;
            std::string out = s.substr(0, std::min(len, s.size()));
            out.resize(len, pad);
            return Value(std::move(out));
        }
        break;
    case QuickBif::Pos:
        if (n == 2 || n == 3) {
            if (!quickText(a[1])) return std::nullopt;
            const std::string &hay = a[1]->bytes;
            std::size_t start = 1;
            if (n == 3 && !quickCount(a[2], start, true)) return std::nullopt;
            if (s.empty() || start > hay.size()) return fromInteger(0);
            const auto at = hay.find(s, start - 1);
            return fromInteger(at == std::string::npos ? 0 : static_cast<std::int64_t>(at + 1));
        }
        break;
    case QuickBif::Right:
        if (n == 2 || n == 3) {
            std::size_t len; char pad;
            if (!quickCount(a[1], len, false) || !quickPad(a, n, 2, pad)) return std::nullopt;
            if (len <= s.size()) return Value(s.substr(s.size() - len));
            return Value(std::string(len - s.size(), pad) + s);
        }
        break;
    case QuickBif::Substr:
        if (n >= 2 && n <= 4) {
            std::size_t start, len; char pad;
            if (!quickCount(a[1], start, true) || !quickPad(a, n, 3, pad)) return std::nullopt;
            const std::size_t from = start - 1;
            if (n == 2) return Value(from < s.size() ? s.substr(from) : std::string());
            if (!quickCount(a[2], len, false)) return std::nullopt;
            std::string out = from < s.size() ? s.substr(from, len) : std::string();
            out.resize(len, pad);
            return Value(std::move(out));
        }
        break;
    case QuickBif::Word:
    case QuickBif::Words:
        if ((which == QuickBif::Word && n == 2) || (which == QuickBif::Words && n == 1)) {
            if (!quickBlanksOnly(s)) return std::nullopt;
            std::size_t want = 0;
            if (n == 2 && !quickCount(a[1], want, true)) return std::nullopt;
            std::size_t i = 0, count = 0;
            while (true) {
                while (i < s.size() && s[i] == ' ') ++i;
                if (i >= s.size()) break;
                const std::size_t b = i;
                while (i < s.size() && s[i] != ' ') ++i;
                if (++count == want) return Value(s.substr(b, i - b));
            }
            if (n == 1) return fromInteger(static_cast<std::int64_t>(count));
            return Value(std::string());
        }
        break;
    default: break;
    }
    return std::nullopt;
}
inline std::optional<Value> quickBif(const std::string &name, const std::vector<BifSlot> &a) {
    const QuickBif which = quickBifOf(name);
    if (which == QuickBif::None || a.empty() || a.size() > 4) return std::nullopt;
    const Value *p[4];
    for (std::size_t i = 0; i < a.size(); ++i) p[i] = a[i] ? &*a[i] : nullptr;
    return quickBif(which, p, a.size());
}
// 256^n by multiplication: GCC 13 reports a false -Warray-bounds inside cpp_int for a shift of cpp_int(1) by 8n bits.
inline boost::multiprecision::cpp_int byteRange(std::size_t n) {
    boost::multiprecision::cpp_int r = 1;
    for (std::size_t i = 0; i < n; ++i) r *= 256;
    return r;
}
// DATATYPE (A L M N U W and the one-argument form), MAX, MIN, ABS under the caller's NUMERIC settings, exactly as the
// interpreter computes them; anything else (B, X, 9, ..., objects, omitted arguments) returns nullopt for the full route.
inline std::optional<Value> numericBif(const std::string &name, const std::vector<BifSlot> &a, const ActivationNumeric &num) {
    for (const auto &x : a) if (!x || x->isObject()) return std::nullopt;
    if (num.digits < 1 || num.digits > 100000 || num.fuzz >= num.digits) return std::nullopt;
    if (rx::eqLit(name, "DATATYPE") && (a.size() == 1 || a.size() == 2)) {
        const std::string &v = a[0]->bytes;
        RexxDecimal d; const char *err = nullptr;
        if (a.size() == 1) return Value::string(tryParseRexxDecimal(*a[0], d, err) ? "NUM" : "CHAR");
        const std::string &t = a[1]->bytes;
        if (t.empty()) return std::nullopt;
        const char type = static_cast<char>(std::toupper(static_cast<unsigned char>(t[0])));
        auto all = [&](auto pred) { if (v.empty()) return false; for (unsigned char c : v) if (!pred(c)) return false; return true; };
        auto lower = [](unsigned char c) { return c >= 'a' && c <= 'z'; };
        auto upper = [](unsigned char c) { return c >= 'A' && c <= 'Z'; };
        auto digit = [](unsigned char c) { return c >= '0' && c <= '9'; };
        switch (type) {
        case 'A': return Value::string(all([&](unsigned char c) { return lower(c) || upper(c) || digit(c); }) ? "1" : "0");
        case 'L': return Value::string(all(lower) ? "1" : "0");
        case 'U': return Value::string(all(upper) ? "1" : "0");
        case 'M': return Value::string(all([&](unsigned char c) { return lower(c) || upper(c); }) ? "1" : "0");
        case 'N': return Value::string(tryParseRexxDecimal(*a[0], d, err) ? "1" : "0");
        case 'W': {
            if (!tryParseRexxDecimal(*a[0], d, err)) return Value::string("0");
            roundRexx(d, num);
            if (d.coefficient == 0) return Value::string("1");
            // A whole number must also be expressible without exponent under DIGITS (12345678901 is not, at DIGITS 9).
            if (d.exponent + decimalDigits(d.coefficient) - 1 >= static_cast<int>(num.digits)) return Value::string("0");
            if (d.exponent >= 0) return Value::string("1");
            if (-d.exponent > decimalDigits(d.coefficient)) return Value::string("0");   // a fraction
            const cpp_int &p = decimalPow10Ref(-d.exponent);
            return Value::string((d.coefficient % p) == 0 ? "1" : "0");
        }
        default: return std::nullopt;
        }
    }
    if ((rx::eqLit(name, "MAX") || rx::eqLit(name, "MIN")) && !a.empty()) {
        std::vector<RexxDecimal> ds(a.size());
        const char *err = nullptr;
        for (std::size_t i = 0; i < a.size(); ++i) if (!tryParseRexxDecimal(*a[i], ds[i], err)) return std::nullopt;
        std::size_t best = 0;
        for (std::size_t i = 1; i < ds.size(); ++i) {
            const int rel = numericRelationDecimal(ds[i], ds[best], num);
            if (rx::eqLit(name, "MAX") ? rel > 0 : rel < 0) best = i;
        }
        return numberResult(ds[best], num);
    }
    // Radix conversions (C2D D2C X2D D2X), exact for any size within DIGITS; two's complement when a length is given.
    auto wholeOf = [&](const Value &v, cpp_int &out) -> bool {
        RexxDecimal d; const char *err = nullptr;
        if (!tryParseRexxDecimal(v, d, err)) return false;
        roundRexx(d, num);
        if (d.exponent > kMaxRexxScale) return false;
        if (d.exponent >= 0) { out = d.coefficient * decimalPow10(d.exponent); return true; }
        if (-d.exponent > decimalDigits(d.coefficient)) return false;
        const cpp_int p = decimalPow10(-d.exponent);
        if (d.coefficient % p != 0) return false;
        out = d.coefficient / p;
        return true;
    };
    auto lengthOf = [&](std::size_t i, std::size_t &out) -> bool {
        const std::string &t = a[i]->bytes;
        if (t.empty() || t.size() > 9 || t.find_first_not_of("0123456789") != std::string::npos) return false;
        out = std::stoul(t); return true;
    };
    auto fits = [&](const cpp_int &v) { return decimalDigits(v < 0 ? cpp_int(-v) : v) <= static_cast<int>(num.digits); };
    auto unsignedOf = [](const std::string &bytes) { cpp_int v = 0; for (unsigned char c : bytes) { v <<= 8; v += c; } return v; };
    auto hexBytes = [](const std::string &hex, std::string &bytes) -> bool {
        std::string h;
        for (char c : hex) { if (std::isxdigit(static_cast<unsigned char>(c))) h += c; else return false; }
        if (h.size() % 2) h.insert(h.begin(), '0');
        bytes.clear();
        for (std::size_t i = 0; i < h.size(); i += 2) bytes += static_cast<char>(std::stoi(h.substr(i, 2), nullptr, 16));
        return true;
    };
    auto signedOf = [&](std::string bytes, std::size_t n) -> cpp_int {   // rightmost n bytes, two's complement
        if (bytes.size() > n) bytes = bytes.substr(bytes.size() - n);
        else bytes.insert(0, n - bytes.size(), '\0');
        cpp_int v = unsignedOf(bytes);
        if (n && (static_cast<unsigned char>(bytes[0]) & 0x80)) v -= byteRange(n);
        return v;
    };
    auto bytesOf = [](cpp_int v, std::size_t n, bool fixed) -> std::string {   // big-endian; fixed: n bytes two's complement
        std::string out;
        if (fixed) {
            if (v < 0) v += byteRange(n);
            for (std::size_t i = 0; i < n; ++i) { out.insert(out.begin(), static_cast<char>(static_cast<unsigned>(v & 0xFF))); v >>= 8; }
            return out;
        }
        if (v == 0) return std::string(1, '\0');
        while (v > 0) { out.insert(out.begin(), static_cast<char>(static_cast<unsigned>(v & 0xFF))); v >>= 8; }
        return out;
    };
    if (rx::eqLit(name, "C2D") && (a.size() == 1 || a.size() == 2)) {
        cpp_int v;
        if (a.size() == 1) v = unsignedOf(a[0]->bytes);
        else { std::size_t n; if (!lengthOf(1, n)) return std::nullopt; v = n ? signedOf(a[0]->bytes, n) : cpp_int(0); }
        if (!fits(v)) return std::nullopt;
        return Value::string(v.convert_to<std::string>());
    }
    if (rx::eqLit(name, "X2D") && (a.size() == 1 || a.size() == 2)) {
        std::string hex = a[0]->bytes, bytes;
        if (hex.find_first_of(" \t") != std::string::npos) return std::nullopt;
        cpp_int v;
        if (a.size() == 1) { if (!hexBytes(hex, bytes)) return std::nullopt; v = unsignedOf(bytes); }
        else {
            std::size_t n; if (!lengthOf(1, n)) return std::nullopt;
            for (char c : hex) if (!std::isxdigit(static_cast<unsigned char>(c))) return std::nullopt;
            if (n == 0) v = 0;
            else {
                if (hex.size() > n) hex = hex.substr(hex.size() - n); else hex.insert(0, n - hex.size(), '0');
                v = 0; for (char c : hex) { v <<= 4; v += std::stoi(std::string(1, c), nullptr, 16); }
                if (std::stoi(std::string(1, hex[0]), nullptr, 16) & 0x8) v -= cpp_int(1) << (4 * n);
            }
        }
        if (!fits(v)) return std::nullopt;
        return Value::string(v.convert_to<std::string>());
    }
    if (rx::eqLit(name, "D2C") && (a.size() == 1 || a.size() == 2)) {
        cpp_int v; if (!wholeOf(*a[0], v)) return std::nullopt;
        if (a.size() == 1) { if (v < 0) return std::nullopt; return Value(bytesOf(v, 0, false)); }
        std::size_t n; if (!lengthOf(1, n)) return std::nullopt;
        return Value(bytesOf(v, n, true));
    }
    if (rx::eqLit(name, "D2X") && (a.size() == 1 || a.size() == 2)) {
        cpp_int v; if (!wholeOf(*a[0], v)) return std::nullopt;
        static const char *hexd = "0123456789ABCDEF";
        std::string out;
        if (a.size() == 1) {
            if (v < 0) return std::nullopt;
            if (v == 0) return Value::string("0");
            while (v > 0) { out.insert(out.begin(), hexd[static_cast<unsigned>(v & 0xF)]); v >>= 4; }
            return Value(std::move(out));
        }
        std::size_t n; if (!lengthOf(1, n)) return std::nullopt;
        if (v < 0) v += cpp_int(1) << (4 * n);
        for (std::size_t i = 0; i < n; ++i) { out.insert(out.begin(), hexd[static_cast<unsigned>(v & 0xF)]); v >>= 4; }
        return Value(std::move(out));
    }
    if (rx::eqLit(name, "ABS") && a.size() == 1) {
        RexxDecimal d; const char *err = nullptr;
        if (!tryParseRexxDecimal(*a[0], d, err)) return std::nullopt;
        if (d.coefficient < 0) d.coefficient = -d.coefficient;
        return numberResult(d, num);
    }
    return std::nullopt;
}
// X2C / X2B / X2D take hex digits, B2X binary digits. The native code handles only the plain form (digits only);
// blanks between groups, their placement rules and every invalid character are the interpreter's (exact results and
// error numbers 93.931 / 93.933 / 93.976 ... with their substitutions).
inline bool plainRadixDigits(const std::string &name, const std::string &s) {
    if (rx::eqLit(name, "B2X")) return s.find_first_not_of("01") == std::string::npos;
    return s.find_first_not_of("0123456789abcdefABCDEF") == std::string::npos;
}
inline bool radixBifName(const std::string &name) { return rx::eqLit(name, "X2C") || rx::eqLit(name, "X2B") || rx::eqLit(name, "X2D") || rx::eqLit(name, "B2X"); }
// The native number / radix code covers the ordinary inputs only; anything else is the interpreter's (its results,
// NUMERIC DIGITS limits and errors, e.g. 93.929 for D2C(209) under DIGITS 1). True when this call must go there.
inline bool numericEdgeName(const std::string &name) {
    static const std::unordered_set<std::string> numeric{"DATATYPE","ABS","SIGN","MAX","MIN","TRUNC","FORMAT","D2C","D2X",
        "C2D","X2D","DIGITS","FUZZ"};
    return numeric.count(name) != 0;
}
// (name is one of numericEdgeName's)
inline bool numericEdgeArgs(const std::string &name, const std::vector<BifSlot> &a, const ActivationNumeric &num);
inline bool numericEdgeForInterpreter(const std::string &name, const std::vector<BifSlot> &a, const ActivationNumeric &num) {
    return numericEdgeName(name) && numericEdgeArgs(name, a, num);
}
inline bool numericEdgeArgs(const std::string &name, const std::vector<BifSlot> &a, const ActivationNumeric &num) {
    for (const auto &s : a) if (s && !s->isObject() && s->bytes.size() > 1000) return true;
    // A number this subset cannot hold (exponent beyond its range) is still a number to the interpreter.
    for (const auto &s : a) if (s && !s->isObject()) {
        RexxDecimal d; const char *err = nullptr;
        if (!tryParseRexxDecimal(*s, d, err) && err && std::strstr(err, "supported")) return true;
    }
    if (a.empty() || !a[0] || a[0]->isObject()) return false;
    const std::string first = a[0]->bytes.str();
    if (rx::eqLit(name, "D2C") || rx::eqLit(name, "D2X")) {
        if (a.size() > 1) return true;   // the signed form (with a length) is the interpreter's
        return first.empty() || first.size() > static_cast<std::size_t>(num.digits) ||
               first.find_first_not_of("0123456789") != std::string::npos;
    }
    // FORMAT: exponent places (expp / expt), or a number with more digits than DIGITS (rounded first, possibly to
    // exponential form): the interpreter's NumberString::formatInternal.
    if (rx::eqLit(name, "FORMAT")) {
        if (a.size() > 3) return true;
        RexxDecimal d; const char *err = nullptr;
        return tryParseRexxDecimal(*a[0], d, err) && decimalDigits(d.coefficient) > static_cast<int>(num.digits);
    }
    if (rx::eqLit(name, "C2D")) return a.size() > 1 || first.size() > 3;
    if (rx::eqLit(name, "X2D")) return a.size() > 1 || first.size() > 7;
    return false;
}
// SOURCELINE([n]) of compiled code: the lines of its original source file, embedded when it was compiled (the package
// the interpreter sees is the library's declaration, not that file). Errors as BUILTIN(SOURCELINE).
inline Value sourceLineBif(const std::vector<std::string> &lines, const std::vector<BifSlot> &a) {
    auto fail = [](const char *code, const std::string &text, std::vector<Value> subs) {
        SyntaxCondition c(code, text, false); c.substitutions = std::move(subs); throw c;
    };
    if (a.size() > 1) fail("40.4", "Too many arguments in invocation of SOURCELINE; maximum expected is 1",
                           {Value::string("SOURCELINE"), Value::string("1")});
    if (a.empty()) return Value::string(std::to_string(lines.size()));
    if (!a[0]) fail("40.5", "Missing argument in invocation of SOURCELINE; argument 1 is required",
                    {Value::string("SOURCELINE"), Value::string("1")});
    if (a[0]->isObject()) throw std::runtime_error("SOURCELINE: the line number must be a string");
    const std::string text = a[0]->bytes.str();
    RexxDecimal d; const char *err = nullptr;
    std::int64_t n = 0;
    if (!tryParseRexxDecimal(*a[0], d, err) || !oorexxWholeNumber(d, 18, true, n))
        fail("40.12", "SOURCELINE argument 1 must be a whole number; found \"" + text + "\"",
             {Value::string("SOURCELINE"), Value::string("1"), *a[0]});
    if (n <= 0) fail("40.14", "SOURCELINE argument 1 must be positive; found \"" + text + "\"",
                     {Value::string("SOURCELINE"), Value::string("1"), *a[0]});
    if (static_cast<std::uint64_t>(n) > lines.size())
        fail("40.34", "SOURCELINE argument 1 (\"" + std::to_string(n) + "\") must be less than or equal to the number of lines in the program (" +
                      std::to_string(lines.size()) + ")", {Value::string(std::to_string(n)), Value::string(std::to_string(lines.size()))});
    return Value::string(lines[static_cast<std::size_t>(n - 1)]);
}
// BIFs that read or set the caller's own state stay compiled whatever their arguments are.
inline bool languageStateBif(const std::string &name) {
    return rx::eqLit(name, "VALUE") || rx::eqLit(name, "VAR") || rx::eqLit(name, "SYMBOL") || rx::eqLit(name, "TRACE") || rx::eqLit(name, "ADDRESS") || rx::eqLit(name, "ARG") ||
           rx::eqLit(name, "DIGITS") || rx::eqLit(name, "FUZZ") || rx::eqLit(name, "FORM") || rx::eqLit(name, "CONDITION");
}
inline Value dispatchBifNative(BifRuntime& bif, Variables& vars, const std::string& name,
                               const std::vector<BifSlot>& slots);
// Built-ins without side effects: when the native implementation refuses a call, the interpreter's own built-in decides
// (its exact error, or its result where the native subset is narrower).
inline bool pureBif(const std::string &name) {
    static const std::unordered_set<std::string> impure{"VALUE","VAR","SYMBOL","TRACE","ADDRESS","ARG","DIGITS","FUZZ","FORM",
        "CONDITION","LINEIN","LINEOUT","CHARIN","CHAROUT","CHARS","LINES","STREAM","QUEUED","RANDOM","SETLOCAL","ENDLOCAL",
        "DIRECTORY","FILESPEC","QUALIFY","RXQUEUE","BEEP","USERID","ERRORTEXT","SOURCELINE"};
    return impure.count(name) == 0;
}
// What the interpreter's own BIF runs instead of the compiled-in breadth catalogue (see dispatchBifNative).
inline bool isolatedBif(const std::string &name) {
    static const std::unordered_set<std::string> isolated{"C2D","TRUNC","X2D","D2X","D2C","TRANSLATE","VERIFY",
        "DATATYPE","SIGN","FORMAT","MAX","MIN","XRANGE","USERID","ERRORTEXT","QUALIFY"};
    return isolated.count(name) != 0;
}
// A built-in function's name with what dispatch asks about it, worked out once: a compiled call site keeps one
// (static), so a call does not look its name up in the tables again (as the interpreter binds a built-in when it
// parses the clause).
struct BifName {
    std::string name;
    bool pure, languageState, numericEdge, radix, isolated;
    explicit BifName(std::string n)
        : name(std::move(n)), pure(pureBif(name)), languageState(languageStateBif(name)), numericEdge(numericEdgeName(name)),
          radix(radixBifName(name)), isolated(isolatedBif(name)) {}
};
inline Value dispatchBifNative(BifRuntime& bif, Variables& vars, const BifName& n, const std::vector<BifSlot>& slots);
inline Value dispatchBif(BifRuntime& bif, Variables& vars, const BifName& n, const std::vector<BifSlot>& slots) {
#ifdef RX2CPP_HOST_API
    const std::string &name = n.name;
    if (n.pure) {
        try { return dispatchBifNative(bif, vars, n, slots); }
        catch (const std::runtime_error &) {
            auto result = interpreterCall(vars, name, slots);
            if (!result) throw std::runtime_error("BIF " + name + ": no result");
            return std::move(*result);
        }
    }
#endif
    return dispatchBifNative(bif, vars, n, slots);
}
inline Value dispatchBif(BifRuntime& bif, Variables& vars, const std::string& name,
                         const std::vector<BifSlot>& slots) {
    return dispatchBif(bif, vars, BifName(name), slots);
}
// A built-in whose name the compiler knows, called with all its arguments present (HybridFunctionCall): the quickBif
// answer from the arguments in place (no argument vector, no name lookup), when they are strings and quickBif takes
// the call; anything else is the full route with the same arguments, as before.
template <typename... A>
inline Value bifDirect(BifRuntime &bif, Variables &vars, const BifName &n, QuickBif which, const A &...args) {
    const Value *p[sizeof...(A)] = {&args...};
    bool plain = true;
    for (const Value *x : p) if (x->isObject()) plain = false;
    if (plain) { if (auto r = quickBif(which, p, sizeof...(A))) return std::move(*r); }
    std::vector<BifSlot> slots;
    slots.reserve(sizeof...(A));
    (slots.emplace_back(args), ...);
    return dispatchBif(bif, vars, n, slots);
}
inline Value dispatchBifNative(BifRuntime& bif, Variables& vars, const std::string& name,
                               const std::vector<BifSlot>& slots) {
    return dispatchBifNative(bif, vars, BifName(name), slots);
}
inline Value dispatchBifNative(BifRuntime& bif, Variables& vars, const BifName& n, const std::vector<BifSlot>& slots) {
    const std::string &name = n.name;
#ifdef RX2CPP_HOST_API
    // An object argument (other than a String, which is a value) goes to the interpreter's own BIF: its ~STRING / ~REQUEST
    // rules and its errors, exactly.
    if (!n.languageState) {
        for (const auto &slot : slots) {
            if (!slot || !slot->isObject()) continue;
            auto result = interpreterCall(vars, name, slots);
            if (!result) throw std::runtime_error("BIF " + name + ": no result");
            return std::move(*result);
        }
    }
    // ERRORTEXT: the interpreter's own message table (its texts differ from the condition-message table compiled in).
    if (rx::eqLit(name, "ERRORTEXT") || (n.numericEdge && numericEdgeArgs(name, slots, vars.numeric)) ||
        (n.radix && !slots.empty() && slots[0] && !slots[0]->isObject() && !plainRadixDigits(name, slots[0]->bytes.str()))) {
        auto result = interpreterCall(vars, name, slots);
        if (!result) throw std::runtime_error("BIF " + name + ": no result");
        return std::move(*result);
    }
#endif
    if(auto quick=quickBif(name,slots)) return std::move(*quick);
    if(auto numeric=numericBif(name,slots,vars.numeric)) return std::move(*numeric);
#ifdef RX2CPP_HOST_API
    if(streamBifName(name)) return streamBif(vars,name,slots);
    if(rx::eqLit(name, "RANDOM")) return randomBif(vars,slots);
    if(rx::eqLit(name, "TIME") || rx::eqLit(name, "DATE")) return timeDateBif(vars,name,slots);
#endif
    if(rx::eqLit(name, "TRACE") || rx::eqLit(name, "ADDRESS")) {   // language state owned by the compiled program, not by a BIF
        if(slots.size()>1 || (slots.size()==1 && (!slots[0] || slots[0]->isObject())))
            throw std::runtime_error("BIF "+name+": invalid arguments");
        if(rx::eqLit(name, "TRACE")) return Value::string(slots.empty() ? traceSetting() : traceSet(*slots[0]));
        return Value::string(slots.empty() ? addressEnvironment() : addressSet(*slots[0]));
    }
#ifdef RX2CPP_HOST_API
    // VALUE(name, [new], selector): ENVIRONMENT, '' (.environment) and every other selector belong to the interpreter
    // that loaded this library, so its own VALUE runs (same results, same errors); the local pool stays compiled.
    if(rx::eqLit(name, "VALUE") && slots.size()>=3 && slots[2]) {
        auto result=interpreterCall(vars,"VALUE",slots);
        if(!result) throw std::runtime_error("BIF VALUE: no result");
        return std::move(*result);
    }
#endif
#ifdef RX2CPP_HOST_API
    // An environment symbol (.name) is looked up by the interpreter (the library's package scope), not in the pool.
    if((rx::eqLit(name, "SYMBOL") || rx::eqLit(name, "VAR") || rx::eqLit(name, "VALUE")) && !slots.empty() && slots[0] && !slots[0]->isObject() &&
       slots[0]->bytes.size()>1 && slots[0]->bytes[0]=='.' && scanSymbol(slots[0]->bytes.str())==SymbolScan::Literal) {
        auto result=interpreterCall(vars,name,slots);
        if(!result) throw std::runtime_error("BIF "+name+": no result");
        return std::move(*result);
    }
    // VALUE of a string that is not a symbol, or assigning a constant symbol: the interpreter's error (40.26, ...),
    // raised before anything is assigned.
    if(rx::eqLit(name, "VALUE") && !slots.empty() && slots[0] && !slots[0]->isObject()) {
        std::string canonical; bool literal=false;
        if(!splitBifSymbol(slots[0]->bytes.str(),canonical,literal) || (literal && slots.size()>1 && slots[1])) {
            auto result=interpreterCall(vars,name,slots);
            if(!result) throw std::runtime_error("BIF VALUE: no result");
            return std::move(*result);
        }
    }
#endif
    if(rx::eqLit(name, "SYMBOL") || rx::eqLit(name, "VAR") || rx::eqLit(name, "VALUE")) {
        rxbif_variables::VariableRouter router(bif.native,
            [&vars]{return frameNumeric(vars);},
            [&vars](const rxbif_variables::Request& req,
                    const rxbif_breadth::NumericContext& numbers) {
                return frameVariableReply(vars,req,numbers);
            });
        return router.invoke(name,slots);
    }
#ifndef RX2CPP_KERNEL
    if(rx::eqLit(name, "FORMAT")) return formatBifFixed(slots, vars.numeric);
#endif
#ifdef RX2CPP_KERNEL
    // The compiled-in ooRexx kernel runs the REAL handler: validation, defaults, omitted arguments and error text included.
    if(rxkernel::handles(name)) {
        bool crossable=true;
        std::vector<std::string> raw; std::vector<bool> present;
        for(const auto& slot:slots) {
            if(slot && slot->isObject()) { crossable=false; break; }
            raw.push_back(slot ? slot->bytes.str() : std::string()); present.push_back(static_cast<bool>(slot));
        }
        if(crossable) {
            std::string out,code,text;
            if(rxkernel::call(name,raw,present,out,code,text)) return Value::string(out);
            throw SyntaxCondition(code,text,false);
        }
    }
#endif
#ifdef RX2CPP_HOST_API
    // What the breadth catalogue would run in an isolated second interpreter instance, the interpreter that loaded this
    // library runs itself (its exact results and errors, e.g. XRANGE 40.23).
    {
        if(n.isolated) {
            auto result=interpreterCall(vars,name,slots);
            if(!result) throw std::runtime_error("BIF "+name+": no result");
            return std::move(*result);
        }
    }
#endif
    // Supplier captures the CURRENT activation, including nested PROCEDURE.
    // A per-call context avoids retained references to expired routine locals.
    rxbif_breadth::Context current(bif.native,bif.dispatch.chainback,
                                    std::nullopt,[&vars]{return frameNumeric(vars);});
    return rxbif_breadth::invoke(name,slots,current);
}
// String methods that are the BIF of the same name: receiver first (s~left(3) = LEFT(s, 3)) or receiver second
// (s~pos(n) = POS(n, s)). Runs under the caller's NUMERIC settings. nullopt for any other selector.
inline std::optional<MessageResult> stringMethodViaBif(const Value &receiver, const std::string &selector, const std::vector<Value> &args) {
    static const char *first[] = {"LEFT","RIGHT","SUBSTR","STRIP","WORD","WORDS","SUBWORD","DELSTR","DELWORD","CENTER","CENTRE",
        "COPIES","REVERSE","C2X","X2C","C2D","D2C","X2D","D2X","B2X","X2B","TRANSLATE","VERIFY","SPACE","TRUNC","FORMAT","ABS",
        "SIGN","MAX","MIN","DATATYPE","BITAND","BITOR","BITXOR","LENGTH","ABBREV","COMPARE","UPPER","LOWER","WORDINDEX",
        "WORDLENGTH", nullptr};
    static const char *second[] = {"POS","LASTPOS","COUNTSTR","CHANGESTR","WORDPOS","INSERT","OVERLAY", nullptr};
    std::string up = selector;
    for (char &c : up) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
    int where = 0;
    for (const char **n = first; *n && !where; ++n) if (up == *n) where = 1;
    for (const char **n = second; *n && !where; ++n) if (up == *n) where = 2;
    if (!where) return std::nullopt;
    for (const Value &a : args) if (a.isObject()) return std::nullopt;
    std::vector<BifSlot> slots;
    slots.reserve(args.size() + 1);
    if (where == 1) slots.emplace_back(receiver);
    for (std::size_t i = 0; i < args.size(); ++i) {
        if (where == 2 && i == 1) slots.emplace_back(receiver);
        slots.emplace_back(args[i]);
    }
    if (where == 2 && args.size() < 2) slots.emplace_back(receiver);
    static thread_local BifRuntime runtime;
    Variables vars;
    if (currentNumeric) vars.numeric = *currentNumeric;
    return MessageResult(dispatchBif(runtime, vars, up, slots));
}
inline const bool stringMethodViaBifInstalled = (stringBifExtension() = &stringMethodViaBif, true);
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
    if (rx::eqLit(name, "C2D") && args.empty()) {
        if (r.size() > 16) return std::nullopt;
        unsigned __int128 v = 0;
        for (unsigned char c : r) v = (v << 8) | c;
        std::string d = u128ToDecimal(v);
        if (d.size() > digits) return std::nullopt;
        return d;
    }
    if (rx::eqLit(name, "D2C") && args.size() == 1) {
        auto v = decimalToU128(r);
        auto len = decimalToU128(args[0].bytes);
        if (!v || !len || *len > 16 || *len == 0 || r.size() > digits) return std::nullopt;
        unsigned bytes = static_cast<unsigned>(*len);
        std::string raw(bytes, '\0');
        unsigned __int128 x = *v;
        for (unsigned i = 0; i < bytes; i++) { raw[bytes - 1 - i] = static_cast<char>(x & 0xFF); x >>= 8; }
        return raw;
    }
    if (rx::eqLit(name, "D2X") && args.size() == 1) {   // the length counts hexadecimal digits
        auto v = decimalToU128(r);
        auto len = decimalToU128(args[0].bytes);
        if (!v || !len || *len > 32 || *len == 0 || r.size() > digits) return std::nullopt;
        unsigned nibbles = static_cast<unsigned>(*len);
        std::string hex(nibbles, '0');
        unsigned __int128 x = *v;
        for (unsigned i = 0; i < nibbles; i++) { hex[nibbles - 1 - i] = hexd[static_cast<unsigned>(x & 15)]; x >>= 4; }
        return hex;
    }
    if (rx::eqLit(name, "X2D") && args.empty()) {
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
        if (rx::eqLit(name, "LENGTH") && args.empty()) return std::to_string(s.size());
        if (rx::eqLit(name, "BITXOR") || rx::eqLit(name, "BITAND")) {
            if (args.size() != 1 || args[0].isObject()) return std::nullopt;
            const std::string &t = args[0].bytes;
            const std::string &longer = s.size() >= t.size() ? s : t;
            const std::size_t m = s.size() < t.size() ? s.size() : t.size();
            std::string r = longer;                       // BITXOR keeps the longer operand's tail; BITAND likewise (no pad)
            if (rx::eqLit(name, "BITXOR")) for (std::size_t i = 0; i < m; i++) r[i] = static_cast<char>(s[i] ^ t[i]);
            else for (std::size_t i = 0; i < m; i++) r[i] = static_cast<char>(s[i] & t[i]);
            return r;
        }
        return std::nullopt;
    default: break;
    }
    if (rx::eqLit(name, "BITOR") && args.size() == 1 && !args[0].isObject()) {
        const std::string &t = args[0].bytes;
        const std::string &longer = s.size() >= t.size() ? s : t;
        const std::size_t m = s.size() < t.size() ? s.size() : t.size();
        std::string r = longer;
        for (std::size_t i = 0; i < m; i++) r[i] = static_cast<char>(s[i] | t[i]);
        return r;
    }
    if (rx::eqLit(name, "REVERSE") && args.empty()) return std::string(s.rbegin(), s.rend());
    if (rx::eqLit(name, "SUBSTR") && (args.size() == 1 || args.size() == 2)) {
        std::size_t n, len = 0;
        if (!plainCount(args[0], n) || n < 1) return std::nullopt;
        const std::size_t start = n - 1, avail = start < s.size() ? s.size() - start : 0;
        if (args.size() == 1) return s.substr(start < s.size() ? start : s.size());
        if (!plainCount(args[1], len)) return std::nullopt;
        const std::size_t take = len < avail ? len : avail;
        return (avail ? s.substr(start, take) : std::string()) + std::string(len - take, ' ');
    }
    if ((rx::eqLit(name, "LEFT") || rx::eqLit(name, "RIGHT")) && args.size() == 1) {
        std::size_t len;
        if (!plainCount(args[0], len)) return std::nullopt;
        if (rx::eqLit(name, "LEFT")) return len <= s.size() ? s.substr(0, len) : s + std::string(len - s.size(), ' ');
        return len <= s.size() ? s.substr(s.size() - len) : std::string(len - s.size(), ' ') + s;
    }
    if (rx::eqLit(name, "C2X") && args.empty()) {
        static const char hex[] = "0123456789ABCDEF";
        std::string r; r.reserve(s.size() * 2);
        for (unsigned char c : s) { r.push_back(hex[c >> 4]); r.push_back(hex[c & 15]); }
        return r;
    }
    return std::nullopt;
}
inline std::unordered_map<void *, bool> &stringIsACache() { static thread_local std::unordered_map<void *, bool> m; return m; }
// The interpreter class object an ISA argument stands for: an interpreter class, or a compiled / native class wrapper.
inline void *stringIsAKey(const Value &cls) {
    if (auto *e = dynamic_cast<EnvObject *>(cls.object.get())) return e->handle;
    if (auto *n = dynamic_cast<NativeRefBase *>(cls.object.get())) return n->materialize();
    return nullptr;
}
// String methods that are hot in parsers (json.cls): [] (no padding), VERIFY with options, ISA of a class object.
inline std::optional<MessageResult> quickStringMethod(const std::string &name, const Value &receiver, const std::vector<Value> &args) {
    const std::string &s = receiver.bytes;
    auto count = [](const Value &v, std::size_t &out, bool positive) {
        if (v.isObject() || v.bytes.empty() || v.bytes.size() > 9 || v.bytes.find_first_not_of("0123456789") != std::string::npos) return false;
        out = std::stoul(v.bytes); return !(positive && out == 0);
    };
    if (rx::eqLit(name, "[]") && (args.size() == 1 || args.size() == 2)) {
        std::size_t n, len = 1;
        if (!count(args[0], n, true) || (args.size() == 2 && !count(args[1], len, false))) return std::nullopt;
        if (n > s.size()) return MessageResult(Value::string(std::string()));
        return MessageResult(Value::string(s.substr(n - 1, len)));
    }
    if (rx::eqLit(name, "VERIFY") && !args.empty() && args.size() <= 4) {
        for (const Value &a : args) if (a.isObject() && !(dynamic_cast<EnvObject *>(a.object.get()) && static_cast<EnvObject *>(a.object.get())->handle == nullptr)) return std::nullopt;
        auto omitted = [&](std::size_t i) { return i >= args.size() || (args[i].isObject()); };
        static const std::string rxEmptyRef; const std::string &ref = args[0].isObject() ? rxEmptyRef : args[0].bytes.str();
        if (args[0].isObject()) return std::nullopt;
        bool match = false;
        if (!omitted(1)) {
            if (args[1].bytes.empty()) return std::nullopt;
            const char o = static_cast<char>(std::toupper(static_cast<unsigned char>(args[1].bytes[0])));
            if (o == 'M') match = true; else if (o != 'N') return std::nullopt;
        }
        std::size_t start = 1, len = std::string::npos;
        if (!omitted(2) && !count(args[2], start, true)) return std::nullopt;
        if (!omitted(3) && !count(args[3], len, false)) return std::nullopt;
        if (start > s.size()) return MessageResult(Value::string("0"));
        bool in[256] = {false};
        for (unsigned char c : ref) in[c] = true;
        const std::size_t end = len == std::string::npos ? s.size() : std::min(s.size(), start - 1 + len);
        for (std::size_t i = start - 1; i < end; ++i)
            if (in[static_cast<unsigned char>(s[i])] == match) return MessageResult(Value::string(std::to_string(i + 1)));
        return MessageResult(Value::string("0"));
    }
    if (rx::eqLit(name, "ISA") && args.size() == 1 && args[0].isObject()) {
        // Every plain string has class String: the answer depends only on the class object asked about.
        void *h = stringIsAKey(args[0]);
        if (!h) return std::nullopt;
        auto it = stringIsACache().find(h);
        if (it != stringIsACache().end()) return MessageResult(Value::string(it->second ? "1" : "0"));
        return std::nullopt;
    }
    auto plainArgs = [&]() { for (const Value &a : args) if (a.isObject()) return false; return true; };
    // A string's STRING / MAKESTRING / REQUEST('STRING') is the string itself.
    if ((rx::eqLit(name, "STRING") || rx::eqLit(name, "MAKESTRING")) && args.empty()) return MessageResult(receiver);
    if (rx::eqLit(name, "REQUEST") && args.size() == 1 && !args[0].isObject()) {
        std::string w = args[0].bytes;
        for (char &c : w) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
        if (w == "STRING") return MessageResult(receiver);
        return std::nullopt;
    }
    // hay~POS(needle [, start]) / ~LASTPOS: the POS / LASTPOS built-ins with the receiver as haystack.
    if ((rx::eqLit(name, "POS") || rx::eqLit(name, "LASTPOS")) && (args.size() == 1 || args.size() == 2) && plainArgs()) {
        std::vector<BifSlot> a{args[0], receiver};
        if (args.size() == 2) a.emplace_back(args[1]);
        if (auto r = quickBif(name, a)) return MessageResult(std::move(*r));
        return std::nullopt;
    }
    if (rx::eqLit(name, "COUNTSTR") && args.size() == 1 && plainArgs()) {
        const std::string &needle = args[0].bytes;
        std::size_t n = 0;
        if (!needle.empty())
            for (std::size_t at = s.find(needle); at != std::string::npos; at = s.find(needle, at + needle.size())) ++n;
        return MessageResult(Value::string(std::to_string(n)));
    }
    if (rx::eqLit(name, "CHANGESTR") && (args.size() == 2 || args.size() == 3) && plainArgs()) {
        const std::string &needle = args[0].bytes, &repl = args[1].bytes;
        std::size_t limit = std::string::npos;
        if (args.size() == 3 && !count(args[2], limit, false)) return std::nullopt;
        if (needle.empty() || limit == 0) return MessageResult(receiver);
        std::string out;
        out.reserve(s.size());
        std::size_t from = 0, done = 0;
        for (std::size_t at = s.find(needle); at != std::string::npos && done < limit; at = s.find(needle, from)) {
            out.append(s, from, at - from);
            out += repl;
            from = at + needle.size();
            ++done;
        }
        out.append(s, from, std::string::npos);
        return MessageResult(Value::string(std::move(out)));
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
    if (radixBifName(name) && !receiver.isObject() && !plainRadixDigits(name, receiver.bytes.str())) return fallback();
    {
        std::vector<BifSlot> asSlots{BifSlot(receiver)};
        for (const Value &v : args) asSlots.emplace_back(v);
        const ActivationNumeric def0;
        if (numericEdgeForInterpreter(name, asSlots, currentNumeric ? *currentNumeric : def0)) return fallback();
    }
    if (rx::eqLit(name, "C2D") || rx::eqLit(name, "D2C") || rx::eqLit(name, "X2D") || rx::eqLit(name, "D2X")) {
        const ActivationNumeric def0;
        const ActivationNumeric &n0 = currentNumeric ? *currentNumeric : def0;
        if (auto fast = fastRadix(name, receiver, args, n0.digits)) return MessageResult(Value::string(*fast));
    }
    if (auto quick = quickStringBif(name, receiver, args)) return MessageResult(Value::string(*quick));
    if (auto quick = quickStringMethod(name, receiver, args)) return std::move(*quick);
    if (rx::eqLit(name, "ISA") && args.size() == 1 && args[0].isObject())
        if (void *h = stringIsAKey(args[0])) {
            MessageResult r = fallback();   // the interpreter answers once per class object; plain strings all share class String
            if (r && !r->isObject()) stringIsACache()[h] = r->bytes == "1";
            return r;
        }
    if (rx::eqLit(name, "SUBCHAR") && args.size() == 1 && !args[0].isObject() && !args[0].bytes.empty() && args[0].bytes.size() < 10 &&
        args[0].bytes.find_first_not_of("0123456789") == std::string::npos) {
        const unsigned long n = std::stoul(args[0].bytes);   // SUBCHAR(n): the n-th character, "" beyond the end
        if (n >= 1) return MessageResult(Value::string(n <= receiver.bytes.size() ? std::string(1, receiver.bytes[n - 1]) : std::string()));
    }
    if (rx::eqLit(name, "DATATYPE") || rx::eqLit(name, "ABS") || rx::eqLit(name, "MAX") || rx::eqLit(name, "MIN") || rx::eqLit(name, "C2D") || rx::eqLit(name, "D2C") || rx::eqLit(name, "X2D") || rx::eqLit(name, "D2X")) {
        std::vector<BifSlot> ns; ns.emplace_back(receiver);
        bool plain = true;
        for (const Value &a : args) { if (a.isObject()) { plain = false; break; } ns.emplace_back(a); }
        if (plain) {
            const ActivationNumeric defN;
            if (auto r = numericBif(name, ns, currentNumeric ? *currentNumeric : defN)) return MessageResult(std::move(*r));
        }
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
