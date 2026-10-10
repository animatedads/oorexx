#!/usr/bin/env bash
# ooTest-driven differential qualification. No blind execution of upstream
# ooTest testGroups; we compile only our explicitly admitted Rexx fixtures.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
REXX_LIB=${REXX_LIB:-${OO_ROOT:-/usr/local}/lib}
SUITE=${OO_TEST_ROOT:?Set OO_TEST_ROOT to the unzipped ooTest snapshot root}
TEST_OUTPUT_DIR=${TEST_OUTPUT_DIR:-$ROOT/build/ootest}
mkdir -p "$TEST_OUTPUT_DIR"
export PATH="$(dirname -- "$REXX_BIN"):$PATH"
export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$SUITE:$SUITE/framework:$(dirname -- "$REXX_BIN"):$ROOT${REXX_PATH:+:$REXX_PATH}"
export RX2CPP_OOTEST_RESULTS_DIR="$TEST_OUTPUT_DIR"
if [[ ! -f "$SUITE/ooTest.frm" ]]; then echo 'ooTest.frm missing' >&2; exit 66; fi
if [[ ! -f "$SUITE/framework/OOREXXUNIT.CLS" ]]; then echo 'OOREXXUNIT.CLS missing' >&2; exit 66; fi
"$REXX_BIN" -v >"$TEST_OUTPUT_DIR/interpreter.version" 2>&1
"$CXX" --version | head -1 >"$TEST_OUTPUT_DIR/cxx.version"
prepare_case() {
  local name=$1 input=$2 expected actual cpp native
  expected="$TEST_OUTPUT_DIR/$name.expected.stdout"
  actual="$TEST_OUTPUT_DIR/$name.actual.stdout"
  cpp="$TEST_OUTPUT_DIR/$name.cpp"
  native="$TEST_OUTPUT_DIR/$name.native"
  # Keep preparation failures test-visible rather than aborting the suite.
  set +e
  "$REXX_BIN" "$input" >"$expected" 2>"$TEST_OUTPUT_DIR/$name.oracle.stderr"
  echo "$?" >"$TEST_OUTPUT_DIR/$name.expected.status"
  "$ROOT/run-compiler.sh" "$input" "$cpp" >"$TEST_OUTPUT_DIR/$name.translator.log" 2>&1
  local compile_rc=$?
  if (( compile_rc == 0 )); then
    "$CXX" -std=c++17 -O2 -Wall -Wextra -I"$ROOT/include" "$cpp" -o "$native" >>"$TEST_OUTPUT_DIR/$name.translator.log" 2>&1
    compile_rc=$?
  fi
  echo "$compile_rc" >"$TEST_OUTPUT_DIR/$name.compile.status"
  if (( compile_rc == 0 )); then
    "$native" >"$actual" 2>"$TEST_OUTPUT_DIR/$name.native.stderr"
    echo "$?" >"$TEST_OUTPUT_DIR/$name.actual.status"
  else
    : >"$actual"
    echo 125 >"$TEST_OUTPUT_DIR/$name.actual.status"
  fi
  set -e
}
for name in squares operators do_until_once division strings message_result message_chain message_in_loop message_operator call_result builtin_abs abs_ootest_microcases exit_status_7 somerexx assignment_ootest_microcases assignment_chains assignment_loop assignment_literals compound_semantics compound_loop compound_multitail compound_trailing; do
  prepare_case "$name" "$ROOT/examples/$name.rex"
done
hello="${OO_SAMPLES:-${OO_ROOT:-/usr/local}/share/ooRexx/samples}/api/c++/callsample/HelloWorld.rex"
if [[ ! -f "$hello" ]]; then echo "Shipped HelloWorld sample not found: $hello" >&2; exit 66; fi
prepare_case shipped_hello_world "$hello"
# Negative grammar and semantic-boundary exercises. No partial C++.
for name in unsupported_object invalid_else augmented_unsupported_mod augmented_unsupported_remainder augmented_unsupported_power augmented_unsupported_logic augmented_missing_rhs numeric_digits abbrev_bif invalid_message_selector call_unknown call_bad_arity call_condition function_bad_arity; do
  input="$TEST_OUTPUT_DIR/$name.rex"
  case "$name" in
    unsupported_object) printf '%s\n' 'a = .array~of(1,2)' 'say a~items' >"$input" ;;
    invalid_else) printf '%s\n' "if 1 = 1 then say 'yes' else say 'no'" >"$input" ;;
    augmented_unsupported_mod) printf '%s\n' 'i = 13' 'i //= 10' >"$input" ;;
    augmented_unsupported_remainder) printf '%s\n' 'i = 13' 'i %= 10' >"$input" ;;
    augmented_unsupported_power) printf '%s\n' 'i = 3' 'i **= 4' >"$input" ;;
    augmented_unsupported_logic) printf '%s\n' 'i = 0' 'i |= 1' >"$input" ;;
    augmented_missing_rhs) printf '%s\n' 'i = 3' 'i +=' >"$input" ;;
    numeric_digits) printf '%s\n' 'numeric digits 18' 'say 1/3' >"$input" ;;
    invalid_message_selector) printf '%s\n' "word = 'abc'" 'word~' >"$input" ;;
    call_unknown) printf '%s\n' 'call NOTCOMPILED 2' >"$input" ;;
    call_bad_arity) printf '%s\n' 'call ABS 1, 2' >"$input" ;;
    call_condition) printf '%s\n' 'call on error' >"$input" ;;
    function_bad_arity) printf '%s\n' "say LENGTH('a', 'b')" >"$input" ;;
    abbrev_bif) printf '%s\n' "say abbrev('ABC', 'AB')" >"$input" ;;
  esac
  rm -f "$TEST_OUTPUT_DIR/$name.cpp"
  set +e
  "$ROOT/run-compiler.sh" "$input" "$TEST_OUTPUT_DIR/$name.cpp" >"$TEST_OUTPUT_DIR/$name.compiler.log" 2>&1
  rc=$?
  set -e
  echo "$rc" >"$TEST_OUTPUT_DIR/$name.compile.status"
done
(
  cd "$SUITE"
  "$REXX_BIN" testOORexx.rex -R "$ROOT/ootest" -f RX2CPP
) >"$TEST_OUTPUT_DIR/ootest.result" 2>&1
cat "$TEST_OUTPUT_DIR/ootest.result"
# ooTest 4.2's stand-alone entry point can return 0 despite failed assertions.
# Check summary explicitly rather than allowing a false-green shell run.
if ! grep -Eq '^Failures:[[:space:]]+0$' "$TEST_OUTPUT_DIR/ootest.result" || \
   ! grep -Eq '^Errors:[[:space:]]+0$' "$TEST_OUTPUT_DIR/ootest.result"; then
  echo 'ooTest reported a failure/error (or incompatible output format)' >&2; exit 1
fi
printf '%s\n' 'PASS ooTest differential qualification'
