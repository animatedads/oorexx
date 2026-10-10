#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
bif=$(cd "$here/../.." && pwd)
: "${RX2CPP_BASE:?compiler source required}"
: "${OO_ROOT:?ooRexx installation required}"
export RX2CPP_BIF_ROOT="$bif" REXX_LIB="$OO_ROOT/lib"
export PATH="$OO_ROOT/bin:$PATH"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
work=${BUILD_DIR:-$(mktemp -d)}
mkdir -p "$work"
"${REXX_BIN:-$OO_ROOT/bin/rexx}" "$here/trunc_compiled.rex" > "$work/oracle.txt"
for cc in ${CXX_LIST:-g++ clang++}; do
  CXX="$cc" "$RX2CPP_BASE/build.sh" "$here/trunc_compiled.rex" "$work/compiled_${cc//+/x}" "$work/compiled_${cc//+/x}.cpp"
  grep -q 'dispatchBif' "$work/compiled_${cc//+/x}.cpp"
  "$work/compiled_${cc//+/x}" > "$work/native_${cc//+/x}.txt"
  diff -u "$work/oracle.txt" "$work/native_${cc//+/x}.txt"
  printf 'Compiled TRUNC %s: %s lines PASS\n' "$cc" "$(wc -l < "$work/oracle.txt")"
done
