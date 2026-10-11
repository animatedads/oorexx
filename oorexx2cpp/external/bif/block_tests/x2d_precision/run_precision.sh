#!/usr/bin/env bash
# Run only from a checked live-repository Git worktree; never an old ZIP snapshot.
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BIF=$(cd -- "$HERE/../.." && pwd)
: "${RX2CPP_BASE:?set RX2CPP_BASE to current GitHub main oorexx2cpp worktree}"
: "${OO_ROOT:?set OO_ROOT to ooRexx interpreter installation root}"
HEAD=$(git -C "$RX2CPP_BASE" rev-parse HEAD)
printf 'X2D precision differential against checked Git commit: %s\n' "$HEAD"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
OUT=${BUILD_DIR:-$(mktemp -d)}
mkdir -p "$OUT"
if [[ -z "${BUILD_DIR:-}" ]]; then trap 'rm -rf -- "$OUT"' EXIT; fi
python3 "$HERE/gen_precision.py" "$OUT/cases.txt"
[[ $(wc -l < "$OUT/cases.txt") -eq 8982 ]] || { echo 'X2D fixture count changed' >&2; exit 1; }
for D in 1 3 9 34 64; do
    RX2CPP_X2D_CORPUS="$OUT/cases.txt" RX2CPP_X2D_DIGITS="$D" \
      "${REXX_BIN:-$OO_ROOT/bin/rexx}" "$HERE/oracle_precision.rex" > "$OUT/oracle_$D.txt"
done
for CXX in ${CXX_LIST:-g++ clang++}; do
    S=${CXX//+/x}
    "$CXX" -std=c++17 -O2 -Wall -Wextra -Werror \
        -I"$BIF/native" "$HERE/native_precision.cpp" -o "$OUT/native_$S"
    for D in 1 3 9 34 64; do
        "$OUT/native_$S" "$D" < "$OUT/cases.txt" > "$OUT/native_${S}_${D}.txt"
        python3 "$HERE/compare_precision.py" "$OUT/oracle_$D.txt" "$OUT/native_${S}_${D}.txt"
    done
    echo "PASS $CXX X2D five NUMERIC DIGITS settings"
done
