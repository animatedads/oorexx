#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
: "${OO_ROOT:?ooRexx installation required}"
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
work=${BUILD_DIR:-$(mktemp -d)}
mkdir -p "$work"
cp "$here/SignBuiltin.cpp" "$work/SignChangedMethod.cpp"
sed -i 's/return n->sign()/return n->abs()/' "$work/SignChangedMethod.cpp"
cp "$here/SignBuiltin.cpp" "$work/SignChangedSignature.cpp"
sed -i 's/SIGN_Max = 1/SIGN_Max = 2/' "$work/SignChangedSignature.cpp"
cd "$root"
"$REXX_BIN" "$here/test_sign_rules.rex" "$here/SignBuiltin.cpp" NATIVE_SUBSET
"$REXX_BIN" "$here/test_sign_rules.rex" "$work/SignChangedMethod.cpp" HOST_ACTIVATION
"$REXX_BIN" "$here/test_sign_rules.rex" "$work/SignChangedSignature.cpp" REJECTED
