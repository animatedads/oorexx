#!/usr/bin/env bash
# Whole programs, one file each (second half of test_program_constructs.sh: one run stays under the regression's
# 30-minute limit): SELF and VALUE semantics, native collections, environment symbols, variable frames.
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
check self_variable "$OUT/src/self_variable.rex"   # SELF as a variable: assigned, by name, dropped, unset in routines
check value_objects "$OUT/src/value_objects.rex"   # VALUE() with objects; a stem name's value is the stem object
check env_lookup "$OUT/src/env_lookup.rex"   # .NAME looked up each time (package LOCAL, .local, .environment), as interpreted
check find_routine "$OUT/src/find_routine.rex"   # .context~package~findRoutine: the same Routine object, kept
check native_stems "$OUT/src/native_stems.rex"   # .Stem~new native in compiled code: [], []=, HASINDEX; crossing
check native_sets "$OUT/src/native_sets.rex"   # .Set~of / .Bag~of native; SEND / SENDWITH to native class objects
check identity_eq "$OUT/src/identity_eq.rex"   # == / \== of interpreter objects: identity when they run Object's own
check native_stringtable "$OUT/src/native_stringtable.rex"   # .StringTable native in compiled code, order included
check array_delete "$OUT/src/array_delete.rex"   # Array~delete native (ArrayClass::deleteItem / closeGap)
check address_reuse "$OUT/src/address_reuse.rex"   # an interpreter object at a collected compiled instance's address is itself
check variable_frame "$OUT/src/variable_frame.rex"   # locals in the frame: VALUE, DROP, INTERPRET, PROCEDURE EXPOSE, recursion
check variable_frame_methods "$OUT/src/variable_frame_methods.rex"   # frames in methods: EXPOSE by name, PROCEDURE EXPOSE through both
check array_subclass "$OUT/src/array_subclass.rex"   # .Array subclasses made natively: the array part native until it crosses
check self_inherited "$OUT/src/self_inherited.rex"   # SELF~isA / ~class / ~isNil in compiled methods: as compiled code holding the object
echo "PASS program constructs (2): $(ls "$OUT"/*.expected | wc -l) programs, $(cat "$OUT"/*.expected | wc -l) lines identical to the interpreter"
