#!/usr/bin/env bash
# ::OPTIONS DIGITS/FUZZ/FORM (+PROLOG/NOPROLOG): initial NUMERIC settings for the main program and every
# ::ROUTINE (label routines inherit the caller); options accumulate, last wins. Output and status must equal
# the interpreter. Invalid values and the unimplemented keywords (TRACE, ALL, ERROR, ... NOVALUE) and
# ::OPTIONS combined with local classes are rejected at compile time with a source location.
set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}; CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/claude-options-$(basename "$CXX")"}; rm -rf "$WORK"; mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
for src in "$ROOT"/examples/claude/options_*.rex; do
  f=$(basename "$src" .rex)
  "$REXX_BIN" "$src" >"$WORK/$f.exp" 2>&1; erc=$?
  "$ROOT/build.sh" "$src" "$WORK/$f.bin" "$WORK/$f.cpp" >"$WORK/$f.blog" 2>&1 || { cat "$WORK/$f.blog"; echo "FAIL build $f"; exit 1; }
  "$WORK/$f.bin" >"$WORK/$f.act" 2>&1; arc=$?
  cmp "$WORK/$f.exp" "$WORK/$f.act" || { diff -u "$WORK/$f.exp" "$WORK/$f.act"; exit 1; }
  [[ $erc == $arc ]] || { echo "FAIL $f exit status interpreter=$erc native=$arc"; exit 1; }
  echo "PASS $f ($(wc -l <"$WORK/$f.exp") lines, status $arc identical)"
done
for f in "$ROOT"/examples/claude/reject/options_*.rex; do
  b=$(basename "$f" .rex)
  if "$ROOT/build.sh" "$f" "$WORK/$b.bin" "$WORK/$b.cpp" >"$WORK/$b.blog" 2>&1; then echo "FAIL $b was accepted"; exit 1; fi
  grep -Eq 'rx2cpp:[0-9]+:[0-9]+:' "$WORK/$b.blog" || { cat "$WORK/$b.blog"; echo "FAIL $b rejected without a source location"; exit 1; }
  echo "PASS $b rejected: $(grep -Eo 'rx2cpp:[0-9]+:[0-9]+: [^(]*' "$WORK/$b.blog" | head -1)"
done
