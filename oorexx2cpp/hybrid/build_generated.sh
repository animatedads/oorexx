#!/usr/bin/env bash
# Full source-driven OO compiler -> C++ class -> live macrospace proxy -> ooRexx.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
OO_INCLUDE=${OO_INCLUDE:-$OO_ROOT/include}
OO_LIB=${OO_LIB:-$OO_ROOT/lib}
CXX=${CXX:-g++}
REXX_BIN=${REXX_BIN:-rexx}
REXX_LIB=${REXX_LIB:-$OO_LIB}
HYBRID_BUILD_DIR=${HYBRID_BUILD_DIR:-$ROOT/build/generated}
mkdir -p "$HYBRID_BUILD_DIR"
export REXX_PATH="$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OO_LIB:$HYBRID_BUILD_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$ROOT/run-hybrid-compiler.sh" "$ROOT/hybrid/accumulator.cls" "$HYBRID_BUILD_DIR/generated"
"$CXX" -std=c++17 -O2 -fPIC -Wall -Wextra -Werror \
    -I"$OO_INCLUDE" -I"$ROOT/hybrid" -I"$ROOT/include" -I"$HYBRID_BUILD_DIR" \
    -shared "$ROOT/hybrid/native_bridge.cpp" "$HYBRID_BUILD_DIR/generated.cpp" \
    -o "$HYBRID_BUILD_DIR/librx2cppbridge.so"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror \
    -I"$OO_INCLUDE" -I"$ROOT/hybrid" -I"$ROOT/include" -I"$HYBRID_BUILD_DIR" \
    "$ROOT/hybrid/generated_host.cpp" -L"$HYBRID_BUILD_DIR" -L"$OO_LIB" \
    -lrx2cppbridge -lrexx -lrexxapi -Wl,-rpath,'$ORIGIN' \
    -o "$HYBRID_BUILD_DIR/generated-host"
"$REXX_BIN" "$ROOT/hybrid/accumulator_oracle.rex" >"$HYBRID_BUILD_DIR/interpreter.stdout"
"$HYBRID_BUILD_DIR/generated-host" "$HYBRID_BUILD_DIR/generated_proxy.rex" \
    "$ROOT/hybrid/generated_macro_driver.rex" >"$HYBRID_BUILD_DIR/native.stdout"
cmp "$HYBRID_BUILD_DIR/interpreter.stdout" "$HYBRID_BUILD_DIR/native.stdout"
printf 'PASS generated OO class & interpreter proxy parity: %s\n' "$CXX"
