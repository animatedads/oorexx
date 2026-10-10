#pragma once
// Independent native built-in function add-on for rx2cpp v0.20 ABI.
// No interpreter linkage. No changes to rx2cpp source.
#include "minirexx_runtime.hpp"  // rx2cpp v0.18 Value ABI, read-only dependency
#include <chrono>
#include <stdexcept>
#include <string>
#include <vector>

namespace rxbif {
// Only this typed exception authorises automatic retry via a real ooRexx BIF.
// Ordinary execution failures, resource errors, and invalid argument diagnostics
// are not interpreted as evidence of missing implementation.
class NativeSubsetUnsupported : public std::runtime_error {
public:
    explicit NativeSubsetUnsupported(const std::string& message)
        : std::runtime_error(message) {}
};

struct Signature { const char *name; unsigned minArgs; unsigned maxArgs; };
const std::vector<Signature> &signatures();

// One context PER Rexx activation. Never cache this globally: ooRexx DATE/TIME
// see a stable instant across a single activation, not a fresh clock per call.
struct Context {
    std::chrono::system_clock::time_point activationTime;
    std::chrono::steady_clock::time_point elapsedStart;
    explicit Context(std::chrono::system_clock::time_point t = std::chrono::system_clock::now())
        : activationTime(t), elapsedStart(std::chrono::steady_clock::now()) {}
};

// Independent dispatch boundary; integrator may delegate unknown BIF names
// here from their own registry, maintaining rx2cpp's existing ABS/LENGTH rules.
// Functions with no implementation, unsupported options and objects fail closed.
rx::Value invoke(const std::string &name, const std::vector<rx::Value> &args, Context &context);
} // namespace rxbif
