# TRUNC — independent native BIF block

This add-on change was built against `animatedads/oorexx` GitHub `main`, BIF
`0.15.2-native-sign`; no older native ZIP was overlaid. Only BIF source changes.

The C++17 fast path implements decimal rounding to current `NUMERIC DIGITS`
*before* truncation to N decimal places, and preserves exactly N decimal places.
It uses decimal characters rather than floating point, preserving embedded-byte
validation and avoiding approximate binary arithmetic. A caller-owned numeric
supplier is read on every native call; missing or invalid NUMERIC context fails
closed. The direct scanner has a bounded 8192-byte result and 4096-digit
precision/places limit; outside these limits it requires a real live-activation
host for fallback. Numeric forms for N requiring ooRexx integer conversion
also retain the controlled host path. No fabricated interpreter context.

## Independent tests

From this repo, point `RX2CPP_BASE` at an actual checked compiler tree,
`OO_ROOT` at a working ooRexx install. `run_blocks.sh` tests direct native BIF
routing with **no interpreter fallback** for 31,640 cases each at NUMERIC
DIGITS 1, 6, 9 and 34 under both GCC and Clang: **253,120 exact-byte passes**.
`run_compiled.sh` checks `rx::dispatchBif` and 20 interpreter-comparable output
lines under both compilers (local compiler v0.30.3 was used for qualification).
`run_rules.sh` uses the ooRexx source-to-rule converter and checks valid wrapper
admission, delegate drift downgrade, and arity-drift rejection. Boundary tests
exercise numeric-supplier refresh, malformed input, typed noncanonical numeric
fallback, omitted required inputs, and missing context.

The newly uploaded GitHub BIF sources were tested against the compiler/runtime
headers in the available local v0.30.3 tree, whose BIF API is unchanged by the
narrow upstream work. This is not full qualification of newer compiler language
features. BIF rule conversion remains ooRexx; `gen.py` produces **test data only**.

## Upstream reference

`ooRexx/ooRexx` `interpreter/expression/BuiltinFunctions.cpp` `BUILTIN(TRUNC)`;
`interpreter/classes/NumberStringClass.cpp` `NumberString::trunc` and
`truncInternal`. Deliberate unsupported numeric classes do **not** count as
native passes. Invalid inputs must never receive a second execution.
