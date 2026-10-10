#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
OO_INCLUDE=${OO_INCLUDE:-$OO_ROOT/include}
OO_LIB=${OO_LIB:-$OO_ROOT/lib}
CXX=${CXX:-g++}
HYBRID_BUILD_DIR=${HYBRID_BUILD_DIR:-$ROOT/build/hybrid}
mkdir -p "$HYBRID_BUILD_DIR"
"$CXX" -std=c++17 -fPIC -O2 -Wall -Wextra -Werror -I"$OO_INCLUDE" -I"$ROOT/hybrid" \
    -shared "$ROOT/hybrid/native_bridge.cpp" -o "$HYBRID_BUILD_DIR/librx2cppbridge.so"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$OO_INCLUDE" -I"$ROOT/hybrid" \
    "$ROOT/hybrid/host.cpp" -L"$HYBRID_BUILD_DIR" -L"$OO_LIB" -lrx2cppbridge -lrexx -lrexxapi \
    -Wl,-rpath,'$ORIGIN' -o "$HYBRID_BUILD_DIR/hybrid-host"
export LD_LIBRARY_PATH="$OO_LIB:$HYBRID_BUILD_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$HYBRID_BUILD_DIR/hybrid-host" "$ROOT/hybrid/proxy_macro.rex" | tee "$HYBRID_BUILD_DIR/output.txt"
cat > "$HYBRID_BUILD_DIR/expected.txt" <<'EXPECTED'
native->interpreter-array: 1
interpreter-proxy->compiled-counter: 17
compiled->interpreter-formatter->compiled: native:[mixed]
compiled-counter-state: 17
EXPECTED
cmp "$HYBRID_BUILD_DIR/output.txt" "$HYBRID_BUILD_DIR/expected.txt"
echo 'PASS macrospace bidirectional native/interpreter bridge'
