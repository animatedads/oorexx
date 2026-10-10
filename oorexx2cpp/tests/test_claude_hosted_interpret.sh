#!/usr/bin/env bash
# INTERPRET through the hosted tier: variables and NUMERIC settings round-trip; errors match the interpreter's
# exit status. Needs OO_ROOT (librexx).
set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}; CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/claude-hinterp-$(basename "$CXX")"}; rm -rf "$WORK"; mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
for src in "$ROOT"/examples/claude/hosted_interpret*.rex; do
  f=$(basename "$src" .rex)
  "$REXX_BIN" "$src" >"$WORK/$f.exp" 2>/dev/null; erc=$?
  "$ROOT/build.sh" "$src" "$WORK/$f.bin" "$WORK/$f.cpp" >"$WORK/$f.blog" 2>&1 || { cat "$WORK/$f.blog"; echo "FAIL build $f"; exit 1; }
  "$WORK/$f.bin" >"$WORK/$f.act" 2>/dev/null; arc=$?
  cmp "$WORK/$f.exp" "$WORK/$f.act" || { diff -u "$WORK/$f.exp" "$WORK/$f.act"; exit 1; }
  [[ $erc == $arc ]] || { echo "FAIL $f exit status interpreter=$erc native=$arc"; exit 1; }
  echo "PASS $f ($(wc -l <"$WORK/$f.exp") lines, status $arc identical)"
done
