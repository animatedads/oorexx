# v0.10 — source-derived compiled-frame ARG and ADDRESS

**Deliverable:** standalone BIF extension only, tested against the unchanged
`rx2cpp_oorexx_v0.25_language_delivery(1).zip` ABI.

The ooRexx source reader and rule generator now produce standalone rule
classes and C++ wrappers for two activation-dependent BIFs: `ARG` and
`ADDRESS`.  A new C++ `ActivationRouter` uses original compiled-frame
suppliers for scalar argument/count/existence/omission semantics and dynamic
ADDRESS state; the numeric context is sampled on each delegate call.

This improves executable **subsets** of two previously host-only BIF names.
It does NOT increase the 81/81 name-routing count, does NOT patch rx2cpp or
implement the compiler's missing built-in registry wiring, and does NOT claim
100% ooRexx BIF semantic equivalence.

**Read:** `frame/FRAME_CONTRACT.md`, `QUALIFICATION_V010.md`.

**Reproduce:**

```bash
export RX2CPP_BASE=/path/to/extracted/unchanged/rx2cpp_v0.25
export OO_ROOT=/path/to/ooRexx/usr/local
CXX=g++    ./frame/tests/run.sh
CXX=clang++ ./frame/tests/run.sh
```

The tests use a compact, upstream-derived source fixture for ARG/ADDRESS,
not a full upstream source checkout; integration should requalify with the
full original C++ source. The larger native and breadth BIF regression suites
remain those shipped with v0.9.
