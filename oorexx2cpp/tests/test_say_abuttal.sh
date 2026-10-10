#!/usr/bin/env bash
# SAY items that touch (abuttal) concatenate with no blank; blank-separated items get one space;
# "name (x)" with a blank is NOT a function call. Parity with the interpreter.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}; CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/abuttal-$(basename "$CXX")"}; rm -rf "$WORK"; mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
cp "$ROOT/examples/say_abuttal.rex" "$WORK/t.rex"
"$REXX_BIN" "$WORK/t.rex" >"$WORK/expected"
"$ROOT/build.sh" "$WORK/t.rex" "$WORK/t.native" "$WORK/t.cpp" >/dev/null
"$WORK/t.native" >"$WORK/actual"
cmp "$WORK/expected" "$WORK/actual" || { diff -u "$WORK/expected" "$WORK/actual"; exit 1; }
echo "PASS say_abuttal ($(wc -l <"$WORK/expected") lines identical to the interpreter)"
# 'hex'X / 'bits'B are literals: full parity with the interpreter on valid forms
"$ROOT/build.sh" "$ROOT/examples/hexbin_literals.rex" "$WORK/hx.native" "$WORK/hx.cpp" >/dev/null
"$REXX_BIN" "$ROOT/examples/hexbin_literals.rex" >"$WORK/hx.expected"
"$WORK/hx.native" >"$WORK/hx.actual"
cmp "$WORK/hx.expected" "$WORK/hx.actual" || { diff -u "$WORK/hx.expected" "$WORK/hx.actual"; exit 1; }
echo "PASS hex/binary literals identical to the interpreter"
# invalid forms: the interpreter raises 15.x; the compiler must fail closed with no C++ emitted
n=0
for bad in "say '['x']'" "say 'g1'x" "say ' 41'x" "say '41 'x" "say '4 1'x" "say '1 0'b" "say '012'b"; do
  n=$((n+1)); printf '%s\n' "$bad" > "$WORK/hex$n.rex"; rm -f "$WORK/hex$n.cpp"
  oracle=$("$REXX_BIN" "$WORK/hex$n.rex" 2>&1 || true); [[ "$oracle" == *"Error 15"* ]] || { echo "FAIL oracle not 15.x: $bad"; exit 1; }
  if "$ROOT/run-compiler.sh" "$WORK/hex$n.rex" "$WORK/hex$n.cpp" >/dev/null 2>&1; then echo "FAIL accepted: $bad"; exit 1; fi
  [[ ! -e "$WORK/hex$n.cpp" ]] || { echo "FAIL partial C++ for: $bad"; exit 1; }
done
echo "PASS $n invalid hex/binary literals rejected like the interpreter (15.x)"
# but a string abutted to a LONGER symbol that merely starts with x or b is genuine abuttal
printf "xy = 'Z'\nbb = 'Q'\nsay 'a'xy'b'bb\n" > "$WORK/ok.rex"; rexx_out=$("$REXX_BIN" "$WORK/ok.rex")
"$ROOT/build.sh" "$WORK/ok.rex" "$WORK/ok.native" "$WORK/ok.cpp" >/dev/null
[ "$("$WORK/ok.native")" = "$rexx_out" ] || { echo "FAIL xy/bb abuttal parity"; exit 1; }
echo "PASS abuttal to symbols beginning with x/b unchanged"
