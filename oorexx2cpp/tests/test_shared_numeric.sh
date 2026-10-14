#!/usr/bin/env bash
# A language rule must have the same grammar and NUMERIC activation semantics
# for standalone programs and compiled package methods. No copied interpreter
# outputs: every expected result is evaluated by ooRexx in this run.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-"$OO_ROOT/bin/rexx"}
CXX=${CXX:-g++}
FIX="$ROOT/tests/fixtures/numeric_shared"
OUT=${TEST_OUTPUT_DIR:-$(mktemp -d)}
mkdir -p "$OUT"
export REXX_PATH="$ROOT:$FIX${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$REXX_BIN" "$ROOT/tests/test_shared_numeric.rex"
"$REXX_BIN" "$FIX/standalone.rex" > "$OUT/standalone.reference"
RX2CPP_BIF_DISABLED=1 CXX="$CXX" "$ROOT/build.sh" "$FIX/standalone.rex" "$OUT/numeric-standalone" "$OUT/standalone.cpp"
"$OUT/numeric-standalone" > "$OUT/standalone.native"
cmp "$OUT/standalone.reference" "$OUT/standalone.native"
"$REXX_BIN" "$FIX/native_reference.rex" > "$OUT/method.reference"
CXX="$CXX" "$ROOT/native/build.sh" "$FIX/native.cls" "$OUT" rxnumericshared
"$REXX_BIN" "$FIX/native_client.rex" > "$OUT/method.native"
cmp "$OUT/method.reference" "$OUT/method.native"
sha=$(sha256sum "$OUT/librxnumericshared.so" | cut -d' ' -f1)
printf '%s\n' '::class Numerics public' '::method init' '::method compute' '  numeric form VALUE' '  return 1' > "$OUT/invalid.cls"   # no expression after VALUE: 35.917 when interpreted
if CXX="$CXX" "$ROOT/native/build.sh" "$OUT/invalid.cls" "$OUT" rxnumericshared >"$OUT/rejected.log" 2>&1; then
  echo 'FAIL accepted invalid NUMERIC FORM expression'; exit 1
fi
[[ $sha == "$(sha256sum "$OUT/librxnumericshared.so" | cut -d' ' -f1)" ]] || {
  echo 'FAIL rejected input replaced the good native library'; exit 1;
}
echo "PASS $CXX shared NUMERIC parser, statement registry, standalone/native parity and rollback"
