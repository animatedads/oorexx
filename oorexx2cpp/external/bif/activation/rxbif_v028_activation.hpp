#pragma once
// Optional, standalone BIF-side adapter against the *read-only* rx2cpp v0.28 API.
// This header does not register anything in rx2cpp and does not manufacture
// CALL arguments, TRACE state, a trap, or an effective source package.
#include "rx_bif_integration.hpp"  // supplied ONLY by compiler v0.28
#include "rxbif_frame.hpp"
#include "rxbif_control.hpp"
#include <cctype>
#include <functional>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace rxbif_v028 {
using Slot = rxbif_breadth::Slot;
using NumericContext = rxbif_breadth::NumericContext;
using FrameSupplier = rxbif_frame::FrameSupplier;
using ControlProvider = rxbif_control::ControlProvider;
using PoolSupplier = std::function<rx::Variables*()>;

// The owner of the generated activation supplies live pointers only while the
// call is executing. A switch to a nested PROCEDURE pool is observed per call.
class Router final {
public:
    Router(rx::BifRuntime& bif, PoolSupplier pool,
           FrameSupplier frame = {}, ControlProvider control = {})
        : bif_(bif), pool_(std::move(pool)), frame_(std::move(frame)),
          control_(std::move(control)) {
        if (!pool_) throw std::invalid_argument("BIF v0.28: live caller pool supplier required");
    }
    Router(const Router&) = delete;
    Router& operator=(const Router&) = delete;

    rx::Value invoke(std::string bif, const std::vector<Slot>& arguments = {}) {
        for (char &c : bif)
            c=static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
        rx::Variables& current = pool();
        // These three functions are available from v0.28's genuine pool-local
        // numeric state. No detached ooRexx routine or invented defaults.
        if (bif=="DIGITS" || bif=="FUZZ" || bif=="FORM") {
            if (!arguments.empty())
                throw std::runtime_error("BIF "+bif+": incorrect argument count");
            const NumericContext numeric = rx::frameNumeric(current);
            rxbif_breadth::validateNumericContext(numeric);
            if (bif=="DIGITS") return rx::Value::string(std::to_string(numeric.digits));
            if (bif=="FUZZ") return rx::Value::string(std::to_string(numeric.fuzz));
            return rx::Value::string(numeric.form==rxbif_breadth::NumericForm::Engineering
                                     ? "ENGINEERING" : "SCIENTIFIC");
        }
        auto liveNumeric = [this] { return rx::frameNumeric(pool()); };
        if (bif=="ARG" || bif=="ADDRESS") {
            if (!frame_) throw std::runtime_error("BIF "+bif+": original frame supplier missing");
            rxbif_frame::ActivationRouter route(bif_.native,liveNumeric,frame_);
            return route.invoke(bif,arguments);
        }
        if (bif=="SOURCELINE" || bif=="TRACE" || bif=="CONDITION") {
            if (!control_) throw std::runtime_error("BIF "+bif+": original control provider missing");
            rxbif_control::ControlRouter route(bif_.native,liveNumeric,control_);
            return route.invoke(bif,arguments);
        }
        // v0.28's existing variable provider is the authority for SYMBOL,
        // VAR, and VALUE and must not be cloned into this add-on. Other BIFs
        // still use their registered native subset / typed-fallback boundary.
        return rx::dispatchBif(bif_,current,bif,arguments);
    }
private:
    rx::Variables& pool() const {
        rx::Variables *p = pool_();
        if (!p) throw std::runtime_error("BIF v0.28: caller activation unavailable");
        return *p;
    }
    rx::BifRuntime& bif_;
    PoolSupplier pool_;
    FrameSupplier frame_;
    ControlProvider control_;
};
} // namespace rxbif_v028
