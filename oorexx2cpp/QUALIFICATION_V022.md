# rx2cpp v0.22 Qualification — 2026-10-10

Reference: ooRexx 5.3.0-13196 interpreter from the supplied Ubuntu debug `.deb`.
Native compilers: GCC and Clang, `-std=c++17 -O2 -Wall -Wextra -Werror`.
Generated executables use the native rx2cpp support header, not librexx.

| Suite | GCC | Clang | Method |
|---|---:|---:|---|
| PARSE positive programs | 17 / 17 | 17 / 17 | full stdout byte comparison |
| PARSE negative syntax forms | 9 / 9 | 9 / 9 | compiler rejection, no partial C++ |
| Prior SELECT examples | 8 / 8 | 8 / 8 | full stdout byte comparison |
| Prior compound-symbol examples | 4 / 4 | 4 / 4 | full stdout byte comparison |
| Native mixin package, invalid graphs | PASS | not rerun | ooRexx-loaded `.so`, 29-line comparison |
| Native two-class package / 2,000 calls | PASS | not rerun | ooRexx-loaded `.so`, collision/rollback checks |

`SELECT` also checks a no-match runtime error and six negative inputs;
compound-symbol checks an additional rejected object expression.

## New feature evidence

`examples/parse/parse_relative_positions.rex`,
`parse_absolute_positions.rex`, `parse_literal_delimiters.rex`,
`parse_variable_delimiters.rex`, `parse_delimiter_source_alias.rex`,
`parse_positional_compound.rex`, `parse_boundary_positions.rex`, and
`parse_dynamic_evaluation.rex` exercise anchored and delimiter-based parsing.
The nine original v0.21 PARSE fixtures remain passing.

The test harness evaluates the **same unmodified ooRexx source** under the
interpreter and the generated C++ binary. The qualification claims only exact
stdout parity on those supported fixtures; it does not establish full grammar,
performance equivalence, numeric-context fidelity, or full ooTest compatibility.

## Boundaries

- Full ooTest 4.2 corpus **not rerun** for v0.22.
- Standalone complete RexxCPS **still unsupported**, not benchmarked natively.
- BIF package v0.1 **not merged**, not modified.
- Interpreter exception-condition parity not yet complete.
- Native library GCC checks were retained but Clang native-library checks were
  not repeated for v0.22; the previous v0.21/v0.20 status remains historical.

## Reproduce

```bash
export REXX_BIN=/absolute/path/to/rexx
export REXX_LIB=/absolute/path/to/oorexx/lib
CXX=g++ tests/test_parse.sh
CXX=clang++ tests/test_parse.sh
CXX=g++ tests/test_select.sh
CXX=clang++ tests/test_select.sh
CXX=g++ tests/test_compound.sh
CXX=clang++ tests/test_compound.sh
OO_ROOT=/absolute/path/to/oorexx CXX=g++ native/test_mixin.sh
OO_ROOT=/absolute/path/to/oorexx CXX=g++ native/test_package.sh
```
