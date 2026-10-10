#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
RX2CPP_BASE=${RX2CPP_BASE:?RX2CPP_BASE must point to extracted, unmodified rx2cpp native ABI}
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-c++}
BUILD_DIR=${BUILD_DIR:-"$ROOT/tests/_generated"}
mkdir -p "$BUILD_DIR" "$BUILD_DIR/bad" "$BUILD_DIR/drift"
cd "$ROOT"
"$REXX_BIN" bif2inline.rex fixtures/BuiltinFunctions.excerpt.cpp "$BUILD_DIR"
test -s "$BUILD_DIR/rxbif.ir.tsv"
REXX_PATH="$BUILD_DIR${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" tests/test_rules.rex
# Prove dynamic Max/foreign BIFs are not admitted and emit no artifacts.
if "$REXX_BIN" bif2inline.rex tests/negative.cpp "$BUILD_DIR/bad" > "$BUILD_DIR/negative.log" 2>&1; then
  echo "FAIL dynamic source signature was accepted" >&2; exit 1
fi
test ! -e "$BUILD_DIR/bad/rxbif_generated.hpp"
# Source method drift cannot quietly invoke a stale native method.
sed 's/string->reverse()/string->futureMethod()/' fixtures/BuiltinFunctions.excerpt.cpp > "$BUILD_DIR/drift.cpp"
"$REXX_BIN" bif2inline.rex "$BUILD_DIR/drift.cpp" "$BUILD_DIR/drift" > "$BUILD_DIR/drift.log"
if grep -q 'BIF_REVERSE(' "$BUILD_DIR/drift/rxbif_generated.hpp"; then
  echo "FAIL source-drifted method admitted" >&2; exit 1
fi
grep -q '^REVERSE.*REJECTED' "$BUILD_DIR/drift/coverage.tsv"
# A receiver/argument-order change must also fail, EVEN when the method
# name and upstream arity have not changed.
mkdir -p "$BUILD_DIR/argdrift"
sed 's/string->center(length, pad)/string->center(pad, length)/' fixtures/BuiltinFunctions.excerpt.cpp > "$BUILD_DIR/argdrift.cpp"
"$REXX_BIN" bif2inline.rex "$BUILD_DIR/argdrift.cpp" "$BUILD_DIR/argdrift" > "$BUILD_DIR/argdrift.log"
if grep -q 'BIF_CENTER(' "$BUILD_DIR/argdrift/rxbif_generated.hpp"; then
  echo "FAIL argument-reshuffled source admitted" >&2; exit 1
fi
grep -q '^CENTER.*REJECTED' "$BUILD_DIR/argdrift/coverage.tsv"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$RX2CPP_BASE/include" -I"$ROOT/native" -I"$BUILD_DIR" \
  "$ROOT/native/rxbif.cpp" "$ROOT/tests/test_generated.cpp" -o "$BUILD_DIR/generated"
"$BUILD_DIR/generated"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$RX2CPP_BASE/include" -I"$ROOT/native" \
  "$ROOT/native/rxbif.cpp" "$ROOT/tests/differential.cpp" -o "$BUILD_DIR/differential"
"$BUILD_DIR/differential" --rexx > "$BUILD_DIR/oracle.rex"
"$REXX_BIN" "$BUILD_DIR/oracle.rex" > "$BUILD_DIR/reference"
"$BUILD_DIR/differential" > "$BUILD_DIR/native"
diff -u "$BUILD_DIR/reference" "$BUILD_DIR/native"
printf 'PASS %s additional independent Rexx/native parity cases\n' "$(wc -l < "$BUILD_DIR/reference")"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$RX2CPP_BASE/include" -I"$ROOT/native" \
  "$ROOT/native/rxbif.cpp" "$ROOT/tests/clock_differential.cpp" -o "$BUILD_DIR/clock_differential"
"$BUILD_DIR/clock_differential" --rexx > "$BUILD_DIR/clock_oracle.rex"
TZ=UTC "$REXX_BIN" "$BUILD_DIR/clock_oracle.rex" > "$BUILD_DIR/clock_reference"
TZ=UTC "$BUILD_DIR/clock_differential" > "$BUILD_DIR/clock_native"
diff -u "$BUILD_DIR/clock_reference" "$BUILD_DIR/clock_native"
printf 'PASS %s additional date/time native/interpreter parity cases\n' "$(wc -l < "$BUILD_DIR/clock_reference")"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$RX2CPP_BASE/include" -I"$ROOT/native" \
  "$ROOT/native/rxbif.cpp" "$ROOT/tests/clock_contract.cpp" -o "$BUILD_DIR/clock_contract"
TZ=UTC "$BUILD_DIR/clock_contract"
# TIME('T') and DATE('T') in ooRexx are timezone-independent civil timestamp
# conversions. TIME('O') reports the activation's timezone offset.
for zone in Europe/London America/New_York Asia/Kolkata Pacific/Auckland; do
    TZ="$zone" "$REXX_BIN" "$BUILD_DIR/clock_oracle.rex" > "$BUILD_DIR/clock_${zone##*/}_reference"
    TZ="$zone" "$BUILD_DIR/clock_differential" > "$BUILD_DIR/clock_${zone##*/}_native"
    diff -u "$BUILD_DIR/clock_${zone##*/}_reference" "$BUILD_DIR/clock_${zone##*/}_native"
    printf 'PASS 49 DATE/TIME cases in %s\n' "$zone"
done
