#!/usr/bin/env bash
# Grammar fidelity: blank concatenation, abuttal, line continuation (, and -), ! and ? in symbols, receiver~attr = value.
# Output and status of the compiled program must equal the interpreter.
set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}; CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/claude-syntax-$(basename "$CXX")"}; rm -rf "$WORK"; mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
for src in "$ROOT"/examples/claude/syntax_*.rex; do
  f=$(basename "$src" .rex)
  "$REXX_BIN" "$src" >"$WORK/$f.exp" 2>&1; erc=$?
  "$ROOT/build.sh" "$src" "$WORK/$f.bin" "$WORK/$f.cpp" >"$WORK/$f.blog" 2>&1 || { cat "$WORK/$f.blog"; echo "FAIL build $f"; exit 1; }
  "$WORK/$f.bin" >"$WORK/$f.act" 2>&1; arc=$?
  cmp "$WORK/$f.exp" "$WORK/$f.act" || { diff -u "$WORK/$f.exp" "$WORK/$f.act"; exit 1; }
  [[ $erc == $arc ]] || { echo "FAIL $f exit status interpreter=$erc native=$arc"; exit 1; }
  echo "PASS $f ($(wc -l <"$WORK/$f.exp") lines, status $arc identical)"
done
# CALL with an omitted argument compiles to an omitted slot (running it needs the BIF activation lane: ChatGPT's boundary).
"$ROOT/build.sh" "$ROOT/tests/fixtures/omitted_arg_call.rex" "$WORK/om.bin" "$WORK/om.cpp" >"$WORK/om.blog" 2>&1 || { cat "$WORK/om.blog"; echo "FAIL build omitted_arg_call"; exit 1; }
grep -q 'push_back(std::nullopt)' "$WORK/om.cpp" || { echo "FAIL omitted argument not emitted"; exit 1; }
echo "PASS omitted_arg_call (compile-only)"
