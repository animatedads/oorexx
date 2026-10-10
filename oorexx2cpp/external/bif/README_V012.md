# rx2cpp BIF source rules v0.12 — control-state activation

This is a **BIF-only** add-on. `rx2cpp` source remains unchanged.

New original-frame BIF rules: **`SOURCELINE`, `TRACE`, `CONDITION`**. Their
converter `control/bif2control.rex` and gate `control/BifControlRouteRule.cls`
are written in ooRexx and inspect the original upstream C++ BIF definitions.
Three independently loadable generated `.cls` rules, native C++ wrappers and
an IR TSV are included. The C++ adapter requires original-activation control
and dynamic numeric suppliers, rather than invoking a detached Rexx routine.

The three functions retain an explicit subset: `CONDITION('A')` and `('O')`
require object ABI; `SOURCELINE(n)` native argument parsing currently admits
positive ASCII decimal integers only. The callback must supply real runtime
semantics for valid requests. A provider test double matches selected interpreter
oracles, but a live rx2cpp compiled-frame provider is not yet integrated.

To qualify against the staged ooRexx interpreter and read-only compiler headers:

```bash
export OO_ROOT=/path/to/oorexx/usr/local
export RX2CPP_BASE=/path/to/unpacked/rx2cpp_oorexx_v0.27_language
CXX=g++   BUILD_DIR=/tmp/bif-control-gcc   ./control/tests/run.sh
CXX=clang++ BUILD_DIR=/tmp/bif-control-clang ./control/tests/run.sh
```

See `control/CONTROL_CONTRACT.md` and `QUALIFICATION_V012.md`. The 81 BIF-name
catalogue and previous native/isolated chain-back remain separate; do not
confuse a registered route with complete BIF compatibility. No rx2cpp files
are included in this distribution.
