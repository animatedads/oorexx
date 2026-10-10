# RexxCPS 2.2 (ooRexx 5.3.0) readiness / benchmark validity

Reference source: `share/ooRexx/samples/rexxcps.rex` in the supplied 5.3.0
Linux debug-build package. **The unmodified RexxCPS does NOT compile in
rx2cpp v0.18. There is no native RexxCPS clauses/second score.**

First compiler diagnostic (exact original source):
`rx2cpp:72:10: unsupported source character '.'` (version literal `2.2`).

The full program exercises many independent missing capabilities, for example:

| Source lines | Constructs | State |
|---|---|---|
| 72, 115, 131 | decimal literals, decimal arithmetic, precision rules | unsupported |
| 80, 197 | SIGNAL ON NOVALUE and condition handlers | unsupported |
| 81–82, 192 | PARSE SOURCE/VERSION/UPPER ARG/VAR | unsupported |
| 91, 93, 106–107 | TIME('R')/CALL TIME and DO count | DO count added; TIME not |
| 113, 127, 129 | compound variables, stem tails/defaults | v0.19 standalone primitive/dynamic-tail subset; full source still blocked by BIFs, numerics, SELECT/WHEN, control flow |
| 128–141 | SELECT/WHEN, logical operations | unsupported |
| 121–125 | LEAVE / ITERATE | unsupported |
| 143–144, 153 | TRACE, ADDRESS, internal routine CALL | unsupported |
| 163–168 | integer division %, continuation clauses | unsupported or incomplete |
| 184 | FORMAT built-in / numeric result formatting | unsupported |
| 191–195 | labels, internal subroutine and RETURN | unsupported |

This is a conservative inventory, not a complete parse or formal feature count.

## Benchmarks

The original shipped **unmodified** script ran under the supplied ooRexx
5.3.0 debug interpreter in 5.62 seconds wall time, reporting 1,789,330
clauses/sec. This is a reference interpreter score ONLY. The benchmark's
self-calibration, internal timer and mixed clause workload are **not**
replicated by the small kernel below.

`examples/rexxcps_loop_kernel.rex` uses the genuine nested-loop **shape**
from RexxCPS (`DO i=1 TO averaging`, `DO count`) but replaces the mix of
clauses with an accumulated integer operation and sets `count=1000`,
`averaging=1000`. Both implementations print `500500000`. It is a synthetic
microkernel and its wall time/speedup is not a RexxCPS result.

Seven alternating measured runs after warmup: interpreter median 0.415431 s,
native GCC -O2 median 0.109759 s, 3.785x on this host, capture-output mode.
Source code and paired measurements are preserved under `benchmarks/reference`.
A host debug-build interpreter and optimized C++ are not a general speed
comparison for all ooRexx installations or programs.

The tested compiler source is an ooRexx precompiler. Generated standalone
C++ binaries do not require ooRexx at runtime. The modular repetition DO
rule is `rules/StmtRepeatDo.cls`.

## Reproduce

```
export REXX_BIN=/path/to/rexx REXX_LIB=/path/to/ooRexx/lib
CXX=g++ benchmarks/test_rexxcps_progress.sh
RUNS=7 python3 benchmarks/benchmark_rexxcps_kernel.py
```

Running the full shipped RexxCPS original under ooRexx is a separate test;
compile it only when the source is fully accepted and output behaviour and
measurement method are qualified.
