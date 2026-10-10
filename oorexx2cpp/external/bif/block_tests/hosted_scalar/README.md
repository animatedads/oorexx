# Hosted scalar BIF boundary — proof, not a compiler integration

Based on the live GitHub `main` BIF sources and Claude's separately committed
`oorexx2cpp/hosted_tier/host_proof.cpp` at `944c482`.

This **independent, BIF-only test** uses the existing `rxbif_breadth::Context`
callback with one persistent `rx2cpp::hosted::Session` from the
compiler-owned `hosted_tier/HostedSession.hpp`. The BIF lane does **not**
create or maintain its own ooRexx interpreter wrapper. It proves only explicitly admitted scalar operations.
It does not share the compiled routine's Rexx activation, variable pool,
method scope, stream environment, queue, conditions/traps or package context.

- `SIGN('-12345')` executes natively; host callback and numeric supplier are **not called**.
- `ERRORTEXT('40')` executes using the hosted C++ API; result returned to native code.
- `X2C('0001FF41')`, forced to the hosted route, preserves all four bytes including NUL and `FF`.
- An invalid host call surfaces its numeric Rexx condition; `ClearCondition()`
  prevents the old error from affecting the next valid call.
- `DATATYPE('1.5','W')` returns `1` at `NUMERIC DIGITS 1` and `0` at
  `NUMERIC DIGITS 2`. The numeric supplier is consulted per delegated call.
- `ARG()` is explicitly refused by the test handler. A new `CallRoutine`
  activation is **not** a valid substitute for the compiled caller's frame.
- Only functions with known scalar String or Boolean result contracts are
  admitted; `Session::Object::asString()` is used **only for those results**.
  No generic object coercion is installed on the BIF dispatcher. True object
  support requires preserving the retained host object reference and identity,
  with ownership, thread attachment and interpreter lifetime checks.
- This smoke is confined to the creating thread. A production host must define
  thread attachment and reentrancy; do not share a `RexxThreadContext` across threads.

## Reproduce from an up-to-date GitHub checkout

```sh
export RX2CPP_BASE=/path/to/current/oorexx2cpp
export OO_ROOT=/path/to/oorexx/install
bash "$RX2CPP_BASE/external/bif/block_tests/hosted_scalar/run.sh"
```

Requires ooRexx C++ API headers, `librexx`, `librexxapi`, a working interpreter
runtime and either GCC or Clang; tests under both by default. Validated locally
against ooRexx 5.3.0, GCC and Clang, at `-O2 -Wall -Wextra -Werror`. Earlier
rx2cpp compiler 0.30.3 headers were used for `rx::Value` and a locally
reconstructed copy of the current public `HostedSession` interface was used
for local C++ qualification. Run against the exact checked GitHub `main`
header to complete current-head qualification; this is **not** a full current
compiler build or regression run.

## Architecture boundary

The fast native BIF catalogue still wins for previously qualified inputs.
Any hosted fallback must be selected explicitly, require fresh `NUMERIC`
context and preserve omitted slots and conditions. The existing scalar
`rxbif_breadth::Handler` is not an object ABI. The first production host API
should reuse `HostedSession::Object` or an equivalent opaque managed handle
and expose an activation-scoped invocation capability; the compiler owns the
latter.

Do not infer that `INTERPRET`, `ARG`, `ADDRESS`, `VALUE`, `TRACE`, `CONDITION`,
`RANDOM`, stream/queue calls or methods overridden at runtime work correctly
through a newly compiled detached Rexx routine. Macrospace is untested here
and is a future code-carriage experiment, not a substitute for activation
identity or live object ownership.

The `::OPTIONS DIGITS/FORM/FUZZ`, number-formatting and
`test_claude_options.sh` work described in Claude's handover belongs to the
compiler lane; none is modified by this test.
