# rx2cpp v0.28 qualification — 2026-10-10

Reference: local ooRexx 5.3.0 staged binary from current project package.
Compiler targets: GCC and Clang, C++17, `-Wall -Wextra -Werror` for the rx2cpp
BIF integration; the standalone external typed-library host supplies its own
`-Wno-unused-parameter` build flag.

| Suite | GCC | Clang |
|---|---|---|
| BIF v0.11 variable activation: 3 programs, byte-identical output | PASS | PASS |
| Native BIF passthrough regression sample | PASS | PASS |
| Activation variable provider preflight: aliases, raw/tail distinction, selector preflight, numeric validity | PASS | PASS |
| Dynamic catalogue: all 81 BIF names admitted by source compiler | PASS | PASS |
| Dynamic integration test: 8 native BIF calls / 5 isolated calls | PASS | PASS |
| Unknown names / truncated manifest / host-only without callback | PASS rejection | PASS rejection |
| Internal routine shadows BIF of same name | PASS | PASS |
| v0.27 PROCEDURE: 9 parity / 6 fail-closed | PASS | PASS |
| v0.26 internal routine: 10 parity / 12 fail-closed | PASS | Not rerun in this qualification |
| Compound variable: 4 parity / 1 fail-closed | Partial: 2/4 before command timeout | PASS: 4/4 |
| Repaired external host: 745 rxmath differential cases | PASS: 0 differences | PASS: 0 differences |
| Repaired external host: rxsock TCP loopback | PASS | PASS |
| Repaired external host: literal-tail vs dynamic-symbol pool binding | PASS | PASS |

The GCC compound-variable regression was interrupted after 2/4 fixture
comparisons in a combined command; no claim of that suite's complete pass.

**Important distinctions:** catalogue admission != runtime availability;
detached interpreter invocation != live caller callback; the repaired extlib
host is separately supplied and validated through a boundary test, not merged
into `::requires LIBRARY` support. No full ooTest run or unchanged RexxCPS
native result is claimed. The unchanged benchmark still has decimal-language
and activation/control-flow blockers.
