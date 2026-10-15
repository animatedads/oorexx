#!/usr/bin/env bash
# Standalone grammar qualification only; does not touch native .so or threads.
set -euo pipefail
# Legacy standalone qualification links only the original runtime.
# Exercise external BIF integration separately in test_bif_dynamic_v028.sh.
export RX2CPP_BIF_DISABLED=1
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/do-while-forever-$(basename "$CXX")"}
mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
parity=0
for source in "$ROOT"/examples/loops_v025/*.rex; do
  name=$(basename "$source" .rex)
  "$REXX_BIN" "$source" >"$WORK/$name.oracle"
  "$ROOT/run-compiler.sh" "$source" "$WORK/$name.cpp"
  "$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$ROOT/include" "$WORK/$name.cpp" -o "$WORK/$name.native"
  "$WORK/$name.native" > "$WORK/$name.actual"
  cmp "$WORK/$name.oracle" "$WORK/$name.actual"
  echo "PASS interpreter/native $name"
  parity=$((parity+1))
done
reject() {
  local name=$1 source=$2 target="$WORK/$1.cpp"
  printf '%s\n' '// previous output is protected' > "$target"
  printf '%s\n' "$source" > "$WORK/$name.rex"
  if "$ROOT/run-compiler.sh" "$WORK/$name.rex" "$target" > "$WORK/$name.stderr" 2>&1; then
    echo "FAIL compiler accepted $name" >&2; exit 1
  fi
  grep -qx '// previous output is protected' "$target" || { echo "FAIL output changed on error $name" >&2; exit 1; }
  grep -q 'rx2cpp:' "$WORK/$name.stderr" || { echo "FAIL diagnostic absent $name" >&2; exit 1; }
  echo "PASS fail-closed $name"
}
reject while_missing_expression $'do while\n say 1\nend'
reject while_missing_end $'do while 0\n say 1'
reject while_invalid_end_name $'do while 0\n say 1\nend index'
reject forever_extra_expression $'do forever 1\n say 1\nend'
reject forever_named_end $'do forever\n leave\nend count'
reject forever_missing_end $'do forever\n leave'
echo "DO WHILE/FOREVER: $parity source-level parity fixtures, 6 fail-closed compiler cases; CXX=$CXX"
