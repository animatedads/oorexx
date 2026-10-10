#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HERE="$ROOT/block_tests/syssleep"
: "${RX2CPP_BASE:?set RX2CPP_BASE to a checked GitHub main oorexx2cpp tree}"
: "${OO_ROOT:?set OO_ROOT to the ooRexx installation with bin/rexx}"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
OUT=${BUILD_DIR:-$(mktemp -d)}
mkdir -p "$OUT"
python3 "$HERE/gen.py" "$OUT/cases.hex"
"${REXX_BIN:-$OO_ROOT/bin/rexx}" "$HERE/oracle.rex" "$OUT/cases.hex" > "$OUT/oracle.txt"
for CXX in ${CXX_LIST:-g++ clang++}; do
    SUFFIX=${CXX//+/x}
    "$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -pthread \
        -I"$RX2CPP_BASE/include" -I"$ROOT/native" "$HERE/test.cpp" -o "$OUT/test_$SUFFIX"
    "$OUT/test_$SUFFIX"
    "$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -pthread \
        -I"$RX2CPP_BASE/include" -I"$ROOT/native" "$HERE/differential.cpp" -o "$OUT/differential_$SUFFIX"
    "$OUT/differential_$SUFFIX" "$OUT/cases.hex" > "$OUT/native_$SUFFIX.txt"
    diff -u "$OUT/oracle.txt" "$OUT/native_$SUFFIX.txt"
    printf 'SYSSLEEP %s: %s/%s oracle comparisons PASS\n' "$CXX" \
       "$(wc -l < "$OUT/native_$SUFFIX.txt")" "$(wc -l < "$OUT/oracle.txt")"
done

# A sleeping Rexx activity/thread must NOT suspend the process or other objects.
for CXX in ${CXX_LIST:-g++ clang++}; do
    SUFFIX=${CXX//+/x}
    "$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -pthread \
        -I"$RX2CPP_BASE/include" -I"$ROOT/native" \
        "$HERE/thread_native.cpp" -o "$OUT/thread_$SUFFIX"
    "$OUT/thread_$SUFFIX"
done
"${REXX_BIN:-$OO_ROOT/bin/rexx}" "$HERE/thread_oracle.rex"
