#!/usr/bin/env bash
# Whole programs, one file each (third part of test_program_constructs.sh: each run stays under the regression's
# 30-minute limit): SELF sends a class does not define, ::CONSTANT, EXIT and SIGNAL in methods.
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
check self_inherited "$OUT/src/self_inherited.rex"   # SELF~isA / ~class / ~isNil in compiled methods: as compiled code holding the object
check constants_native "$OUT/src/constants_native.rex"   # ::CONSTANT from compiled code: the interpreter's value, asked once; hiding as interpreted
check method_exit "$OUT/src/method_exit.rex"   # EXIT from a method body returns, from an internal routine leaves; SIGNAL as a jump; SIGL / PARSE SOURCE / .LINE in classes of a program
check datatype_options "$OUT/src/datatype_options.rex"   # DATATYPE: every option natively as StringUtil::dataType (B X S V O I 9 were the interpreter's)
check env_epoch "$OUT/src/env_epoch.rex"   # environment symbols kept by interpreter epoch: interpreted routine, INTERPRET, STRING method, another thread, setEntry
check env_security "$OUT/src/env_security.rex"   # environment symbols under the package security manager: LOCAL / ENVIRONMENT asked, .nil, no RESULT, 34.903
check security_manager "$OUT/src/security_manager.rex"   # every security manager check (LOCAL ENVIRONMENT CALL COMMAND STREAM METHOD), taken when an activation starts
echo "PASS program constructs (3): $(ls "$OUT"/*.expected | wc -l) programs, $(cat "$OUT"/*.expected | wc -l) lines identical to the interpreter"
