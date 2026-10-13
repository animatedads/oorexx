#!/usr/bin/env bash
# Interpreter-vs-native internal routine language qualification.
set -euo pipefail
# Legacy standalone qualification links only the original runtime.
# Exercise external BIF integration separately in test_bif_dynamic_v028.sh.
export RX2CPP_BIF_DISABLED=1
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/internal-routines-$(basename "$CXX")"}
mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
passes=0
for source in "$ROOT"/examples/routines_v026/*.rex; do
  name=$(basename "$source" .rex)
  "$REXX_BIN" "$source" >"$WORK/$name.oracle"
  "$ROOT/run-compiler.sh" "$source" "$WORK/$name.cpp"
  "$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$ROOT/include" "$WORK/$name.cpp" -o "$WORK/$name.native"
  "$WORK/$name.native" >"$WORK/$name.nativeout"
  cmp "$WORK/$name.oracle" "$WORK/$name.nativeout"
  echo "PASS interpreter/native $name"
  passes=$((passes+1))
done
reject() {
  local name=$1 contents=$2
  local output="$WORK/reject_$name.cpp"
  printf '%s\n' '// must not overwrite existing output' > "$output"
  printf '%s\n' "$contents" > "$WORK/reject_$name.rex"
  if RX2CPP_HOSTED=0 "$ROOT/run-compiler.sh" "$WORK/reject_$name.rex" "$output" > "$WORK/reject_$name.stderr" 2>&1; then
    echo "FAIL accepted $name" >&2; exit 1
  fi
  grep -qx '// must not overwrite existing output' "$output" || { echo "FAIL overwrote $name" >&2; exit 1; }
  grep -q 'rx2cpp:' "$WORK/reject_$name.stderr" || { echo "FAIL missing diagnostic $name" >&2; exit 1; }
  echo "PASS reject $name"
}
parity() {
  local name=$1 contents=$2
  printf '%s\n' "$contents" > "$WORK/parity_$name.rex"
  "$REXX_BIN" "$WORK/parity_$name.rex" > "$WORK/parity_$name.oracle" 2>&1 || true
  "$ROOT/run-compiler.sh" "$WORK/parity_$name.rex" "$WORK/parity_$name.cpp"
  "$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$ROOT/include" "$WORK/parity_$name.cpp" -o "$WORK/parity_$name.native"
  "$WORK/parity_$name.native" > "$WORK/parity_$name.nativeout" 2>&1 || true
  cmp "$WORK/parity_$name.oracle" "$WORK/parity_$name.nativeout" || { diff -u "$WORK/parity_$name.oracle" "$WORK/parity_$name.nativeout"; echo "FAIL $name" >&2; exit 1; }
  echo "PASS interpreter/native $name"
  passes=$((passes+1))
}
reject label_without_exit $'say 1\nf:\n return 2'
# A routine without RETURN that runs off the end of the program is valid ooRexx (the program ends there; the
# interpreter prints 3 once): parity, not rejection.
parity missing_return $'call f\nsay "back" result\ncall f\nexit\nf:\n say 3'
reject procedure_after_statement $'exit\nf:\n say 2\n procedure\n return 0'
reject procedure_at_entry $'procedure\nsay 2\nexit'
reject signal_unsupported $'exit\nf:\n signal xyz\n return 0'
reject unknown_internal $'call missing 9\nexit'
reject use_arg_at_entry $'use arg value\nsay value'
reject label_in_block $'do 1\nf:\n say 1\nend\nexit'
echo "Internal routine qualification: $passes byte-identical programs, 7 protected-output rejection cases; CXX=$CXX"
