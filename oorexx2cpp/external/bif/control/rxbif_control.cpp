#include "rxbif_control.hpp"
#include <cctype>
#include <limits>
#include <stdexcept>
#include <utility>
namespace rxbif_control {
namespace {
std::string upper(std::string s) {
    for (char &c : s) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
    return s;
}
std::string scalar(const Slot& value, const char* name) {
    if (!value || value->isObject())
        throw std::runtime_error(std::string("BIF ") + name + ": missing or object argument requires interpreter ABI");
    return value->bytes.str();
}
std::size_t sourcePosition(const Slot& slot) {
    const auto text = scalar(slot, "SOURCELINE");
    if (text.empty()) throw std::runtime_error("BIF SOURCELINE: invalid line number");
    std::size_t position = 0;
    for (unsigned char c : text) {
        // Restricted native decimal subset. All other Rexx numeric spellings
        // explicitly reject until the original activation provides conversion.
        if (c < '0' || c > '9' || position > (std::numeric_limits<std::size_t>::max() - (c-'0')) / 10)
            throw std::runtime_error("BIF SOURCELINE: unsupported numeric line number");
        position = position * 10 + (c-'0');
    }
    if (position == 0) throw std::runtime_error("BIF SOURCELINE: line must be positive");
    return position;
}
rx::Value safeScalarResult(rx::Value result, const char* name) {
    if (result.isObject())
        throw std::runtime_error(std::string("BIF ") + name + ": object result requires qualified Rexx object identity ABI");
    return result;
}
}
ControlRouter::ControlRouter(rxbif::Context& native,
                             rxbif_breadth::NumericSupplier numeric,
                             ControlProvider activation)
  : provider_(std::move(activation)),
    routing_(native, [this](const std::string& name, const std::vector<Slot>& args,
                             const NumericContext& ctx){ return execute(name,args,ctx); },
             std::nullopt, std::move(numeric)) {
    if (!provider_ || !routing_.currentNumeric)
        throw std::invalid_argument("BIF control: original activation and dynamic numeric suppliers required");
    routing_.preferChainback = true;
}
rx::Value ControlRouter::invoke(const std::string& bif, const std::vector<Slot>& args) {
    const std::string name = upper(bif);
    if (name != "TRACE" && name != "SOURCELINE" && name != "CONDITION")
        throw std::runtime_error("BIF "+name+": no qualified control-state adapter");
    return rxbif_breadth::invoke(name,args,routing_);
}
rx::Value ControlRouter::execute(const std::string& name,
                                const std::vector<Slot>& args,const NumericContext& numeric) {
    rxbif_breadth::validateNumericContext(numeric);
    Request req{};
    if (name == "SOURCELINE") {
        if (args.size() > 1) throw std::runtime_error("BIF SOURCELINE: incorrect argument count");
        if (args.empty()) req.operation = Operation::SourceCount;
        else {
            req.operation = Operation::SourceLine;
            req.sourceLine = sourcePosition(args.front());
        }
    } else if (name == "TRACE") {
        if (args.size() > 1) throw std::runtime_error("BIF TRACE: incorrect argument count");
        if (args.empty() || !args[0]) req.operation = Operation::TraceRead;
        else {
            req.operation = Operation::TraceExchange;
            req.argument = scalar(args.front(), "TRACE");
            // Do not pretend to interpret/set trace flags here: the original
            // activation validates and changes them, returning OLD setting.
        }
    } else if (name == "CONDITION") {
        if (args.size() > 1) throw std::runtime_error("BIF CONDITION: incorrect argument count");
        const std::string option = (args.empty() || !args[0]) ? "I" : scalar(args[0], "CONDITION");
        if (option.empty()) throw std::runtime_error("BIF CONDITION: empty option");
        char letter = static_cast<char>(std::toupper(static_cast<unsigned char>(option.front())));
        if (std::string("ACDEIORS").find(letter) == std::string::npos)
            throw std::runtime_error("BIF CONDITION: invalid option");
        // A and O can return .nil, a directory, an array, or another Rexx
        // object. They cannot be represented by pretending to use empty text.
        if (letter == 'A' || letter == 'O')
            throw std::runtime_error("BIF CONDITION: option requires qualified Rexx object result ABI");
        req.operation = (letter == 'R') ? Operation::ConditionReset : Operation::ConditionRead;
        req.argument.assign(1,letter);
    } else throw std::runtime_error("BIF control: invalid function");
    // The caller-activation provider owns all state, error signalling,
    // effective source-package selection, and trap/trace side effects.
    // NumericContext always reflects the current invoking activation.
    return safeScalarResult(provider_(req,numeric),name.c_str());
}
} // namespace rxbif_control
