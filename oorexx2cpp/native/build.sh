#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if (( $# != 3 )); then echo 'Usage: native/build.sh class.cls output-dir package-name' >&2; exit 64; fi
SOURCE=$(cd "$(dirname -- "$1")" && pwd -P)/$(basename -- "$1")
mkdir -p "$2"
OUT=$(cd "$2" && pwd -P)
PACKAGE=$3
[[ "$PACKAGE" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]] || { echo 'Invalid native package name' >&2; exit 65; }
mkdir -p "$OUT"
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
OO_INCLUDE=${OO_INCLUDE:-$OO_ROOT/include}
OO_LIB=${OO_LIB:-$OO_ROOT/lib}
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
# The runtime's decimal arithmetic uses Boost.Multiprecision (headers only).
if ! printf '#include <boost/multiprecision/cpp_int.hpp>\n' | "$CXX" -std=c++17 -E -x c++ - >/dev/null 2>&1; then
    echo "rx2cpp: the Boost headers are needed (boost/multiprecision/cpp_int.hpp); on Debian / Ubuntu: sudo apt install libboost-dev" >&2
    exit 69
fi
export REXX_PATH="$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OO_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
# Build in isolation so bad source or a failed C++ compilation cannot
# replace a previously qualified library or leave new partial generated files.
TMP=$(mktemp -d "$OUT/.rx2cpp-stage.XXXXXX")
# RX2CPP_KEEP_STAGE=1 keeps the stage directory (generated C++) for inspection
trap '[[ -n "${RX2CPP_KEEP_STAGE:-}" ]] || rm -rf -- "$TMP"' EXIT
# Objects: .NAME classes and message sends use the host interpreter that loads this library
export RX2CPP_HOST_API=1
# BIFs: same add-on root and same dispatcher as build.sh (standalone programs)
if [[ "${RX2CPP_BIF_DISABLED:-0}" != 1 && -z "${RX2CPP_BIF_ROOT:-}" && -f "$ROOT/external/bif/catalog/bifs.tsv" ]]; then
    export RX2CPP_BIF_ROOT="$ROOT/external/bif"
fi
[[ "${RX2CPP_BIF_DISABLED:-0}" == 1 ]] && unset RX2CPP_BIF_ROOT
bifflags=( ); bifsrc=( )
if [[ -n "${RX2CPP_BIF_ROOT:-}" ]]; then
    bif="$RX2CPP_BIF_ROOT"
    bifflags=( -I"$bif/native" -I"$bif/variables" )
    bifsrc=( "$bif/native/rxbif.cpp" "$bif/native/rxbif_breadth.cpp" "$bif/variables/rxbif_variables.cpp" )
fi
# BIFs: same add-on root and same dispatcher as build.sh (standalone programs)
if [[ "${RX2CPP_BIF_DISABLED:-0}" != 1 && -z "${RX2CPP_BIF_ROOT:-}" && -f "$ROOT/external/bif/catalog/bifs.tsv" ]]; then
    export RX2CPP_BIF_ROOT="$ROOT/external/bif"
fi
[[ "${RX2CPP_BIF_DISABLED:-0}" == 1 ]] && unset RX2CPP_BIF_ROOT
bifflags=( ); bifsrc=( )
if [[ -n "${RX2CPP_BIF_ROOT:-}" ]]; then
    bif="$RX2CPP_BIF_ROOT"
    bifflags=( -I"$bif/native" -I"$bif/variables" )
    bifsrc=( "$bif/native/rxbif.cpp" "$bif/native/rxbif_breadth.cpp" "$bif/variables/rxbif_variables.cpp" )
fi
# Interpreted table: RX2CPP_TABLE=path, else <source>.rx2cpp next to the source (see native/NativeInterpretedTable.cls).
if [[ -z "${RX2CPP_TABLE:-}" && -f "${SOURCE%.*}.rx2cpp" ]]; then RX2CPP_TABLE="${SOURCE%.*}.rx2cpp"; fi
if [[ -n "${RX2CPP_TABLE:-}" ]]; then
    [[ -f "$RX2CPP_TABLE" ]] || { echo "rx2cpp: interpreted table not found: $RX2CPP_TABLE" >&2; exit 66; }
    RX2CPP_TABLE="$(cd "$(dirname -- "$RX2CPP_TABLE")" && pwd)/$(basename -- "$RX2CPP_TABLE")"; export RX2CPP_TABLE
