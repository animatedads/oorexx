# rx2cpp v0.24 — RexxCPS structural language additions

This is a language/compiler-only update based on ooRexx 5.3.0 reference
execution and the original, unchanged `rexxcps.rex`. BIF sources remain
owned by the separate BIF lane and have not been merged or modified.

## Added

- `RxStmtLeaveIterate` (independently loadable class): `LEAVE` and `ITERATE`,
  optionally naming an active counted control variable. Selects the nearest
  matching lexical `DO`, ignoring nested `IF` and `SELECT` blocks.
- Counted, repetition and `DO UNTIL` code generation updated to create
  explicit iteration/exit targets with a separate C++ body scope.
  `ITERATE` on a counted loop still executes its counter increment;
  `ITERATE` on `DO UNTIL` still performs the post-test.
- `END controlVariable` validation for counted `DO`.
- `RxExprLogical` for infix Rexx `|` below comparison precedence.
  `RxOperatorRules` retains left-receiver object dispatch and operand
  evaluation order; the runtime validates both logical values.
- `%` is integer division dispatched through the same object-message API,
  with checked, *deliberately narrow* default `NUMERIC DIGITS 9` support.

## Known limits

This release does **not** implement decimal literals, `NUMERIC` contexts,
BigInt, other logical operators, arbitrary precision whole-number division,
`DO WHILE`, labels/internal routines, `SIGNAL`, `TRACE VALUE`, or
`ADDRESS VALUE`. Unsupported constructs must reject rather than be
silently interpreted as native C++ operations. For `%`, non-integral or
more than nine decimal digits are rejected by the native runtime; no claim
of general Rexx numeric compatibility is made.

The unchanged RexxCPS 2.2 source still fails to compile at its decimal
version literal (line 72). The previous lexical obstacle at the later `|`
site is addressed, but this is **not** a native RexxCPS score.

## Test

Use the unpacked ooRexx reference runtime, or a system `rexx`:

```
export REXX_BIN=/path/to/rexx
export REXX_LIB=/path/to/oorexx/lib
CXX=g++ ./tests/test_rexxcps_structural.sh
CXX=clang++ ./tests/test_rexxcps_structural.sh
```

The fixture files in `examples/rexxcps_structural/` are unchanged for
interpreter and compiler-native execution. See `QUALIFICATION_V024.md`.
