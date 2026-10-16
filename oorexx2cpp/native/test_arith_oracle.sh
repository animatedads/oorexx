#!/usr/bin/env bash
# Native decimal arithmetic against the interpreter: random operands (plain, decimal, exponent, trailing zeros, signs) under
# NUMERIC DIGITS 1..40 (and FUZZ), for + - * / % // ** and the comparisons; every result (or error code) must be identical.
#   ARITH_CASES=n (default 20000 per family), ARITH_SEED=s (default 1)
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
N=${ARITH_CASES:-20000}; SEED=${ARITH_SEED:-1}
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
F="$ROOT/native/fixtures/arith_oracle"
for fam in addsub ops small; do
  g++ -std=c++17 -O1 -I"$ROOT/include" "$F/drv_$fam.cpp" -o "$OUT/drv_$fam"
  (cd "$OUT" && "$REXX_BIN" "$F/gen_$fam.rex" "$N" "$SEED")
  "$OUT/drv_$fam" < "$OUT/cases_$fam.txt" > "$OUT/actual_$fam.txt"
  if ! cmp -s "$OUT/expected_$fam.txt" "$OUT/actual_$fam.txt"; then
    echo "FAIL arithmetic ($fam) differs from the interpreter:"
    paste -d'|' "$OUT/cases_$fam.txt" "$OUT/expected_$fam.txt" "$OUT/actual_$fam.txt" | awk -F'|' '$2"" != $3""' | head -10
    exit 1
  fi
done
echo "PASS arithmetic oracle: $((3 * N)) random cases identical to the interpreter (seed $SEED)"