fi
# A package spread over several .cls files (::REQUIRES 'other.cls') is combined into one source first.
if grep -qiE "^[[:space:]]*::requires[[:space:]]+['\"][^'\"]+\.cls['\"][[:space:]]*$" "$SOURCE"; then
    (cd "$(dirname -- "$SOURCE")" && "$REXX_BIN" "$ROOT/native/combine_package.rex" "$SOURCE" "$TMP/combined.cls" >/dev/null)
    SOURCE="$TMP/combined.cls"
fi
# A ::REQUIRES still in the source (not a LIBRARY, not found next to the source or on REXX_PATH, kept by
# RX2CPP_KEEP_INTERPRETED, or not a .cls file) is not compiled: the interpreter loads that package at run time. Say so:
# the program would otherwise look compiled when it is only partly.
grep -iE "^[[:space:]]*::requires[[:space:]]" "$SOURCE" | grep -viE "[[:space:];]library([[:space:];]|$)" | while IFS= read -r req; do
    echo "rx2cpp: warning: not compiled, loaded by the interpreter at run time: $(printf '%s' "$req" | sed -e 's/^[[:space:]]*//')" >&2
done || true
# RX2CPP_COMPILER_LIB=dir: generate with rx2cpp compiled by itself (dir/librx2cppc.so, see native/build_self.sh);
# the driver is rx2cpp_native_library.rex with its compiler packages replaced by that library. Same output, faster.
if [[ -n "${RX2CPP_COMPILER_LIB:-}" ]]; then
    [[ -f "$RX2CPP_COMPILER_LIB/librx2cppc.so" ]] || { echo "rx2cpp: no librx2cppc.so in $RX2CPP_COMPILER_LIB" >&2; exit 66; }
    { sed -e "/^::requires '/d" "$ROOT/rx2cpp_native_library.rex"; echo "::requires 'rx2cppc' library"; } > "$TMP/rx2cpp_driver.rex"
    (cd "$ROOT" && LD_LIBRARY_PATH="$RX2CPP_COMPILER_LIB:$LD_LIBRARY_PATH" "$REXX_BIN" "$TMP/rx2cpp_driver.rex" "$SOURCE" "$TMP/generated" "$PACKAGE")
else
    (cd "$ROOT" && "$REXX_BIN" rx2cpp_native_library.rex "$SOURCE" "$TMP/generated" "$PACKAGE")
fi
# Each library keeps its own copy of the runtime's inline variables (hooks, current context, library package): GCC would
# otherwise make them process-wide (STB_GNU_UNIQUE overrides -Bsymbolic) and two loaded libraries would share them.
uniqueflag=( )
if "$CXX" -fno-gnu-unique -x c++ -E /dev/null >/dev/null 2>&1; then uniqueflag=( -fno-gnu-unique ); fi
cxxflags=( -std=c++17 -O2 -fPIC -Wall -Wextra -Werror "${uniqueflag[@]}"
    -I"$OO_INCLUDE" -I"$ROOT/include" -I"$ROOT/hybrid" -I"$TMP" -DRX2CPP_HOST_API "${bifflags[@]}" )
objs=( )
for src in "$TMP/generated.cpp" "${bifsrc[@]}"; do
    obj="$TMP/obj_${#objs[@]}_$(basename -- "$src" .cpp).o"
    "$CXX" "${cxxflags[@]}" -c "$src" -o "$obj"
    objs+=( "$obj" )
