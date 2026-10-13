#!/usr/bin/env bash
# Two compiled libraries loaded in one process keep their own runtime state (hooks, current context, SELF, package):
# GCC would make the runtime's inline variables process-wide unless the libraries are built with -fno-gnu-unique.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
export REXX_PATH="$OUT:$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
F="$ROOT/native/fixtures"
cp "$F/twolib_A.cls" "$F/twolib_B.cls" "$OUT/"
{ cat "$F/twolib_client.rex"; printf '\n::requires "twolib_A.cls"\n::requires "twolib_B.cls"\n'; } > "$OUT/interpreted.rex"
{ cat "$F/twolib_client.rex"; printf '\n::requires "rxtwoa" library\n::requires "rxtwob" library\n'; } > "$OUT/compiled.rex"
(cd "$OUT" && "$REXX_BIN" interpreted.rex > expected.txt 2>&1)
for L in A B; do
  lib=rxtwo$(echo $L | tr AB ab)
  "$ROOT/native/build.sh" "$OUT/twolib_$L.cls" "$OUT" $lib > "$OUT/build_$L.log" 2>&1 || { echo "FAIL build $L"; tail -20 "$OUT/build_$L.log"; exit 1; }
  if command -v nm >/dev/null && nm -D --defined-only "$OUT/lib$lib.so" | awk '$2=="u"' | grep -q .; then
    echo "FAIL lib$lib.so has process-wide (unique) symbols"; exit 1
  fi
done
(cd "$OUT" && "$REXX_BIN" compiled.rex > actual.txt 2>&1) || true
diff -u "$OUT/expected.txt" "$OUT/actual.txt" || { echo "FAIL output differs from the interpreter"; exit 1; }
echo "PASS two compiled libraries in one process: $(wc -l < "$OUT/expected.txt") lines identical, no shared runtime state"
