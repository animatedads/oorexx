#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
bif=$(cd "$here/../.." && pwd)
: "${RX2CPP_BASE:?compiler source required}"
: "${OO_ROOT:?ooRexx installation required}"
rexx=${REXX_BIN:-$OO_ROOT/bin/rexx}
export PATH="$OO_ROOT/bin:$PATH"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
work=${BUILD_DIR:-$(mktemp -d)}
mkdir -p "$work"
python3 "$here/gen.py" "$work/cases.txt"
for cc in ${CXX_LIST:-g++ clang++}; do
  "$cc" -std=c++17 -O2 -Wall -Wextra -Werror -I"$RX2CPP_BASE/include" -I"$bif/native" \
    "$here/trunc_native.cpp" "$bif/native/rxbif.cpp" "$bif/native/rxbif_breadth.cpp" -o "$work/trunc_${cc//+/x}"
  "$cc" -std=c++17 -O2 -Wall -Wextra -Werror -I"$RX2CPP_BASE/include" -I"$bif/native" \
    "$here/trunc_boundary.cpp" "$bif/native/rxbif.cpp" "$bif/native/rxbif_breadth.cpp" -o "$work/boundary_${cc//+/x}"
  "$work/boundary_${cc//+/x}"
  for digits in 1 6 9 34; do
    "$rexx" "$here/trunc_oracle.rex" "$work/cases.txt" "$digits" > "$work/oracle_$digits"
    "$work/trunc_${cc//+/x}" "$work/cases.txt" "$digits" > "$work/result_$digits" 2> "$work/reads_$digits"
    diff -u "$work/oracle_$digits" "$work/result_$digits"
    printf 'TRUNC %s digits %s: %s/%s PASS\n' "$cc" "$digits" "$(wc -l < "$work/result_$digits")" "$(wc -l < "$work/oracle_$digits")"
  done
done
