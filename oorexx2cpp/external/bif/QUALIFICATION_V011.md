# BIF v0.11 qualification — 2026-10-10

## Baselines

- BIF v0.10 complete add-on copied unchanged except this revision's docs,
  version, manifest and the new `variables/` subpackage.
- rx2cpp v0.25 compiler headers read-only (no source edits).
- ooRexx 5.3.0 r13196 staged interpreter executable and libraries.
- Native C++17 GCC and Clang with `-O2 -Wall -Wextra -Werror`.

## Executed

| Suite | GCC | Clang |
|---|---|---|
| `variables/tests/run.sh` (NEW) | PASS | PASS |
| `frame/tests/run.sh` (v0.10 ARG/ADDRESS) | PASS | PASS |
| `tests/run_breadth.sh` (81-name catalogue) | PASS | PASS |
| `tests/run.sh` (native + date/time) | PASS | PASS |
| `live/tests/run.sh` (activation numerics) | PASS | PASS |
| `tests/run_fallback_classification.sh` | PASS | PASS |

New variable suite covers:

- 3/3 actual ooRexx-generated `.cls` source rules and corresponding C++
  inline wrapper header, intermediary TSV.
- Seven deliberately changed signature/call-site source fixture inputs
  rejected by the ooRexx generator.
- Ten deterministic output lines matched byte-for-byte against the actual
  ooRexx 5.3.0 BIFs: unset/assigned variable classification, `SYMBOL` `VAR`
  statuses, `VALUE` pre-assignment return, literal vs invalid symbol,
  stem/compound examples.
- Live per-call numeric supplier (including engineering form) reaches
  provider; invalid numeric context rejects before provider execution.
- Omission distinct from empty string; unsupported object arguments,
  assignment, selector object and unqualified external selector rejected;
  no accidental implicit environment I/O.
- Unsupported BIF name and absent providers fail closed.

The provider used for the differential suite is a **test double** for the
specific deterministic input cases, not an implementation of the ooRexx
variable retriever. The C++ adapter and generated rule wrappers are genuine;
real compiled-frame provider wiring is an outstanding host integration task.

Previous native, date/time, live numeric bridge, and strict fallback suites
were rerun under GCC and Clang. Native differential results: 37 generated C++
checks, 110 general BIF interpreter comparisons, 49 DATE/TIME comparisons in
UTC and four additional timezones, and 21 clock contract cases. Breadth route
regression: 81-name synthetic inventory, host callbacks and 17 isolated
ooRexx executions. These are independent of the new variable provider.

Both compilers qualify the **adapter contract**, not the integration of
a caller-variable provider into rx2cpp: that integration is still pending.

## Outstanding

- Original compiled Rexx activation provider for variable retriever and
  transactional `VALUE`, including `PROCEDURE`/`EXPOSE`, stem tails and
  selectors.
- ooRexx object marshalling/identity and preflight of old values before writes.
- Full upstream source checkout input and upstream ooTest group coverage.
- Compiler BIF registration remains outside this add-on.
