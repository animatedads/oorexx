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
# FORWARD CLASS (SUPER) without ARRAY (the method's own arguments) is supported in the host-API lane: parity, not refusal.
mkdir -p "$OUT/forward-super"
printf 'say .Child~new~m\nsay .Parent~new~m\n::requires "forward_super_no_array.cls"\n' > "$OUT/forward-super/interpreted.rex"
printf 'say .Child~new~m\nsay .Parent~new~m\n::requires "rx2cpp_fwdsuper" library\n' > "$OUT/forward-super/compiled.rex"
(cd "$ROOT/native/fixtures" && "$REXX_BIN" "$OUT/forward-super/interpreted.rex" > "$OUT/forward-super/expected.txt" 2>&1)
"$ROOT/native/build.sh" "$ROOT/native/fixtures/forward_super_no_array.cls" "$OUT/forward-super" rx2cpp_fwdsuper > "$OUT/forward-super/build.log" 2>&1 \
  || { tail -20 "$OUT/forward-super/build.log"; echo 'FAIL FORWARD CLASS (SUPER) without ARRAY rejected' >&2; exit 1; }
(cd "$OUT/forward-super" && LD_LIBRARY_PATH="$OUT/forward-super:$LD_LIBRARY_PATH" "$REXX_BIN" compiled.rex > actual.txt 2>&1) || true
cmp "$OUT/forward-super/expected.txt" "$OUT/forward-super/actual.txt" || { diff -u "$OUT/forward-super/expected.txt" "$OUT/forward-super/actual.txt"; exit 1; }
echo 'PASS FORWARD CLASS (SUPER) without ARRAY: identical to the interpreter'
for fixture in duplicate_class unsupported_routine; do
  rm -rf "$OUT/negative-$fixture"; mkdir -p "$OUT/negative-$fixture"
  if "$ROOT/native/build.sh" "$ROOT/native/fixtures/$fixture.cls" "$OUT/negative-$fixture" "rx2cpp_neg_$fixture" >"$OUT/negative-$fixture.log" 2>&1; then
      echo "FAIL unexpectedly accepted $fixture" >&2; exit 1
  fi
  [[ ! -e "$OUT/negative-$fixture/lib${fixture}.so" && ! -e "$OUT/negative-$fixture/lib${fixture#negative_}.so" ]]
  # (a "! pipeline" never fails under set -e: test explicitly)
  if find "$OUT/negative-$fixture" -maxdepth 1 -name 'lib*.so' | grep -q .; then echo "FAIL $fixture left a library" >&2; exit 1; fi
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
if "$ROOT/native/build.sh" "$ROOT/native/fixtures/duplicate_class.cls" "$OUT" rx2cpp_dual >"$OUT/rollback.log" 2>&1; then
  echo 'FAIL invalid package was rebuilt over a valid one' >&2; exit 1
fi
after=$(sha256sum "$OUT/librx2cpp_dual.so")
[[ "$before" == "$after" ]] || { echo 'FAIL existing binary altered by failed compilation' >&2; exit 1; }
echo 'PASS failed compilation preserves previous valid shared library'
