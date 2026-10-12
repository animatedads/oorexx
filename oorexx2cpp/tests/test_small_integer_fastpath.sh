#!/usr/bin/env bash
# Small-integer arithmetic fast path under NUMERIC DIGITS 3/5/9/12 and FUZZ: compiled output equals the interpreter.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}; REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
F="$ROOT/tests/fixtures/small_integer_digits.rex"
"$REXX_BIN" "$F" > "$T/ref.out"
"$ROOT/build.sh" "$F" "$T/p.bin" >/dev/null 2>&1
"$T/p.bin" > "$T/nat.out"
cmp "$T/ref.out" "$T/nat.out" || { echo "FAIL small integer fast path"; diff "$T/ref.out" "$T/nat.out"; exit 1; }
echo "PASS small-integer fast path: DIGITS 3/5/9/12, rounding boundaries and FUZZ identical to the interpreter"
