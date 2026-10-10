#include "rxbif_breadth.hpp"
#include "rxbif_symbol.hpp"
#include <algorithm>
#include <cctype>
#include <limits>
namespace rxbif_breadth {
void validateNumericContext(const NumericContext& context) {
    if (context.digits == 0 || context.fuzz >= context.digits)
        throw std::runtime_error("BIF chainback: invalid NUMERIC DIGITS/FUZZ snapshot");
    if (context.form != NumericForm::Scientific && context.form != NumericForm::Engineering)
        throw std::runtime_error("BIF chainback: invalid NUMERIC FORM snapshot");
}
namespace {
rx::Value delegate(const std::string& name, const std::vector<Slot>& arguments, Context& ctx) {
    if (!ctx.chainback) throw std::runtime_error("BIF " + name + ": interpreter chainback/host activation not installed");
    // Resolve the live activation anew on EVERY pass-through. A constructor-time
    // snapshot is stale after a NUMERIC instruction or nested routine return.
    const std::optional<NumericContext> numeric = ctx.currentNumeric
        ? std::optional<NumericContext>{ctx.currentNumeric()} : ctx.numeric;
    if (!numeric) throw std::runtime_error("BIF " + name + ": caller NUMERIC context missing; refusing pass-through");
    validateNumericContext(*numeric);
    return ctx.chainback(name, arguments, *numeric);
}
}
const std::vector<Spec>& catalog() {
    static const std::vector<Spec> specs = {
        {"CENTER",2,3,"NATIVE_SUBSET"},
        {"CENTRE",2,3,"NATIVE_SUBSET"},
        {"DELSTR",1,3,"NATIVE_SUBSET"},
        {"DELWORD",2,3,"NATIVE_SUBSET"},
        {"INSERT",2,5,"NATIVE_SUBSET"},
        {"LEFT",2,3,"NATIVE_SUBSET"},
        {"OVERLAY",2,5,"NATIVE_SUBSET"},
        {"POS",2,4,"NATIVE_SUBSET"},
        {"LASTPOS",2,4,"NATIVE_SUBSET"},
        {"REVERSE",1,1,"NATIVE_SUBSET"},
        {"RIGHT",2,3,"NATIVE_SUBSET"},
        {"STRIP",1,3,"NATIVE_SUBSET"},
        {"SPACE",1,3,"NATIVE_SUBSET"},
        {"SUBSTR",2,4,"NATIVE_SUBSET"},
        {"LOWER",1,3,"NATIVE_SUBSET"},
        {"UPPER",1,3,"NATIVE_SUBSET"},
        {"SUBWORD",2,3,"NATIVE_SUBSET"},
        {"WORD",2,2,"NATIVE_SUBSET"},
        {"WORDINDEX",2,2,"NATIVE_SUBSET"},
        {"WORDLENGTH",2,2,"NATIVE_SUBSET"},
        {"COPIES",2,2,"NATIVE_SUBSET"},
        {"WORDPOS",2,3,"NATIVE_SUBSET"},
        {"WORDS",1,1,"NATIVE_SUBSET"},
        {"ABBREV",2,3,"NATIVE_SUBSET"},
        {"BITAND",1,3,"NATIVE_SUBSET"},
        {"BITOR",1,3,"NATIVE_SUBSET"},
        {"BITXOR",1,3,"NATIVE_SUBSET"},
        {"B2X",1,1,"NATIVE_SUBSET"},
        {"X2B",1,1,"NATIVE_SUBSET"},
        {"C2X",1,1,"NATIVE_SUBSET"},
        {"X2C",1,1,"NATIVE_SUBSET"},
        {"C2D",1,2,"ISOLATED_REXX"},
        {"TRUNC",1,2,"ISOLATED_REXX"},
        {"X2D",1,2,"ISOLATED_REXX"},
        {"D2X",1,2,"ISOLATED_REXX"},
        {"D2C",1,2,"ISOLATED_REXX"},
        {"COMPARE",2,3,"NATIVE_SUBSET"},
        {"LENGTH",1,1,"RX2CPP_BASE_SUBSET"},
        {"TRANSLATE",1,6,"ISOLATED_REXX"},
        {"VERIFY",2,5,"ISOLATED_REXX"},
        {"DATATYPE",1,2,"ISOLATED_REXX"},
        {"ADDRESS",0,0,"HOST_ACTIVATION"},
        {"DIGITS",0,0,"HOST_ACTIVATION"},
        {"FUZZ",0,0,"HOST_ACTIVATION"},
        {"FORM",0,0,"HOST_ACTIVATION"},
        {"USERID",0,0,"ISOLATED_REXX"},
        {"ERRORTEXT",1,1,"ISOLATED_REXX"},
        {"ARG",0,2,"HOST_ACTIVATION"},
        {"DATE",0,5,"NATIVE_SUBSET"},
        {"TIME",0,3,"NATIVE_SUBSET"},
        {"RANDOM",0,3,"HOST_ACTIVATION"},
        {"XRANGE",0,std::numeric_limits<std::size_t>::max(),"ISOLATED_REXX"},
        {"SYMBOL",1,1,"HOST_ACTIVATION"},
        {"VAR",1,1,"HOST_ACTIVATION"},
        {"VALUE",1,3,"HOST_ACTIVATION"},
        {"ABS",1,1,"RX2CPP_BASE_SUBSET"},
        {"SIGN",1,1,"ISOLATED_REXX"},
        {"FORMAT",1,5,"HOST_ACTIVATION"},
        {"MAX",1,std::numeric_limits<std::size_t>::max(),"ISOLATED_REXX"},
        {"MIN",1,std::numeric_limits<std::size_t>::max(),"ISOLATED_REXX"},
        {"SOURCELINE",0,1,"HOST_ACTIVATION"},
        {"TRACE",0,1,"HOST_ACTIVATION"},
        {"LINEIN",0,3,"HOST_ACTIVATION"},
        {"CHARIN",0,3,"HOST_ACTIVATION"},
        {"LINEOUT",0,3,"HOST_ACTIVATION"},
        {"CHAROUT",0,3,"HOST_ACTIVATION"},
        {"LINES",0,2,"HOST_ACTIVATION"},
        {"CHARS",0,1,"HOST_ACTIVATION"},
        {"STREAM",1,3,"HOST_ACTIVATION"},
        {"QUEUED",0,0,"HOST_ACTIVATION"},
        {"CONDITION",0,1,"HOST_ACTIVATION"},
        {"CHANGESTR",3,4,"NATIVE_SUBSET"},
        {"COUNTSTR",2,2,"NATIVE_SUBSET"},
        {"RXFUNCADD",2,3,"HOST_ACTIVATION"},
        {"RXFUNCDROP",1,1,"HOST_ACTIVATION"},
        {"RXFUNCQUERY",1,1,"HOST_ACTIVATION"},
        {"RXQUEUE",1,2,"HOST_ACTIVATION"},
        {"SETLOCAL",0,0,"HOST_ACTIVATION"},
        {"ENDLOCAL",0,0,"HOST_ACTIVATION"},
        {"QUALIFY",1,1,"ISOLATED_REXX"},
        {"GC",0,1,"HOST_ACTIVATION"},
    };
    return specs;
}
rx::Value invoke(const std::string& requested, const std::vector<Slot>& a, Context& ctx) {
    std::string name = requested;
    for(char& c : name) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
    auto& all = catalog();
    const auto found = std::find_if(all.begin(),all.end(), [&](const Spec& x){return name == x.name;});
    if(found == all.end()) throw std::runtime_error("unknown ooRexx BUILTIN: " + name);
    if(a.size() < found->minArgs || a.size() > found->maxArgs)
        throw std::runtime_error("BIF " + name + ": incorrect argument count");
    if (ctx.preferChainback) return delegate(name,a,ctx);
    // Exact, precision-independent subset. All other DATATYPE options retain
    // their original route; never accidentally treat them as supported native.
    if (!ctx.preferChainback && name == "DATATYPE" && a.size() == 2 &&
        a[0] && a[1] && !a[0]->isObject() && !a[1]->isObject() &&
        !a[1]->bytes.empty()) {
        const unsigned char ch = static_cast<unsigned char>(a[1]->bytes[0]);
        if (ch == 'S' || ch == 's' || ch == 'V' || ch == 'v')
            return rx::Value::string(rxbif_symbol::datatype(
                a[0]->bytes, static_cast<char>(ch == 's' ? 'S' : ch == 'v' ? 'V' : ch)) ? "1" : "0");
    }

    const std::string mode = found->mode;
    if (mode == "NATIVE_SUBSET" || mode == "RX2CPP_BASE_SUBSET") {
        bool complete = true;
        std::vector<rx::Value> compact;
        compact.reserve(a.size());
        for(const auto& item : a) {
            if (!item) { complete = false; break; }
            compact.push_back(*item);
        }
        if(complete) {
            try {
                if(mode == "NATIVE_SUBSET") return rxbif::invoke(name,compact,ctx.native);
                return rx::builtinValue(name,compact);
            } catch(const rxbif::NativeSubsetUnsupported&) {
                // Retry only a declared native coverage miss. Never swallow
                // invalid-call diagnostics, resource failures or arbitrary C++
                // exceptions: these may already have changed activation state.
                if (!ctx.chainback) throw;
            }
        }
    }
    return delegate(name,a,ctx);
}
} // namespace rxbif_breadth
