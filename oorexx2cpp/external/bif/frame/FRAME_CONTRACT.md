# rx2cpp BIF compiled-frame adapter — v0.10

## Authority boundary

This adapter is a **BIF-side** C++ component. It is **not** a modification to
rx2cpp, ooRexx, the interpreter, or the compiled language frontend.

The compiler integration lane must provide two live provider functions:

- `NumericSupplier` returning the current `NUMERIC DIGITS`, `NUMERIC FUZZ`, and
  `NUMERIC FORM` of the *original Rexx activation* on every delegated call.
- `FrameSupplier` returning the *original compiled frame's* effective `ADDRESS`
  environment and its invocation arguments, including positional omissions.

A borrowed `RexxCallContext*` for a newly created helper routine is **not** the
compiled caller frame. Never infer the original frame's `ARG()` values from the
helper's `GetArguments()`. Do not cache activation state across calls or nested
routine invocations. The supplying host controls lifetimes and thread safety;
`ActivationRouter` and its callback captures must not outlive that frame.

## Source-derived route

The ooRexx-written `frame/bif2frame.rex` reads upstream C++
`BUILTIN(ARG)` and `BUILTIN(ADDRESS)` definitions with `BifSourceReader.cls`,
checks signature and essential semantic call-site anchors using
`BifFrameRouteRule.cls`, and emits both individual `.cls` rule classes and
`rxbif_frame_generated.hpp` plus an IR TSV. These anchors provide targeted
source-drift detection; they are not a complete machine proof of upstream
semantic equivalence. `frame/fixtures/BuiltinFunctions.frame.cpp` is a compact
upstream-derived structural fixture, **not the entire original C++ file**.
Qualify against the full source checkout when available.

## Example integration (pseudocode, no compiler edits made here)

```cpp
rxbif::Context native;
rxbif_frame::ActivationRouter adapter(
    native,
    [&compiledActivation] { return compiledActivation.captureNumerics(); },
    [&compiledActivation] { return compiledActivation.captureFrame(); });

const auto count = rxbif_frame_generated::BIF_ARG(adapter, {});
const auto omitted = rxbif_frame_generated::BIF_ARG(adapter,
    {rx::Value::string("2"), rx::Value::string("O")});
const auto environment = rxbif_frame_generated::BIF_ADDRESS(adapter);
```

Actual integration depends on the compiler lane supplying the two methods
above. They do not exist in the current rx2cpp v0.25 ABI and are **not**
implemented or declared in this add-on.

## Qualified function behaviour

### `ARG`

- `ARG()` returns the count of positions in the supplied original invocation.
- `ARG(n)` and `ARG(n,'N')` return an existing scalar, otherwise `''`.
- `ARG(n,'E')` / `ARG(n,'O')` check presence/omission, including out-of-range.
- Only positive decimal-digit position strings are admitted as a tested numeric
  subset. More general Rexx integer-string forms are explicitly rejected.
- The `ARG(n,'A')` array result is **not** implemented; it fails explicitly.
- Returning an interpreter-managed object as a scalar has no qualified object
  identity/lifetime bridge and fails rather than performing an implicit cast.
- No execution using a newly created ooRexx routine's `ARG()` is permitted.

### `ADDRESS`

- `ADDRESS()` (zero arguments) reads the caller-supplied current effective
  command environment, and re-samples it on each call.
- No default host environment is assumed when it is not supplied.

### Other activation BIFs

`VALUE`, `SYMBOL`, `TRACE`, `CONDITION`, streams, queues and other host-state
BIFs retain their existing fail-closed restrictions. No no-op behaviour, mock
values or synthetic benchmark output is introduced.

## Errors and numeric context

Every pass-through uses the established v0.8 per-call numeric supplier contract
and v0.9 strict fallback classification. Invalid snapshots and absent providers
fail before the adapter returns a value. Neither adapter modifies the caller's
numeric settings, variables, address state or argument list.
