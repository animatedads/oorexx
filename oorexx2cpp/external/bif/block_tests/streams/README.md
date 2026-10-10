# rx2cpp stream fidelity contract — oracle-first, no implementation changes

This suite is deliberately **tests before stream implementation**. Its source of truth is a real ooRexx 5.3.0 r13196 interpreter, not an invented native file model. The 11 independent Rexx programs were executed in clean working directories and their complete stdout captured byte-for-byte as one uppercase-hex row per case in `expected_traces.tsv`. Cases using binary output include a literal NUL byte; hex encoding prevents transport damage in GitHub text. Stderr must remain empty. Reference output comprises 152 lines (including binary-bearing lines).

## Run interpreter oracle

```sh
export REXX_BIN=/path/to/ooRexx/bin/rexx
export LD_LIBRARY_PATH=/path/to/ooRexx/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
bash oorexx2cpp/external/bif/block_tests/streams/run_oracle.sh
```

The runner creates a fresh isolated directory per case, feeds one known binary stdin fixture to each program, and compares actual stdout bytes to the pinned interpreter trace. No timestamp, absolute path, locale-dependent textual diagnostic or wall-clock threshold is part of a trace. The oracle passed **11/11** on three independent runs in the qualification environment; after switching to hex baselines, two further complete runs passed. Deliberate mutation of the `01_line_state` expected trace was detected and rejected.

## Run compiled-program gate (NOT YET QUALIFIED)

```sh
export RX2CPP_BASE=/fresh-git-checkout/animatedads/oorexx/oorexx2cpp
export REXX_BIN=/path/to/ooRexx/bin/rexx
export OO_ROOT=/path/to/ooRexx
bash "$RX2CPP_BASE/external/bif/block_tests/streams/run_compiled.sh"
```

This demands a Git checkout with a resolvable commit SHA, attempts to compile and execute every case, then compares stdout **and stderr** with the oracle. It fails if any program is rejected, fails at runtime, differs in a single byte, or produces stderr. The build/operation logs are retained when `STREAM_TEST_OUTPUT_DIR` is set. A successful compiler parse alone is never a fidelity pass. **This runner has not been run against a materialized current GitHub compiler checkout.** Do not claim a compiled stream backend from the interpreter-only green baseline.

## Oracle cases and fidelity surfaces

| Case | What is proved by the interpreter reference |
| --- | --- |
| 01_line_state | `LINEIN`, `LINEOUT`, `LINES`, `CHARS`, `STREAM` status, open/close, cursors and EOF |
| 02_binary_cursor | `CHARIN`, `CHAROUT`, binary NUL and FF, explicit byte positions, zero-length reads and EOF |
| 03_modes_queries | `OPEN WRITE REPLACE`, `OPEN WRITE APPEND`, `SEEK`, stream size/position, mode transitions |
| 04_errors_conditions | `NOTREADY` and `SYNTAX` categories, invalid query, recovery after handled errors |
| 05_object_stream | Live `.Stream` instance with open/lineout/linein/state/close |
| 06_mixed_handles | Named BIF calls and `.Stream` object handles on the same path |
| 07_default_io | Default `LINEIN()` with binary stdin, including an embedded NUL |
| 08_seek_write | Positioned writes and reads, CRLF/LF/blank line semantics, EOF |
| 09_activation_state | Cursor state spanning nested `PROCEDURE` activation |
| 10_stream_commands | `QUERY EXISTS`, `QUERY SIZE/POSITION`, `SEEK`, status across close/reopen |
| 11_default_output | Default `LINEOUT` and `CHAROUT`, stdout byte ordering including embedded NUL |

## Classification on GitHub `main` at test creation

`LINEIN`, `LINEOUT`, `CHARIN`, `CHAROUT`, `LINES`, `CHARS`, and `STREAM` all appear as `HOST_ACTIVATION` in `external/bif/catalog/bifs.tsv` and the C++ breadth router. Their **registration is not native execution coverage**. The separate `hosted_tier/HostedSession.hpp` is an interpreter object bridge, but it does not by itself prove shared compiled-caller stream activation, standard-stream redirection, traps or combined BIF/object cursor semantics. Do not send stateful streams through the isolated, stateless BIF chainback. No BIF catalogue change is made by this package.

## What remains unqualified

A full ooTest stream suite, platform-specific path/encoding and newline behaviours (MVS records are a separate backend), parallel access to the same stream, explicit `NOTREADY`/`SYNTAX` runtime condition codes in a compiled activation, stream overrides/registered routines, ownership across objects and threads, full `.Stream` identity and methods, and hosted/native mixed dispatch. New tests should be frozen against ooRexx before implementing these paths. Blocking I/O must block only the caller activity and must never hold a global interpreter/process mutex. No user files are touched outside isolated test directories.

**Contract:** red means unqualified; green requires exact interpreter-vs-compiled parity plus native/host resource and error semantics. This test-only commit makes no claim of stream implementation.
