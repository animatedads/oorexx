#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BIF=$(cd -- "$HERE/../.." && pwd)
: "${RX2CPP_BASE:?set RX2CPP_BASE to the checked GitHub oorexx2cpp tree}"
: "${OO_ROOT:?set OO_ROOT to the ooRexx interpreter installation}"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=${BUILD_DIR:-$(mktemp -d)}
mkdir -p "$OUT"
python3 "$HERE/gen.py" "$OUT/cases.tsv"
"$REXX_BIN" "$HERE/oracle.rex" "$OUT/cases.tsv" > "$OUT/oracle.out"
for cc in ${CXX_LIST:-g++ clang++}; do
  tag=${cc//+/x}
  "$cc" -std=c++17 -O2 -Wall -Wextra -Werror \
    -I"$BIF/native" "$HERE/native.cpp" -o "$OUT/x2d_native_$tag"
  "$OUT/x2d_native_$tag" "$OUT/cases.tsv" > "$OUT/native_$tag.out"
  cmp "$OUT/oracle.out" "$OUT/native_$tag.out"
  echo "X2D $cc oracle $(wc -l < "$OUT/oracle.out")/$(wc -l < "$OUT/native_$tag.out") PASS"
  "$cc" -std=c++17 -O2 -Wall -Wextra -Werror \
    -I"$RX2CPP_BASE/include" -I"$BIF/native" \
    "$HERE/route_test.cpp" "$BIF/native/rxbif_breadth.cpp" "$BIF/native/rxbif.cpp" \
    -o "$OUT/x2d_route_$tag"
  "$OUT/x2d_route_$tag"
done
