#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname "$0")/.." && pwd)
: "${REXX_BIN:=rexx}"
: "${REXX_LIB:=}"
: "${CXX:=g++}"
BIF=${RX2CPP_BIF_ROOT:-$ROOT/external/bif}
BUILD_DIR=${BUILD_DIR:-"${TMPDIR:-/tmp}/rx2cpp-v028-bif-$(basename "$CXX")"}
mkdir -p "$BUILD_DIR"
export REXX_BIN REXX_LIB RX2CPP_BIF_ROOT="$BIF"
if [[ -n "$REXX_LIB" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
for sample in bif_variable_v028 bif_variable_scope_v028 bif_variable_call_v028; do
  "$REXX_BIN" "$ROOT/examples/$sample.rex" > "$BUILD_DIR/$sample.oracle"
  "$ROOT/build.sh" "$ROOT/examples/$sample.rex" "$BUILD_DIR/$sample" > "$BUILD_DIR/$sample.build"
  "$BUILD_DIR/$sample" > "$BUILD_DIR/$sample.native"
  diff -u "$BUILD_DIR/$sample.oracle" "$BUILD_DIR/$sample.native"
  echo "PASS $CXX interpreter/native: $sample"
done
"$ROOT/build.sh" "$ROOT/examples/bif_variable_runtime_reject.rex" "$BUILD_DIR/reject" > "$BUILD_DIR/reject.build"
if "$BUILD_DIR/reject" > "$BUILD_DIR/reject.out" 2> "$BUILD_DIR/reject.err"; then
  echo 'FAIL external selector accepted' >&2; exit 1
fi
grep -q 'external selector not qualified' "$BUILD_DIR/reject.err"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror \
   -I"$ROOT/include" -I"$BIF/native" -I"$BIF/variables" \
   "$ROOT/tests/bif_activation_preflight.cpp" \
   "$BIF/native/rxbif.cpp" "$BIF/native/rxbif_breadth.cpp" "$BIF/variables/rxbif_variables.cpp" \
   -o "$BUILD_DIR/activation_preflight"
"$BUILD_DIR/activation_preflight"
# Other BIF implementations still route through v0.11: source-derived native.
cat > "$BUILD_DIR/existing_bif.rex" <<'REXX'
s='abcdef'
say substr(s,2,3)
say reverse(s)
say words('one two three')
REXX
"$REXX_BIN" "$BUILD_DIR/existing_bif.rex" > "$BUILD_DIR/existing.oracle"
"$ROOT/build.sh" "$BUILD_DIR/existing_bif.rex" "$BUILD_DIR/existing_bif" > "$BUILD_DIR/existing.build"
"$BUILD_DIR/existing_bif" > "$BUILD_DIR/existing.native"
diff -u "$BUILD_DIR/existing.oracle" "$BUILD_DIR/existing.native"
echo "PASS $CXX v0.11 native BIF and original compiler compatibility"
