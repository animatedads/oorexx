#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
: "${RX2CPP_BASE:?checked compiler path required}"
: "${OO_ROOT:?ooRexx installation required}"
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
export RX2CPP_BIF_ROOT="$root"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
work=${BUILD_DIR:-$(mktemp -d)}
mkdir -p "$work"
"$REXX_BIN" "$here/sign_compiled.rex" > "$work/sign_oracle.txt"
for cc in ${CXX_LIST:-g++ clang++}; do
    CXX="$cc" "$RX2CPP_BASE/build.sh" "$here/sign_compiled.rex" "$work/sign_${cc//+/x}" "$work/sign_${cc//+/x}.cpp"
    grep -q 'dispatchBif' "$work/sign_${cc//+/x}.cpp"
    "$work/sign_${cc//+/x}" > "$work/sign_${cc//+/x}.txt"
    diff -u "$work/sign_oracle.txt" "$work/sign_${cc//+/x}.txt"
    printf '%s compiled SIGN route PASS (%s lines)\n' "$cc" "$(wc -l < "$work/sign_oracle.txt")"
done
