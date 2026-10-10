#!/bin/bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
source_dir=$(cd "$here/../.." && pwd)
: "${RX2CPP_BASE:?point to checked compiler source tree}"
: "${REXX_BIN:?point to actual ooRexx binary}"
: "${OO_ROOT:?point to ooRexx installation}"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
build=${BUILD_DIR:-$(mktemp -d)}
mkdir -p "$build"
python3 "$here/generate_symbol_matrix.py" "$build/cases.hex"
for cc in ${CXX_LIST:-g++ clang++}; do
  "${cc}" -std=c++17 -O2 -Wall -Wextra -Werror \
     -I"$RX2CPP_BASE/include" -I"$source_dir/native" \
     "$here/symbol_native_runner.cpp" "$source_dir/native/rxbif_breadth.cpp" \
     "$source_dir/native/rxbif.cpp" -o "$build/symbol_${cc##*/}"
  for option in S V; do
    "$REXX_BIN" "$here/symbol_oracle.rex" "$build/cases.hex" "$option" > "$build/oracle_${option}"
    "$build/symbol_${cc##*/}" "$build/cases.hex" "$option" > "$build/native_${option}"
    diff -u "$build/oracle_${option}" "$build/native_${option}"
    printf '%s DATATYPE %s: %s cases PASS\n' "$cc" "$option" "$(wc -l < "$build/cases.hex")"
  done
done
