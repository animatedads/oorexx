#!/usr/bin/env bash
# Full differential qualification: ooRexx source -> ooRexx interpreter vs
# same source -> ooRexx-written compiler -> C++ compiler -> native executable.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
CXX=${CXX:-g++}
export RX2CPP_BIF_DISABLED=1   # this suite qualifies the bootstrap subset without the BIF add-on
REXX_BIN=${REXX_BIN:-rexx}
TEST_OUTPUT_DIR=${TEST_OUTPUT_DIR:-build/qualification}
mkdir -p "$TEST_OUTPUT_DIR"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
"$REXX_BIN" -v >/dev/null 2>&1 || fail "No runnable ooRexx interpreter at $REXX_BIN"
command -v "$CXX" >/dev/null || fail "No C++17 compiler at $CXX"
pass=0
for name in squares nested strings edgecases comments escapes operators aliases message_result message_chain message_in_loop message_operator call_result builtin_abs abs_ootest_microcases somerexx do_until_once do_until_nested division if_inline_else if_then_loop exit_early compound_semantics compound_loop compound_multitail compound_trailing; do
    ./run-compiler.sh "examples/$name.rex" "$TEST_OUTPUT_DIR/$name.cpp"
    "$CXX" -std=c++17 -O2 -Wall -Wextra -Iinclude "$TEST_OUTPUT_DIR/$name.cpp" -o "$TEST_OUTPUT_DIR/$name.native"
    "$REXX_BIN" "examples/$name.rex" >"$TEST_OUTPUT_DIR/$name.expected"
    "$TEST_OUTPUT_DIR/$name.native" >"$TEST_OUTPUT_DIR/$name.actual"
    cmp -s "$TEST_OUTPUT_DIR/$name.expected" "$TEST_OUTPUT_DIR/$name.actual" || {
        diff -u "$TEST_OUTPUT_DIR/$name.expected" "$TEST_OUTPUT_DIR/$name.actual" || true
        fail "Differential output mismatch: $name"
    }
    printf 'PASS interpreter/native parity: %s\n' "$name"
    pass=$((pass + 1))
done
# First shipped ooRexx sample: fully differential, same source (RETURN a
# nonnumeric object at the program entry point; the CLI exits with status 0).
SAMPLES=${OO_SAMPLES:-${OO_ROOT:-/usr/local}/share/ooRexx/samples}
hello="$SAMPLES/api/c++/callsample/HelloWorld.rex"
if [[ -f "$hello" ]]; then
    ./run-compiler.sh "$hello" "$TEST_OUTPUT_DIR/shipped_HelloWorld.cpp"
    "$CXX" -std=c++17 -O2 -Wall -Wextra -Iinclude "$TEST_OUTPUT_DIR/shipped_HelloWorld.cpp" -o "$TEST_OUTPUT_DIR/shipped_HelloWorld.native"
    "$REXX_BIN" "$hello" >"$TEST_OUTPUT_DIR/shipped_HelloWorld.expected"
    "$TEST_OUTPUT_DIR/shipped_HelloWorld.native" >"$TEST_OUTPUT_DIR/shipped_HelloWorld.actual"
    cmp -s "$TEST_OUTPUT_DIR/shipped_HelloWorld.expected" "$TEST_OUTPUT_DIR/shipped_HelloWorld.actual" || fail 'shipped HelloWorld output mismatch'
    printf 'PASS shipped HelloWorld interpreter/native parity\n'
    pass=$((pass + 1))
else
    printf 'SKIP shipped sample (set OO_SAMPLES to the ooRexx samples directory)\n'
