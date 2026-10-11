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
inline Value dispatchBif(BifRuntime& bif, Variables& vars, const std::string& name,
                         const std::vector<BifSlot>& slots) {
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
