#pragma once
// A frame-bound BIF adapter. The providers must be supplied by the owner of
// the ORIGINAL compiled ooRexx activation; they are not RexxCallContext shims.
// Both providers are sampled on EACH call; no cross-call activation snapshot.
#include "rxbif_breadth.hpp"
#include <functional>
#include <string>
#include <vector>

namespace rxbif_frame {
using Slot = rxbif_breadth::Slot;
struct FrameSnapshot final {
    // Source invocation arguments, including positional holes and trailing
    // omissions. Not the argument list of a newly created helper routine.
    std::vector<Slot> arguments;
    // Effective ADDRESS environment of the *original* executing Rexx frame.
    std::string address;
};
using FrameSupplier = std::function<FrameSnapshot()>;
class ActivationRouter final {
public:
    ActivationRouter(rxbif::Context& native,
                     rxbif_breadth::NumericSupplier numeric,
                     FrameSupplier frame);
    ActivationRouter(const ActivationRouter&) = delete;
    ActivationRouter& operator=(const ActivationRouter&) = delete;
    ActivationRouter(ActivationRouter&&) = delete;
    ActivationRouter& operator=(ActivationRouter&&) = delete;
    rx::Value invoke(const std::string& bif, const std::vector<Slot>& bifArguments = {});
private:
    rx::Value run(const std::string& bif, const std::vector<Slot>& args,
                  const rxbif_breadth::NumericContext& numeric);
    FrameSupplier frame_;
    rxbif_breadth::Context router_;
};
} // namespace rxbif_frame
