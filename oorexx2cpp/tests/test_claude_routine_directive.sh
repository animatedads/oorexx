#!/usr/bin/env bash
# ::ROUTINE name [PUBLIC|PRIVATE]: code units with their own variable pool and default NUMERIC settings,
# built-ins beat ::ROUTINE, internal labels beat both, EXIT ends only the routine; stdout and exit status
# identical to the interpreter.  Unsupported forms (EXTERNAL, quoted names, label clash, duplicates,
# PUBLIC PRIVATE) must be rejected at compile time with a source location.
set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}; CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/claude-routine-$(basename "$CXX")"}; rm -rf "$WORK"; mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
for f in routine_directive routine_numeric_builtin routine_exit routine_trap routine_args; do
  "$REXX_BIN" "$ROOT/examples/claude/$f.rex" >"$WORK/$f.exp" 2>&1; erc=$?
  "$ROOT/build.sh" "$ROOT/examples/claude/$f.rex" "$WORK/$f.bin" "$WORK/$f.cpp" >"$WORK/$f.blog" 2>&1 || { cat "$WORK/$f.blog"; echo "FAIL build $f"; exit 1; }
  "$WORK/$f.bin" >"$WORK/$f.act" 2>&1; arc=$?
  cmp "$WORK/$f.exp" "$WORK/$f.act" || { diff -u "$WORK/$f.exp" "$WORK/$f.act"; exit 1; }
  [[ $erc == $arc ]] || { echo "FAIL $f exit status interpreter=$erc native=$arc"; exit 1; }
  echo "PASS $f ($(wc -l <"$WORK/$f.exp") lines, status $arc identical)"
done
for f in "$ROOT"/examples/claude/reject/routine_*.rex; do
  b=$(basename "$f" .rex)
  if RX2CPP_HOSTED=0 "$ROOT/build.sh" "$f" "$WORK/$b.bin" "$WORK/$b.cpp" >"$WORK/$b.blog" 2>&1; then echo "FAIL $b was accepted"; exit 1; fi
  grep -Eq 'rx2cpp:[0-9]+:[0-9]+:' "$WORK/$b.blog" || { cat "$WORK/$b.blog"; echo "FAIL $b rejected without a source location"; exit 1; }
  echo "PASS $b rejected: $(grep -Eo 'rx2cpp:[0-9]+:[0-9]+: [^(]*' "$WORK/$b.blog" | head -1)"
done
