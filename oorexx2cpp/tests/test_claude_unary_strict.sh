#!/usr/bin/env bash
# Unary \ (logical NOT) and USE STRICT ARG (required/optional, 40.3/40.4 contract): parity with the interpreter.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}; CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/claude-unary-strict-$(basename "$CXX")"}; rm -rf "$WORK"; mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
for f in unary_not use_strict_arg; do
  "$REXX_BIN" "$ROOT/examples/claude/$f.rex" >"$WORK/$f.exp"
  "$ROOT/build.sh" "$ROOT/examples/claude/$f.rex" "$WORK/$f.bin" "$WORK/$f.cpp" >/dev/null
  "$WORK/$f.bin" >"$WORK/$f.act"
  cmp "$WORK/$f.exp" "$WORK/$f.act" || { diff -u "$WORK/$f.exp" "$WORK/$f.act"; exit 1; }
  echo "PASS $f ($(wc -l <"$WORK/$f.exp") lines identical)"
done
# argument-count contract: too many / too few must fail at run time with the interpreter's 40.x code
i=0
for body in "call f 1,2,3|40.4" "call f|40.3"; do
  i=$((i+1)); call=${body%%|*}; code=${body##*|}
  printf '%s\nexit\nf:\nprocedure\nuse strict arg a, b = 7\nreturn\n' "$call" >"$WORK/c$i.rex"
  o=$("$REXX_BIN" "$WORK/c$i.rex" 2>&1 || true); [[ "$o" == *"Error $code"* ]] || { echo "FAIL oracle $code: $call"; exit 1; }
  "$ROOT/build.sh" "$WORK/c$i.rex" "$WORK/c$i.bin" "$WORK/c$i.cpp" >/dev/null
  n=$("$WORK/c$i.bin" 2>&1 || true); [[ "$n" == *"Error $code"* ]] || { echo "FAIL native $code: $call -> $n"; exit 1; }
done
echo "PASS USE STRICT ARG count errors (40.3, 40.4) match"
