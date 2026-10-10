# rx2cpp BIF breadth v0.5 — qualification record

Date: 2026-10-10. Target base: rx2cpp v0.20 delivery (read-only).
Original ooRexx executable: ooRexx 5.3.0 r13196, from supplied Ubuntu debug `.deb`.
Upstream source inventory: ooRexx GitHub `BuiltinFunctions.cpp` blob `05ea58114e9e5b59a1cceebf8dd418b78058d342` (verified 81 macro names and their Min/Max declarations, including dynamic `argcount` forms for MAX/MIN/XRANGE).

## Observed PASS checks

- 81-entry unique name/arity routing catalog: PASS.
- `bif2breadth.rex` (ooRexx) scanned original verbatim 12-definition excerpt: 12 ADMITTED, 69 MISSING; exit code 3 (intentionally non-success when input incomplete).
- `tests/make_inventory_fixture.rex` generated **synthetic** C++ signature blocks for all 81 names; ooRexx source scanner accepted 81/81 and emitted 81 `.cls` rule classes + 81 individual inline C++ call-site wrappers; this proves generator breadth, **not conversion of all 81 real implementations**.
- Dynamic arity `MAX`, `MIN`, `XRANGE`: emitted with open-ended upper bound. `ARG`, `ABS`, `DATE`: route metadata checked from loadable generated ooRexx classes.
- Upstream shape rejection for a changed CENTER argument declaration: PASS, exit code 3 and REJECTED in report.
- GCC C++17 `-Wall -Wextra -Werror -O2`: PASS, 81 host-callback routes + 17 real ooRexx interpreter BIF executions (all 16 isolated names represented, plus an omitted-argument case).
- Clang C++17 `-Wall -Wextra -Werror -O2`: same PASS.
- Unknown/context-sensitive BIF rejection from isolated interpreter (`ARG`): PASS.
- Default hostless rejection for `ARG` and `SIGN` when chainback not installed: PASS.
- Existing native `REVERSE`, existing rx2cpp `LENGTH`: PASS without interpreter callback.
- Existing v0.4 `tests/run.sh` (GCC): PASS, 37 generated-C++ checks, 110 native/interpreter cases, 49 DATE/TIME cases in UTC and four additional timezones, 21 clock contracts, plus existing negative/syntax tests.

## Not yet qualified

- **The full unmodified upstream C++ file was not available as local input**; 81/81 full-source generator admission remains to be run against the pinned source checkout by the integration owner. Inventory metadata (names/arity) was compared to that upstream blob through GitHub, but full method bodies were not supplied as a fixture.
- 27 live-activation callbacks need a host implementation, permissions and interpreter integration. The mock callback used for routing tests is intentionally not a semantic test of these BIFs.
- 36 existing native helpers are known qualified *subsets*, not complete BIF semantics. The 16 detached interpreter invocations run in a new activation, without caller state, object identity, numeric precision context or overrides.
- Complete ooTest upstream BIF suites are not passed by this pack. No change was made to rx2cpp's existing registry or core.

## Reproduction

```sh
cd rx2cpp_bif_source_rules_v0.5
RX2CPP_BASE=/extracted/rx2cpp_oorexx_v0.20 \
 OO_ROOT=/extracted/oorexx/usr/local \
 LD_LIBRARY_PATH=/extracted/oorexx/usr/local/lib \
 ./tests/run_breadth.sh

# Optional clang:
CXX=clang++ BUILD_DIR=/tmp/bif-breadth-clang \
 RX2CPP_BASE=/extracted/rx2cpp_oorexx_v0.20 \
 OO_ROOT=/extracted/oorexx/usr/local \
 LD_LIBRARY_PATH=/extracted/oorexx/usr/local/lib \
 ./tests/run_breadth.sh

# Existing regression:
RX2CPP_BASE=/extracted/rx2cpp_oorexx_v0.20 \
 REXX_BIN=/extracted/oorexx/usr/local/bin/rexx \
 LD_LIBRARY_PATH=/extracted/oorexx/usr/local/lib ./tests/run.sh
```
