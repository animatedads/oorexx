# v0.11 — source-derived SYMBOL, VAR and VALUE BIF frame routing

**Standalone BIF add-on only. No rx2cpp changes.**

New ooRexx source converter `variables/bif2variables.rex`, rule class
`variables/BifVariableRouteRule.cls`, and C++ adapter
`variables/rxbif_variables.hpp` / `.cpp`.

This adds source-checked, generated `.cls` BIF rules and inline C++ call sites
for `SYMBOL`, `VAR`, and `VALUE`. Correct execution requires a real
**caller-frame variable provider**, not a guessed C++ dictionary or a fresh
interpreter activation. The adapter handles symbol status results, typed
old-value exchange requests, omitted vs empty arguments, mandatory fresh
numeric settings, and rejects unqualified object or selector operations.

See [variables/VARIABLE_CONTRACT.md](variables/VARIABLE_CONTRACT.md) and
[QUALIFICATION_V011.md](QUALIFICATION_V011.md).

Reproduce from the extracted package root:

```bash
export RX2CPP_BASE=/absolute/path/to/unchanged/rx2cpp_v0.25
export OO_ROOT=/absolute/path/to/ooRexx/usr/local
CXX=g++     ./variables/tests/run.sh
CXX=clang++ ./variables/tests/run.sh
```

**No automated integration claim:** rx2cpp v0.25 has not registered these
BIFs, and its compiled activation has not been extended to supply the
`VariableProvider`. The 81-name catalogue retains routing coverage, not
81 complete native executions. `VALUE` external selectors and object-valued
results remain the host's responsibility, and unsupported cases fail closed.
