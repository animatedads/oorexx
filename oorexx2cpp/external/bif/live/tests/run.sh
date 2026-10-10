#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
: "${RX2CPP_BASE:?Set RX2CPP_BASE to extracted unchanged rx2cpp v0.23}"
: "${OO_ROOT:?Set OO_ROOT to extracted ooRexx prefix}"
CXX=${CXX:-g++}
BUILD_DIR=${BUILD_DIR:-"$ROOT/live/tests/_build/$(basename "$CXX")"}
mkdir -p "$BUILD_DIR" "$BUILD_DIR/gen"
cd "$ROOT"
export LD_LIBRARY_PATH="$OO_ROOT/lib:$BUILD_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT${REXX_PATH:+:$REXX_PATH}"
"$OO_ROOT/bin/rexx" live/bif2live.rex live/fixtures/BuiltinFunctions.live3.cpp "$BUILD_DIR/gen"
[ "$(find "$BUILD_DIR/gen" -maxdepth 1 -name 'Bif_*.cls' | wc -l)" -eq 4 ]
REXX_PATH="$BUILD_DIR/gen:$ROOT${REXX_PATH:+:$REXX_PATH}" "$OO_ROOT/bin/rexx" live/tests/rules.rex
# Fail closed if a source declaration or the actual C++ implementation changes.
for case in arity body format_arity format_body; do
  if [ "$case" = arity ]; then
    sed 's/DIGITS_Max = 0/DIGITS_Max = 1/' live/fixtures/BuiltinFunctions.live3.cpp > "$BUILD_DIR/drift.cpp"
  elif [ "$case" = body ]; then
    sed 's/context->digits()/context->fuzz()/' live/fixtures/BuiltinFunctions.live3.cpp > "$BUILD_DIR/drift.cpp"
  elif [ "$case" = format_arity ]; then
    sed 's/FORMAT_Max = 5/FORMAT_Max = 4/' live/fixtures/BuiltinFunctions.live3.cpp > "$BUILD_DIR/drift.cpp"
  else
    sed 's/number->format(before, after, expp, expt)/number->format(before, after)/' live/fixtures/BuiltinFunctions.live3.cpp > "$BUILD_DIR/drift.cpp"
  fi
  if "$OO_ROOT/bin/rexx" live/bif2live.rex "$BUILD_DIR/drift.cpp" "$BUILD_DIR/gen" > "$BUILD_DIR/drift.log" 2>&1; then
    echo "ERROR: drift $case accepted" >&2; exit 1
  fi
  # Regenerate pristine source after intentional negative test, in case
  # future generators emit partial artifacts before failing.
  "$OO_ROOT/bin/rexx" live/bif2live.rex live/fixtures/BuiltinFunctions.live3.cpp "$BUILD_DIR/gen" > /dev/null
done
"$CXX" -std=c++17 -O2 -fPIC -shared -Wall -Wextra -Werror \
  -I"$ROOT/native" -I"$ROOT/live" -I"$BUILD_DIR/gen" \
  -I"$RX2CPP_BASE/include" -I"$OO_ROOT/include" \
  "$ROOT/live/rxbif_live_call.cpp" "$ROOT/live/rxbif_live_package.cpp" \
  "$ROOT/native/rxbif.cpp" "$ROOT/native/rxbif_breadth.cpp" \
  -L"$OO_ROOT/lib" -lrexx -lrexxapi -o "$BUILD_DIR/librxbif_live.so"
( cd "$ROOT/live/tests" && "$OO_ROOT/bin/rexx" probe.rex > "$BUILD_DIR/probe.log" )
grep -q '^default 9 0 SCIENTIFIC$' "$BUILD_DIR/probe.log"
grep -q '^changed 17 2 ENGINEERING$' "$BUILD_DIR/probe.log"
grep -q '^nested 12 1 SCIENTIFIC$' "$BUILD_DIR/probe.log"
grep -q '^default-format PASS FORMAT$' "$BUILD_DIR/probe.log"
grep -q '^digits4-format PASS FORMAT$' "$BUILD_DIR/probe.log"
grep -q '^engineering17-format PASS FORMAT$' "$BUILD_DIR/probe.log"
for label in default-chainback digits4-chainback engineering17-chainback; do
  grep -q "^$label PASS NUMERIC 4$" "$BUILD_DIR/probe.log"
done
grep -q '^PASS live invocation$' "$BUILD_DIR/probe.log"
for script in reject_arg.rex reject_unknown.rex reject_trace.rex reject_address.rex reject_format_bad.rex reject_format_missing.rex; do
  if ( cd "$ROOT/live/tests" && "$OO_ROOT/bin/rexx" "$script" > "$BUILD_DIR/$script.log" 2>&1 ); then
    echo "ERROR: $script expected explicit failure" >&2; exit 1
  fi
done
grep -q 'no qualified live activation adapter' "$BUILD_DIR/reject_arg.rex.log"
grep -q 'unknown ooRexx BUILTIN' "$BUILD_DIR/reject_unknown.rex.log"
grep -q 'no qualified live activation adapter' "$BUILD_DIR/reject_trace.rex.log"
grep -q 'no qualified live activation adapter' "$BUILD_DIR/reject_address.rex.log"
grep -q 'Error 93.943' "$BUILD_DIR/reject_format_bad.rex.log"
grep -q 'BIF FORMAT: missing required number' "$BUILD_DIR/reject_format_missing.rex.log"
echo "PASS: $CXX generated source rules=4, numeric context on all live pass-throughs: FORMAT/TRUNC/MAX/SIGN in default/changed/nested activations, arity/body drift (DIGITS and FORMAT), host-unsafe and unknown rejects"
