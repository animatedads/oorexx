#include "rxbif_frame.hpp"
#include <algorithm>
#include <cctype>
#include <cstdint>
#include <limits>
#include <stdexcept>

namespace rxbif_frame {
namespace {
std::string upper(std::string in) {
    for (char& c : in) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
    return in;
}
// This intentionally admits only the tested decimal-integer subset. Rexx's
// full numeric string conversion is an interpreter decision, not atoi().
std::size_t positivePosition(const Slot& value) {
    if (!value || value->isObject())
        throw std::runtime_error("BIF ARG: position must be a positive whole number");
    const std::string s = value->bytes.str();
    if (s.empty()) throw std::runtime_error("BIF ARG: empty position");
    std::size_t n = 0;
    for (unsigned char c : s) {
        if (c < '0' || c > '9' || n > (std::numeric_limits<std::size_t>::max() - (c - '0'))/10)
            throw std::runtime_error("BIF ARG: unsupported noncanonical numeric position");
        n = 10*n + static_cast<std::size_t>(c - '0');
    }
    if (n == 0) throw std::runtime_error("BIF ARG: position must be positive");
    return n;
}
rx::Value scalarArgument(const Slot& value) {
    if (!value) return rx::Value::string("");
    if (value->isObject())
        throw std::runtime_error("BIF ARG: Rexx object return requires qualified object ABI");
    return *value;
}
}
ActivationRouter::ActivationRouter(rxbif::Context& native,
                                   rxbif_breadth::NumericSupplier numeric,
                                   FrameSupplier frame)
    : frame_(std::move(frame)),
      router_(native,
              [this](const std::string& name, const std::vector<Slot>& args,
                     const rxbif_breadth::NumericContext& ctx) {
                  return run(name, args, ctx);
              }, std::nullopt, std::move(numeric)) {
    if (!frame_ || !router_.currentNumeric)
        throw std::invalid_argument("BIF compiled frame and numeric suppliers are mandatory");
    router_.preferChainback = true;
}
rx::Value ActivationRouter::invoke(const std::string& requested,
                                    const std::vector<Slot>& args) {
    const std::string name = upper(requested);
    // This adapter offers specific, source-verified FRAME semantics. Other
    // names require their own qualified bridge and never silently run here.
    if (name != "ARG" && name != "ADDRESS")
        throw std::runtime_error("BIF " + name + ": no qualified compiled-frame adapter");
    return rxbif_breadth::invoke(name, args, router_);
}
rx::Value ActivationRouter::run(const std::string& name,
                                const std::vector<Slot>& args,
                                const rxbif_breadth::NumericContext& numeric) {
    rxbif_breadth::validateNumericContext(numeric);
    if (name == "ARG") {
        if (args.size() > 2) throw std::runtime_error("BIF ARG: incorrect argument count");
        if (!args.empty() && !args[0]) {
            if (args.size() > 1 && args[1])
                throw std::runtime_error("BIF ARG: option requires position");
        }
        // Decode call arguments before reading frame to avoid touching host
        // state after a known invalid call.
        const bool hasPosition = !args.empty() && static_cast<bool>(args[0]);
        std::size_t position = hasPosition ? positivePosition(args[0]) : 0;
        char mode = 'N';
        if (args.size() > 1 && args[1]) {
            if (args[1]->isObject() || args[1]->bytes.empty())
                throw std::runtime_error("BIF ARG: invalid option");
            mode = static_cast<char>(std::toupper(static_cast<unsigned char>(args[1]->bytes.front())));
            if (mode != 'E' && mode != 'O' && mode != 'N' && mode != 'A')
                throw std::runtime_error("BIF ARG: invalid option; expected AENO");
        }
        if (mode == 'A')
            throw std::runtime_error("BIF ARG: array-valued option A needs native array identity ABI");
        FrameSnapshot frame = frame_();
        if (!hasPosition) return rx::Value::string(std::to_string(frame.arguments.size()));
        const bool exists = position <= frame.arguments.size() &&
                            static_cast<bool>(frame.arguments[position - 1]);
        if (mode == 'E') return rx::Value::string(exists ? "1" : "0");
        if (mode == 'O') return rx::Value::string(exists ? "0" : "1");
        if (!exists) return rx::Value::string("");
        return scalarArgument(frame.arguments[position - 1]);
    }
    if (name == "ADDRESS") {
        if (!args.empty()) throw std::runtime_error("BIF ADDRESS: incorrect argument count");
        FrameSnapshot frame = frame_();
        if (frame.address.empty())
            throw std::runtime_error("BIF ADDRESS: effective host environment was not supplied");
        return rx::Value::string(frame.address);
    }
    throw std::runtime_error("BIF " + name + ": no qualified compiled-frame adapter");
}
} // namespace rxbif_frame
