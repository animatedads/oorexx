# rx2cpp v0.25 language-only qualification — 2026-10-10

Baseline: complete `rx2cpp_oorexx_v0.24_thread_corpus_delivery.zip` (which contains Claude's *corpus*, not implementation). Native compiler in this release remains written in ooRexx. The independently maintained BIF module is not modified or merged. Claude's new thread implementation patch is **not merged**.

## Newly implemented language rules

* `rules/StmtDoWhile.cls`: `DO WHILE condition ... END` with pre-tested, reevaluated condition; `ITERATE` targets the test and `LEAVE` exits.
* `rules/StmtDoForever.cls`: `DO FOREVER ... END` with lexical `ITERATE` / `LEAVE` and safe nested C++ body scope.
* Both registered in `core/RxRuleRegistry.cls` before `StmtRepeatDo.cls`, preserving strict fail-closed dispatch and independently loadable classes.
* No changes to the native `.so`/mixin backend or to the BIF implementation.

## New interpreter/native differential qualification

Using the supplied ooRexx 5.3.0 r13196 debug-build interpreter:

| Check | GCC -O2 | Clang -O2 |
| --- | --- | --- |
| Five full-source stdout byte-for-byte comparisons | 5/5 | 5/5 |
| Eight fail-closed source cases, existing output preserved | 8/8 | 8/8 |

Fixtures: `examples/loops_v025/*.rex`. They include zero-iteration WHILE, early LEAVE, ITERATE, nested loops, SELECT transfer and compound variables. Reproduce with `CXX=g++ tests/test_do_while_forever.sh` or `CXX=clang++ tests/test_do_while_forever.sh` after setting `REXX_BIN` and `REXX_LIB`.

## Previous compiler regressions

Under GCC: `tests/test_rexxcps_structural.sh` 7/7 differential, 7 syntax rejects, 4 runtime rejects; `tests/test_select.sh` 8/8 differential, 1 expected runtime error and six syntax rejects; `tests/test_compound.sh` 4/4 differential and its rejection gate all pass.

The combined old GCC/Clang full structural rerun exceeded the command-time limit after the GCC suites passed, *before* finishing the Clang structural suite. Four selected pre-existing Clang regressions (`or_division`, `iterate_outer`, `select_basic`, `compound_multitail`) were separately compiled and compared byte-for-byte, all passed. The full old Clang regression and whole ooTest suite are **not claimed** as completed for v0.25.

## Claude threading handoff

Input archive `rx2cpp_threads_v0.1.zip`, SHA-256 `4f5d36212b0d547c8fd3ba4280ee71aee3e2f6694e291c75513fb357c91f4347`, contains `thr_patch/rx2cpp_threads_v0.1.patch` plus its README. The patch was authored for v0.23, but `patch -p1 --dry-run` succeeds against both the v0.24 baseline and this v0.25 language tree. **It has not been applied**: threading remains Claude-owned and is not represented here as qualified runtime support. Verify and merge in a separately labelled integration step.

## Still unsupported

The unchanged RexxCPS 2.2 source does not compile. Decimal arithmetic and context, labels/internal subroutine activations, `SIGNAL ON NOVALUE`, activation-sensitive TRACE/ADDRESS, and BIF integration are separate gaps. The synthetic RexxCPS kernel is not a score for the real RexxCPS benchmark.
