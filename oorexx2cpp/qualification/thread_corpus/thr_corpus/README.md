# ooRexx threading conformance corpus v0.1

Oracle: ooRexx 5.3.0 r13196 (debug build), Linux x86-64, 2 cores.
Every program prints deterministic stdout. `run_corpus.sh` repeats each one (default 10 runs)
and refuses to record a golden file unless all runs agree on stdout and exit code.

    LD_LIBRARY_PATH=/path/to/oorexx/lib ./run_corpus.sh /path/to/rexx 10 record   # regenerate golden
    ./run_corpus.sh /path/to/wrapper 10 check                                      # test a compiled build

For a compiled build pass a wrapper script that compiles+runs `$1` and exits with the program's code.
stderr is recorded in `golden/*.stderr.set` for information only (see t06).

| Test | Covers |
|---|---|
| t01 | `~start` with arguments, `~result` in submission order |
| t02 | guarded method: no lost updates across 4 activities |
| t03 | **KERNEL_LOCK_DEPENDENT** unguarded shared counter; interpreter gives exactly 400000 |
| t04 | `GUARD ON WHEN` releases the scope lock while waiting |
| t05 | `REPLY` returns early value; body continues on its own activity |
| t06 | error in a started message is raised again at `~result` (code 42.3) |
| t07 | nested `~start` |
| t08 | `~completed` before/after `~result` |
| t09 | same activity re-enters a guarded method on one scope |
| t10 | `~send` synchronous vs `~start` asynchronous ordering |
| t11 | NUMERIC DIGITS/FUZZ are per activation, not inherited by started messages |
| t12 | `.Message~new(...)` with `~start` and `~send` |
| t13 | UNGUARDED method runs while another activity holds the lock; guarded one waits |
| t14 | same-scope guarded deadlock is *detected*: SYNTAX 98.905, no hang |

## Interpreter facts recorded
* Unguarded counter test is exact (400000): activities are effectively serialised. Native parallel code can differ; decide compatibility vs parallel mode explicitly.
* Which thread prints an asynchronous error's stderr header (worker line vs caller `~result` line) varies run to run; the catchable condition at `~result` does not.
* Deadlock on a guarded method is detected and raised as 98.905. A compiled runtime must detect it too or the t14 program will hang.

## Not covered yet
`~notify`, `GUARD OFF`, `SysSleep`-free interleavings, multiple scopes via mixins, `.Message~completed` races, BSF4OORexx/Java threads, RXAPI/macrospace.
