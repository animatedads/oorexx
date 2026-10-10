#!/usr/bin/env bash
# Qualify PROCEDURE isolation and live EXPOSE aliases against real ooRexx.
set -euo pipefail
# Legacy standalone qualification links only the original runtime.
# Exercise external BIF integration separately in test_bif_dynamic_v028.sh.
export RX2CPP_BIF_DISABLED=1
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/procedures-$(basename "$CXX")"}
mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
passes=0
for source in "$ROOT"/examples/procedures_v027/*.rex; do
  name=$(basename "$source" .rex)
  "$REXX_BIN" "$source" >"$WORK/$name.oracle"
  "$ROOT/run-compiler.sh" "$source" "$WORK/$name.cpp"
  "$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$ROOT/include" "$WORK/$name.cpp" -o "$WORK/$name.native"
  "$WORK/$name.native" >"$WORK/$name.nativeout"
  cmp "$WORK/$name.oracle" "$WORK/$name.nativeout"
  echo "PASS activation parity $name"
  passes=$((passes+1))
done
reject() {
  local name=$1 contents=$2
  local output="$WORK/reject_$name.cpp"
  printf '%s\n' '// must not overwrite existing output' > "$output"
  printf '%s\n' "$contents" > "$WORK/reject_$name.rex"
  if "$ROOT/run-compiler.sh" "$WORK/reject_$name.rex" "$output" >"$WORK/reject_$name.stderr" 2>&1; then
    echo "FAIL accepted $name" >&2; exit 1
  fi
  grep -qx '// must not overwrite existing output' "$output" || { echo "FAIL overwrote $name" >&2; exit 1; }
  grep -q 'rx2cpp:' "$WORK/reject_$name.stderr" || { echo "FAIL missing diagnostic $name" >&2; exit 1; }
  echo "PASS reject $name"
}
reject entry_procedure $'procedure\nsay 1\nexit'
reject late_procedure $'call r\nexit\nr:\n say 2\n procedure\n return 3'
reject duplicate_procedure $'call r\nexit\nr:\n procedure\n procedure\n return 2'
reject missing_expose $'call r\nexit\nr:\n procedure expose\n return 2'
reject compound_dynamic $'call r\nexit\nr:\n procedure expose a.i\n return 2'
reject expose_comma $'call r\nexit\nr:\n procedure expose a, b\n return 2'
echo "PROCEDURES: $passes native/interpreter parity fixtures, 6 fail-closed rejections; CXX=$CXX"
