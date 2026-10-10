# rx2cpp v0.20 qualification — 2026-10-10

Source baseline: v0.19 full source delivery. Modified compiler source:
`rules/StmtSelect.cls` (new) and `core/RxRuleRegistry.cls` (registry entry).
No other compiler rule, C++ runtime, hybrid compiler, native library backend
or BIF module was changed in this version.

Oracle: supplied ooRexx 5.3.0-13196 debug Linux x86-64 interpreter.
Native: GCC and Clang, `-std=c++17 -O2 -Wall -Wextra -Werror`.

| Qualification | GCC | Clang |
|---|---:|---:|
| SELECT differential programs (complete stdout byte equality) | 8 / 8 | 8 / 8 |
| SELECT no-match without OTHERWISE signals error (not code parity) | PASS | PASS |
| SELECT invalid grammar rejects with diagnostic and no C++ | 6 / 6 | 6 / 6 |
| Focused ooTest group `RX2CPPSelect.testGroup` | 17 tests | 17 tests |
| Focused ooTest assertions | 44 | 44 |
| Focused ooTest failures / errors | 0 / 0 | 0 / 0 |
| Existing v0.19 compound-variable differential fixtures | 4 / 4 | 4 / 4 |
| Existing unsupported-object rejection | PASS | PASS |
| Existing RexxCPS loop-kernel and repetition DO regression | 8 checks GCC | not rerun Clang |

New differential programs: `select_basic`, `select_otherwise`, `select_nested`,
`select_compound`, `select_no_otherwise`, `select_short_circuit`,
`select_otherwise_do`, `select_semicolon`. Tests also cover the six invalid
cases listed in `tests/test_select.sh`.

Official historic ooTest 4.2 `SELECT.testGroup` executed separately against
ooRexx 5.3: **20 tests, 20 assertions, 0 failures, 2 errors** (`test_15`
and `test_16`). Both call `expectSyntax(34.1)` but actual ooRexx 5.3 raises
`SYNTAX 34.2` for a non-boolean `WHEN` expression. This is an upstream
expectation/target-version disagreement, not evidence of a native compiler
success or failure. The official group was NOT translated into native code.
Original `rexxcps.rex` still rejects at line 72, column 10, decimal literal
`2.2` (exit 65, no generated C++). There is no native RexxCPS score.

The complete historical ooTest corpus and complete standalone compiler
regression suite were NOT run; no claim of full project qualification.

Repeatable focused test:

```bash
export REXX_BIN=/path/to/ooRexx/bin/rexx
export REXX_LIB=/path/to/ooRexx/lib
export OO_TEST_ROOT=/path/to/ooTest-4.2.0-snapshot06
CXX=g++ ootest/run_select.sh
CXX=clang++ ootest/run_select.sh
CXX=g++ tests/test_compound.sh
CXX=clang++ tests/test_compound.sh
```
