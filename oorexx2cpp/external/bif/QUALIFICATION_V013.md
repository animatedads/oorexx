# BIF v0.13 qualification — 2026-10-10

## Baselines

- BIF v0.12 original archive, unchanged existing implementation files.
- User-supplied rx2cpp v0.28 BIF activation delivery, read-only extracted tree.
- User-supplied rx2cpp-extlib v0.1 standalone typed-routine host, read-only.
- User-supplied Claude threading/operators patch reviewed, **not applied**: it
  targets the language compiler, not this BIF delivery.
- User-supplied ooRexx 5.3.0 r13196 debug binary and libraries.

## Executed tests

| Check | GCC C++17 -O2 | Clang C++17 -O2 |
|---|---|---|
| New v0.28 optional activation adapter and extlib boundary | PASS | PASS |
| `DIGITS/FUZZ/FORM` change between calls and nested pools | PASS | PASS |
| v0.28 real `SYMBOL/VAR/VALUE` provider, PROCEDURE EXPOSE alias | PASS | PASS |
| `ARG` with positional holes, `ADDRESS` with changed effective environment | PASS with supplied frame fixture | PASS with supplied frame fixture |
| `TRACE`, `SOURCELINE`, `CONDITION` callbacks | PASS with supplied control fixture | PASS with supplied control fixture |
| Reject unavailable provider, invalid NUMERIC, object reads, illegal options | PASS | PASS |
| extlib raw symbol vs literal-tail and changed numeric settings in actual `rxmath` calls | PASS | PASS |
| Inherited source-derived frame (2 classes), variable (3 classes), control (3 classes) tests with v0.28 headers | PASS | PASS |

Additionally rx2cpp v0.28 compiler `test_bif_activation_v028.sh` ran the
three full native/interpreter variable program comparisons under GCC and all
three passed. The combined test command **timed out before the later compiler
checks**. This is a PARTIAL compiler-level run, not a whole v0.28 qualification.
Its Clang compiler-level test was not rerun here. The previous 110 native and
49 DATE/TIME differential cases were not rerun in this v0.13 release; their
previous qualification remains historical, not fresh evidence.

## Coverage statement

The inherited catalogue retains 81/81 BIF **names routable**. v0.13 adds
an executable optional adapter for `DIGITS`, `FUZZ`, and `FORM` using the
compiler's actual numeric fields, plus a compiled/linked consumer boundary for
existing frame/control BIF adapters. **Neither full automatic rx2cpp
registration nor 81/81 semantic compatibility is claimed.**

There is no change to source-generated C++ builtin bodies, and no new BIF
implementation in rx2cpp itself. The companion extlib boundary remains
optional and separate from BIF name resolution.
