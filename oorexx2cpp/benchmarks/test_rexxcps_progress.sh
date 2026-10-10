#!/usr/bin/env bash
# Test the RexxCPS-derived repetition DO / counted DO kernel.
# Environment: REXX_BIN, REXX_LIB, CXX. No hardwired host paths.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
BUILD=${BUILD:-"$ROOT/build/rexxcps-progress"}
mkdir -p "$BUILD"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
for name in do_repeat do_repeat_nested rexxcps_loop_kernel; do
    "$ROOT/run-compiler.sh" "$ROOT/examples/$name.rex" "$BUILD/$name.cpp"
    "$CXX" -std=c++17 -O2 -Wall -Wextra -I"$ROOT/include" "$BUILD/$name.cpp" -o "$BUILD/$name.native"
    "$REXX_BIN" "$ROOT/examples/$name.rex" >"$BUILD/$name.oracle"
    "$BUILD/$name.native" >"$BUILD/$name.actual"
    cmp "$BUILD/$name.oracle" "$BUILD/$name.actual"
    echo "PASS $name interpreter/native parity"
done
# Reject invalid DO control forms at compile time with no partial artifact.
for form in 'do while 1' 'do forever' 'do until' 'do'; do
    printf '%s\n%s\n' "$form" 'end' >"$BUILD/invalid.rex"
    rm -f "$BUILD/invalid.cpp"
    if "$ROOT/run-compiler.sh" "$BUILD/invalid.rex" "$BUILD/invalid.cpp" >"$BUILD/invalid.log" 2>&1; then
        echo "FAIL unexpected acceptance: $form" >&2; exit 1
    fi
    test ! -e "$BUILD/invalid.cpp"
    grep -E 'rx2cpp:[0-9]+:[0-9]+:' "$BUILD/invalid.log" >/dev/null
    echo "PASS fail-closed $form"
done
# Runtime rejects unsupported numeric DO count (error, not a silent loop).
printf "do -2\n say 'bad'\nend\n" >"$BUILD/negative.rex"
"$ROOT/run-compiler.sh" "$BUILD/negative.rex" "$BUILD/negative.cpp"
"$CXX" -std=c++17 -O2 -I"$ROOT/include" "$BUILD/negative.cpp" -o "$BUILD/negative.native"
if "$BUILD/negative.native" >"$BUILD/negative.stdout" 2>"$BUILD/negative.stderr"; then
    echo 'FAIL negative repeat count executed' >&2; exit 1
fi
grep -q 'DO repetition count must be nonnegative' "$BUILD/negative.stderr"
echo 'PASS negative repetition count rejected'
echo '8 checks passed'
