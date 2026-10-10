# Explicit optional ooRexx chain-back example

```cpp
#include "rxbif_breadth.hpp"
#include "rxbif_oorexx_bridge.hpp"

// Owned per thread, not shared concurrently across threads.
rxbif::Context nativeClock;
rxbif_breadth::IsolatedOoRexx rexx("/absolute/path/native/isolated_chainback.rex");
rxbif_breadth::Context context(nativeClock, [&](const std::string& bif,
                   const std::vector<rxbif_breadth::Slot>& args) {
    // ONLY detached-safe scalar functions. Reject stateful ones.
    return rexx.call(bif, args);
});

const auto answer = rxbif_breadth::invoke("X2D",
    {rx::Value::string("FF")}, context);
// answer.bytes == "255"
```

If the BIF is `ARG`, `VAR`, `TRACE`, `STREAM`, `QUEUED`, or another activation-sensitive BIF, `IsolatedOoRexx::call` throws deliberately. Supply the host's real activation-bound execution function via `Context::chainback` instead; do not route it to a freshly created interpreter. Use `std::nullopt` for omitted arguments, not an empty-string `rx::Value`.

`Context` preserves the earlier add-on's per-activation `DATE`/`TIME` native clock behaviour. Changing the compiler's BIF registry remains a separate integration responsibility.
