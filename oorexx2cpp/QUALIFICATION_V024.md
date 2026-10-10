# rx2cpp v0.24 focused qualification — 2026-10-10

Reference: supplied ooRexx 5.3.0 Linux x86-64 debug build.
Target: native C++17 without interpreter runtime for the structural fixtures.
Build flags: `-std=c++17 -O2 -Wall -Wextra -Werror`.

| Test suite | GCC | Clang |
|---|---|---|
| RexxCPS-derived structural byte-for-byte comparisons | 7/7 | 7/7 |
| Compiler rejected illegal/unsupported forms without overwriting output | 7/7 | 7/7 |
| Native runtime rejected invalid numeric/logical operations | 4/4 | 4/4 |
| Earlier SELECT suite | 8/8 | 8/8 |
| Earlier compound-variable suite | 4/4 | 4/4 |

The GCC PARSE regression produced 21 byte-identical cases before the
combined suite command timed out. **Not** recorded as complete.
The complete historical ooTest corpus and native `.so` packages were **not**
requalified in this round.

Control transfers are verified for named and unnamed loops, nested loops,
transfers through SELECT, repetition DO, and DO UNTIL. Native `%` matches
small signed integer division; numbers outside the qualified decimal subset
are intentionally rejected. `|` evaluates both operands, validates binary
logical values and preserves normal comparison precedence.

The unchanged RexxCPS source is not yet compilable and has **no** native
benchmark result for v0.24.
