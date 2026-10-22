#!/usr/bin/env bash
# Whole programs, one file each, of constructs found compiling the Rexx Parser (Josep Maria Blasco's reports,
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
check routine_call "$OUT/src/routine_call.rex"   # routine~call / ~callWith from compiled code (an error in the routine)
check init_internal "$OUT/src/init_internal.rex"   # RETURN value of an internal routine of INIT
check stem_returns "$OUT/src/stem_returns.rex"   # a stem returned by a routine, a method, a stem attribute
check dynamic_call "$OUT/src/dynamic_call.rex"   # CALL (expression): a label of the routine or method first
check d2c_signed "$OUT/src/d2c_signed.rex"   # D2C / D2X with a length (two's complement), native
check routine_native "$OUT/src/routine_native.rex"   # routine~call / ~callWith run natively
check no_result "$OUT/src/no_result.rex"   # 91.999 for a message without a result
check env_entries "$OUT/src/env_entries.rex"   # environment entries that are not classes: current value each time
check native_object_messages "$OUT/src/native_object_messages.rex"   # ISNIL, CLASS, class identity, CONTAINS natively
check string_words "$OUT/src/string_words.rex"   # CONTAINSWORD / CASELESSCONTAINSWORD natively
check truth "$OUT/src/truth.rex"     # an object as a logical value: its string value (requestString)
check self_variable "$OUT/src/self_variable.rex"   # SELF as a variable: assigned, by name, dropped, unset in routines
check value_objects "$OUT/src/value_objects.rex"   # VALUE() with objects; a stem name's value is the stem object
check env_lookup "$OUT/src/env_lookup.rex"   # .NAME looked up each time (package LOCAL, .local, .environment), as interpreted
check find_routine "$OUT/src/find_routine.rex"   # .context~package~findRoutine: the same Routine object, kept
check native_stems "$OUT/src/native_stems.rex"   # .Stem~new native in compiled code: [], []=, HASINDEX; crossing
check native_sets "$OUT/src/native_sets.rex"   # .Set~of / .Bag~of native; SEND / SENDWITH to native class objects
check identity_eq "$OUT/src/identity_eq.rex"   # == / \== of interpreter objects: identity when they run Object's own
check native_stringtable "$OUT/src/native_stringtable.rex"   # .StringTable native in compiled code, order included
check array_delete "$OUT/src/array_delete.rex"   # Array~delete native (ArrayClass::deleteItem / closeGap)
echo "PASS program constructs: $(ls "$OUT"/*.expected | wc -l) programs, $(cat "$OUT"/*.expected | wc -l) lines identical to the interpreter"
