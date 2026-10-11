#!/usr/bin/env bash
# Interpreter/native parity for the ooRexx indexed setter two-scalar-argument ABI.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OO_LIB=${OO_LIB:-$OO_ROOT/lib}
CXX=${CXX:-g++}
OUT=${PACKAGE_TEST_DIR:-$(mktemp -d)}
mkdir -p "$OUT"
export REXX_PATH="$ROOT:$ROOT/native/fixtures:$OO_ROOT/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$ROOT/native/build.sh" "$ROOT/native/fixtures/index_setter.cls" "$OUT" rx2cpp_objindex_setter
"$REXX_BIN" "$ROOT/native/fixtures/index_setter_oracle.rex" > "$OUT/index.reference.out"
"$REXX_BIN" "$ROOT/native/fixtures/index_setter_client.rex" > "$OUT/index.native.out"
cmp "$OUT/index.reference.out" "$OUT/index.native.out"
grep -Fx 'after 7 12 19 21' "$OUT/index.native.out" >/dev/null
grep -Fx 'different 4 20 24 12' "$OUT/index.native.out" >/dev/null
grep -Fx 'two 809' "$OUT/index.native.out" >/dev/null
grep -Fx 'child 6 14 20 20' "$OUT/index.native.out" >/dev/null
grep -Fx 'isolated 33 20' "$OUT/index.native.out" >/dev/null
accepted=$(sha256sum "$OUT/librx2cpp_objindex_setter.so")
for testcase in 'use arg x, ' 'use arg x, x'; do
  { printf '%s\n' '::class BadCell public' '::method init' '::method "[]="'; printf '  %s\n' "$testcase"; printf '%s\n' '  return x'; } > "$OUT/rejected.cls"
  if "$ROOT/native/build.sh" "$OUT/rejected.cls" "$OUT" rx2cpp_objindex_setter > "$OUT/rejected.log" 2>&1; then
    echo "FAIL unsupported USE ARG accepted: $testcase" >&2; exit 1
  fi
  [[ "$accepted" == "$(sha256sum "$OUT/librx2cpp_objindex_setter.so")" ]] || { echo 'FAIL publication rollback' >&2; exit 1; }
done
echo "PASS $CXX scalar []=/[] two-argument interpreter parity and 3 fail-closed cases"
