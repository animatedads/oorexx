#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
CXX=${CXX:-g++}
OUT=${PACKAGE_TEST_DIR:-$ROOT/build/inheritance-$(basename "$CXX")}
mkdir -p "$OUT"
export REXX_PATH="$ROOT:$ROOT/native/fixtures${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
CXX="$CXX" "$ROOT/native/build.sh" "$ROOT/native/fixtures/inheritance_slots.cls" "$OUT" rx2cpp_inherit
"$REXX_BIN" "$ROOT/native/fixtures/inheritance_slots_oracle.rex" > "$OUT/oracle.out"
"$REXX_BIN" "$ROOT/native/fixtures/inheritance_slots_client.rex" > "$OUT/native.out"
cmp "$OUT/oracle.out" "$OUT/native.out"
[[ "$(wc -l < "$OUT/native.out")" -eq 16 ]]
echo 'PASS 3-level inherited method dispatch, scope slots, class identity, separate instances'
"$REXX_BIN" "$ROOT/native/fixtures/inheritance_override_token.rex" > "$OUT/override.out"
printf 'original\nclass-scope\nclass-scope\nleaf-scope\nleaf-scope\nFORGED\n' > "$OUT/override.expected"
cmp "$OUT/override.out" "$OUT/override.expected"
echo 'PASS root token access is class-directed, not intercepted by subclass override'
if "$REXX_BIN" "$ROOT/native/fixtures/inheritance_copy_reject.rex" > "$OUT/copy.out" 2> "$OUT/copy.err"; then
  echo 'FAIL copied a native object without scope cloning' >&2; exit 1
fi
grep -q 'native COPY requires per-scope independent state' "$OUT/copy.err"
echo 'PASS native COPY fails closed until per-scope deep-copy exists'
! readelf -d "$OUT/librx2cpp_inherit.so" | grep -E 'NEEDED.*(librexx|foreign|alchemy)'
echo 'PASS no Foreign Runtime or librexx dynamic linkage'
for fixture in inheritance_unknown_parent inheritance_derived_init inheritance_reserved_accessor; do
  if CXX="$CXX" "$ROOT/native/build.sh" "$ROOT/native/fixtures/$fixture.cls" "$OUT/bad-$fixture" "bad_$fixture" > "$OUT/bad-$fixture.log" 2>&1; then
    echo "FAIL accepted unsupported source $fixture" >&2; exit 1
  fi
  echo "PASS fail-closed $fixture"
done
