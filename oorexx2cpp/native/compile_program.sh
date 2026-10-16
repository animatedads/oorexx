#!/usr/bin/env bash
# compile_program.sh PROGRAM.rex OUTDIR [LIBNAME]
#
# A whole ooRexx program compiled: its main code becomes the public routine RX2CPP_MAIN of a native library
# (OUTDIR/lib<LIBNAME>.so), together with its ::ROUTINEs and ::CLASSes; OUTDIR/<program>.rex is a small launcher that
# runs it:
#
#   rexx OUTDIR/prog.rex arguments...
#
# The main code keeps its line numbers (SIGL, .LINE, SOURCELINE), its file name and call type (PARSE SOURCE: COMMAND),
# its arguments, and its EXIT / RETURN value (the launcher's exit status). Everything the program creates is compiled
# code's, so its arrays and directories stay native (no message to the interpreter per element).
#   RX2CPP_KEEP_INTERPRETED="BSF.CLS ..." as for native/build.sh (packages that stay interpreted).
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ $# -ge 2 ]] || { echo "usage: compile_program.sh PROGRAM.rex OUTDIR [LIBNAME]" >&2; exit 64; }
PROG=$(cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1")
[[ -f "$PROG" ]] || { echo "compile_program.sh: no such program: $1" >&2; exit 66; }
mkdir -p "$2"
OUT=$(cd -- "$2" && pwd)
BASE=$(basename -- "$PROG"); BASE=${BASE%.*}
LIB=${3:-rx$(printf '%s' "$BASE" | tr -c 'A-Za-z0-9' '_' | tr 'A-Z' 'a-z')}
SRC="$OUT/${BASE}_program.cls"
# Line 1 empty, line 2 the routine directive with the combine marker (the program's line L is line L+2 here: the
# marker says so), then the program unchanged (a #! first line blanked, as the interpreter ignores it).
{
  printf '\n'
  printf '::routine RX2CPP_MAIN public /* ---- rx2cpp combined: %s ---- */\n' "$PROG"
  awk 'NR == 1 && /^#!/ { print ""; next } { print }' "$PROG"
} > "$SRC"
"$ROOT/native/build.sh" "$SRC" "$OUT" "$LIB"
cat > "$OUT/$BASE.rex" <<EOF
/* $BASE.rex: runs $(basename -- "$PROG") compiled by rx2cpp (lib$LIB): native/compile_program.sh */
rx2cppMain = .context~package~findRoutine('RX2CPP_MAIN')
rx2cppMain~callWith(arg(1, 'A'))
if var('RESULT') then exit result
exit
::requires '$LIB' library
EOF
echo "compiled program: $OUT/$BASE.rex (library $OUT/lib$LIB.so)"
