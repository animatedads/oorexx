#!/usr/bin/env bash
# Logical operators & | &&: interpreter-vs-native parity, including which operand strings are legal.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}; CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/logic-$(basename "$CXX")"}; rm -rf "$WORK"; mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
build() {
  if [[ "${2:-}" == grammar_only ]]; then
    RX2CPP_BIF_DISABLED=1 CXX="$CXX" "$ROOT/build.sh" "$1.rex" "$1.native" "$1.cpp" >/dev/null
  else
    CXX="$CXX" "$ROOT/build.sh" "$1.rex" "$1.native" "$1.cpp" >/dev/null
  fi
}
name=logic_basic; cp "$ROOT/examples/$name.rex" "$WORK/$name.rex"
"$REXX_BIN" "$WORK/$name.rex" >"$WORK/$name.expected"; build "$WORK/$name"; "$WORK/$name.native" >"$WORK/$name.actual"
cmp "$WORK/$name.expected" "$WORK/$name.actual" || { diff -u "$WORK/$name.expected" "$WORK/$name.actual"; exit 1; }
echo "PASS $name ($(wc -l <"$WORK/$name.expected") lines identical to the interpreter)"
# Which operand strings does the interpreter accept as logical values? Native must agree on
# BOTH acceptance and result.
i=0; mismatch=0
for v in '"0"' '"1"' '" 1 "' '"01"' '"1.0"' '"2"' '""' '"a"' '"-0"'; do
  i=$((i+1)); p="$WORK/val$i"; printf 'say %s | 0\n' "$v" > "$p.rex"
  set +e; ie=$("$REXX_BIN" "$p.rex" 2>/dev/null); irc=$?; set -e; [ $irc -eq 0 ] && iok=ok || iok=err
  build "$p" grammar_only; set +e; ne=$("$p.native" 2>/dev/null); nrc=$?; set -e; [ $nrc -eq 0 ] && nok=ok || nok=err
  if [[ "$iok" != "$nok" ]] || { [[ "$iok" == ok ]] && [[ "$ie" != "$ne" ]]; }; then
    echo "MISMATCH operand $v: interpreter=$iok('$ie') native=$nok('$ne')"; mismatch=$((mismatch+1)); fi
done
[ $mismatch -eq 0 ] || { echo "FAIL $mismatch operand-acceptance mismatches"; exit 1; }
echo "PASS operand acceptance identical for $i operand strings"
for bad in 'say 1 |' 'say & 1' 'say 1 &&& 0'; do
  printf '%s\n' "$bad" > "$WORK/bad.rex"; rm -f "$WORK/bad.cpp"
  if "$ROOT/run-compiler.sh" "$WORK/bad.rex" "$WORK/bad.cpp" >/dev/null 2>&1; then echo "FAIL accepted: $bad"; exit 1; fi
  [[ ! -e "$WORK/bad.cpp" ]] || { echo "FAIL partial C++ for: $bad"; exit 1; }
done
echo "PASS 3 malformed logical expressions rejected with no output"
