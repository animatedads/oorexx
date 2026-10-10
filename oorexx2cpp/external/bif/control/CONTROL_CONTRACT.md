# BIF control-state adapter — original activation (v0.12)

## Authority

The interpreter source is `ooRexx/ooRexx/interpreter/expression/BuiltinFunctions.cpp`,
blob SHA `05ea58114e9e5b59a1cceebf8dd418b78058d342` (source review October 2026).
`SOURCELINE`, `TRACE`, and `CONDITION` must operate on their **actual calling
Rexx activation**. Creating a fresh ooRexx routine cannot reproduce its source
package, current TRACE setting, or trapped condition.

The independent BIF add-on exports `ControlRouter`. rx2cpp must supply
`NumericSupplier` and `ControlProvider` for the **original compiled frame**.
`NumericSupplier` is invoked before **each** BIF call (including nested calls),
not once at adapter construction; its `digits`, `fuzz`, `form` are checked.

`ControlProvider(Request, NumericContext)` owns these operations:

| Operation | Contract |
|---|---|
| SourceCount | Effective package's source line count, not a source file cached at compilation |
| SourceLine | The 1-based line of that same effective package; out-of-range is an ooRexx error |
| TraceRead | Current trace setting without side effects |
| TraceExchange | Validate setting, atomically obtain previous trace, apply new setting, return previous trace |
| ConditionRead | Scalar `I`, `C`, `D`, `E`, `S` from current trapped condition and its trap state |
| ConditionReset | Clear original activation's trapped condition and return an empty string |

On `CONDITION`, options are distinguished by first character (case-insensitive).
`CONDITION('A')` and `CONDITION('O')` are **not yet supported**: their
potential `.nil`, Directory, Array or arbitrary object results require a qualified
object ownership/identity ABI. Returning an empty string in their place would
be wrong. Provider returns with object results in all other routes are also
rejected. Host implementations must ensure any mutation and old-value return
are atomic, and that an error does not leave partially changed trace/trap state.

`SOURCELINE(n)` currently accepts a safe positive *decimal-digit* subset; the
full ooRexx numeric conversion space (e.g. `1.0`) is not claimed. An omitted
`TRACE` argument queries the setting, while a present empty string must be
passed to the original activation for validation, not silently treated as omitted.

## Upstream source -> ooRexx-generated rule -> native wrapper

`control/bif2control.rex` is the conversion engine (written in ooRexx). It
runs `compiler/BifSourceReader.cls`, `control/BifControlRouteRule.cls` and
rejects unsupported source/arity/body changes. It emits:

- `control/generated/Bif_{SOURCELINE,TRACE,CONDITION}.cls`;
- `control/generated/rxbif_control.ir.tsv`;
- `control/generated/rxbif_control_generated.hpp` (direct inline wrappers).

Source gate checks use comment/string-masked C++ so commented-out prior
call sites cannot authorise a changed implementation. These are targeted drift
checks, not a formal proof of whole-function semantic equivalence. The bundled
source fixture is a **structural excerpt**; regeneration against the complete
upstream C++ source and original upstream ooTest suites is future qualification.

The rule's C++ wrapper invokes `ControlRouter`, which delegates to the original
activation and obtains a fresh caller NUMERIC snapshot on each call. The
object-valued and host-state boundaries intentionally fail closed.

## Integration

This module does **not** alter rx2cpp. Integration is the compiler owner's job:
produce the real caller activation provider (including effective package when
`INTERPRET` is active, trace/traps, and object identity), then register these
three generated rules in the compiler's extension system. A `RexxCallContext`
created by a helper routine is not equivalent to the compiled original frame.

## Test status

See `QUALIFICATION_V012.md`. The test provider is an explicit deterministic
**test double**, not an implementation of real compiled-frame state. Differential
fixtures check its emitted scalar results against ooRexx 5.3.0 interpreter
microcases, including a trapped `NOVALUE` condition.
