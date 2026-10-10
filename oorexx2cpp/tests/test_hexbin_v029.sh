#!/usr/bin/env bash
# Claude's hex/binary literal discovery, selectively rebased on decimal lexer.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
export RX2CPP_BIF_ROOT="${RX2CPP_BIF_ROOT:-$ROOT/external/bif}"
unset RX2CPP_BIF_DISABLED
work=${TEST_OUTPUT_DIR:-"$ROOT/build/hexbin-$(basename "$CXX")"}
mkdir -p "$work"
bif=$RX2CPP_BIF_ROOT
for name in hexbin_literals hexbin_focus hexbin_raw; do
  src=$ROOT/examples/$name.rex
  "$REXX_BIN" "$src" > "$work/$name.oracle"
  "$ROOT/run-compiler.sh" "$src" "$work/$name.cpp"
  "$CXX" -std=c++17 -O0 -Wall -Wextra -Werror -I"$ROOT/include" -I"$bif/native" -I"$bif/variables" \
    "$work/$name.cpp" "$bif/native/rxbif.cpp" "$bif/native/rxbif_breadth.cpp" \
    "$bif/variables/rxbif_variables.cpp" -o "$work/$name.native"
  "$work/$name.native" > "$work/$name.actual"
  cmp "$work/$name.oracle" "$work/$name.actual"
  printf 'PASS %s (%s bytes) compiler=%s\n' "$name" "$(wc -c < "$work/$name.actual")" "$CXX"
done
for bad in "$ROOT"/tests/hex_invalid/*.rex; do
  key=$(basename "$bad" .rex)
  if "$REXX_BIN" "$bad" > "$work/$key.oracle" 2> "$work/$key.oracle.err"; then
    echo "FAIL: reference accepted invalid literal $key" >&2; exit 1
  fi
  dest="$work/$key.cpp"
  printf '// existing output protected\n' > "$dest"
  if "$ROOT/run-compiler.sh" "$bad" "$dest" > "$work/$key.compiler.log" 2>&1; then
    echo "FAIL: compiler accepted invalid literal $key" >&2; exit 1
  fi
  test "$(cat "$dest")" = '// existing output protected'
  grep -q 'rx2cpp:' "$work/$key.compiler.log"
  echo "PASS reject $key protected output"
done
printf 'PASS hex/bin (3 differential fixtures and 6 protected rejections) CXX=%s\n' "$CXX"
