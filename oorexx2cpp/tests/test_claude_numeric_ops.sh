#!/usr/bin/env bash
# // (remainder) and ** (power): hand-written edge cases plus 250 random differential cases (seeded), exact parity.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}; CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/claude-numeric-ops-$(basename "$CXX")"}; rm -rf "$WORK"; mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
for f in numeric_ops_hand numeric_ops_random; do
  "$REXX_BIN" "$ROOT/examples/claude/$f.rex" >"$WORK/$f.exp"
  "$ROOT/build.sh" "$ROOT/examples/claude/$f.rex" "$WORK/$f.bin" "$WORK/$f.cpp" >/dev/null
  "$WORK/$f.bin" >"$WORK/$f.act"
  cmp "$WORK/$f.exp" "$WORK/$f.act" || { diff -u "$WORK/$f.exp" "$WORK/$f.act" | head -20; exit 1; }
  echo "PASS $f ($(wc -l <"$WORK/$f.exp") lines identical)"
done
