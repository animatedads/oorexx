# rx2cpp v0.24 threading-corpus qualification

Reference corpus: Claude-provided `thr_corpus_v0.1.zip`, copied unchanged.
Test platform: supplied ooRexx 5.3.0 r13196 Linux x86-64 debug build.

| Check | Result |
|---|---|
| 14 interpreter corpus cases, 2 repetitions each, golden stdout + rc | PASS 14/14 |
| Compiler first-pass against unmodified 14 source files | FAIL CLOSED 14/14 |
| Compiler output overwritten despite rejection | NONE |
| Compiled native threading semantic equivalence | NOT YET SUPPORTED |

This corpus is an *independent runtime qualification*, not a continuation of
RexxCPS performance results. No threading capability or speedup is claimed.

Structural v0.24 qualification is separately documented in `QUALIFICATION_V024.md`.
