#!/usr/bin/env bash
# SIGNAL ON / OFF, labels, SIGNAL label, RC, SIGL, CONDITION(), RAISE PROPAGATE in compiled methods: same output
# as the interpreter, including the error numbers and messages raised by compiled arithmetic.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
export REXX_PATH="$OUT:$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
F="$ROOT/native/fixtures"
cp "$F/signal.cls" "$OUT/"
{ cat "$F/signal_client.rex"; printf '\n::requires "signal.cls"\n'; } > "$OUT/interpreted.rex"
{ cat "$F/signal_client.rex"; printf '\n::requires "rxsig" library\n'; } > "$OUT/compiled.rex"
(cd "$OUT" && "$REXX_BIN" interpreted.rex > expected.txt 2>&1)
"$ROOT/native/build.sh" "$OUT/signal.cls" "$OUT" rxsig > "$OUT/build.log" 2>&1 || { echo "FAIL build"; tail -30 "$OUT/build.log"; exit 1; }

(cd "$OUT" && "$REXX_BIN" compiled.rex > actual.txt 2>&1) || true
diff -u "$OUT/expected.txt" "$OUT/actual.txt" || { echo "FAIL output differs from the interpreter"; exit 1; }
echo "PASS SIGNAL ON in compiled methods: $(wc -l < "$OUT/expected.txt") lines identical to the interpreter"
