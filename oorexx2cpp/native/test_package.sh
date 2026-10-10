#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OO_LIB=${OO_LIB:-$OO_ROOT/lib}
CXX=${CXX:-g++}
OUT=${PACKAGE_TEST_DIR:-$ROOT/build/native-package-$(basename "$CXX")}
mkdir -p "$OUT"
export REXX_PATH="$ROOT:$ROOT/native/fixtures:$OO_ROOT/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$ROOT/native/build.sh" "$ROOT/native/fixtures/two_classes.cls" "$OUT" rx2cpp_dual
"$REXX_BIN" "$ROOT/native/fixtures/two_classes_oracle.rex" > "$OUT/oracle.out"
"$REXX_BIN" "$ROOT/native/fixtures/two_classes_client.rex" > "$OUT/native.out"
cmp "$OUT/oracle.out" "$OUT/native.out"
[[ "$(wc -l <"$OUT/native.out")" == 7 ]]
echo 'PASS two classes, same method names, independent state, identity'
"$REXX_BIN" "$ROOT/native/fixtures/multi_stress_oracle.rex" > "$OUT/stress-oracle.out"
"$REXX_BIN" "$ROOT/native/fixtures/multi_stress.rex" > "$OUT/stress-native.out"
cmp "$OUT/stress-oracle.out" "$OUT/stress-native.out"
echo 'PASS 2000 calls and state integrity'
! readelf -d "$OUT/librx2cpp_dual.so" | grep -E 'NEEDED.*(librexx|foreign|alchemy)'
echo 'PASS package shared library has no librexx/Foreign Runtime dependencies'
for fixture in duplicate_class unsupported_inheritance unsupported_routine; do
  mkdir -p "$OUT/negative-$fixture"
  if "$ROOT/native/build.sh" "$ROOT/native/fixtures/$fixture.cls" "$OUT/negative-$fixture" "rx2cpp_neg_$fixture" >"$OUT/negative-$fixture.log" 2>&1; then
      echo "FAIL unexpectedly accepted $fixture" >&2; exit 1
  fi
  [[ ! -e "$OUT/negative-$fixture/lib${fixture}.so" && ! -e "$OUT/negative-$fixture/lib${fixture#negative_}.so" ]]
  ! find "$OUT/negative-$fixture" -maxdepth 1 -name 'lib*.so' | grep .
  echo "PASS fail-closed: $fixture"
done
"$ROOT/native/build.sh" "$ROOT/native/fixtures/collision.cls" "$OUT" rx2cpp_collision >"$OUT/collision-build.log"
if "$REXX_BIN" "$ROOT/native/fixtures/collision_client.rex" >"$OUT/collision.out" 2>"$OUT/collision.err"; then
    echo 'FAIL global class name collision was accepted' >&2; exit 1
fi
if ! grep -q 'native class name already registered' "$OUT/collision.err"; then
    echo 'FAIL collision diagnostic missing' >&2; cat "$OUT/collision.err" >&2; exit 1
fi
echo 'PASS preexisting .Array class protected from collision'

# Compiler and native-build failures must preserve an existing valid binary.
before=$(sha256sum "$OUT/librx2cpp_dual.so")
if "$ROOT/native/build.sh" "$ROOT/native/fixtures/unsupported_inheritance.cls" "$OUT" rx2cpp_dual >"$OUT/rollback.log" 2>&1; then
  echo 'FAIL invalid package was rebuilt over a valid one' >&2; exit 1
fi
after=$(sha256sum "$OUT/librx2cpp_dual.so")
[[ "$before" == "$after" ]] || { echo 'FAIL existing binary altered by failed compilation' >&2; exit 1; }
echo 'PASS failed compilation preserves previous valid shared library'
