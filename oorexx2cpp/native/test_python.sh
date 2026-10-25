#!/usr/bin/env bash
# oorexxpython (ooRexx/Python bridge) from compiled code, and Python calling back into compiled code: the demo
# interpreted and compiled, outputs identical.
#   ORXPY_BUILD: the bridge's build directory (oorexx.abi3.so, librexxpython.so, python.cls); unset: SKIP.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ -z "${ORXPY_BUILD:-}" ]] && { echo "SKIP python: ORXPY_BUILD not set"; exit 0; }
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
B=$(cd "$ORXPY_BUILD" && pwd)
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
export REXX_PATH="$OUT:$B:$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$B:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export ORX_PYTHON=${ORX_PYTHON:-$(command -v python3)}
F="$ROOT/native/fixtures"
cp "$F/py_demo.cls" "$OUT/"
{ cat "$F/py_demo_client.rex"; printf '\n::requires "py_demo.cls"\n'; } > "$OUT/interpreted.rex"
{ cat "$F/py_demo_client.rex"; printf '\n::requires "rxpydemo" library\n'; } > "$OUT/compiled.rex"
(cd "$OUT" && "$REXX_BIN" interpreted.rex > expected.txt 2>&1) ||
  { rc=$?; echo "FAIL the interpreted run itself failed (rc=$rc), so oorexxpython does not work here:"; cat "$OUT/expected.txt"; exit 1; }
RX2CPP_KEEP_INTERPRETED="python.cls" "$ROOT/native/build.sh" "$OUT/py_demo.cls" "$OUT" rxpydemo > "$OUT/build.log" 2>&1 || { echo "FAIL build"; tail -30 "$OUT/build.log"; exit 1; }
(cd "$OUT" && "$REXX_BIN" compiled.rex > actual.txt 2>&1) || true
if [[ -n "${PY_SHOW:-}" ]]; then cat "$OUT/actual.txt"; fi
diff -u "$OUT/expected.txt" "$OUT/actual.txt" || { echo "FAIL output differs from the interpreter"; exit 1; }
echo "PASS python: $(wc -l < "$OUT/expected.txt") lines identical to the interpreter (Python via oorexxpython, and back)"
