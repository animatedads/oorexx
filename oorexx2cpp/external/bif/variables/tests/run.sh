#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname "$0")/../.." && pwd)
: "${RX2CPP_BASE:?Set read-only rx2cpp v0.25 source root}"
: "${OO_ROOT:?Set staged ooRexx prefix}"
CXX=${CXX:-g++}
BUILD_DIR=${BUILD_DIR:-"${TMPDIR:-/tmp}/rxbif-v011-$(basename "$CXX")"}
mkdir -p "$BUILD_DIR/generated"
export REXX_PATH="$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$ROOT"
"$OO_ROOT/bin/rexx" variables/bif2variables.rex variables/fixtures/BuiltinFunctions.variables.cpp "$BUILD_DIR/generated" | tee "$BUILD_DIR/convert.log"
test "$(find "$BUILD_DIR/generated" -maxdepth 1 -name 'Bif_*.cls' | wc -l)" -eq 3
REXX_PATH="$BUILD_DIR/generated:$ROOT" "$OO_ROOT/bin/rexx" variables/tests/test_generated_rules.rex
for kind in symbol_arity symbol_retriever var_arity var_exists value_arity value_assign value_selector; do
  case "$kind" in
    symbol_arity) sed 's/SYMBOL_Max = 1/SYMBOL_Max = 2/' variables/fixtures/BuiltinFunctions.variables.cpp > "$BUILD_DIR/drift.cpp" ;;
    symbol_retriever) sed 's/VariableDictionary::getVariableRetriever(name)/VariableDictionary::getVariable(name)/' variables/fixtures/BuiltinFunctions.variables.cpp > "$BUILD_DIR/drift.cpp" ;;
    var_arity) sed 's/VAR_Max = 1/VAR_Max = 2/' variables/fixtures/BuiltinFunctions.variables.cpp > "$BUILD_DIR/drift.cpp" ;;
    var_exists) sed 's/retriever->exists(context)/retriever->existsElsewhere(context)/' variables/fixtures/BuiltinFunctions.variables.cpp > "$BUILD_DIR/drift.cpp" ;;
    value_arity) sed 's/VALUE_Max = 3/VALUE_Max = 2/' variables/fixtures/BuiltinFunctions.variables.cpp > "$BUILD_DIR/drift.cpp" ;;
    value_assign) sed 's/retriever->assign(context, newvalue)/retriever->replace(context, newvalue)/' variables/fixtures/BuiltinFunctions.variables.cpp > "$BUILD_DIR/drift.cpp" ;;
    value_selector) sed 's/SystemInterpreter::valueFunction/SystemInterpreter::environmentValue/' variables/fixtures/BuiltinFunctions.variables.cpp > "$BUILD_DIR/drift.cpp" ;;
  esac
  if "$OO_ROOT/bin/rexx" variables/bif2variables.rex "$BUILD_DIR/drift.cpp" "$BUILD_DIR/generated" > "$BUILD_DIR/drift-$kind.log" 2>&1; then
    echo "FAIL upstream source drift accepted: $kind" >&2;exit 1
  fi
done
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror \
 -I"$ROOT/native" -I"$ROOT/variables" -I"$BUILD_DIR/generated" -I"$RX2CPP_BASE/include" \
 "$ROOT/variables/rxbif_variables.cpp" "$ROOT/native/rxbif_breadth.cpp" "$ROOT/native/rxbif.cpp" \
 "$ROOT/variables/tests/variable_activation.cpp" -o "$BUILD_DIR/variable_activation"
"$OO_ROOT/bin/rexx" variables/tests/oracle.rex > "$BUILD_DIR/oracle.txt"
"$BUILD_DIR/variable_activation" > "$BUILD_DIR/native.txt"
diff -u "$BUILD_DIR/oracle.txt" "$BUILD_DIR/native.txt"
echo "PASS $(basename "$CXX") SYMBOL/VAR/VALUE verified C++ vs original ooRexx selected microcases"
