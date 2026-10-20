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
# RX2CPP_SEPARATE_PACKAGES=1: every package the program requires (found next to its requirer or on REXX_PATH) is built
# as its own native library first, dependencies first, named after its source file (lib rxp_<name>), and required as
# that library: each keeps its own package (.context~package~name, its ~local, findRoutine / findClass of what is not
# PUBLIC), as interpreted. Otherwise (default) they are combined into the program's one library: one package for all.
if [[ "${RX2CPP_SEPARATE_PACKAGES:-}" == 1 ]]; then
    map=${RX2CPP_LIBMAP:-}
    seenNames=" "
    while IFS= read -r dep; do
        [[ -n "$dep" ]] || continue
        name=$(basename -- "$dep")
        case "$seenNames" in *" ${name^^} "*) echo "compile_program.sh: two required packages are named $name: RX2CPP_SEPARATE_PACKAGES needs distinct names" >&2; exit 65;; esac
        seenNames="$seenNames${name^^} "
        dlib="rxp_$(printf '%s' "${name%.*}" | tr -c 'A-Za-z0-9' '_' | tr 'A-Z' 'a-z')"
        echo "compile_program.sh: package $dep -> lib$dlib.so"
        RX2CPP_LIBMAP="$map" RX2CPP_PACKAGE_NAME="$dep" RX2CPP_SOURCE_DIR="$(dirname -- "$dep")" \
            LD_LIBRARY_PATH="$OUT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$ROOT/native/build.sh" "$dep" "$OUT" "$dlib"
        map="${map:+$map }$name=$dlib"
    done < <(cd -- "$(dirname -- "$PROG")" && RX2CPP_SOURCE_DIR="$(dirname -- "$PROG")" "${REXX_BIN:-rexx}" "$ROOT/native/combine_package.rex" "$PROG" --order)
    export RX2CPP_LIBMAP="$map"
    export LD_LIBRARY_PATH="$OUT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
# Its ::REQUIRES are found as the interpreter finds them: next to the program first (its copy here is in OUTDIR), then on
# REXX_PATH (combine_package.rex, RX2CPP_SOURCE_DIR).
RX2CPP_SOURCE_DIR="$(dirname -- "$PROG")" RX2CPP_PACKAGE_NAME="$PROG" "$ROOT/native/build.sh" "$SRC" "$OUT" "$LIB"
cat > "$OUT/$BASE.rex" <<EOF
/* $BASE.rex: runs $(basename -- "$PROG") compiled by rx2cpp (lib$LIB): native/compile_program.sh */
rx2cppMain = .context~package~findRoutine('RX2CPP_MAIN')
rx2cppMain~callWith(arg(1, 'A'))
if var('RESULT') then exit result
exit
::requires '$LIB' library
EOF
echo "compiled program: $OUT/$BASE.rex (library $OUT/lib$LIB.so)"
