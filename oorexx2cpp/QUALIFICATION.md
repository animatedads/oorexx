# rx2cpp v0.18 — RexxCPS qualification supplement

Test host: Linux x86-64, ooRexx 5.3.0 supplied debug package, GCC/Clang
C++17 -O2. Original RexxCPS 2.2 source unchanged; it is **not compiled**.

| Qualification | GCC | Clang |
|---|---|---|
| `DO count` with modified count in loop | PASS | PASS |
| Nested repeat/count loops, output parity | PASS | PASS |
| RexxCPS-shaped 1m-body kernel output | PASS | PASS |
| 4 unsupported `DO` forms fail closed | PASS | PASS |
| Negative repeat count runtime rejection | PASS | PASS |
| Selected previous standalone samples (GCC) | PASS (3) | not rerun |

Existing **full** historical ooTest and full standalone regression were
not run in this focused release. The earlier results below pertain to v0.17
and must not be presented as fresh v0.18 qualification.

Original RexxCPS interpreter run: wall 5.62s, reported 1,789,330 clauses/s.
Synthetic kernel: seven alternating measurements after warmup:
interpreter median 0.415431s, native median 0.109759s, native speedup 3.785x.
This does not justify a RexxCPS native-clauses/s claim.

See `benchmarks/REXXCPS_READINESS.md` for semantic limitations and upstream
construct inventory, and `benchmarks/reference/benchmark_results_20261010.json`
for all paired measurements.

---

# Prior v0.17 qualification (historical, not rerun here)

# rx2cpp v0.17 — Qualification, 2026-10-10

Host: Linux x86-64, supplied ooRexx 5.3.0 debug interpreter.
Targets: GCC/Clang C++17 compiled ooRexx native packages (.so).

| Test | GCC | Clang |
|---|---|---|
| New mixin graph and two-object interpreter/native parity (29 lines) | PASS | PASS |
| New mixin fail-closed rejection cases (5 each) | PASS | PASS |
| Native shared-object independence from Foreign Runtime / librexx | PASS | PASS |
| Inherited class-scope regression incl. COPY safety (7 checks) | PASS | PASS |
| Existing multi-class native package regression (8 checks) | PASS | PASS |
| Existing single-class native package and Crypto rejection (4 checks) | PASS | PASS |
| Macrospace callback bridge | PASS | PASS |
| ooRexx hybrid compiler negative tests (11) | PASS | Not rerun (shared front-end) |

## New test semantics

- `Root`, `Salt`, `Pepper`, `Dish` and `Grand` in one package.
- Each class owns its independently scoped `value` when exposed by its methods.
- Duplicate method `WHO` is resolved by ooRexx inheritance/mixin dispatch.
- One instance is altered without modifying another object's scopes.
- Different valid `::CLASS` option orderings are accepted.
- Unknown mixin, invalid non-mixin target, unrelated root, repeated direct
  mixin, and repeated inherited path all reject without an output `.so`.

The exact baseline commands are in `native/test_mixin.sh`,
`native/test_inheritance.sh`, `native/test_package.sh`, `native/test.sh`,
and `hybrid/build_and_test.sh`.

The *full* standalone executable regression and official historical ooTest
corpus were not rerun for v0.17. There is no claim of total language
compatibility or arbitrary-precision `NUMERIC DIGITS` support.

`crypto.cls` was checked using an available source candidate; it is *not*
confirmed as byte-identical to the authoritative accepted Crypto v0.8.3.
Native compilation of this candidate correctly fails (no `.so` published).
