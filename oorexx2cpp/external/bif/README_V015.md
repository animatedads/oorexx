# rx2cpp BIF v0.15 — native block qualification

This is the independent, external BIF add-on, based on v0.14. **No rx2cpp
source was changed**. The ooRexx-written BIF-to-IR/rules converter and all
activation/chain-back adapters are inherited unchanged. This release modifies
only `native/rxbif.cpp` and adds `block_tests/` with reproducible tests.

## Native corrections

1. `LASTPOS(needle, haystack, start)` now treats `start` as the last possible
   **ending** character of the match, not its starting character.
2. `POS` and `LASTPOS` now support `range` (fourth argument), restricting
   a forward/backward search window without copying the haystack.
3. `COUNTSTR('', text)` returns `0`, and `CHANGESTR('', text, replacement[, limit])`
   returns `text` unchanged, matching the tested ooRexx behaviour.
4. Numeric arguments clearly invalid for integer-index BIFs no longer masquerade
   as `NativeSubsetUnsupported`. Noncanonical whole-number forms such as `2.0`
   and `2E0` still request correctly contextualised fallback (they are *not*
   silently rounded or rewritten by C++).

## Test blocks

Run `block_tests/run.sh` with `RX2CPP_BASE`, `REXX_BIN`, `LD_LIBRARY_PATH`,
`CXX`, and optionally `BUILD_DIR` set. This uses genuine ooRexx to generate the
oracle on the current host; each case compares the **hexadecimal bytes** of
native and ooRexx results, including binary values and embedded NUL.

`block_tests/gen_matrix.py` and `gen_range.py` are deterministic **test-data
builders only**. They do not implement or convert BIFs. BIF-to-IR conversion
remains implemented in ooRexx (`bif2inline.rex` and `.cls` rule classes).

The source is based on ooRexx `BuiltinFunctions.cpp` upstream blob
`05ea58114e9e5b59a1cceebf8dd418b78058d342`; original method semantics
also come from ooRexx string methods. The supplied staged interpreter used for
qualification is ooRexx 5.3.0 r13196 debug. This suite tests many useful
subsets, **not the entire upstream ooTest corpus or 81 complete BIF semantics**.

## Next blocks

- Conversion family `C2D`, `D2C`, `X2D`, `D2X` requires numeric-context work.
- `TRANSLATE`, `VERIFY`, `DATATYPE` and grouping in `B2X`/`X2B` need targeted tests.
- `DATE`/`TIME` have separately inherited five-timezone coverage but incomplete
  parsing, omission and activation nuances.
- Objects, omitted argument slots and arbitrary Rexx decimal contexts remain
  qualified fallback or fail-closed boundaries; do not coerce them silently.
