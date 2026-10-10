#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
OUT=${TEST_OUTPUT_DIR:-"$ROOT/build/control-routines-$(basename "$CXX")"}
mkdir -p "$OUT"
export LD_LIBRARY_PATH="$OO_ROOT/lib:$OUT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/native/fixtures:$ROOT${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" "$ROOT/native/fixtures/routine_control_oracle.rex" > "$OUT/oracle.out"
OO_ROOT="$OO_ROOT" CXX="$CXX" REXX_BIN="$REXX_BIN" "$ROOT/native/build.sh" "$ROOT/native/fixtures/routine_control.cls" "$OUT" rx2cpp_ctrl
"$REXX_BIN" "$ROOT/native/fixtures/routine_control_client.rex" > "$OUT/native.out"
cmp "$OUT/oracle.out" "$OUT/native.out"
echo "PASS $CXX hybrid IF/ELSE and DO WHILE (native class + routine)"
# Unsupported bare DO and missing END must reject without overwriting the last good library.
prior=$(sha256sum "$OUT/librx2cpp_ctrl.so" | cut -d' ' -f1)
for kind in bare_do missing_end; do
  case "$kind" in
    bare_do) body=$'  do 2\n    a = a + 1\n  end\n  return a';;
    missing_end) body=$'  do while a > 0\n    a = a - 1\n  return a';;
  esac
  printf '%s\n%s\n' $'::class ControlHost public\n::method init\n  return\n::routine RX_CONTROL public\n  use arg a' "$body" > "$OUT/reject_$kind.cls"
  if OO_ROOT="$OO_ROOT" CXX="$CXX" REXX_BIN="$REXX_BIN" "$ROOT/native/build.sh" "$OUT/reject_$kind.cls" "$OUT" rx2cpp_ctrl >"$OUT/reject_$kind.log" 2>&1; then
    echo "FAIL accepted $kind" >&2; exit 1
  fi
  [[ $(sha256sum "$OUT/librx2cpp_ctrl.so" | cut -d' ' -f1) == "$prior" ]] || { echo "FAIL rollback for $kind" >&2; exit 1; }
  echo "PASS $CXX reject $kind without publishing"
done
