# rx2cpp v0.26 — internal routines and activation arguments

This complete, language-only source delivery is based on v0.25. The precompiler is **written in ooRexx** and emits C++17. The limited standalone native runtime does not link to ooRexx.

## Demonstration

```sh
export REXX_BIN=/path/to/rexx
export REXX_LIB=/path/to/oorexx/lib
./build.sh examples/routines_v026/nested_calls.rex build/nested_calls
./build/nested_calls
```

The original `examples/routines_v026/nested_calls.rex` source also runs in ooRexx. A prebuilt generated C++ example and x86-64 native executable are in `artifacts/v026/`.

## Qualification

```sh
CXX=g++ tests/test_internal_routines.sh
CXX=clang++ tests/test_internal_routines.sh
```

Each runs ten interpreter/native full-output comparisons and twelve deliberately unsupported-source rejection tests, including output-file preservation. See `QUALIFICATION_V026.md` for results and limits.

## Rulesets

`RxRoutineRules.cls` owns internal routine declarations; `StmtUseArg.cls` owns argument assignment. Routine resolution is done before execution and shares the existing expression and CALL parser for arguments. The BIF and threading lanes remain separate. `PROCEDURE EXPOSE`, arbitrary OO activations, and numeric decimal-context semantics are not yet provided.
