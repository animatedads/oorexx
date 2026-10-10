# v0.27 qualification — 2026-10-10

All tests used the supplied ooRexx 5.3.0 debug interpreter and C++17 `-O2
-Wall -Wextra -Werror` with reference stdout compared byte-for-byte.

| Suite | GCC | Clang |
|---|---|---|
| New PROCEDURE/EXPOSE positive fixtures | 9/9 | 9/9 |
| New protected-output syntax rejections | 6/6 | 6/6 |
| v0.26 internal routine parity fixtures | 10/10 | 10/10 |
| v0.26 protected-output rejections (revised to exclude new valid syntax) | 12/12 | 12/12 |
| Existing compound-variable parity | 4/4 | 4/4 |
| Existing compound-symbol rejection | 1/1 | 1/1 |
| Existing SELECT parity | 8/8 | Not rerun this release |
| SELECT no-match + malformed rejection | PASS (1 + 6) | Not rerun this release |

The original unchanged RexxCPS 2.2 was checked and remains **not supported**:
`rx2cpp:72:10: expected end of instruction (at '.')` for the version decimal
literal. No RexxCPS native performance score is claimed.

The complete upstream ooTest suite, native-library .so regression, historic
PARSE suite, and hybrid/thread suite were **not rerun** for v0.27. Earlier
qualifications do not silently constitute a new pass.

Fixtures: `examples/procedures_v027/*.rex`.
Reproducers: `tests/test_procedures.sh`, `tests/test_internal_routines.sh`,
`tests/test_compound.sh`, and `tests/test_select.sh`.
