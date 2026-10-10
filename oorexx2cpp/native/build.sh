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
export REXX_PATH="$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OO_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
# Build in isolation so bad source or a failed C++ compilation cannot
# replace a previously qualified library or leave new partial generated files.
TMP=$(mktemp -d "$OUT/.rx2cpp-stage.XXXXXX")
trap 'rm -rf -- "$TMP"' EXIT
(cd "$ROOT" && "$REXX_BIN" rx2cpp_native_library.rex "$SOURCE" "$TMP/generated" "$PACKAGE")
"$CXX" -std=c++17 -O2 -fPIC -shared -Wall -Wextra -Werror \
    -I"$OO_INCLUDE" -I"$ROOT/include" -I"$ROOT/hybrid" -I"$TMP" \
    "$TMP/generated.cpp" "$TMP/generated_package.cpp" -o "$TMP/lib${PACKAGE}.so"
# Publish the binary last, after successful generation/linking.
mv -f "$TMP/generated.cpp" "$OUT/generated.cpp"
mv -f "$TMP/generated.hpp" "$OUT/generated.hpp"
mv -f "$TMP/generated_package.cpp" "$OUT/generated_package.cpp"
mv -f "$TMP/lib${PACKAGE}.so" "$OUT/lib${PACKAGE}.so"
printf 'Built native ooRexx library: %s\n' "$OUT/lib${PACKAGE}.so"
