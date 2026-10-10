#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BIF=$(cd -- "$HERE/../.." && pwd)
: "${RX2CPP_BASE:?set RX2CPP_BASE to the checked GitHub oorexx2cpp tree}"
: "${OO_ROOT:?set OO_ROOT to the ooRexx interpreter installation}"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_LIB="$OO_ROOT/lib" REXX_BIN="${REXX_BIN:-$OO_ROOT/bin/rexx}"
export RX2CPP_BIF_ROOT="$BIF" RX2CPP_BIF_ISOLATED=0 RX2CPP_HOSTED=0
OUT=${BUILD_DIR:-$(mktemp -d)}
mkdir -p "$OUT"
"$REXX_BIN" "$HERE/compiled.rex" > "$OUT/oracle.out"
for cc in ${CXX_LIST:-g++ clang++}; do
  tag=${cc//+/x}
  CXX="$cc" "$RX2CPP_BASE/build.sh" "$HERE/compiled.rex" "$OUT/compiled_$tag" "$OUT/compiled_$tag.cpp"
  grep -q 'dispatchBif' "$OUT/compiled_$tag.cpp"
  "$OUT/compiled_$tag" > "$OUT/compiled_$tag.out"
  cmp "$OUT/oracle.out" "$OUT/compiled_$tag.out"
  echo "X2D compiled $cc $(wc -l < "$OUT/oracle.out") lines PASS"
done
