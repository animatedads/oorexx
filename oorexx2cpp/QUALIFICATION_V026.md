# rx2cpp v0.26 — internal routines, labels and call activation

Target: supplied ooRexx 5.3.0 r13196, GCC and Clang, Linux x86-64, C++17 `-O2 -Wall -Wextra -Werror`.

## Change set

* `rules/RxRoutineRules.cls`: lexical discovery of literal `label:` directives, rejecting duplicate names, generating one callable C++ function per routine and requiring top-level `EXIT`/`RETURN` before labels. Compiler-generated callbacks are registered before main code executes, so forward references and recursion work.
* `rules/StmtUseArg.cls`: routine argument assignment. Omitted argument drops the target symbol; explicit empty string remains an assigned empty string.
* `core/RxCompiler.cls`, `core/RxCppEmitter.cls`, `core/RxStream.cls`, `core/RxLexer.cls`: route label declarations and internal routines through a separate output section, retain the main body, and provide routine-scoped code emission.
* `rules/StmtCall.cls` and `rules/ExprBuiltinCall.cls`: give declared internal routines precedence over the built-in shortlist; `CALL` updates/drops `RESULT`, while function-expression calls don't update it.
* `rules/StmtReturn.cls`: distinguish top-level process return from the optional object returned by internal routines. `rules/StmtExit.cls` rejects EXIT from within this restricted routine backend.
* `include/minirexx_runtime.hpp`: native `RoutineRegistry`, argument-value call dispatch, and omitted-argument handling. Standalone executables remain free of ooRexx and Alchemy Foreign Runtime linkage.

## Actual qualification

`tests/test_internal_routines.sh`, run independently under `CXX=g++` and `CXX=clang++`, each:

* 10 complete programs: interpreter/native stdout byte-for-byte identical.
* 12 compile-time rejection checks: nonzero compiler status, `rx2cpp:` diagnostic, existing generated C++ unchanged.
* Covers forward labels, CALL with arguments, PARSE ARG, USE ARG, omitted/empty arguments, nested and recursive invocations, RESULT, internal names shadowing BIFs, loop/ITERATE in a routine.

Both runs passed. Evidence: `qualification/v026/internal-gcc.log` and `internal-clang.log`.

**Earlier regression runs this development turn:** GCC `test_do_while_forever.sh` (5 parity, 8 rejects); GCC `test_rexxcps_structural.sh` (7 parity, 7 source rejects, 4 runtime rejects); GCC and Clang `test_select.sh` (8 parity, six syntax rejects plus no-match error); GCC and Clang `test_compound.sh` (4 parity, one reject); Clang `test_do_while_forever.sh` (5 parity, 8 rejects). These completed before packaging.

A later combined recording command timed out after both internal-routine suites had completed, during the older GCC loop suite. It is *not* recorded as a clean complete combined rerun. The full upstream ooTest corpus and native `.so` suites were not rerun for v0.26.

## Unchanged RexxCPS

The unmodified shipped `rexxcps.rex` still rejects its decimal version literal, first reported at line 72. No C++ file is generated for that rejection and there is no valid native RexxCPS score.

## Semantic boundaries

These routines are a deliberately constrained *standalone executable* implementation. They share a `Variables` pool with the caller and have an independent argument vector. A native `RoutineRegistry` uses `MessageResult`/`std::optional<Value>` to distinguish no return from a returned object. `PROCEDURE`, `EXPOSE`, nontrivial condition traps, dynamic labels, external calls, omitted positional CALL arguments, implicit blank/abuttal concatenation and global `EXIT` from a routine are not implemented. Literal labels are only supported following an explicit top-level EXIT or RETURN; labels that are flow targets inside ordinary blocks remain unsupported. No assertion of complete activation-frame semantics is made.

The BIF module is separately owned. Claude's threading v0.3 patch is separately owned and unmerged; its diff also includes expression grammar modifications which conflict with independently changed shared compiler files. Do not automatically or silently merge it.