fi
# Process EXIT codes must match, not just stdout bytes.
name=exit_status_7
./run-compiler.sh "examples/$name.rex" "$TEST_OUTPUT_DIR/$name.cpp"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Iinclude "$TEST_OUTPUT_DIR/$name.cpp" -o "$TEST_OUTPUT_DIR/$name.native"
set +e
"$REXX_BIN" "examples/$name.rex" >"$TEST_OUTPUT_DIR/$name.expected"
expected_status=$?
"$TEST_OUTPUT_DIR/$name.native" >"$TEST_OUTPUT_DIR/$name.actual"
actual_status=$?
set -e
[[ $expected_status -eq 7 && $actual_status -eq 7 ]] || fail "EXIT status mismatch: expected=$expected_status actual=$actual_status"
cmp -s "$TEST_OUTPUT_DIR/$name.expected" "$TEST_OUTPUT_DIR/$name.actual" || fail "EXIT output mismatch"
printf 'PASS interpreter/native EXIT 7 and output parity\n'
pass=$((pass + 1))
# Direct native/.Object proxy method-return outcome differential. The
# reference ::class is interpreter-only; compiled-side object uses native ABI.
"$REXX_BIN" tests/oorexx_message_outcome.rex >"$TEST_OUTPUT_DIR/message-outcome.expected"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -Iinclude tests/native_message_outcome.cpp -o "$TEST_OUTPUT_DIR/native_message_outcome"
"$TEST_OUTPUT_DIR/native_message_outcome" >"$TEST_OUTPUT_DIR/message-outcome.actual"
cmp -s "$TEST_OUTPUT_DIR/message-outcome.expected" "$TEST_OUTPUT_DIR/message-outcome.actual" || { diff -u "$TEST_OUTPUT_DIR/message-outcome.expected" "$TEST_OUTPUT_DIR/message-outcome.actual" || true; fail 'native RESULT state semantics'; }
printf 'PASS native/interpreter message return, no-return and cascade semantics\n'
pass=$((pass + 1))
# Verify the native operator-message extension point is a real working ABI,
# with independent = and \= methods (not logical negation).
"$CXX" -std=c++17 -O2 -Wall -Wextra -Iinclude tests/native_operator_dispatch.cpp -o "$TEST_OUTPUT_DIR/native_operator_dispatch"
"$TEST_OUTPUT_DIR/native_operator_dispatch" || fail 'native operator message ABI'
printf 'PASS native independent operator-message dispatch\n'
pass=$((pass + 1))
# Exact oracle for inherited .Object identity comparators; compares two *separately*
# authored programs because ::class source compilation is not implemented yet.
"$REXX_BIN" tests/oorexx_object_inheritance.rex >"$TEST_OUTPUT_DIR/object-defaults.expected"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -Iinclude tests/native_object_inheritance.cpp -o "$TEST_OUTPUT_DIR/native_object_inheritance"
"$TEST_OUTPUT_DIR/native_object_inheritance" >"$TEST_OUTPUT_DIR/object-defaults.actual"
if ! cmp -s "$TEST_OUTPUT_DIR/object-defaults.expected" "$TEST_OUTPUT_DIR/object-defaults.actual"; then
    diff -u "$TEST_OUTPUT_DIR/object-defaults.expected" "$TEST_OUTPUT_DIR/object-defaults.actual" || true
    fail 'ooRexx .Object inherited comparator parity'
fi
printf 'PASS inherited .Object comparison defaults and subclass override parity\n'
pass=$((pass + 1))
# Negative validation: rejects unsupported syntax with source location; no output generated.
for pair in 'unsupported:~' 'incomplete-division:/' 'doubled-backslash:invalid' 'same-line-else:invalid' 'incomplete-until:invalid'; do
    name=${pair%%:*}
    if [[ "$name" == incomplete-division ]]; then
        printf 'x = 1 /\n' >"$TEST_OUTPUT_DIR/$name.rex"
    elif [[ "$name" == same-line-else ]]; then
        printf '%s\n' "if 1 = 1 then say 'yes' else say 'no'" >"$TEST_OUTPUT_DIR/$name.rex"
    elif [[ "$name" == incomplete-until ]]; then
        printf '%s\n' 'do until' '  say 1' 'end' >"$TEST_OUTPUT_DIR/$name.rex"
    elif [[ "$name" == doubled-backslash ]]; then
        printf '%s\n' 'if 1 \\= 2 then do' '  say 1' 'end' >"$TEST_OUTPUT_DIR/$name.rex"
    else
        cp examples/unsupported.rex "$TEST_OUTPUT_DIR/$name.rex"
    fi
    rm -f "$TEST_OUTPUT_DIR/$name.cpp"
    if RX2CPP_HOSTED=0 ./run-compiler.sh "$TEST_OUTPUT_DIR/$name.rex" "$TEST_OUTPUT_DIR/$name.cpp" >"$TEST_OUTPUT_DIR/$name.log" 2>&1; then
        fail "Unsupported syntax accepted: $name"
    fi
    [[ ! -f "$TEST_OUTPUT_DIR/$name.cpp" ]] || fail "Invalid source emitted C++: $name"
    grep -Eq 'rx2cpp:[0-9]+:[0-9]+:' "$TEST_OUTPUT_DIR/$name.log" || fail "Missing source diagnostic: $name"
    printf 'PASS rejected invalid syntax: %s\n' "$name"
    pass=$((pass + 1))
