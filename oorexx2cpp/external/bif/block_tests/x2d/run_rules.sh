#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BIF=$(cd -- "$HERE/../.." && pwd)
: "${OO_ROOT:?set OO_ROOT to the ooRexx interpreter installation}"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=${BUILD_DIR:-$(mktemp -d)}
mkdir -p "$OUT"
cp "$HERE/X2DBuiltin.cpp" "$OUT/drift_delegate.cpp"
sed -i 's/return string->x2d(n)/return string->x2c()/' "$OUT/drift_delegate.cpp"
cp "$HERE/X2DBuiltin.cpp" "$OUT/drift_arity.cpp"
sed -i 's/X2D_Max = 2/X2D_Max = 3/' "$OUT/drift_arity.cpp"
cd "$BIF"
"$REXX_BIN" "$HERE/test_rules.rex" "$HERE/X2DBuiltin.cpp" NATIVE_SUBSET
"$REXX_BIN" "$HERE/test_rules.rex" "$OUT/drift_delegate.cpp" HOST_ACTIVATION
"$REXX_BIN" "$HERE/test_rules.rex" "$OUT/drift_arity.cpp" REJECTED
