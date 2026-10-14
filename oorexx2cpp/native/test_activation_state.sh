#!/usr/bin/env bash
# RANDOM seeds and the stream table per activation in a compiled library, as interpreted.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
export REXX_PATH="$OUT:$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
F="$ROOT/native/fixtures"
cp "$F/activation_state.cls" "$OUT/"
{ cat "$F/activation_state_client.rex"; printf '\n::requires "activation_state.cls"\n'; } > "$OUT/interpreted.rex"
{ cat "$F/activation_state_client.rex"; printf '\n::requires "rxactst" library\n'; } > "$OUT/compiled.rex"
(cd "$OUT" && "$REXX_BIN" interpreted.rex > expected.txt 2>&1; rm -f activation_state.txt activation_state.txt.out)
"$ROOT/native/build.sh" "$OUT/activation_state.cls" "$OUT" rxactst > "$OUT/build.log" 2>&1 || { echo "FAIL build"; tail -30 "$OUT/build.log"; exit 1; }
(cd "$OUT" && "$REXX_BIN" compiled.rex > actual.txt 2>&1) || true
diff -u "$OUT/expected.txt" "$OUT/actual.txt" || { echo "FAIL output differs from the interpreter"; exit 1; }
echo "PASS activation state: $(wc -l < "$OUT/expected.txt") lines identical to the interpreter"
