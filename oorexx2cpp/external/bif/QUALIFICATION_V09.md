# BIF v0.9 validation — 10 October 2026

## Read-only compiler reference

- Supplied compiler: `rx2cpp_oorexx_v0.25_language_delivery(1).zip`
- SHA-256: `64a5173c0411416990b18a3c147807d73088cc9392311d766fe701d5eadb5dc3`
- Tests compile with the v0.25 read-only `include/minirexx_runtime.hpp`.
- No file in rx2cpp v0.25 was edited, copied into this BIF delivery, or merged.

## Executed validation (gcc and clang++ at C++17 -O2)

| Suite | GCC | Clang |
| --- | --- | --- |
| `tests/run_fallback_classification.sh` (new) | PASS | PASS |
| `tests/run.sh` | PASS | PASS |
| `tests/run_breadth.sh` | PASS | PASS |
| `live/tests/run.sh` | PASS | PASS |
| Existing generated C++ checks | 37 PASS | 37 PASS |
| Existing scalar differential cases | 110 PASS | 110 PASS |
| DATE/TIME exact cases | 49 PASS in 5 timezones | 49 PASS in 5 timezones |
| Clock contract checks | 21 PASS | 21 PASS |
| Detached ooRexx BIF calls | 17 PASS | 17 PASS |

## New negative tests

- A native subset miss (`COUNTSTR` with empty needle, and a 4-argument `POS`)
  triggers precisely one host callback, with the numeric context sampled on
  each fallback.
- Bad `DATE` output style and invalid LEFT pad produce a direct failure
  without executing the host callback or reading numeric context.
- The known unsupported case with no host callback fails rather than faking
  a result; with no numeric snapshot it also fails before host invocation.
- A qualified native-only invocation succeeds without touching the fallback.

## Scope and caveats

- Still 81/81 **route names**, not 81/81 compiled-equivalent semantics.
- `bif2breadth.rex` source test uses a genuine 12-BIF excerpt plus an
  **explicitly synthetic** 81-name signature fixture. Full upstream source
  generation is not claimed to have run.
- 27 host activation BIFs still depend on their caller-state adapters.
- Direct bridging of interpreter-managed objects and overloaded BIF resolution
  is not claimed.
- This is a standalone BIF add-on; rx2cpp v0.25 only registers ABS and
  LENGTH and still does not automatically compile the remaining 79 BIF names.
- The original test suite is not a full upstream ooTest qualification.
