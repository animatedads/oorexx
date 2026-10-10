#!/usr/bin/env bash
# Optional, separate-lane external native typed-library host contract test.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${RX2CPP_EXTLIB_ROOT:?Point to repaired rx2cpp_extlib_v0.1 package}"
: "${OO_ROOT:?Point to installed ooRexx prefix with include/oorexxapi.h}"
CXX=${CXX:-g++}
BUILD_DIR=${BUILD_DIR:-"${TMPDIR:-/tmp}/rx2cpp-extlib-repair-$(basename "$CXX")"}
mkdir -p "$BUILD_DIR"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -Wno-unused-parameter \
  -I"$ROOT/include" -I"$RX2CPP_EXTLIB_ROOT/include" -I"$OO_ROOT/include" \
  "$ROOT/tests/extlib_repair_poolstem.cpp" -ldl -o "$BUILD_DIR/extlib_repair_poolstem"
"$BUILD_DIR/extlib_repair_poolstem"
