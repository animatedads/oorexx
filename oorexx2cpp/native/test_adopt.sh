#!/usr/bin/env bash
# Compiled instances handed back by the interpreter (class-method results, arrays, arguments) keep interpreter
# behaviour and identity, and their compiled methods run directly (no interpreter send for them).
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
export REXX_PATH="$OUT:$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
F="$ROOT/native/fixtures"
cp "$F/adopt.cls" "$OUT/"
{ cat "$F/adopt_client.rex"; printf '\n::requires "adopt.cls"\n'; } > "$OUT/interpreted.rex"
{ cat "$F/adopt_client.rex"; printf '\n::requires "rxadopt" library\n'; } > "$OUT/compiled.rex"
(cd "$OUT" && "$REXX_BIN" interpreted.rex > expected.txt 2>&1)
"$ROOT/native/build.sh" "$OUT/adopt.cls" "$OUT" rxadopt > "$OUT/build.log" 2>&1 || { echo "FAIL build"; tail -30 "$OUT/build.log"; exit 1; }
(cd "$OUT" && RX2CPP_BIF_STATS=1 "$REXX_BIN" compiled.rex > actual.txt 2> stats.txt) || true
diff -u "$OUT/expected.txt" "$OUT/actual.txt" || { echo "FAIL output differs from the interpreter"; cat "$OUT/stats.txt"; exit 1; }
if grep -E '~(X|Y) to The POINT class' "$OUT/stats.txt"; then echo "FAIL compiled Point methods went through the interpreter"; exit 1; fi
echo "PASS adoption: $(wc -l < "$OUT/expected.txt") lines identical; compiled Point methods run directly"
