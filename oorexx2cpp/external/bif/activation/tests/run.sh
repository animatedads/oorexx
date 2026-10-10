#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
: "${RX2CPP_BASE:?Set RX2CPP_BASE to extracted read-only rx2cpp v0.28 root}"
: "${RX2CPP_EXTLIB_ROOT:?Set RX2CPP_EXTLIB_ROOT to extracted rx2cpp-extlib v0.1 root}"
: "${OO_ROOT:?Set OO_ROOT to the staged ooRexx 5.3 installation root}"
CXX=${CXX:-g++}
BUILD_DIR=${BUILD_DIR:-"${TMPDIR:-/tmp}/rxbif-v013-$(basename "$CXX")"}
mkdir -p "$BUILD_DIR"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -Wno-unused-parameter \
  -I"$ROOT/native" -I"$ROOT/variables" -I"$ROOT/frame" -I"$ROOT/control" \
  -I"$ROOT/activation" -I"$RX2CPP_BASE/include" \
  -I"$RX2CPP_EXTLIB_ROOT/include" -I"$OO_ROOT/include" \
  "$ROOT/activation/tests/v028_integration.cpp" \
  "$ROOT/native/rxbif.cpp" "$ROOT/native/rxbif_breadth.cpp" \
  "$ROOT/variables/rxbif_variables.cpp" "$ROOT/frame/rxbif_frame.cpp" \
  "$ROOT/control/rxbif_control.cpp" -ldl -o "$BUILD_DIR/interop"
"$BUILD_DIR/interop" "$OO_ROOT/lib"
