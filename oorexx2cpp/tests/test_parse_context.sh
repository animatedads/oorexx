#!/usr/bin/env bash
# Focused v0.23 PARSE activation-source language tests. Standalone executable.
set -euo pipefail
# Legacy standalone qualification links only the original runtime.
# Exercise external BIF integration separately in test_bif_dynamic_v028.sh.
export RX2CPP_BIF_DISABLED=1
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/parse-context-$(basename "$CXX")"}
mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
passed=0
function compare_case() {
  local name=$1; shift
  local src="$ROOT/examples/parse/$name.rex"
  "$REXX_BIN" "$src" "$@" > "$WORK/$name.expected"
  "$ROOT/run-compiler.sh" "$src" "$WORK/$name.cpp"
  "$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$ROOT/include" "$WORK/$name.cpp" -o "$WORK/$name.native"
  "$WORK/$name.native" "$@" > "$WORK/$name.actual"
  cmp "$WORK/$name.expected" "$WORK/$name.actual" || { diff -u "$WORK/$name.expected" "$WORK/$name.actual"; exit 1; }
  echo "PASS $name: interpreter/native exact"
  passed=$((passed+1))
}
compare_case parse_source
compare_case parse_source_rexxcps
compare_case parse_source_upper
compare_case parse_upper_var
compare_case parse_arg_wrapper 'aBc deF'
compare_case parse_arg_multiple 'aBc deF'
compare_case parse_arg_wrapper 'aBc' 'deF'
compare_case parse_arg_wrapper
compare_case parse_arg_multiple
# Version deliberately differs by the additional word COMPILED. Check exact
# interpreter-reported version prefix plus marker and its UPPER variant.
version_src="$ROOT/examples/parse/parse_version_case.rex"
"$REXX_BIN" "$version_src" > "$WORK/version.interpreter"
sed 's/$/ COMPILED/' "$WORK/version.interpreter" > "$WORK/version.expected"
"$ROOT/run-compiler.sh" "$version_src" "$WORK/version.cpp"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$ROOT/include" "$WORK/version.cpp" -o "$WORK/version.native"
"$WORK/version.native" > "$WORK/version.actual"
cmp "$WORK/version.expected" "$WORK/version.actual" || { diff -u "$WORK/version.expected" "$WORK/version.actual"; exit 1; }
echo 'PASS PARSE VERSION: reference version with COMPILED marker'
passed=$((passed+1))
negatives=(
  'parse source'
  'parse version'
  'parse arg'
  'parse lower'
  'parse upper unknown x'
  'parse arg a + x'
  'parse source x, y'
)
for i in "${!negatives[@]}"; do
  printf '%s\n' "${negatives[i]}" > "$WORK/negative_$i.rex"
  rm -f "$WORK/negative_$i.cpp"
  if "$ROOT/run-compiler.sh" "$WORK/negative_$i.rex" "$WORK/negative_$i.cpp" > "$WORK/negative_$i.log" 2>&1; then
    echo "FAIL: accepted invalid context case $i" >&2; exit 1
  fi
  [[ ! -e "$WORK/negative_$i.cpp" ]] || { echo "FAIL: partial C++ for invalid context case $i" >&2; exit 1; }
  grep -q 'rx2cpp:' "$WORK/negative_$i.log" || { echo "FAIL: missing rejection diagnostic $i" >&2; exit 1; }
  echo "PASS reject context case $i"
done
printf 'PARSE CONTEXT QUALIFIED: %s positive comparisons and %s negative cases, CXX=%s\n' "$passed" "${#negatives[@]}" "$CXX"
