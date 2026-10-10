#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
RX2CPP_BASE=${RX2CPP_BASE:?point to unpacked unchanged rx2cpp}
OO_ROOT=${OO_ROOT:?point to unpacked ooRexx root}
REXX_BIN=${REXX_BIN:-"$OO_ROOT/bin/rexx"}
CXX=${CXX:-g++}
BUILD_DIR=${BUILD_DIR:-"$ROOT/tests/_breadth"}
mkdir -p "$BUILD_DIR"
cd "$ROOT"
# The complete source is supplied by the integration lane; this fixture is an
# upstream VERBATIM excerpt and thus EXPECTED to leave 69 names missing.
set +e
REXX_PATH="$ROOT${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" bif2breadth.rex fixtures/BuiltinFunctions.excerpt.cpp "$BUILD_DIR" > "$BUILD_DIR/scan.log"
rc=$?
set -e
if [ "$rc" -ne 3 ]; then echo "Expected 69 missing fixture BIFs (rc=3), got $rc"; exit 1; fi
grep -q '12 / 81 missing: 69 rejected: 0' "$BUILD_DIR/scan.log"
[ "$(find "$BUILD_DIR" -maxdepth 1 -name 'Bif_*.cls' | wc -l)" -eq 12 ]
# A BUILTIN-looking macro embedded in a C++ comment or string is NOT code.
REXX_PATH="$ROOT${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" tests/source_scan_comments.rex \
  tests/BuiltinFunctions.adversarial.cpp
# Synthetic full-inventory scan must produce all 81 .cls rules and C++ wrappers.
REXX_PATH="$ROOT${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" tests/make_inventory_fixture.rex "$BUILD_DIR/synthetic.cpp"
mkdir -p "$BUILD_DIR/full"
REXX_PATH="$ROOT${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" bif2breadth.rex "$BUILD_DIR/synthetic.cpp" "$BUILD_DIR/full" > "$BUILD_DIR/full.log"
grep -q '81 / 81 missing: 0 rejected: 0' "$BUILD_DIR/full.log"
[ "$(find "$BUILD_DIR/full" -maxdepth 1 -name 'Bif_*.cls' | wc -l)" -eq 81 ]
REXX_PATH="$BUILD_DIR/full:$ROOT${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" tests/test_breadth_rules.rex
# Fail-closed source drift: changed arity is not qualified, even in catalogue.
sed 's/CENTER_Min = 2/CENTER_Min = 7/' fixtures/BuiltinFunctions.excerpt.cpp > "$BUILD_DIR/drift.cpp"
mkdir -p "$BUILD_DIR/drift"
set +e
REXX_PATH="$ROOT${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" bif2breadth.rex "$BUILD_DIR/drift.cpp" "$BUILD_DIR/drift" > "$BUILD_DIR/drift.log"
drift_rc=$?
set -e
[ "$drift_rc" -eq 3 ]
grep -q "CENTER.*REJECTED" "$BUILD_DIR/drift/coverage.breadth.tsv"
"$CXX" -std=c++17 -Wall -Wextra -Werror -O2 \
    -I"$RX2CPP_BASE/include" -I"$ROOT/native" -I"$OO_ROOT/include" -I"$BUILD_DIR/full" -I"$BUILD_DIR" \
    "$ROOT/native/rxbif.cpp" "$ROOT/native/rxbif_breadth.cpp" \
    "$ROOT/native/rxbif_oorexx_bridge.cpp" "$ROOT/tests/breadth_bridge.cpp" \
    -L"$OO_ROOT/lib" -lrexx -lrexxapi -o "$BUILD_DIR/breadth_bridge"
"$BUILD_DIR/breadth_bridge" "$ROOT/native/isolated_chainback.rex"
