#!/usr/bin/env bash
# External routines called from compiled code (through the interpreter): a stem the caller has, named by an argument,
# is worked on in place (SysStemSort, SysStemInsert, SysStemDelete, SysStemCopy source), a stem the callee fills
# comes back (SysFileTree, SysStemCopy target); ::ROUTINE ... EXTERNAL "LIBRARY rxmath ..." under the caller's
# NUMERIC DIGITS, by name and by a computed name. Output identical to the interpreter's.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
export LD_LIBRARY_PATH="$OUT/bin:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
mkdir -p "$OUT/src/d"
touch "$OUT/src/d/a.txt" "$OUT/src/d/b.txt"
cp "$ROOT/native/fixtures/external_stems.rex" "$OUT/src/"
rc=0; (cd "$OUT/src" && "$REXX_BIN" external_stems.rex) > "$OUT/expected.txt" 2>&1 || rc=$?
echo "rc=$rc" >> "$OUT/expected.txt"
"$ROOT/native/compile_program.sh" "$OUT/src/external_stems.rex" "$OUT/bin" > "$OUT/build.log" 2>&1 || { echo "FAIL build"; tail -30 "$OUT/build.log"; exit 1; }
rc=0; (cd "$OUT/src" && REXX_PATH="$OUT/bin" "$REXX_BIN" "$OUT/bin/external_stems.rex") > "$OUT/actual.txt" 2>&1 || rc=$?
echo "rc=$rc" >> "$OUT/actual.txt"
diff -u "$OUT/expected.txt" "$OUT/actual.txt" || { echo "FAIL output differs from the interpreter"; exit 1; }
echo "PASS external stems: $(wc -l < "$OUT/expected.txt") lines identical to the interpreter (exit status included)"
