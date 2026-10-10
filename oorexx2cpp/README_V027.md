# rx2cpp v0.27 — PROCEDURE / EXPOSE activation pools

An incremental **language-only** release based on rx2cpp v0.26. The compiler
remains authored in ooRexx and produces C++17 native executables. No BIF or
threading lane changes have been imported.

## New capability

A labeled internal routine may begin with `PROCEDURE` or `PROCEDURE EXPOSE`
followed by simple variable or whole-stem names (`a.`). A procedure activation
owns an independent map; every named exposed variable redirects to its
caller's current map **live**, including through recursive exposure chains.
Routines without PROCEDURE use their caller's current pool, not the original
program-level pool. The existing `RESULT` semantics remain caller-local.

All source parsing is in separately loadable ooRexx classes:
`rules/RxProcedureRules.cls` for activation binding and
`rules/StmtProcedure.cls` for misplaced-procedure rejection. The internal
routine registry (`rules/RxRoutineRules.cls`) supplies the caller pool to
routine callbacks, while `include/minirexx_runtime.hpp` owns alias resolution.
`include/rx_compound_symbols.hpp` respects exposed stems and their reset
semantics.

## Run tests

```sh
REXX_BIN=/path/to/rexx REXX_LIB=/path/to/lib tests/test_procedures.sh
CXX=clang++ REXX_BIN=/path/to/rexx REXX_LIB=/path/to/lib tests/test_procedures.sh
```

## Explicit limitations

- Dynamic computed compound variable aliases, e.g. `PROCEDURE EXPOSE a.i`,
  are rejected, as are `EXPOSE` lists with commas.
- No general object-scoped PROCEDURE, SIGNAL, condition traps, decimal numeric
  context, or macrospace activity integration is claimed here.
- Class method activations, mixins, BIF callback activation contexts, and
  threaded activations are distinct qualification boundaries.
- The Variables C++ type was changed from an unordered_map typedef to a
  derived map class with exposure metadata. Consumers that include the
  standalone runtime header should rebuild; do not assume binary ABI stability.
- This is neither a native Crypto compilation milestone nor a complete
  RexxCPS compilation. The unchanged RexxCPS still fails at its decimal
  version literal on line 72.

## Branch ownership

Thread patch lane: Claude, **not merged**. BIF pack: separate developer lane,
**not merged**. This package advances only standalone Rexx language semantics.
