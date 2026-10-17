#!/usr/bin/env bash
# Native registers (whole-number variables as machine integers): output identical to the interpreter.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
export LD_LIBRARY_PATH="$OUT/bin:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
mkdir -p "$OUT/src"
cp "$ROOT/native/fixtures/native_registers.rex" "$OUT/src/"
rc=0; (cd "$OUT/src" && "$REXX_BIN" native_registers.rex) > "$OUT/expected.txt" 2>&1 || rc=$?
echo "rc=$rc" >> "$OUT/expected.txt"
"$ROOT/native/compile_program.sh" "$OUT/src/native_registers.rex" "$OUT/bin" > "$OUT/build.log" 2>&1 || { echo "FAIL build"; tail -30 "$OUT/build.log"; exit 1; }
rc=0; (cd "$OUT/src" && REXX_PATH="$OUT/bin" "$REXX_BIN" "$OUT/bin/native_registers.rex") > "$OUT/actual.txt" 2>&1 || rc=$?
echo "rc=$rc" >> "$OUT/actual.txt"
diff -u "$OUT/expected.txt" "$OUT/actual.txt" || { echo "FAIL output differs from the interpreter"; exit 1; }
echo "PASS native registers: $(wc -l < "$OUT/expected.txt") lines identical to the interpreter (exit status included)"
