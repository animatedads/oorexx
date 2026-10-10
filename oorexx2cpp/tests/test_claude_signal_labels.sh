#!/usr/bin/env bash
# SIGNAL ON/OFF SYNTAX, RAISE SYNTAX ARRAY(...) [RETURN], EXIT inside routines, same-line labels, duplicate labels:
# stdout and process status identical to the interpreter (incl. the ooRexx rule that a plain RAISE is
# only seen by the program's top-level trap, never by an internal routine's trap).
set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}; CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/claude-signal-$(basename "$CXX")"}; rm -rf "$WORK"; mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
for f in labels_same_line signal_syntax; do
  "$REXX_BIN" "$ROOT/examples/claude/$f.rex" >"$WORK/$f.exp" 2>&1; erc=$?
  "$ROOT/build.sh" "$ROOT/examples/claude/$f.rex" "$WORK/$f.bin" "$WORK/$f.cpp" >/dev/null || { echo "FAIL build $f"; exit 1; }
  "$WORK/$f.bin" >"$WORK/$f.act" 2>&1; arc=$?
  cmp "$WORK/$f.exp" "$WORK/$f.act" || { diff -u "$WORK/$f.exp" "$WORK/$f.act"; exit 1; }
  [[ $erc == $arc ]] || { echo "FAIL $f exit status interpreter=$erc native=$arc"; exit 1; }
  echo "PASS $f ($(wc -l <"$WORK/$f.exp") lines, status $arc identical)"
done
