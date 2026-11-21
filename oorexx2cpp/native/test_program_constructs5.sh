#!/usr/bin/env bash
# Whole programs, one file each (fifth part of test_program_constructs.sh: each run stays well under the regression's
# 60-minute limit): ::OPTIONS condition SYNTAX (NOVALUE / ERROR / FAILURE / LOSTDIGITS / NOSTRING / NOTREADY / ALL).
# Output identical to the interpreter (trunk r13550). Claude (Opus 5.5), 2026-11-21.
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
check options_syntax "$OUT/src/options_syntax.rex"   # ::OPTIONS ALL SYNTAX: 98.970-98.974 / 98.986 unless a running CATCH takes the condition (internal routines too); SIGNAL ON NOVALUE turns it off; methods
check options_partial "$OUT/src/options_partial.rex"   # ::OPTIONS policies accumulate (ALL SYNTAX, then NOVALUE / NOSTRING / FAILURE CONDITION)
check options_more "$OUT/src/options_more.rex"   # untrapped FAILURE as ERROR (98.970), SIGNAL OFF / CALL ON turn the option off for the activation only, NOVALUE ERROR, methods and routines without traps
check options_interpret "$OUT/src/options_interpret.rex"   # INTERPRET has the ::OPTIONS policies in force; a CATCH around it wins, SIGNAL ON turns them off
echo "PASS program constructs (5): $(ls "$OUT"/*.expected | wc -l) programs, $(cat "$OUT"/*.expected | wc -l) lines identical to the interpreter"
