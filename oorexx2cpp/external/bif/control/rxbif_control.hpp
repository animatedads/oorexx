#pragma once
// BIF-only, caller-activation control-state seam, not a replacement activation.
// The original compiled frame retains source, trace, trap, and numeric authority.
#include "rxbif_breadth.hpp"
#include <cstddef>
#include <functional>
#include <string>
#include <vector>
namespace rxbif_control {
using Slot = rxbif_breadth::Slot;
using NumericContext = rxbif_breadth::NumericContext;
// Operations are intentionally distinct. TRACE replacement and CONDITION reset
// must happen atomically in the owning activation, with no detached fallback.
enum class Operation { SourceCount, SourceLine, TraceRead, TraceExchange,
                       ConditionRead, ConditionReset };
struct Request final {
    Operation operation;
    std::size_t sourceLine = 0;     // 1-based; SourceLine only
    std::string argument;          // trace setting or selected condition letter
};
using ControlProvider = std::function<rx::Value(const Request&, const NumericContext&)>;
class ControlRouter final {
public:
    ControlRouter(rxbif::Context& native, rxbif_breadth::NumericSupplier numeric,
                  ControlProvider originalActivation);
    ControlRouter(const ControlRouter&) = delete;
    ControlRouter& operator=(const ControlRouter&) = delete;
    rx::Value invoke(const std::string& bif, const std::vector<Slot>& arguments = {});
private:
    rx::Value execute(const std::string& name, const std::vector<Slot>& args,
                      const NumericContext& ctx);
    ControlProvider provider_;
    rxbif_breadth::Context routing_;
};
} // namespace rxbif_control
