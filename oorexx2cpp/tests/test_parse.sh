#!/usr/bin/env bash
# Tested-language PARSE subset; compiler remains written in ooRexx.
set -euo pipefail
# Legacy standalone qualification links only the original runtime.
# Exercise external BIF integration separately in test_bif_dynamic_v028.sh.
export RX2CPP_BIF_DISABLED=1
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/parse-$(basename "$CXX")"}
mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
passed=0
for src in "$ROOT"/examples/parse/*.rex; do
  # VERSION deliberately appends COMPILED and is qualified separately.
  case "${src##*/}" in parse_version*.rex) continue ;; esac
  name=${src##*/}; name=${name%.rex}
  "$REXX_BIN" "$src" >"$WORK/$name.oracle"
  "$ROOT/run-compiler.sh" "$src" "$WORK/$name.cpp"
  "$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$ROOT/include" "$WORK/$name.cpp" -o "$WORK/$name.native"
  "$WORK/$name.native" >"$WORK/$name.actual"
  cmp "$WORK/$name.oracle" "$WORK/$name.actual" || { diff -u "$WORK/$name.oracle" "$WORK/$name.actual"; exit 1; }
  echo "PASS $name (byte-identical ooRexx/native)"
  passed=$((passed+1))
done
# Target templates with literal/positional patterns, commas, unknown PARSE
# forms must not silently lower to a blank-delimited operation.
# (An empty template is valid Rexx: examples/parse/parse_empty_templates.rex compares it with the interpreter.)
neg_names=(missing_source missing_with invalid_relative empty_literal variable_pattern_empty oversized_position comma_template unsupported_arg_pattern)
neg_sources=('parse var' 'parse value 3 x' 'parse var s a + b' 'parse var s a "" b' 'parse var s a ( ) b' 'parse var s a +9999999999999999999999999 b' 'parse value "a b" with x, y' 'parse arg a + b')
for i in "${!neg_names[@]}"; do
  name=${neg_names[i]}
  printf '%s\n' "${neg_sources[i]}" >"$WORK/negative_$name.rex"
  rm -f "$WORK/negative_$name.cpp"
  if "$ROOT/run-compiler.sh" "$WORK/negative_$name.rex" "$WORK/negative_$name.cpp" >"$WORK/negative_$name.log" 2>&1; then
    echo "FAIL: accepted unsupported $name" >&2; exit 1
  fi
  [[ ! -e "$WORK/negative_$name.cpp" ]] || { echo "FAIL: partial output $name" >&2; exit 1; }
  grep -q 'rx2cpp:' "$WORK/negative_$name.log" || { echo "FAIL: missing diagnostic $name" >&2; cat "$WORK/negative_$name.log"; exit 1; }
  echo "PASS reject $name"
done
printf 'PARSE QUALIFIED: %d differential programs, %d negative forms, CXX=%s\n' "$passed" "${#neg_names[@]}" "$CXX"
