#!/usr/bin/env bash
# Whole programs, one file each (fourth part of test_program_constructs.sh: each run stays under the regression's
# 30-minute limit): String methods and .nil comparisons answered natively (ported from the interpreter).
# Originally: constructs found compiling the Rexx Parser (Josep Maria Blasco's reports,
# 2026-10-20/21) and the runtime paths they exercise. Output identical to the interpreter.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
cp -r "$ROOT/native/fixtures/program_constructs" "$OUT/src"
check() {   # name program-path
  local name=$1 prog=$2
  (cd "$OUT" && LD_LIBRARY_PATH="$OO_ROOT/lib" "$REXX_BIN" "$prog") > "$OUT/$name.expected" 2>&1
  "$ROOT/native/compile_program.sh" "$prog" "$OUT/$name" > "$OUT/$name.build" 2>&1 || { echo "FAIL build $name"; tail -20 "$OUT/$name.build"; exit 1; }
  (cd "$OUT" && LD_LIBRARY_PATH="$OUT/$name:$OO_ROOT/lib" "$REXX_BIN" "$OUT/$name/$(basename "$prog")") > "$OUT/$name.actual" 2>&1
  diff -u "$OUT/$name.expected" "$OUT/$name.actual" || { echo "FAIL $name differs from the interpreter"; exit 1; }
}
check string_match "$OUT/src/string_match.rex"   # STARTSWITH ENDSWITH (caseless too) and MAKEARRAY natively: StringClassMisc.cpp primitiveMatch, StringUtil::makearray
check nil_compare "$OUT/src/nil_compare.rex"   # a string compared with .nil (no MAKESTRING, no NOSTRING), .nil compared with any object: identity
check stem_object_values "$OUT/src/stem_object_values.rex"   # s.[tail] = object answered by the native stem (only the indexes must be strings)
check collection_union "$OUT/src/collection_union.rex"   # StringTable / Directory UNION natively (CoreClasses.orx single_union), interpreter order
check internal_exit "$OUT/src/internal_exit.rex"   # EXIT in internal routines reached by CALL (no C++ exception) and by function calls, CALL ON, PROCEDURE, loops, SIGNAL ON
check scope_lock_threads "$OUT/src/scope_lock_threads.rex"   # guarded methods from four threads, GUARD WHEN hand-off (ScopeLock fast path)
check string_substr "$OUT/src/string_substr.rex"   # ~SUBSTR natively (quickStringBif) and every form that goes the full route: ends, pad, non-plain numbers, objects, errors, NUMERIC DIGITS 3
check method_use_arg "$OUT/src/method_use_arg.rex"   # USE ARG set after the frame (rx::setArgument), an omitted EXPOSEd name dropped
check message_receivers "$OUT/src/message_receivers.rex"   # message sends on variable receivers: no throwaway empty strings, object receivers held
check arg_exists_omitted "$OUT/src/arg_exists_omitted.rex"   # ARG(n, 'E'/'O') with literal operands read in place; methods, routines, internal routines, errors
check string_send_quick "$OUT/src/string_send_quick.rex"   # x~CONTAINS / x~ISA as rx::sendContains / rx::sendIsA, string[i] in indexValue: in place for a string (library mode), objects, quoted selectors
check instance_isa_args "$OUT/src/instance_isa_args.rex"   # ISA of compiled instances cached by method table (or name), identity compares, pooled native call arguments: nested, recursive, omitted
check string_send_direct "$OUT/src/string_send_direct.rex"   # x~SUBSTR / x~LENGTH as rx::sendSubstr / rx::sendLength: argument order, in-place reads, object receivers
check external_library_calls "$OUT/src/external_library_calls.rex"   # ::ROUTINE ... EXTERNAL "LIBRARY rxmath ...": function and CALL forms from program, method, routine, internal routine, NUMERIC DIGITS (no import merge afterwards)
check external_program_merge "$OUT/src/external_program_merge.rex"   # external .rex programs: public routines / classes merged into the caller, merge check settled per routine name, error 43 then found, dynamic CALL
check trunc_native "$OUT/src/trunc_native.rex"   # TRUNC natively (NumberString::trunc): numbers x places x DIGITS 5 / 9 / 16, signs, zeros, exponents, string method, errors
check trunc_errors "$OUT/src/trunc_errors.rex"   # TRUNC errors raised natively (40.3 / 40.4 / 40.5 / 40.12 / 93.902 / 93.906 / 93.943 with the interpreter's substitutions, its order), places ' 2' / '2.0' / '1E1' / beyond 5 digits, function and method
check rxmath_native "$OUT/src/rxmath_native.rex"   # rxmath natively (rxmath_port): 16 RxCalc functions, degrees / radians / grades over quadrant boundaries, DIGITS 5-20, FORM ENGINEERING (results stay scientific), precision 1-18, nan / infinity, CALL, method, routine; errors and an external public routine of the same name the interpreter's
echo "PASS program constructs (4): $(ls "$OUT"/*.expected | wc -l) programs, $(cat "$OUT"/*.expected | wc -l) lines identical to the interpreter"
