#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname "$0")/../.." && pwd)
: "${RX2CPP_BASE:?Set RX2CPP_BASE to read-only rx2cpp v0.25 root}"
: "${OO_ROOT:?Set OO_ROOT to ooRexx installation prefix}"
CXX=${CXX:-g++}
BUILD_DIR=${BUILD_DIR:-"$ROOT/frame/tests/_build-$(basename "$CXX")"}
mkdir -p "$BUILD_DIR/generated"
cd "$ROOT"
export REXX_PATH="$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$OO_ROOT/bin/rexx" frame/bif2frame.rex frame/fixtures/BuiltinFunctions.frame.cpp "$BUILD_DIR/generated" | tee "$BUILD_DIR/convert.log"
[ "$(find "$BUILD_DIR/generated" -name 'Bif_*.cls' | wc -l)" -eq 2 ]
REXX_PATH="$BUILD_DIR/generated:$ROOT" "$OO_ROOT/bin/rexx" frame/tests/test_generated_rules.rex
"$OO_ROOT/bin/rexx" frame/tests/oracle.rex
for type in address_body address_arity arg_body arg_arity; do
  case "$type" in
    address_body) sed 's/context->getAddress()/context->getEnvironment()/' frame/fixtures/BuiltinFunctions.frame.cpp > "$BUILD_DIR/drift.cpp" ;;
    address_arity) sed 's/ADDRESS_Max = 0/ADDRESS_Max = 1/' frame/fixtures/BuiltinFunctions.frame.cpp > "$BUILD_DIR/drift.cpp" ;;
    arg_body) sed 's/getMethodArgumentCount()/getRoutineArgumentCount()/' frame/fixtures/BuiltinFunctions.frame.cpp > "$BUILD_DIR/drift.cpp" ;;
    arg_arity) sed 's/ARG_Max = 2/ARG_Max = 3/' frame/fixtures/BuiltinFunctions.frame.cpp > "$BUILD_DIR/drift.cpp" ;;
  esac
  if "$OO_ROOT/bin/rexx" frame/bif2frame.rex "$BUILD_DIR/drift.cpp" "$BUILD_DIR/generated" > "$BUILD_DIR/$type.log" 2>&1; then
    echo "FAIL drift accepted: $type" >&2; exit 1
  fi
done
"$OO_ROOT/bin/rexx" frame/bif2frame.rex frame/fixtures/BuiltinFunctions.frame.cpp "$BUILD_DIR/generated" >/dev/null
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror \
  -I"$ROOT/native" -I"$ROOT/frame" -I"$BUILD_DIR/generated" \
  -I"$RX2CPP_BASE/include" \
  "$ROOT/frame/rxbif_frame.cpp" "$ROOT/native/rxbif_breadth.cpp" "$ROOT/native/rxbif.cpp" \
  "$ROOT/frame/tests/frame_activation.cpp" -o "$BUILD_DIR/frame_activation"
"$BUILD_DIR/frame_activation"
echo "PASS $(basename "$CXX") frame adapters with source drift rejection"
