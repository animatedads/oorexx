#!/usr/bin/env bash
# BSF4ooRexx (Java) from compiled code, and Java calling back into compiled objects (BsfCreateRexxProxy): each demo
# interpreted and compiled, outputs identical.
#   BSF4OOREXX_HOME: an unpacked BSF4ooRexx install zip (the directory holding BSF.CLS); unset: SKIP.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ -z "${BSF4OOREXX_HOME:-}" ]] && { echo "SKIP bsf: BSF4OOREXX_HOME not set"; exit 0; }
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
B=$(cd "$BSF4OOREXX_HOME" && pwd)
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
JH=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
mkdir -p "$OUT/native"
cp "$B/install/lib/libBSF4ooRexx850.so-64-amd64" "$OUT/native/libBSF4ooRexx850.so"
ln -s libBSF4ooRexx850.so "$OUT/native/libBSF4ooRexx.so"
export REXX_PATH="$OUT:$B:$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OUT/native:$JH/lib/server:$JH/lib:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export CLASSPATH=$(ls "$B"/lib/bsf4ooRexx-*-bin.jar | head -1)
F="$ROOT/native/fixtures"
for demo in bsf_demo bsf_callback; do
  lib=rx${demo//_/}
  cp "$F/$demo.cls" "$OUT/"
  { cat "$F/${demo}_client.rex"; printf '\n::requires "%s.cls"\n' $demo; } > "$OUT/i_$demo.rex"
  { cat "$F/${demo}_client.rex"; printf '\n::requires "%s" library\n' $lib; } > "$OUT/c_$demo.rex"
  # (the interpreted run is the oracle: if it fails, BSF4ooRexx or Java is the problem; show what the interpreter said)
  (cd "$OUT" && "$REXX_BIN" i_$demo.rex 2>&1 | grep -v '^Picked up JAVA_TOOL_OPTIONS' > e_$demo.txt) ||
    { rc=$?; echo "FAIL $demo: the interpreted run itself failed (rc=$rc), so BSF4ooRexx or Java does not work here:"; cat "$OUT/e_$demo.txt"; exit 1; }
  RX2CPP_KEEP_INTERPRETED="BSF.CLS" "$ROOT/native/build.sh" "$OUT/$demo.cls" "$OUT" $lib > "$OUT/build.log" 2>&1 || { echo "FAIL build $demo"; tail -30 "$OUT/build.log"; exit 1; }
  (cd "$OUT" && "$REXX_BIN" c_$demo.rex 2>&1 | grep -v '^Picked up JAVA_TOOL_OPTIONS' > a_$demo.txt) || true
  diff -u "$OUT/e_$demo.txt" "$OUT/a_$demo.txt" || { echo "FAIL $demo: output differs from the interpreter"; exit 1; }
  echo "PASS bsf $demo: $(wc -l < "$OUT/e_$demo.txt") lines identical to the interpreter"
  if [[ -n "${BSF_SHOW:-}" ]]; then cat "$OUT/a_$demo.txt"; fi
done
