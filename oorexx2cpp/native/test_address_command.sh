#!/usr/bin/env bash
# ADDRESS environment command in a compiled library: the interpreter runs the command; same output, same RC,
# ADDRESS() and a variable named ADDRESS as interpreted.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
export REXX_PATH="$OUT:$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
F="$ROOT/native/fixtures"
cp "$F/address_command.cls" "$OUT/"
{ cat "$F/address_command_client.rex"; printf '\n::requires "address_command.cls"\n'; } > "$OUT/interpreted.rex"
{ cat "$F/address_command_client.rex"; printf '\n::requires "rxaddr" library\n'; } > "$OUT/compiled.rex"
(cd "$OUT" && "$REXX_BIN" interpreted.rex > expected.txt 2>&1)
"$ROOT/native/build.sh" "$OUT/address_command.cls" "$OUT" rxaddr > "$OUT/build.log" 2>&1 || { echo "FAIL build"; tail -30 "$OUT/build.log"; exit 1; }
grep -q 'interpreterCommand' "$OUT/generated.cpp" || { echo "FAIL ADDRESS command is not compiled"; exit 1; }
(cd "$OUT" && "$REXX_BIN" compiled.rex > actual.txt 2>&1) || true
diff -u "$OUT/expected.txt" "$OUT/actual.txt" || { echo "FAIL output differs from the interpreter"; exit 1; }
echo "PASS ADDRESS command: $(wc -l < "$OUT/expected.txt") lines identical to the interpreter"
