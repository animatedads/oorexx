# rx2cpp v0.25 — language compiler expansion (DO WHILE/FOREVER)

This is a **complete, language-only** delivery based on v0.24 + the unmodified threading conformance corpus. It preserves the ooRexx-written compiler and independently loaded grammar classes. See `QUALIFICATION_V025.md` for exact evidence.

## Build + qualification

```sh
export REXX_BIN=/path/to/ooRexx/bin/rexx
export REXX_LIB=/path/to/ooRexx/lib
CXX=g++ tests/test_do_while_forever.sh
CXX=clang++ tests/test_do_while_forever.sh
```

To compile a standalone program:

```sh
./run-compiler.sh examples/loops_v025/do_while_iterate.rex output.cpp
g++ -std=c++17 -O2 -Iinclude output.cpp -o output
./output
```

The generated standalone executable has no ooRexx dependency. `DO WHILE` and `DO FOREVER` language coverage is independent of native `.so` package method compilation. Claude's thread patch is not merged into this release.
