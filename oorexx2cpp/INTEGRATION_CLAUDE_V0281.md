# Claude patch integration — v0.28.1

## Provenance

- Base: rx2cpp v0.28.0 BIF activation compiler (BIF implementation v0.11).
- Claude inputs: `rx2cpp_oorexx_v0.27_threads_integration.zip` and `claude_threads_ops_on_v027.patch`, received 2026-10-10.
- The patch is authored against v0.27 and applies to v0.28 with 0 rejected hunks;
  native `include/minirexx_runtime.hpp` receives 9-line offsets for two hunks.
- Important packaging fix: the original `+++ rx27_int/...` paths require normalisation
  to `+++ rx27b/rx2cpp_oorexx_v0.27_language/...` when applying with `patch -p2`
  from the project root; otherwise added files land in the root directory.
- Original patch SHA256: `5f3e4765aefe8299bd1b49fe20a1d9a720c0466087cdce2cd6fd915061323d85`.
- Original archive SHA256: `234d2be0982506a7ab0a614e40117003023c61ef5edab8c64708afc1d5498b77`.
- 25/28 patch-modified/added files match Claude's archive byte-for-byte.
  The three intentional differences are the shared BIF runtime header (v0.28
  additional context lines) and the two test shell scripts (v0.28 BIF-aware builds
  and a Bash syntax repair). No files under `external/bif/` changed.

## Changes

- Native class package: method `GUARDED` and `UNGUARDED` acceptance,
  per-scope locking, compiled `SELF~method(...)` sends and correct host dispatch.
- Standalone and native expression grammar: explicit `||` concatenation,
  `&` and `&&` operators alongside existing `|`, exact 0/1 logical conditions.
- Safe unsupported rejection: more general receiver/chained/cascade SELF sends,
  unsupported method options; no claims of full threading.
- Compatibility adjustment: `tests/test_concat.sh` uses v0.28 `build.sh`
  for BIF dependency flags. `tests/test_logic.sh` does the same for its principal
  integrated program, then uses BIF-disabled grammar-only builds for 9 small
  operand probes to avoid unnecessarily recompiling BIF sources nine times.
  A malformed Bash conditional in Claude's original logic script was repaired.

## Ownership and limits

The threading implementation remains Claude's lane, BIF implementation remains
its separate lane, and this release is an integration snapshot. `GUARD ON WHEN`,
`REPLY`, compiled-body deadlock condition 98.905 and threaded `PROCEDURE`
activation semantics are still not implemented. `SELF` sends cover the explicitly
tested bounded syntax, not arbitrary chained object expressions. The ooRexx
interpreter/thread corpus remains the semantic oracle.

See `QUALIFICATION_V0281.md` for exact executed tests.
