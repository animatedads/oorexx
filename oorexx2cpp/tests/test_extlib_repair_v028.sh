#!/usr/bin/env bash
# Optional, separate-lane external native typed-library host contract test.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# The repaired rx2cpp_extlib (v0.1b: separate symbol and literal stem-tail hooks) is carried in this tree
# (include/rx2cpp_extlib.hpp); RX2CPP_EXTLIB_ROOT names an external copy to test instead.
RX2CPP_EXTLIB_ROOT=${RX2CPP_EXTLIB_ROOT:-$ROOT}
grep -q 'tailSet' "$RX2CPP_EXTLIB_ROOT/include/rx2cpp_extlib.hpp" || { echo "FAIL $RX2CPP_EXTLIB_ROOT/include/rx2cpp_extlib.hpp is not the repaired library (no literal stem-tail hooks)"; exit 1; }
: "${OO_ROOT:?Point to installed ooRexx prefix with include/oorexxapi.h}"
CXX=${CXX:-g++}
BUILD_DIR=${BUILD_DIR:-"${TMPDIR:-/tmp}/rx2cpp-extlib-repair-$(basename "$CXX")"}
mkdir -p "$BUILD_DIR"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -Wno-unused-parameter \
  -I"$ROOT/include" -I"$RX2CPP_EXTLIB_ROOT/include" -I"$OO_ROOT/include" \
  "$ROOT/tests/extlib_repair_poolstem.cpp" -ldl -o "$BUILD_DIR/extlib_repair_poolstem"
"$BUILD_DIR/extlib_repair_poolstem"
