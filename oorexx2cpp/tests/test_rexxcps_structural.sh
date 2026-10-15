#!/usr/bin/env bash
# Strict source-level verification of RexxCPS structural features.
set -euo pipefail
# Legacy standalone qualification links only the original runtime.
# Exercise external BIF integration separately in test_bif_dynamic_v028.sh.
export RX2CPP_BIF_DISABLED=1
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/rexxcps-structural-$(basename "$CXX")"}
mkdir -p "$WORK"
[[ -z "${REXX_LIB:-}" ]] || export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
pass=0
for src in "$ROOT"/examples/rexxcps_structural/*.rex; do
  name=$(basename "$src" .rex)
  "$REXX_BIN" "$src" >"$WORK/$name.oracle" 2>"$WORK/$name.oracle.err"
  "$ROOT/run-compiler.sh" "$src" "$WORK/$name.cpp"
  "$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$ROOT/include" "$WORK/$name.cpp" -o "$WORK/$name.native"
  "$WORK/$name.native" >"$WORK/$name.native.out" 2>"$WORK/$name.native.err"
  cmp "$WORK/$name.oracle" "$WORK/$name.native.out"
  echo "PASS parity $name"
  pass=$((pass+1))
done
# Bad source is rejected before writing; an existing output is never clobbered.
reject () {
  local name=$1 source=$2 sentinel=$WORK/$name.cpp
  printf '// previous valid output\n' >"$sentinel"
  printf '%s\n' "$source" >"$WORK/$name.rex"
  if "$ROOT/run-compiler.sh" "$WORK/$name.rex" "$sentinel" >"$WORK/$name.err" 2>&1; then
    echo "FAIL compiler admitted $name" >&2; exit 1
  fi
  grep -q '^// previous valid output$' "$sentinel" || { echo "FAIL overwritten $name" >&2; exit 1; }
  echo "PASS reject $name"
}
# LEAVE / ITERATE outside a loop or naming no active loop: error 28.x when it runs (RexxActivation::leaveLoop), as
# interpreted - the clauses before it run, the program fails.
runtime28 () {
  local name=$1 source=$2
  printf '%s\n' "$source" >"$WORK/$name.rex"
  "$REXX_BIN" "$WORK/$name.rex" >"$WORK/$name.oracle" 2>/dev/null && { echo "FAIL interpreter accepted $name" >&2; exit 1; }
  "$ROOT/run-compiler.sh" "$WORK/$name.rex" "$WORK/$name.cpp"
  "$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$ROOT/include" "$WORK/$name.cpp" -o "$WORK/$name.native"
  if "$WORK/$name.native" >"$WORK/$name.native.out" 2>"$WORK/$name.native.err"; then echo "FAIL runtime accepted $name" >&2; exit 1; fi
  cmp "$WORK/$name.oracle" "$WORK/$name.native.out" || { echo "FAIL output before the error differs: $name" >&2; exit 1; }
  grep -q '28\.' "$WORK/$name.native.err" || { echo "FAIL $name: not error 28" >&2; cat "$WORK/$name.native.err"; exit 1; }
  echo "PASS runtime error 28 $name"
}
runtime28 leave_outside $'say "first"\nleave\nsay "bad"'
runtime28 iterate_outside $'say "first"\niterate\nsay "bad"'
runtime28 leave_unknown $'do i=1 to 2\n say i\n leave j\nend i'
runtime28 iterate_unknown $'do i=1 to 2\n say i\n iterate j\nend i'
reject end_name_wrong $'do i=1 to 2\n say i\nend j'
reject end_name_on_repeat $'do 3\n say "a"\nend i'
reject malformed_exponent $'say 1.1E+'
# Structural/runtime failure must be explicit, never a plausible result.
for bad in '2 | 1' '1 | 2' '3 % 0' '9999999999 % 2'; do
  test_name=$(printf '%s' "$bad" | tr -cs '[:alnum:]' '_')
  printf 'say (%s)\n' "$bad" >"$WORK/$test_name.rex"
  "$ROOT/run-compiler.sh" "$WORK/$test_name.rex" "$WORK/$test_name.cpp"
  "$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$ROOT/include" "$WORK/$test_name.cpp" -o "$WORK/$test_name.native"
  if "$WORK/$test_name.native" >"$WORK/$test_name.out" 2>"$WORK/$test_name.err"; then
    echo "FAIL runtime accepted $bad" >&2; exit 1
  fi
  grep -q 'rx2cpp runtime error:' "$WORK/$test_name.err"
  echo "PASS runtime reject $bad"
done
printf 'REXXCPS STRUCTURAL: %d byte-identical parity fixtures, 7 compiler rejections, 4 runtime rejection cases; %s\n' "$pass" "$CXX"
