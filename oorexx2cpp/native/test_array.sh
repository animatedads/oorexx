#!/usr/bin/env bash
# Native .ARRAY in a compiled library: same output as the interpreter (append chains, conversion on
# unhandled messages, identity once the interpreter holds the array, DO OVER, errors).
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
export REXX_PATH="$OUT:$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
F="$ROOT/native/fixtures"
cp "$F/array.cls" "$OUT/"
{ cat "$F/array_client.rex"; printf '\n::requires "array.cls"\n'; } > "$OUT/interpreted.rex"
{ cat "$F/array_client.rex"; printf '\n::requires "rxarray" library\n'; } > "$OUT/compiled.rex"
(cd "$OUT" && "$REXX_BIN" interpreted.rex > expected.txt 2>&1)
"$ROOT/native/build.sh" "$OUT/array.cls" "$OUT" rxarray > "$OUT/build.log" 2>&1 || { echo "FAIL build"; tail -30 "$OUT/build.log"; exit 1; }
grep -q 'nativeArrayClass' "$OUT/generated.cpp" || { echo "FAIL .ARRAY is not native"; exit 1; }
(cd "$OUT" && "$REXX_BIN" compiled.rex > actual.txt 2>&1) || true
diff -u "$OUT/expected.txt" "$OUT/actual.txt" || { echo "FAIL output differs from the interpreter"; exit 1; }
echo "PASS native Array: $(wc -l < "$OUT/expected.txt") lines identical to the interpreter"
