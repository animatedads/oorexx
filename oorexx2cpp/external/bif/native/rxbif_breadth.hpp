#pragma once
// 81-name BIF routing adapter, separate from rx2cpp. "Covered" means a
// verifiable route is available, not that every native subset is equivalent.
#include "rxbif.hpp"
#include <functional>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>
namespace rxbif_breadth {
using Slot = std::optional<rx::Value>;  // nullopt is an OMITTED Rexx argument.
// The NUMERIC context belongs to the invoking Rexx activation, not the bridge.
// It must travel on EVERY fallback path, including native-subset fallbacks.
enum class NumericForm { Scientific, Engineering };
struct NumericContext final {
    std::size_t digits;
    std::size_t fuzz;
    NumericForm form;
};
void validateNumericContext(const NumericContext& context);
using Handler = std::function<rx::Value(const std::string&, const std::vector<Slot>&, const NumericContext&)>;
// Called immediately before EACH delegated BIF, including native-subset misses.
// Use a caller-owned activation/frame whose lifetime exceeds the invocation.
using NumericSupplier = std::function<NumericContext()>;
struct Context {
  rxbif::Context& native;
  Handler chainback; // Caller-owned live-activation handler OR explicitly isolated interpreter.
  // Mandatory for any invocation that crosses the bridge, even for zero-arg BIFs.
  // The producer must snapshot the current caller's NUMERIC settings.
  std::optional<NumericContext> numeric; // Legacy per-call snapshot; not for a mutable activation.
  NumericSupplier currentNumeric; // Preferred for a mutable activation. Read on every pass-through.
  bool preferChainback = false; // use ooRexx even for a supported native subset
  explicit Context(rxbif::Context& value, Handler handler = {},
                   std::optional<NumericContext> numericContext = std::nullopt,
                   NumericSupplier numericSupplier = {})
      : native(value), chainback(std::move(handler)), numeric(numericContext),
        currentNumeric(std::move(numericSupplier)) {}
};
struct Spec { const char* name; std::size_t minArgs, maxArgs; const char* mode; };
const std::vector<Spec>& catalog();
rx::Value invoke(const std::string& name,const std::vector<Slot>& args,Context& ctx);
} // namespace rxbif_breadth
