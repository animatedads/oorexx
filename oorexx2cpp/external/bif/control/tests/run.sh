#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname "$0")/../.." && pwd)
: "${RX2CPP_BASE:?Set read-only rx2cpp v0.27 source root}"
: "${OO_ROOT:?Set ooRexx prefix}"
CXX=${CXX:-g++}
BUILD_DIR=${BUILD_DIR:-"${TMPDIR:-/tmp}/rxbif-v012-$(basename "$CXX")"}
mkdir -p "$BUILD_DIR/generated"
cd "$ROOT"
export REXX_PATH="$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$OO_ROOT/bin/rexx" control/bif2control.rex control/fixtures/BuiltinFunctions.control.cpp "$BUILD_DIR/generated" | tee "$BUILD_DIR/convert.log"
[ "$(find "$BUILD_DIR/generated" -name 'Bif_*.cls' | wc -l)" -eq 3 ]
REXX_PATH="$BUILD_DIR/generated:$ROOT" "$OO_ROOT/bin/rexx" control/tests/test_generated_rules.rex
for which in sourceline_arity sourceline_package sourceline_fetch trace_arity trace_previous trace_set condition_arity condition_get condition_reset condition_copy comment_spoof; do
    case "$which" in
    sourceline_arity) sed 's/SOURCELINE_Max = 1/SOURCELINE_Max = 2/' control/fixtures/BuiltinFunctions.control.cpp > "$BUILD_DIR/drift.cpp" ;;
    sourceline_package) sed 's/getEffectivePackageObject()/getPackageObject()/' control/fixtures/BuiltinFunctions.control.cpp > "$BUILD_DIR/drift.cpp" ;;
    sourceline_fetch) sed 's/package->getLine(line_number)/package->getLineText(line_number)/' control/fixtures/BuiltinFunctions.control.cpp > "$BUILD_DIR/drift.cpp" ;;
    trace_arity) sed 's/TRACE_Max = 1/TRACE_Max = 2/' control/fixtures/BuiltinFunctions.control.cpp > "$BUILD_DIR/drift.cpp" ;;
    trace_previous) sed 's/traceSetting()/oldTraceSetting()/' control/fixtures/BuiltinFunctions.control.cpp > "$BUILD_DIR/drift.cpp" ;;
    trace_set) sed 's/setTrace(setting)/changeTrace(setting)/' control/fixtures/BuiltinFunctions.control.cpp > "$BUILD_DIR/drift.cpp" ;;
    condition_arity) sed 's/CONDITION_Max = 1/CONDITION_Max = 2/' control/fixtures/BuiltinFunctions.control.cpp > "$BUILD_DIR/drift.cpp" ;;
    condition_get) sed 's/getConditionObj()/getTrapCondition()/' control/fixtures/BuiltinFunctions.control.cpp > "$BUILD_DIR/drift.cpp" ;;
    condition_reset) sed 's/setConditionObj(OREF_NULL)/clearCondition()/' control/fixtures/BuiltinFunctions.control.cpp > "$BUILD_DIR/drift.cpp" ;;
    condition_copy) sed 's/conditionobj->copy()/conditionobj->asString()/' control/fixtures/BuiltinFunctions.control.cpp > "$BUILD_DIR/drift.cpp" ;;
    comment_spoof) sed 's/context->traceSetting()/context->badTraceSetting() \/\* context->traceSetting() \*\//' control/fixtures/BuiltinFunctions.control.cpp > "$BUILD_DIR/drift.cpp" ;;
    esac
    if "$OO_ROOT/bin/rexx" control/bif2control.rex "$BUILD_DIR/drift.cpp" "$BUILD_DIR/generated" > "$BUILD_DIR/drift-$which.log" 2>&1; then
        echo "FAIL: upstream source drift accepted: $which" >&2
        exit 1
    fi
done
"$OO_ROOT/bin/rexx" control/bif2control.rex control/fixtures/BuiltinFunctions.control.cpp "$BUILD_DIR/generated" >/dev/null
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$ROOT/native" -I"$ROOT/control" -I"$BUILD_DIR/generated" -I"$RX2CPP_BASE/include" \
    "$ROOT/control/rxbif_control.cpp" "$ROOT/native/rxbif_breadth.cpp" "$ROOT/native/rxbif.cpp" \
    "$ROOT/control/tests/control_activation.cpp" -o "$BUILD_DIR/control_activation"
"$OO_ROOT/bin/rexx" control/tests/oracle.rex > "$BUILD_DIR/oracle.txt"
"$BUILD_DIR/control_activation" > "$BUILD_DIR/native.txt"
diff -u "$BUILD_DIR/oracle.txt" "$BUILD_DIR/native.txt"
"$OO_ROOT/bin/rexx" control/tests/condition_oracle.rex > "$BUILD_DIR/condition_reference.txt"
"$BUILD_DIR/control_activation" --trapped > "$BUILD_DIR/condition_native.txt"
diff -u "$BUILD_DIR/condition_reference.txt" "$BUILD_DIR/condition_native.txt"
echo "PASS $(basename "$CXX") source-derived SOURCELINE/TRACE/CONDITION caller-control adapters"