done
"$CXX" "${cxxflags[@]}" -c "$TMP/generated_package.cpp" -o "$TMP/obj_package.o"
"$CXX" -shared -Wl,-Bsymbolic "${objs[@]}" "$TMP/obj_package.o" -o "$TMP/lib${PACKAGE}.so"
# interpreted_form tokenized (the default): rexxc tokenizes the declaration package. rexxc resolves the EXTERNAL
# methods, so it runs against the library just built; the image then replaces the embedded source.
if [[ -f "$TMP/generated_declaration.cls" ]]; then
    REXXC="$(dirname -- "$REXX_BIN")/rexxc"; [[ -x "$REXXC" ]] || REXXC=rexxc
    if ! (cd "$TMP" && RX2CPP_TOKENIZING=1 LD_LIBRARY_PATH="$TMP${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
          "$REXXC" generated_declaration.cls generated_declaration.rxc > generated_rexxc.log 2>&1); then
        echo "rx2cpp: rexxc failed on the declaration package (or put 'interpreted_form source' in the .rx2cpp table):" >&2
        grep -v -e '^Open Object Rexx' -e '^Build date' -e '^Addressing mode' -e '^Copyright' -e '^This program' -e '^of the Common' -e '^https://www.oorexx' "$TMP/generated_rexxc.log" >&2
        if grep -q 'Unable to load library' "$TMP/generated_rexxc.log"; then
            echo "rx2cpp: rexxc loads every ::REQUIRES ... LIBRARY dependency: add its directory to LD_LIBRARY_PATH for the build" >&2
        fi
        exit 65
    fi
    { od -An -v -td1 "$TMP/generated_declaration.rxc" | awk '{ for (i = 1; i <= NF; i++) printf "%s,", $i; print "" }'; echo 0; } \
        > "$TMP/generated_declaration_image.inc"
    awk '/\/\*RX2CPP_DECLARATION_BEGIN\*\// { print "static const char declaration[] = {"; print "#include \"generated_declaration_image.inc\""; print "};"; next } { print }' \
        "$TMP/generated_package.cpp" > "$TMP/generated_package_image.cpp"
    grep -q 'generated_declaration_image.inc' "$TMP/generated_package_image.cpp" || { echo "rx2cpp: declaration marker missing" >&2; exit 65; }
    mv -f "$TMP/generated_package_image.cpp" "$TMP/generated_package.cpp"
    "$CXX" "${cxxflags[@]}" -c "$TMP/generated_package.cpp" -o "$TMP/obj_package.o"
    "$CXX" -shared -Wl,-Bsymbolic "${objs[@]}" "$TMP/obj_package.o" -o "$TMP/lib${PACKAGE}.so"
fi
# Publish the binary last, after successful generation/linking.
mv -f "$TMP/generated.cpp" "$OUT/generated.cpp"
mv -f "$TMP/generated.hpp" "$OUT/generated.hpp"
mv -f "$TMP/generated_package.cpp" "$OUT/generated_package.cpp"
# Keep the declaration package (and its rexxc image) next to the library for diagnosis.
if [[ -f "$TMP/generated_declaration.cls" ]]; then mv -f "$TMP/generated_declaration.cls" "$OUT/${PACKAGE}_declaration.cls"; fi
if [[ -f "$TMP/generated_declaration.rxc" ]]; then mv -f "$TMP/generated_declaration.rxc" "$OUT/${PACKAGE}_declaration.rxc"; fi
# The published generated_package.cpp includes the tokenized image: publish it too, so the sources rebuild as they are.
if [[ -f "$TMP/generated_declaration_image.inc" ]]; then mv -f "$TMP/generated_declaration_image.inc" "$OUT/generated_declaration_image.inc"; fi
if [[ -f "$TMP/generated_interpreted.cls" ]]; then mv -f "$TMP/generated_interpreted.cls" "$OUT/${PACKAGE}_interpreted.cls"; fi
mv -f "$TMP/lib${PACKAGE}.so" "$OUT/lib${PACKAGE}.so"
# <lib>_requires.cls: what an interpreted program requires in place of the original source. Besides loading the library
# it imports the library's declaration package, so the library's public classes resolve in the requiring program as
# they would from the source package (before .LOCAL: a public class ERROR, not the .ERROR stream). A bare
# ::requires 'lib' LIBRARY only reaches them through .ENVIRONMENT.
upper=$(printf '%s' "$PACKAGE" | tr '[:lower:]' '[:upper:]')
printf "/* rx2cpp: require this file instead of the original source of native library %s. */\npkg = .environment['RX2CPP.PACKAGE.%s']\nif pkg \\\\== .nil then .context~package~addPackage(pkg)\n::requires '%s' library\n" \
    "$PACKAGE" "$upper" "$PACKAGE" > "$OUT/${PACKAGE}_requires.cls"
printf 'Built native ooRexx library: %s\n' "$OUT/lib${PACKAGE}.so"
