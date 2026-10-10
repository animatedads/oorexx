#pragma once
// RX2CPP BIF v0.6: a BORROWED, activation-scoped ooRexx routine callback.
// Do not retain a CallScope or RexxCallContext beyond the native routine call.
#include <oorexxapi.h>
#include "rxbif_breadth.hpp"
#include <string>

namespace rxbif_live {
class CallScope final {
public:
    explicit CallScope(RexxCallContext *caller);
    CallScope(const CallScope&) = delete;
    CallScope& operator=(const CallScope&) = delete;
    CallScope(CallScope&&) = delete;
    CallScope& operator=(CallScope&&) = delete;
    rx::Value invoke(const std::string& name);
    rx::Value invoke(const std::string& name, const std::vector<rxbif_breadth::Slot>& args);
private:
    void validate() const;
    rx::Value execute(const std::string& name, const std::vector<rxbif_breadth::Slot>& args,
                      const rxbif_breadth::NumericContext& numeric);
    RexxCallContext *const caller_; // borrowed, valid only during this native routine call
    RexxInstance *const original_; // identity only; NOT an activation token
    rxbif::Context native_;       // only clock/native subset plumbing, never detached interpreter
    rxbif_breadth::Context bif_;
};
RexxObjectPtr asRexxScalar(RexxCallContext *caller, const rx::Value& value);
} // namespace rxbif_live
