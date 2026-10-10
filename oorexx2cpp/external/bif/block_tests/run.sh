#!/bin/sh
# Independent native BIF block qualification (no compiler changes).
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
CXX=${CXX:-c++}
REXX_BIN=${REXX_BIN:?point REXX_BIN at the ooRexx 5.3 interpreter}
RX2CPP_BASE=${RX2CPP_BASE:?point RX2CPP_BASE at unchanged compiler include/}
BUILD_DIR=${BUILD_DIR:-"$ROOT/block_tests/_build"}
mkdir -p "$BUILD_DIR"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$RX2CPP_BASE/include" -I"$ROOT/native" \
  "$ROOT/native/rxbif.cpp" "$ROOT/block_tests/native_runner.cpp" -o "$BUILD_DIR/native_runner"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$RX2CPP_BASE/include" -I"$ROOT/native" \
  "$ROOT/native/rxbif.cpp" "$ROOT/block_tests/negative_cases.cpp" -o "$BUILD_DIR/negative_cases"
"$BUILD_DIR/negative_cases"
"$REXX_BIN" "$ROOT/block_tests/oracle.rex" > "$ROOT/block_tests/matrix.oracle"
"$REXX_BIN" "$ROOT/block_tests/range.rex" > "$ROOT/block_tests/range.oracle"
"$BUILD_DIR/native_runner" "$ROOT/block_tests/matrix.tsv" > "$ROOT/block_tests/matrix.native"
"$BUILD_DIR/native_runner" "$ROOT/block_tests/range.tsv" > "$ROOT/block_tests/range.native"
python3 "$ROOT/block_tests/verify.py"
echo 'PASS invalid-input classification: 48 checks'
