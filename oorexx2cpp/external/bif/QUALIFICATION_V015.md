# Native BIF block qualification — v0.15 (2026-10-10)

Reference: ooRexx 5.3.0 r13196 debug, staged interpreter executable.
Read-only compile ABI: rx2cpp v0.28.1 Claude integration `include/minirexx_runtime.hpp`.
Compilers: GCC and Clang, C++17 `-O2 -Wall -Wextra -Werror`.
Compiler project was not modified. All other inherited v0.14 files unchanged
(except VERSION and the top of README.md). No activation/extlib work in this release.

## Native exact-byte block results

| Block | GCC | Clang | Implementations tested |
|---|---:|---:|---|
| Binary / hex | 117/117 | 117/117 | C2X, X2C, X2B, B2X, BITAND, BITOR, BITXOR |
| String search / replacement | 441/441 | 441/441 | POS, LASTPOS, COUNTSTR, CHANGESTR, COMPARE, ABBREV |
| Word functions | 1,140/1,140 | 1,140/1,140 | WORDS, WORD, WORDINDEX, WORDLENGTH, SUBWORD, DELWORD, WORDPOS, SPACE |
| String padding / transformation | 1,284/1,284 | 1,284/1,284 | LEFT, RIGHT, CENTER, CENTRE, STRIP, SUBSTR, INSERT, OVERLAY, UPPER, LOWER, DELSTR, COPIES, REVERSE and SPACE |
| Explicit 4th-argument POS/LASTPOS ranges | 4,116/4,116 | 4,116/4,116 | Start, range, empty search, beyond-end, zero-length, multi-byte search |
| Invalid index / fallback classification | 48/48 | 48/48 | invalid text, negative, fractional, noncanonical whole-number representations |

Total **7,098 exact-output examples per compiler**; 48 negative classification checks per compiler.
No byte mismatch in final tested matrix. Initial unmodified v0.14 baseline had 23 mismatches in the
2,982-case matrix (LASTPOS 7, COUNTSTR 1, CHANGESTR 15); fixed before final run.
Additional 4,116 fourth-argument range cases are newly admitted native coverage.

## Inherited original suite

The original `tests/run.sh` was also run under both compilers against updated
rxbif.cpp and the unchanged v0.28.1 include. Both reported:
- 12/12 source-derived excerpt BIF rules, including `.cls` rule loading.
- 37 native generated-C++ checks.
- 110 general independent interpreter/native comparisons.
- 49 DATE/TIME interpreter comparisons, in UTC and each of four additional
  timezones (Europe/London, America/New_York, Asia/Kolkata, Pacific/Auckland).
- 21 native DATE/TIME context checks.

The inherited suite was completed before a final minor allocation optimisation
in numeric fallback classification; the 7,098 new cases and 48 negative checks
were rerun with the final files under both compilers.

## Native timing smoke test (not formal benchmarking)

Runs 150,000 calls per BIF after warm-up, including named dispatch and
rx::Value construction. Values below are observed per-call nanoseconds on this
shared host, not guaranteed production performance or a fair interpreter
speed-up comparison.

| BIF | GCC ns/call | Clang ns/call |
|---|---:|---:|
| C2X | 291 | 260 |
| BITXOR | 461 | 518 |
| LASTPOS | 223 | 225 |
| POS | 237 | 209 |
| WORDS | 236 | 310 |
| LEFT | 158 | 159 |

These timing measurements are a smoke test, not an IPC, CPU-clock-matched,
or end-to-end application benchmark.

## Outstanding semantic coverage

The 81-name breadth catalogue routes names but does not establish 81 fully
native or complete BIF implementations. Native conversion families, binary
grouping, variable / condition / IO, object coercion, omitted argument slots,
and full Rexx precision remain outside this qualification. Do not turn a known
unsupported numeric form into an invented approximate result. Source conversion
stays written in ooRexx; Python scripts here only generate/verify test fixtures.
