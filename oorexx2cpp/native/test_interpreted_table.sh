#!/usr/bin/env bash
# Interpreted table (<package>.rx2cpp): prefer_interpreted / requires_interpreted for classes and methods.
# The library with the table must print what the interpreter prints; the build reports what moved and refuses
# a requires_interpreted rule it cannot honour.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
export REXX_PATH="$OUT:$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
F="$ROOT/native/fixtures"
cp "$F/interp_table.cls" "$F/interp_table.rx2cpp" "$OUT/"
{ cat "$F/interp_table_client.rex"; printf '\n::requires "interp_table.cls"\n'; } > "$OUT/interpreted.rex"
{ cat "$F/interp_table_client.rex"; printf '\n::requires "rxitable" library\n'; } > "$OUT/compiled.rex"
(cd "$OUT" && "$REXX_BIN" interpreted.rex > expected.txt)
"$ROOT/native/build.sh" "$OUT/interp_table.cls" "$OUT" rxitable > "$OUT/build.log" 2>&1 || { echo "FAIL build"; tail -30 "$OUT/build.log"; exit 1; }
for want in 'interpreted: COUNTER DESCRIBE (prefer)' 'interpreted: COUNTER WHERE (requires)' 'interpreted: COUNTER MAKE CLASS (prefer)' \
            'interpreted: SHAPE (requires)' 'interpreted: SQUARE (inherits interpreted SHAPE)' 'COUNTER PEEK): warning: EXPOSE'; do
  grep -qF "$want" "$OUT/build.log" || { echo "FAIL build report missing: $want"; cat "$OUT/build.log"; exit 1; }
done
(cd "$OUT" && "$REXX_BIN" compiled.rex > actual.txt 2>&1) || true
diff -u "$OUT/expected.txt" "$OUT/actual.txt" || { echo "FAIL output differs from the interpreter"; exit 1; }
# requires_interpreted that cannot be honoured stops the build.
printf 'requires_interpreted Counter peek\n' > "$OUT/bad.rx2cpp"
if RX2CPP_TABLE="$OUT/bad.rx2cpp" "$ROOT/native/build.sh" "$OUT/interp_table.cls" "$OUT/bad" rxbad > "$OUT/bad.log" 2>&1; then
  echo "FAIL requires_interpreted on an EXPOSE method was accepted"; exit 1
fi
grep -qF 'EXPOSE shares variables' "$OUT/bad.log" || { echo "FAIL refusal reason"; cat "$OUT/bad.log"; exit 1; }
# A rule naming nothing: requires -> error.
printf 'requires_interpreted Counter nosuch\n' > "$OUT/none.rx2cpp"
if RX2CPP_TABLE="$OUT/none.rx2cpp" "$ROOT/native/build.sh" "$OUT/interp_table.cls" "$OUT/none" rxnone > "$OUT/none.log" 2>&1; then
  echo "FAIL unmatched requires_interpreted rule was accepted"; exit 1
fi
grep -qF 'no such class or method' "$OUT/none.log" || { echo "FAIL unmatched reason"; cat "$OUT/none.log"; exit 1; }
grep -q 'generated_declaration_image.inc' "$OUT/generated_package.cpp" || { echo "FAIL default form is not tokenized"; exit 1; }
# interpreted_form source: same output, declaration embedded as text.
form_build() {   # form libname dir
  mkdir -p "$OUT/$3"
  { printf 'interpreted_form %s\n' "$1"; cat "$F/interp_table.rx2cpp"; } > "$OUT/$3/table.rx2cpp"
  RX2CPP_TABLE="$OUT/$3/table.rx2cpp" "$ROOT/native/build.sh" "$OUT/interp_table.cls" "$OUT/$3" "$2" > "$OUT/$3/build.log" 2>&1 \
    || { echo "FAIL build form $1"; tail -20 "$OUT/$3/build.log"; exit 1; }
  { cat "$F/interp_table_client.rex"; printf '\n::requires "%s" library\n' "$2"; } > "$OUT/$3/client.rex"
}
form_run() { (cd "$OUT/$1" && LD_LIBRARY_PATH="$OUT/$1:$LD_LIBRARY_PATH" "$REXX_BIN" client.rex 2>&1) || true; }
form_build source rxsrc src
grep -q 'generated_declaration_image.inc' "$OUT/src/generated_package.cpp" && { echo "FAIL source form was tokenized"; exit 1; }
diff -u "$OUT/expected.txt" <(form_run src) || { echo "FAIL source form output"; exit 1; }
# interpreted_form file: editable file next to the library, read at every load.
form_build file rxfile file
[[ -f "$OUT/file/rxfile_interpreted.cls" ]] || { echo "FAIL no editable file"; exit 1; }
grep -qF '/* #REXX2CPP METHODS COUNTER */' "$OUT/file/rxfile_interpreted.cls" || { echo "FAIL methods marker"; exit 1; }
diff -u "$OUT/expected.txt" <(form_run file) || { echo "FAIL file form output"; exit 1; }
sed -i "s/'Counter at'/'Edited at'/; s/'shape with'/'edited shape with'/" "$OUT/file/rxfile_interpreted.cls"
sed "s/^Counter at/Edited at/; s/shape with/edited shape with/" "$OUT/expected.txt" > "$OUT/edited.txt"
diff -u "$OUT/edited.txt" <(form_run file) || { echo "FAIL edit to the file not picked up at load"; exit 1; }
mv "$OUT/file/rxfile_interpreted.cls" "$OUT/file/moved.cls"
form_run file | grep -qF 'interpreted source file not found' || { echo "FAIL missing file not reported"; exit 1; }
echo "PASS interpreted table: methods, class methods, whole class, inherited, refusals; forms tokenized, source, file (live edit)"