done
# Syntax failures must not be confused with unsupported semantic runtime values.
printf 'say 9223372036854775807 + 1\n' >"$TEST_OUTPUT_DIR/overflow.rex"
./run-compiler.sh "$TEST_OUTPUT_DIR/overflow.rex" "$TEST_OUTPUT_DIR/overflow.cpp"
"$CXX" -std=c++17 -O2 -Iinclude "$TEST_OUTPUT_DIR/overflow.cpp" -o "$TEST_OUTPUT_DIR/overflow.native"
if "$TEST_OUTPUT_DIR/overflow.native" >"$TEST_OUTPUT_DIR/overflow.stdout" 2>"$TEST_OUTPUT_DIR/overflow.stderr"; then
    fail 'native 64-bit overflow accepted silently'
fi
grep -q 'integer overflow' "$TEST_OUTPUT_DIR/overflow.stderr" || fail 'Overflow error missing'
pass=$((pass + 1))
printf 'PASS native overflow refused\n'
# Runtime failure on division by zero is explicit rather than a silent result.
printf 'say 10/0\n' >"$TEST_OUTPUT_DIR/zero-division.rex"
./run-compiler.sh "$TEST_OUTPUT_DIR/zero-division.rex" "$TEST_OUTPUT_DIR/zero-division.cpp"
"$CXX" -std=c++17 -O2 -Iinclude "$TEST_OUTPUT_DIR/zero-division.cpp" -o "$TEST_OUTPUT_DIR/zero-division.native"
if "$TEST_OUTPUT_DIR/zero-division.native" >"$TEST_OUTPUT_DIR/zero-division.stdout" 2>"$TEST_OUTPUT_DIR/zero-division.stderr"; then
    fail 'native division by zero accepted silently'
fi
grep -q 'division by zero' "$TEST_OUTPUT_DIR/zero-division.stderr" || fail 'Missing divide-by-zero diagnostic'
pass=$((pass + 1))
printf 'PASS native division by zero refused\n' 
# Numeric semantics beyond the proven subset must fail explicitly rather than
# present incorrect formatted decimals as ooRexx NUMERIC DIGITS 9 results.
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -Iinclude tests/native_abs_boundaries.cpp -o "$TEST_OUTPUT_DIR/native_abs_boundaries"
"$TEST_OUTPUT_DIR/native_abs_boundaries" || fail 'ABS subset numeric guard'
pass=$((pass + 1))
# Compiler self-hosting must currently fail closed; no false claims about coverage.
rm -f "$TEST_OUTPUT_DIR/self.cpp"
if ./run-compiler.sh rx2cpp.rex "$TEST_OUTPUT_DIR/self.cpp" >"$TEST_OUTPUT_DIR/self.log" 2>&1; then
    fail 'compiler source unexpectedly accepted: inspect self-host contract'
fi
[[ ! -f "$TEST_OUTPUT_DIR/self.cpp" ]] || fail 'partial self-host translation created output'
pass=$((pass + 1))
printf 'PASS self-host readiness correctly reported as not yet implemented\n'
printf '%s qualification checks passed using %s and %s\n' "$pass" "$REXX_BIN" "$CXX"
