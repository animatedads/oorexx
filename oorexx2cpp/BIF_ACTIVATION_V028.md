# rx2cpp v0.28 — BIF activation and external native host boundary

Date: 2026-10-10. This is the compiler-side integration of the independently
maintained `rx2cpp_bif_source_rules_v0.11_variable_activation` release.
The BIF generator and implementation code are not edited in this branch.

## Runtime selection

* `external/bif/` is a vendored, unmodified v0.11 BIF delivery, retained for
  reproducibility. `RX2CPP_BIF_ROOT` can select a different compatible delivery.
* `run-compiler.sh` loads the BIF catalogue from `catalog/bifs.tsv` when present.
  Its 81 names are **admission candidates**; they do not each constitute a
  qualified native implementation.
* A user-defined internal routine takes precedence over a BIF of the same name.
  Unknown names, invalid catalogue contents, and argument-count mismatches reject
  before the C++ output is committed.
* `RX2CPP_BIF_DISABLED=1` keeps the older ABS/LENGTH-only bootstrap mode for
  independent language qualification.
* `RX2CPP_BIF_ISOLATED=1`, `OO_ROOT`, and
  `RX2CPP_BIF_ISOLATED_SCRIPT=$RX2CPP_BIF_ROOT/native/isolated_chainback.rex`
  enable the **explicitly interpreter-dependent** detached chainback for selected
  BIFs. This is not the same as a callback into the current ooRexx activation.

## Current activation integration

`include/rx_bif_integration.hpp` supplies a callback `frameVariableReply` over
`rx::Variables`. The active variable pool is passed for each BIF invocation.
`PROCEDURE EXPOSE` aliases are followed through `variableOwner`, so a write in
an exposed routine modifies the original owner. Compound tails are resolved
using the caller's own pool. `SYMBOL`, `VAR`, and `VALUE` now exercise this
v0.11 variable router without duplicate implementations of those BIFs.

`ActivationNumeric` is stored on each variable pool and copied into a child
PROCEDURE pool. The compiler does NOT yet parse general `NUMERIC DIGITS/FUZZ/FORM`
instructions or provide fully specified decimal mathematics; non-default values
are qualified only by C++ provider tests, not compiled Rexx syntax.

Host-only functions without their required callback fail explicitly, and the
external-selector form of `VALUE` rejects before modifying any variable.
Unsupported object-valued previous results and replacements reject without
mutating the caller's state. This is a qualified subset of variable name and
object semantics, not full ooRexx equivalence.

## Repaired external library typed-routine host

Claude's separately supplied `rx2cpp_extlib_v0.1(1).zip` changes the callback
contract so raw symbol hooks (`varGet/varSet/varDrop`) and literal-tail hooks
(`tailGet/tailSet/tailDrop`) are distinct. The latter must not treat a literal
stem-element tail as a dynamic variable name. The compiler-side optional test
`tests/test_extlib_repair_v028.sh` explicitly binds these hooks to an exposed
`rx::Variables` pool and verifies both routes resolve to separate keys.

The external typed-routine library host is **not** wired into the compiler's
`::requires LIBRARY` resolution in this release. It does not change the BIF
catalogue, native class backend, or interpreter bridge. Keep the repaired
extlib ZIP alongside the BIF package until a proper package loader is wired.

## Reproduction

```sh
export REXX_BIN=/path/to/ooRexx/bin/rexx
export REXX_LIB=/path/to/ooRexx/lib
export OO_ROOT=/path/to/ooRexx
CXX=g++ tests/test_bif_dynamic_v028.sh
CXX=clang++ tests/test_bif_dynamic_v028.sh
CXX=g++ tests/test_bif_activation_v028.sh
CXX=clang++ tests/test_bif_activation_v028.sh

# Separately obtained corrected external library host:
export RX2CPP_EXTLIB_ROOT=/path/to/rx2cpp_extlib_v0.1
CXX=g++ tests/test_extlib_repair_v028.sh
CXX=clang++ tests/test_extlib_repair_v028.sh
```

## Not yet claimed

* All 81 names callable on every invocation path.
* General decimal context, object result transport, selectors and system state.
* `ARG`/`ADDRESS`/`TRACE` bound to true compiled or interpreter frames.
* Dynamic third-party `::requires LIBRARY` resolution in generated programs.
* Native compiled-method `.so` activation and 5.3 interpreter object identity.
* Full historical ooTest or unchanged RexxCPS compatibility/performance.

Claude continues to own threading; the BIF lane continues to own BIF
implementations. v0.28 modifies only the compiler-side wiring and tests.
