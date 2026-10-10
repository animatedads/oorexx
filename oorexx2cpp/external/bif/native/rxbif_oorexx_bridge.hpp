#pragma once
#include "rxbif_breadth.hpp"
#include <memory>
#include <string>
namespace rxbif_breadth {
// Only for scalar, context-independent BIFs enumerated in isolated_chainback.rex.
// Unlike live-host chainback it does NOT share caller activation, streams,
// environment, traps, numeric context, method overrides, or object identity. Its numeric settings are transported explicitly.
class IsolatedOoRexx {
public:
    explicit IsolatedOoRexx(std::string program);
    ~IsolatedOoRexx();
    IsolatedOoRexx(const IsolatedOoRexx&)=delete;
    IsolatedOoRexx& operator=(const IsolatedOoRexx&)=delete;
    // Numeric snapshot MUST be captured from the original caller activation.
    // No implicit default numerics: a detached interpreter's defaults are unsafe.
    rx::Value call(const std::string& name,const std::vector<Slot>& values,
                   const NumericContext& numeric);
private:
    struct Impl;
    std::unique_ptr<Impl> impl;
};
} // namespace rxbif_breadth
