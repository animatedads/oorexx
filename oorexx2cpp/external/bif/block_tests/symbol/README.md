# Native DATATYPE S/V — independent BIF block

This block was authored directly against `animatedads/oorexx` GitHub main, whose BIF
baseline was `0.15.0-native-blocks`. It is **not** an overlay of the separately
delivered v0.16–v0.19 ZIP packages.

## Native scope

- `DATATYPE(value,'S')`: true for a valid ooRexx symbol (including literal/numeric symbols).
- `DATATYPE(value,'V')`: true only for an assignable variable name, stem or compound name.
- ASCII/Linux ooRexx 5.3.0 `LanguageParser::scanSymbol` rules; 250-byte maximum.
- Case-insensitive first option byte; binary/NUL input remains binary.
- Both paths run in the existing `rxbif_breadth::invoke` dispatcher with no
  interpreter or numeric-context lookup. They are precision-independent.
- All other DATATYPE options, object-valued arguments, and omitted option slots
  **retain the existing external/host route**. No automatic broad DATATYPE native
  coverage is claimed.

## Tests (run from the checked-out repository)

Set `RX2CPP_BASE` to the checked compiler tree, `OO_ROOT` to a functioning
ooRexx installation, and `REXX_BIN="$OO_ROOT/bin/rexx"`.

```sh
export RX2CPP_BASE=/path/to/oorexx2cpp
export OO_ROOT=/path/to/oorexx
export REXX_BIN="$OO_ROOT/bin/rexx"
bash "$RX2CPP_BASE/external/bif/block_tests/symbol/run_blocks.sh"
bash "$RX2CPP_BASE/external/bif/block_tests/symbol/run_compiled.sh"
```

`run_blocks.sh` regenerates a fixed matrix of 23,614 binary-safe inputs,
then runs **each option separately** against the real ooRexx interpreter and
the native C++ entry point, at `-O2 -Wall -Wextra -Werror`. Neither native
block has a chain-back callback installed. Both GCC and Clang passed
23,614/23,614 cases for S and V each.

`run_compiled.sh` separately builds compiled Rexx programs and verifies
`rx::dispatchBif` in the emitted C++; 20/20 program output lines passed
for GCC and Clang on the available local **v0.30.3** compiler tree.
This is not a claim of complete v0.30.6 compiler-suite qualification.

Test corpus: empty strings; punctuation, letters and digits; exponents with
signs; stems/compound symbols; 250/251-byte boundaries; high-bit and embedded
NUL bytes; deterministic combinations and seeded fuzz. Fixture generation
uses Python **only for test data**. BIF source conversion remains ooRexx.

## Provenance / known limits

The checked GitHub native blob before this change was
`61aa78ebf4a8e139c9c8f66f872a69dc1ec8c19f`; the breadth router blob
was `742cc98eafa17a59e8c5cae60b6a2f6e6b8b7870`. The original ooRexx
reference was `ooRexx/ooRexx` Scanner.cpp,
`LanguageParser::scanSymbol`, and StringUtil.cpp `dataType` S/V branches.
No upstream source code is embedded.

This one narrowly tested block does not imply that the rest of the native
catalogue or the current compiler have been regression-qualified. In
particular, EBCDIC/MVS symbol-table behaviour is **not** qualified by this
ASCII/Linux implementation.
