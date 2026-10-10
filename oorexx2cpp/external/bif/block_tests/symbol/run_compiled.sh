#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
: "${RX2CPP_BASE:?compiler tree must be supplied}"
: "${REXX_BIN:?ooRexx interpreter binary must be supplied}"
: "${OO_ROOT:?ooRexx installation root must be supplied}"
export RX2CPP_BIF_ROOT="$(cd "$here/../.." && pwd)"
export REXX_LIB="$OO_ROOT/lib"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
build=${BUILD_DIR:-$(mktemp -d)}
mkdir -p "$build"
"$REXX_BIN" "$here/compiled_route.rex" > "$build/compiled_oracle.txt"
for cc in ${CXX_LIST:-g++ clang++}; do
    CXX="$cc" "$RX2CPP_BASE/build.sh" "$here/compiled_route.rex" "$build/compiled_${cc##*/}" "$build/compiled_${cc##*/}.cpp"
    grep -q 'dispatchBif' "$build/compiled_${cc##*/}.cpp"
    "$build/compiled_${cc##*/}" > "$build/compiled_${cc##*/}.txt"
    diff -u "$build/compiled_oracle.txt" "$build/compiled_${cc##*/}.txt"
    printf '%s compiled DATATYPE S/V: %s cases PASS\n' "$cc" "$(wc -l < "$build/compiled_oracle.txt")"
done
