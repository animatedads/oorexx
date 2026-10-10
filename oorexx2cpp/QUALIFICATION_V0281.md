# rx2cpp v0.28.1 qualification — 2026-10-10

Environment: local ooRexx 5.3.0 debug interpreter; GCC and Clang with C++17,
`-Wall -Wextra -Werror`. The comparisons below are interpreter/native stdout
comparisons where applicable.

| Suite | GCC | Clang |
|---|---|---|
| Claude native guarded methods: 4 x 25,000 guarded and unguarded calls, rejected options | PASS | PASS |
| Claude native SELF sends, subclass override, 4 x 2,500 threaded bumps, rejection fixtures | PASS | PASS |
| Concatenation: 11-line parity, 3 rejects, compiled native class composition | PASS | PASS |
| Logic: 14-line parity, 9 operand strings, 3 rejects | PASS | PASS |
| v0.28 dynamic BIF 81-name catalogue, 8 native and 5 isolated calls, failure paths | PASS | PASS |
| v0.11 variable activation: 3 parity programs and variable-provider preflight | PASS | PASS |
| PROCEDURE: 9 parity, 6 fail-closed | PASS | PASS |
| Internal routines: 10 parity, 12 fail-closed | PASS | PASS |
| SELECT: 8 parity, 6 syntax failures and no-match handling | PASS | PASS |
| Compound: 4 parity and 1 rejection | PASS | PASS |
| DO WHILE/FOREVER: 5 parity, 8 rejection | PASS | PASS |
| RexxCPS structural rules: 7 parity, 7 compiler rejections, 4 runtime rejections | PASS | PASS |
| PARSE context: 10 positive, 8 negative | PASS | PASS |

Claude's 14-case thread corpus: 14/14 reference checks with RUNS=2, and 14
standalone compiler fail-closed checks preserving prior generated output.
The native thread tests are a **separate backend**, not success on those 14
standalone programs.

RexxCPS original 2.2: compiler status 65 at 72:10 on `rexxcps=2.2`; no output
C++ generated; no native timing or score. Decimal arithmetic and other language
constructs remain unsupported.

This is focused regression qualification, not a full ooTest, all-operating-system,
ThreadSanitizer, race-analysis or complete interpreter equivalence certification.
