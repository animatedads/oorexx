#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OO_LIB=${OO_LIB:-$OO_ROOT/lib}
OUT=${NATIVE_OUTPUT_DIR:-$ROOT/build/native-test}
mkdir -p "$OUT"
export LD_LIBRARY_PATH="$OO_LIB:$OUT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT:$OO_ROOT/bin${REXX_PATH:+:$REXX_PATH}"
"$ROOT/native/build.sh" "$ROOT/hybrid/accumulator.cls" "$OUT" rx2cpp_accumulator
"$REXX_BIN" "$ROOT/native/accumulator_reference.rex" >"$OUT/reference.stdout"
"$REXX_BIN" "$ROOT/native/accumulator_client.rex" >"$OUT/native.stdout"
cmp "$OUT/reference.stdout" "$OUT/native.stdout"
[[ $(wc -l <"$OUT/native.stdout") -eq 7 ]]
printf 'PASS native .so ::requires class parity (including object identity, binary-safe method and 2 instances)\n'
set +e
"$REXX_BIN" "$ROOT/native/reject_invalid_argument.rex" >"$OUT/invalid.stdout" 2>"$OUT/invalid.stderr"
invalid_rc=$?
set -e
[[ $invalid_rc -ne 0 ]] || { echo 'FAIL invalid argument was accepted'; exit 1; }
printf 'PASS invalid nonstring object rejected (exit %s)\n' "$invalid_rc"
# No Foreign Runtime, no ooRexx bridge, and no rexx shared library linkage.
! readelf -d "$OUT/librx2cpp_accumulator.so" | grep -E 'NEEDED.*(foreign|alchemy|librexx)' 
printf 'PASS no Foreign Runtime or interpreter dynamic-link dependency\n'
# The current compiler may not invent a crypto implementation. It must reject
# the actual high-precision, multi-class source rather than publish bad code.
if [[ -n "${CRYPTO_CLS:-}" && -f "${CRYPTO_CLS:-}" ]]; then
   set +e
   "$ROOT/native/build.sh" "$CRYPTO_CLS" "$OUT/crypto-rejected" rx2cpp_crypto >"$OUT/crypto.compiler.log" 2>&1
   crypto_rc=$?
   set -e
   [[ $crypto_rc -ne 0 && ! -f "$OUT/crypto-rejected/librx2cpp_crypto.so" ]] || { echo 'FAIL crypto source must reject'; exit 1; }
   printf 'PASS unsupported crypto source rejected without emitting a misleading .so\n'
fi
