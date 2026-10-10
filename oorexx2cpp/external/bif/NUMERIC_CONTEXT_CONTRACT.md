# Mandatory NUMERIC context transport — v0.7

## Producer contract

Every pass-through call receives a snapshot of the **calling Rexx activation**:
`digits` (positive integer), `fuzz` (nonnegative integer less than digits), and
`form` (`SCIENTIFIC` or `ENGINEERING`). Capture immediately before crossing the
BIF boundary. Do not read the fallback interpreter's settings and call that the
caller context. Do not fabricate default 9/0/SCIENTIFIC when the caller's
context is unknown. The bridge throws rather than guessing.

For a native `RexxCallContext*`, v0.7 uses `GetContextDigits()`,
`GetContextFuzz()`, and `GetContextForm()`; the context must be borrowed only
while the native routine call is active. For a pure compiled rx2cpp caller,
the integration lane must preserve these settings in its activation/frame
model and supply the snapshot. v0.7 does NOT change the compiler to do that.

## Transport routes

1. Native-to-host callback receives `(BIF name, positional argument slots,
   const NumericContext&)` on EVERY fallback, including a native-subset
   mismatch. The caller's snapshot must be present and valid.
2. Isolated ooRexx embeds the three numeric values in a fixed, validated
   argument envelope before BIF name and other arguments. The ooRexx program
   applies `NUMERIC DIGITS`, `NUMERIC FUZZ`, and `NUMERIC FORM` *inside its own
   activation* before executing only allowlisted BIFs. It never runs arbitrary
   user-supplied code.
3. Live ooRexx creates a subordinate routine in the current instance/thread.
   Its fixed numeric prologue is derived from the caller snapshot. Arguments
   stay as `RexxObjectPtr` slots, supporting omitted positions.

The source generator does not need to guess the numeric requirements of each
BIF; every generated rule advertises `requiresNumericContext` because any
individual invocation could be delegated.

## Fail-closed cases

- Missing snapshot, invalid DIGITS/FUZZ/FORM, or a mismatch with a live
  activation's current settings: reject **before** calling through.
- Wrong instance/thread, invalid arity, unknown BIF, unresolved host-only
  activation BIF, or unsupported object marshalling: reject.
- The old two-argument `IsolatedOoRexx::call` and the old two-argument host
  callback types must be migrated to the new three-component numeric contract.
  This is an intentional compile-time integration break, not a silent default.

## Semantics boundary

NUMERIC preservation is necessary but not sufficient for full Rexx parity.
String-only argument/results, object identity, source-level routine overrides,
activation-variable lookups, stream semantics, and error-condition identity
may require additional host adapters. The 81 names remain **routable** rather
than 81 universally runnable BIFs.
