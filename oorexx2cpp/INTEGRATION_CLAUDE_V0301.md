# Claude integration onto v0.30.1 (attribute/constant) — 2026-10-10 (update 2: SIGNAL/RAISE/labels)

Base: `rx2cpp_oorexx_v0.30.1_attribute_constant` (unchanged except the files below). Patch: `claude_lang_on_v0301.patch`
(`diff -ruN` with SAME-NAMED roots `a/` `b/`; apply with `patch -p1`). The earlier x281 patch was whole-tree because its roots were
named differently — do not use it.

## What this adds (all differentially tested against ooRexx 5.3.0 r13196)

| Item | Files | Evidence |
| --- | --- | --- |
| Unary `\` (logical NOT); previously "unsupported source character '\'" | `core/RxLexer.cls`, `rules/ExprUnary.cls`, `rules/OperatorRules.cls`, `include/minirexx_runtime.hpp` | `tests/test_claude_unary_strict.sh` |
| `USE STRICT ARG` in internal routines: required args, optional with constant default (string/number), Error 40.3/40.4 | `rules/StmtUseArg.cls`, `core/RxCompiler.cls` (`routineName`), `rules/RxRoutineRules.cls`, runtime `useStrictArguments` | same test, both error codes checked against interpreter |
| `//` remainder and `**` power | `core/RxLexer.cls`, `rules/ExprMultiply.cls`, `include/rx_rexx_number.hpp`, runtime dispatch | `tests/test_claude_numeric_ops.sh`: 27 hand cases + 250 seeded random cases, byte-exact; 1,244 further random cases run during development matched |
| `NUMERIC DIGITS` cap raised 1000 -> 100000 (libs use 2000-3000) | `include/rx_rexx_number.hpp` | digits 3000 cases in hand fixture |
| Labels: instruction on the same line (`name: procedure; use arg x; ...`); duplicate labels (Rexx: first wins) | `rules/RxRoutineRules.cls` | `tests/test_claude_signal_labels.sh` |
| `SIGNAL ON SYNTAX [NAME l]` / `SIGNAL OFF SYNTAX`, `RAISE SYNTAX n.m [ARRAY(...)] [RETURN\|EXIT]` | `rules/StmtSignal.cls`, `rules/StmtRaise.cls`, `core/RxRuleRegistry.cls`, `core/RxStream.cls` (`signalAhead`), `core/RxCompiler.cls` (main-level trap), `rules/RxRoutineRules.cls` (routine trap), runtime `SyntaxCondition`/`TrapState` | same test; stdout **and exit status** identical |
| `EXIT` inside an internal routine (was fail-closed); routines may end with EXIT | `rules/StmtExit.cls`, runtime `ProgramExit`, `core/RxCppEmitter.cls` | same test (status 3) |
| `.TRUE` / `.FALSE` in expressions (strings 1 / 0) | `rules/ExprAtom.cls` | same test |
| Pre-existing v0.30.1 failure: `tests/native_operator_dispatch.cpp` (a string compared against an object on the right no longer threw) | `include/rx_rexx_number.hpp` | `tests/run.sh` "native operator message ABI" now passes; pristine v0.30.1 fails it (rc 7) |

**ooRexx 5.3 trap rule (verified by a 13-case matrix, replicated):** a plain `RAISE SYNTAX` (no `RETURN`) raised inside an internal
routine is *not* seen by any internal routine's `SIGNAL ON SYNTAX`, only by the program's top-level trap; `RAISE ... RETURN` is
trapped locally; genuine runtime errors (e.g. `1 % 0`) are trapped by the nearest trap. The trap is disabled when it fires.
When method activations exist (object lane), a RAISE crossing a method boundary should reach the caller's trap — that frame kind
is not modelled here; `SyntaxCondition::skipInternalTraps` is the hook.
| Bug: a quoted `'='` (or other operator text) between SAY items was parsed as the comparison operator | `rules/ExprCompare.cls` (requires OP token) | found by the random differential; also affected earlier x281 |
| Harness: `tests/run.sh` sets `RX2CPP_BIF_DISABLED=1` (bootstrap-subset suite) | `tests/run.sh` | previously failed on missing `rxbif_breadth.hpp` |

Semantics matched from upstream source (not guessed): `//` truncates operands longer than DIGITS to DIGITS+1 digits (no rounding)
and returns the dividend unchanged when |x|<|y|; `**` is left-to-right binary powering at DIGITS+len(n)+1 with the base truncated to
DIGITS+1, the negative-power reciprocal truncated to working digits+1 and rounded once at the end, formatted with the
`adjusted >= DIGITS || |exponent| > 2*DIGITS` rule (`upstreamRule` flag on `formatRexxDecimal`; other callers unchanged).

## Boundaries (not claimed)

* `//` / `**` error text is a runtime `std::runtime_error` with the right *code* (26.12, 40.3, 40.4), not an ooRexx SYNTAX condition.
* `**` exponent limited to 9 digits; `numeric form value`, `numeric digits` above 100000 unsupported.
* USE STRICT ARG defaults must be constants (the interpreter also rejects expressions, error 35); `.nil` defaults need the object lane.
  Omitted middle arguments (`call f 1,,3`) are not representable in the standalone lane yet.
* SIGNAL/RAISE scope: only the SYNTAX condition; `SIGNAL label` (jump), other conditions (ERROR, NOVALUE, HALT, NOTREADY), RAISE
  forms other than `ARRAY(...)`, and `CONDITION()` are not implemented (fail closed). The handler label must be a label in the
  program and is run as a routine on the trapping activation's variable pool (so handlers should end in RETURN/EXIT).
  Uncaught error text/status differs from the interpreter (`rx2cpp runtime error`, status 2).
* **Finding for the library effort:** with the plain-lane items above done, every file of the user's archive/compress libraries is
  now stopped by the *directive gate* (`::class`, `::method`, `::requires "x.cls"`), i.e. the object lane. Remaining standalone items
  are not the blocker any more.

## Lane split (to avoid collisions)

* ChatGPT language lane: `~` sends, `::class`, `::method`, `::attribute`, `forward`, `a[i]`, `.array`/collections.
* ChatGPT BIF lane: `c2x`, `x2c`, `bitxor` and the rest of `external/bif` (untouched here).
* Claude lane: threading/operators, external libraries (`::requires … LIBRARY`, already merged by ChatGPT in v0.30.1), NUMERIC,
  SIGNAL/RAISE/CONDITION, then label/routine syntax.
* Files both lanes touch: `core/RxLexer.cls`, `core/RxCompiler.cls`, `rules/RxRoutineRules.cls`. Merge with 3-way, not overwrite.

## Qualification run

`tests/test_claude_unary_strict.sh`, `tests/test_claude_numeric_ops.sh`, `tests/test_claude_signal_labels.sh`: pass on GCC and Clang.
Full-suite results: see the accompanying message / `QUALIFICATION_CLAUDE_V0301.md` if present.

## Reproduction

```
export REXX_BIN=/path/to/rexx REXX_LIB=/path/to/lib OO_ROOT=/path/to/oorexx
CXX=g++ tests/test_claude_unary_strict.sh && CXX=g++ tests/test_claude_numeric_ops.sh
```
Boost headers are required (v0.29+ decimal backend).
