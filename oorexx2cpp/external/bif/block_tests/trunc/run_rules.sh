#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
bif=$(cd "$here/../.." && pwd)
: "${OO_ROOT:?ooRexx installation required}"
export PATH="$OO_ROOT/bin:$PATH" LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
work=${BUILD_DIR:-$(mktemp -d)}
mkdir -p "$work"
cp "$here/TruncBuiltin.cpp" "$work/drift_method.cpp"
sed -i 's/return number->trunc(n)/return number->abs(n)/' "$work/drift_method.cpp"
cp "$here/TruncBuiltin.cpp" "$work/drift_arity.cpp"
sed -i 's/TRUNC_Max = 2/TRUNC_Max = 3/' "$work/drift_arity.cpp"
cd "$bif"
"${REXX_BIN:-$OO_ROOT/bin/rexx}" "$here/test_trunc_rules.rex" "$here/TruncBuiltin.cpp" NATIVE_SUBSET
"${REXX_BIN:-$OO_ROOT/bin/rexx}" "$here/test_trunc_rules.rex" "$work/drift_method.cpp" HOST_ACTIVATION
"${REXX_BIN:-$OO_ROOT/bin/rexx}" "$here/test_trunc_rules.rex" "$work/drift_arity.cpp" REJECTED
