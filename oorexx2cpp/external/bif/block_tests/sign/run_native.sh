#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
: "${RX2CPP_BASE:?checked compiler path required}"
: "${OO_ROOT:?ooRexx installation required}"
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
work=${BUILD_DIR:-$(mktemp -d)}
mkdir -p "$work"
python3 "$here/generate_sign_matrix.py" "$work/cases.hex"
for cc in ${CXX_LIST:-g++ clang++}; do
    "$cc" -std=c++17 -O2 -Wall -Wextra -Werror -I"$RX2CPP_BASE/include" -I"$root/native" \
        "$here/sign_native.cpp" "$root/native/rxbif.cpp" "$root/native/rxbif_breadth.cpp" -o "$work/sign_${cc//+/x}"
    "$cc" -std=c++17 -O2 -Wall -Wextra -Werror -I"$RX2CPP_BASE/include" -I"$root/native" \
        "$here/sign_boundary.cpp" "$root/native/rxbif.cpp" "$root/native/rxbif_breadth.cpp" -o "$work/boundary_${cc//+/x}"
    "$work/boundary_${cc//+/x}"
    for digits in 1 9 34; do
        "$REXX_BIN" "$here/sign_oracle.rex" "$work/cases.hex" "$digits" > "$work/oracle_${digits}"
        for mode in direct dispatch; do
            "$work/sign_${cc//+/x}" "$work/cases.hex" "$mode" > "$work/${cc//+/x}_${mode}_${digits}"
            python3 "$here/compare_sign.py" "$work/oracle_${digits}" "$work/${cc//+/x}_${mode}_${digits}"
        done
    done
done
