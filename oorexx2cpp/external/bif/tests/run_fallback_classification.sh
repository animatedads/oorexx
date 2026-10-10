#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${RX2CPP_BASE:?Set RX2CPP_BASE to the unchanged rx2cpp v0.25 root}"
CXX=${CXX:-g++}
BUILD_DIR=${BUILD_DIR:-"$ROOT/tests/_fallback"}
mkdir -p "$BUILD_DIR"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$RX2CPP_BASE/include" -I"$ROOT/native" \
 "$ROOT/native/rxbif.cpp" "$ROOT/native/rxbif_breadth.cpp" \
 "$ROOT/tests/fallback_classification.cpp" -o "$BUILD_DIR/fallback_classification"
"$BUILD_DIR/fallback_classification"
