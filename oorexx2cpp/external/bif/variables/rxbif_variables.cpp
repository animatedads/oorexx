#include "rxbif_variables.hpp"
#include <cctype>
#include <stdexcept>
#include <utility>
namespace rxbif_variables {
namespace {
std::string upper(std::string s) {
  for(char& c : s) c=static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
  return s;
}
std::string scalar(const Slot& a, const char* what) {
  if (!a || a->isObject())
    throw std::runtime_error(std::string("BIF variable: missing or unqualified ")+what);
  return a->bytes;
}
// A variable's value: any object (rx::Value keeps its identity and lifetime, as a variable does).
rx::Value priorResult(const Slot& value) {
  if (!value) throw std::runtime_error("BIF variable: caller provider returned no prior value");
  return *value;
}
}
VariableRouter::VariableRouter(rxbif::Context& native,
        rxbif_breadth::NumericSupplier numbers, VariableProvider provider)
    : provider_(std::move(provider)),
      chain_(native, [this](const std::string& name, const std::vector<Slot>& args,
                             const NumericContext& numbers) {return execute(name,args,numbers);},
             std::nullopt, std::move(numbers)) {
  if (!provider_ || !chain_.currentNumeric)
    throw std::invalid_argument("BIF variables require original-frame provider and live numeric supplier");
  chain_.preferChainback = true;
}
rx::Value VariableRouter::invoke(const std::string& name,const std::vector<Slot>& args) {
  const std::string canonical=upper(name);
  if (canonical!="SYMBOL" && canonical!="VAR" && canonical!="VALUE")
    throw std::runtime_error("BIF "+canonical+": no qualified variable adapter");
  return rxbif_breadth::invoke(canonical,args,chain_);
}
rx::Value VariableRouter::execute(const std::string& name,
                    const std::vector<Slot>& args,const NumericContext& numeric) {
  rxbif_breadth::validateNumericContext(numeric);
  // Always validate arguments BEFORE a provider call. All selector handling
  // belongs to the provider; no environment I/O in this library.
  if (args.empty() || !args[0])
    throw std::runtime_error("BIF "+name+": name must be supplied");
  const std::string symbol=scalar(args[0],"symbol name");
  if (name=="SYMBOL" || name=="VAR") {
    if (args.size()!=1) throw std::runtime_error("BIF "+name+": incorrect argument count");
    Reply result=provider_({Action::Classify,symbol,std::nullopt,std::nullopt},numeric);
    if(result.kind==SymbolKind::Invalid) return rx::Value::string(name=="SYMBOL"?"BAD":"0");
    if(result.kind==SymbolKind::Literal) {
      if(result.assigned) throw std::runtime_error("BIF variable: inconsistent literal classification");
      return rx::Value::string(name=="SYMBOL"?"LIT":"0");
    }
    if(result.kind!=SymbolKind::Assignable)
      throw std::runtime_error("BIF variable: unknown provider symbol classification");
    if(name=="SYMBOL") return rx::Value::string(result.assigned?"VAR":"LIT");
    return rx::Value::string(result.assigned?"1":"0");
  }
  if (args.size()>3) throw std::runtime_error("BIF VALUE: incorrect argument count");
  const Slot newValue=args.size()>1?args[1]:std::nullopt;
  const Slot selector=args.size()>2?args[2]:std::nullopt;
  if (selector && selector->isObject())
    throw std::runtime_error("BIF VALUE: selector object conversion requires qualified ABI");
  // The provider MUST perform lexical validation and snapshot/return the old
  // value before changing the original activation. For external selectors it
  // is also responsible for policy, isolation, and failure recovery.
  const Action action=newValue?Action::Exchange:Action::Fetch;
  Reply result=provider_({action,symbol,newValue,selector},numeric);
  if(result.kind==SymbolKind::Invalid)
    throw std::runtime_error("BIF VALUE: caller reported invalid symbol/selector");
  if(newValue && result.kind!=SymbolKind::Assignable)
    throw std::runtime_error("BIF VALUE: assignment to nonassignable symbol");
  return priorResult(result.prior);
}
} // namespace rxbif_variables
