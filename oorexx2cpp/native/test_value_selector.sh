#!/usr/bin/env bash
# VALUE(name, [new], selector) in a compiled library: the interpreter's own VALUE, same output and errors.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
export REXX_PATH="$OUT:$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
F="$ROOT/native/fixtures"
cp "$F/value_selector.cls" "$OUT/"
{ cat "$F/value_selector_client.rex"; printf '\n::requires "value_selector.cls"\n'; } > "$OUT/interpreted.rex"
{ cat "$F/value_selector_client.rex"; printf '\n::requires "rxvalsel" library\n'; } > "$OUT/compiled.rex"
(cd "$OUT" && "$REXX_BIN" interpreted.rex > expected.txt 2>&1)
"$ROOT/native/build.sh" "$OUT/value_selector.cls" "$OUT" rxvalsel > "$OUT/build.log" 2>&1 || { echo "FAIL build"; tail -30 "$OUT/build.log"; exit 1; }
(cd "$OUT" && "$REXX_BIN" compiled.rex > actual.txt 2>&1) || true
diff -u "$OUT/expected.txt" "$OUT/actual.txt" || { echo "FAIL output differs from the interpreter"; exit 1; }
echo "PASS VALUE with selector: $(wc -l < "$OUT/expected.txt") lines identical to the interpreter"
