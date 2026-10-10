#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
CXX=${CXX:-g++}
OUT=${MIXIN_TEST_DIR:-$ROOT/build/mixin-$(basename "$CXX")}
mkdir -p "$OUT"
export REXX_PATH="$ROOT:$ROOT/native/fixtures${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
CXX="$CXX" REXX_BIN="$REXX_BIN" "$ROOT/native/build.sh" "$ROOT/native/fixtures/mixin_scopes.cls" "$OUT" rx2cpp_mixin
"$REXX_BIN" "$ROOT/native/fixtures/mixin_scopes_oracle.rex" > "$OUT/oracle.out"
"$REXX_BIN" "$ROOT/native/fixtures/mixin_scopes_client.rex" > "$OUT/native.out"
cmp "$OUT/oracle.out" "$OUT/native.out"
[[ $(wc -l < "$OUT/native.out") -eq 29 ]]
echo 'PASS two sibling mixins, class-scoped EXPOSE, method precedence, identity'
! readelf -d "$OUT/librx2cpp_mixin.so" | grep -E 'NEEDED.*(librexx|foreign|alchemy)'
echo 'PASS no foreign-runtime dependency'
for fixture in mixin_bad_nonmixin mixin_bad_root mixin_bad_duplicate mixin_bad_repeat_path mixin_bad_unknown; do
    if CXX="$CXX" REXX_BIN="$REXX_BIN" "$ROOT/native/build.sh" "$ROOT/native/fixtures/$fixture.cls" "$OUT/rejected-$fixture" "reject_$fixture" > "$OUT/$fixture.log" 2>&1; then
       echo "FAIL unexpectedly accepted $fixture" >&2; exit 1
    fi
    [[ ! -e "$OUT/rejected-$fixture/libreject_$fixture.so" ]]
    grep -Eq 'rx2cpp:|Error' "$OUT/$fixture.log" || { cat "$OUT/$fixture.log"; exit 1; }
    echo "PASS fail-closed $fixture"
done
