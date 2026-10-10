# BIF v0.14 qualification — 2026-10-10

## Inputs

- Base: BIF v0.13 standalone archive, source and native implementations unchanged except new optional `activation/rxbif_v0281_scoped.hpp`, tests, and release metadata.
- Integration reference: user-uploaded `rx2cpp_oorexx_v0.28.1_claude_integration_delivery(1).zip`, extracted read-only.
- ooRexx reference: user-supplied 5.3.0 r13196 debug interpreter.
- External typed library: user-supplied `rx2cpp_extlib_v0.1(1)(1)(1).zip`.

## Executed tests

| Test | GCC | Clang |
|---|---|---|
| New scoped activation (`activation/tests/run_v0281.sh`) | PASS | PASS |
| Existing v0.13 activation/extlib integration (`activation/tests/run.sh`) | PASS | PASS |
| ooRexx-written BIF breadth generation, 81 synthetic rules and native bridge (`tests/run_breadth.sh`) | PASS | Not rerun |
| v0.28.1 compiler `tests/test_bif_activation_v028.sh`: first 3 compiled Rexx vs ooRexx variable fixtures | PASS | Not rerun |
| Remaining v0.28.1 compiler BIF suite | **TIMED OUT**, no PASS claim | Not rerun |

The scoped activation test asserts: missing binding fails; fresh NUMERIC DIGITS/FUZZ/FORM for each invocation; nested caller state returns after unwind; same BIF runtime or variable pool cannot be borrowed concurrently by two threads; two disjoint activations execute concurrently; missing frame supplier fails. The inherited strict fallback classification remains unmodified.

## Precise limitations

- This optional BIF-only adapter is **not automatically called** by rx2cpp-generated frames. The compiler integration lane must install/uninstall `ScopedActivation` around every genuine activation.
- Scoped bindings prohibit concurrent use of the same pool or BifRuntime across threads; they do **not** make shared Rexx objects or exposed aliases intrinsically thread-safe.
- The 81-name synthetic source fixture verifies routing generation, not 81 original interpreter BIF implementations.
- Existing `SYMBOL`/`VAR`/`VALUE`, `ARG`/`ADDRESS`, `TRACE`/`CONDITION`/`SOURCELINE` keep their prior documented subset/host-callback limitations.
- The supplied v0.28.1 compiler's `external/bif` is an older v0.11 vendor snapshot. Tests used the external v0.14 root; no compiler or extlib source was modified.
