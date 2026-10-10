#!/usr/bin/env bash
# Differential ::ATTRIBUTE GET/SET and ::CONSTANT test against live ooRexx.
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
"$ROOT/native/build.sh" "$ROOT/native/fixtures/attribute_modes_constant.cls" "$OUT" rx2cpp_attrmodeconstant
"$REXX_BIN" "$ROOT/native/fixtures/attribute_modes_constant_oracle.rex" >"$OUT/reference.out"
"$REXX_BIN" "$ROOT/native/fixtures/attribute_modes_constant_client.rex" >"$OUT/native.out"
cmp "$OUT/reference.out" "$OUT/native.out"
grep -Fx 'methods 1 1 1 0 0 1' "$OUT/native.out" >/dev/null
# Syntax failures must not replace the good compiled library.
valid=$(sha256sum "$OUT/librx2cpp_attrmodeconstant.so")
for testcase in \
 '::attribute item GET SET' \
 '::attribute item SET GET' \
 "::constant item (1 + 2)" \
 "::attribute item; ::constant item 'duplicate'" \
 "::constant item 'duplicate'; ::method item"; do
  src="$OUT/reject.cls"
  printf '::class Widget public\n::method init\n%s\n' "$(printf '%s' "$testcase" | sed 's/; /\n/g')" >"$src"
  if "$ROOT/native/build.sh" "$src" "$OUT" rx2cpp_attrmodeconstant >"$OUT/reject.log" 2>&1; then
    echo "FAIL: accepted unsupported/duplicate directive: $testcase" >&2; exit 1
  fi
  [[ "$valid" == "$(sha256sum "$OUT/librx2cpp_attrmodeconstant.so")" ]] || {
    echo 'FAIL: negative compilation overwrote valid native library' >&2; exit 1;
  }
done
echo "PASS $CXX ::ATTRIBUTE GET/SET ::CONSTANT class+instance: exact interpreter parity; 5 protected rejections"
