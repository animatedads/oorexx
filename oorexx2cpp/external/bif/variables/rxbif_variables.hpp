#pragma once
// BIF-only, caller-owned variable-dictionary seam. Independent of rx2cpp.
// A helper RexxCallContext DOES NOT supply the original frame's variables.
#include "rxbif_breadth.hpp"
#include <functional>
#include <string>
#include <vector>
namespace rxbif_variables {
using Slot = rxbif_breadth::Slot;
using NumericContext = rxbif_breadth::NumericContext;
enum class Action { Classify, Fetch, Exchange };
enum class SymbolKind { Invalid, Literal, Assignable };
// The variable provider owns lexical rules, stem/compound tails, EXPOSE,
// frame scope, environment namespaces, object identity, and atomicity.
// No C++ map is assumed equivalent to the Rexx variable retriever.
struct Request final {
    Action action;
    std::string name;  // raw Rexx string, without speculative uppercasing
    Slot replacement; // nullopt means no assignment, never a string "" sentinel
    Slot selector;    // nullopt = caller-local scope; "" = .environment
};
struct Reply final {
    SymbolKind kind = SymbolKind::Invalid;
    bool assigned = false; // only meaningful for Classify
    Slot prior;           // required for Fetch/Exchange, including empty value
};
using VariableProvider = std::function<Reply(const Request&, const NumericContext&)>;
class VariableRouter final {
public:
    VariableRouter(rxbif::Context& native, rxbif_breadth::NumericSupplier numbers,
                   VariableProvider provider);
    VariableRouter(const VariableRouter&) = delete;
    VariableRouter& operator=(const VariableRouter&) = delete;
    VariableRouter(VariableRouter&&) = delete;
    VariableRouter& operator=(VariableRouter&&) = delete;
    rx::Value invoke(const std::string& name,const std::vector<Slot>& arguments);
private:
    rx::Value execute(const std::string&,const std::vector<Slot>&,const NumericContext&);
    VariableProvider provider_;
    rxbif_breadth::Context chain_;
};
} // namespace rxbif_variables
