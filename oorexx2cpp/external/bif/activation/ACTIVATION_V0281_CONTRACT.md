# BIF v0.14 — v0.28.1 scoped activation contract

This is an **optional BIF-side** adapter. No rx2cpp v0.28.1 code is changed.

`ScopedActivation` binds a borrowed `rx::BifRuntime` and `rx::Variables` to the current C++ thread. A `ThreadRouter` looks up the current binding **for each BIF invocation**, then reuses the BIF v0.13 router and its current numeric-context and typed-fallback safeguards. It must be constructed in the original compiled activation's lifetime; a new nested `PROCEDURE` or `SELF` method activation must bind its actual pool. No implicit propagation to other threads occurs.

The class checks conflicting simultaneous use of either a pool or a BIF runtime across threads; nested bindings in the *same* thread are allowed, and unwind to the prior scope. Use distinct runtime/pool instances for independent concurrently executing activations. This is a **guardrail**, not a claim that rx2cpp's classes, mutable variables or ooRexx public API are generally thread-safe. Different compiled activations using exposed aliases or shared objects require higher-level synchronization by the host.

Per-call `DIGITS`, `FUZZ`, `FORM`, native subset dispatch and chain-back all use the current pool. `ARG`, `ADDRESS`, `TRACE`, `SOURCELINE` and `CONDITION` remain unavailable unless the original frame/control callbacks are supplied; this wrapper does not invent them. Scalar-only and omitted-argument limitations remain.

### Build

`RX2CPP_BASE=/path/to/rx2cpp_oorexx_v0.28.1_claude_integration CXX=g++ activation/tests/run_v0281.sh`

Repeat with `CXX=clang++`. This test uses only BIF-source files and **read-only** rx2cpp v0.28.1 headers.

### Caller ownership requirement

The actual compiler integration lane must install/uninstall `ScopedActivation` when entering/leaving each genuine activation. This ZIP does **not** do that wiring and should not be described as integrated compiled-program support.
