# rx2cpp 0.19 qualification, 2026-10-10

Reference: supplied ooRexx 5.3.0 debug Linux x86-64 binary.
Native compilers: GCC (`-std=c++17 -O2 -Wall -Wextra -Werror`) and Clang
(same flags). All comparisons are complete byte-for-byte stdout checks against
execution of the identical `.rex` source under the reference interpreter.

| Check | GCC | Clang |
|---|---|---|
| compound_semantics | PASS | PASS |
| compound_loop | PASS | PASS |
| compound_multitail | PASS | PASS |
| compound_trailing | PASS | PASS |
| rejected unsupported object expression, no partial C++ | PASS | PASS |

Previous standalone examples rerun with GCC: `squares`, `assignment_chains`,
`message_result`, `somerexx` — all PASS output parity. `somerexx` remains the
100,002-line reference.

The ooTest complete runner prepared 16 positive cases with successful C++
compilation before an execution timeout; it was interrupted before emitting
its final ooTest result. **No full ooTest-pass claim is made for v0.19.**
The complete native-package/mixin test suite was not rerun; no native package
backend source was changed.

Native output linkage inspection: generated executable depends on system
C++/C libraries, **not `librexx` and not Alchemy Foreign Runtime**.

Known limits: see `COMPOUND_SYMBOLS.md`. In particular, whole-package `crypto.cls`
is not compiled by this release; original RexxCPS 2.2 is still unsupported.
