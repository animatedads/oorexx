#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
: "${RX2CPP_BASE:?Set RX2CPP_BASE to the extracted v0.28.1 compiler root}"
CXX=${CXX:-g++}
OUT=${TEST_OUTPUT_DIR:-"${TMPDIR:-/tmp}/bif-v014-$(basename "$CXX")"}
mkdir -p "$OUT"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -Wno-unused-parameter -pthread \
 -I"$ROOT/native" -I"$ROOT/variables" -I"$ROOT/frame" \
 -I"$ROOT/control" -I"$ROOT/activation" -I"$RX2CPP_BASE/include" \
 "$ROOT/activation/tests/v0281_scoped.cpp" \
 "$ROOT/native/rxbif.cpp" "$ROOT/native/rxbif_breadth.cpp" \
 "$ROOT/variables/rxbif_variables.cpp" "$ROOT/frame/rxbif_frame.cpp" \
 "$ROOT/control/rxbif_control.cpp" -ldl -o "$OUT/scoped"
"$OUT/scoped"
