#!/usr/bin/env bash
# Interpreter/native differential: live object identity survives ABI entry,
# return, interpreted callbacks, nested re-entry, omitted args, and replacement.
# Does not claim to validate GC roots across interpreter shutdown or all objects.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
CXX=${CXX:-g++}
[[ -x "$REXX_BIN" ]] || { echo "Missing ooRexx executable: $REXX_BIN" >&2; exit 2; }
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
export REXX_PATH="$OUT:$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cp "$ROOT/native/fixtures/object_boundary.cls" "$OUT/object_boundary.cls"
cp "$ROOT/native/fixtures/object_boundary_client.rex" "$OUT/client.rex"
{
  cat "$OUT/client.rex"
  printf '\n::requires "object_boundary.cls"\n'
} > "$OUT/interpreted.rex"
{
  cat "$OUT/client.rex"
  printf '\n::requires "rxboundary" library\n'
} > "$OUT/compiled.rex"
(
  cd "$OUT"
  "$REXX_BIN" interpreted.rex > expected.txt
)
# Pin independently checked ooRexx semantics; a wrong test fixture must not
# make two equally wrong implementations appear to agree.
cmp "$ROOT/native/fixtures/object_boundary_expected.txt" "$OUT/expected.txt"
if ! CXX="$CXX" "$ROOT/native/build.sh" "$OUT/object_boundary.cls" "$OUT" rxboundary > "$OUT/build.log" 2>&1; then
  echo "FAIL $CXX compiling native object identity fixture" >&2
  tail -n 45 "$OUT/build.log" >&2
  exit 1
fi
(
  cd "$OUT"
  "$REXX_BIN" compiled.rex > actual.txt
)
if ! cmp "$OUT/expected.txt" "$OUT/actual.txt"; then
  echo "FAIL $CXX native object ABI differs from the interpreter" >&2
  diff -u "$OUT/expected.txt" "$OUT/actual.txt" >&2 || true
  exit 1
fi
echo "PASS $CXX object identity, returned object, missing-vs-NIL, interpreted callbacks, 2400 replacement/return checks"
