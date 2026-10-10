# BIF add-on v0.9 compatibility with rx2cpp v0.25

This delivery was built *against* the exact read-only `include/minirexx_runtime.hpp`
from the user-supplied `rx2cpp_oorexx_v0.25_language_delivery(1).zip`.
No compiler file is rewritten or repackaged. The BIF generator remains ooRexx
(`bif2breadth.rex`, `bif2inline.rex`, `live/bif2live.rex`).

rx2cpp v0.25's new `DO WHILE` and `DO FOREVER` rules are owned by the compiler
lane. `RxBuiltinRules.cls` still permits only `ABS` and `LENGTH`, so this BIF
package is an *integration candidate*, not an assertion that the v0.25
compiler automatically emits the add-on's 81 route wrappers.

## Change since v0.8

Native subset limitations now raise `rxbif::NativeSubsetUnsupported`, a
specific error type. The breadth dispatcher retries only that type.
Invalid arguments, invalid DATE/TIME output styles, resource limits and
arbitrary C++ exceptions will no longer be converted to a second invocation.
This avoids masking the original error and executing potentially stateful BIFs
twice. Missing per-call NUMERIC context continues to fail closed.

`tests/run_fallback_classification.sh` checks both successful coverage-miss
fallback and rejection of invalid calls without invoking the host callback.

## Remaining boundaries

- The full upstream `BuiltinFunctions.cpp` is still not present locally.
  Synthetic inventory generation proves 81-name routing, not 81 upstream
  source conversions nor full ooTest equivalence.
- Runtime host activation adapters are still required for 27 BIFs.
- `NumericContext` is sampled on every cross-runtime call but does not
  transport the caller's argument list, variable scope, trace and condition
  state, object identity, stream state, queue state or routine overrides.
- Compiler integration must be an independent, explicit opt-in change owned
  by the rx2cpp lane. This delivery does not attempt that merge.
