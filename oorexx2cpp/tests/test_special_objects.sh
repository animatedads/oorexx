#!/usr/bin/env bash
# Native .NIL and hosted .OUTPUT/.ROUTINES interpreter-differential tests.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
: "${OO_ROOT:?ooRexx 5.3 installation root required}"
REXX_BIN=${REXX_BIN:-"$OO_ROOT/bin/rexx"}
CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-$(mktemp -d)}
if [[ -z ${TEST_OUTPUT_DIR:-} ]]; then trap 'rm -rf "$WORK"' EXIT; fi
mkdir -p "$WORK"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export RX2CPP_BIF_DISABLED=1
FIX="$ROOT/tests/fixtures/special_objects"
for name in nil_native hosted_symbols; do
    "$REXX_BIN" "$FIX/$name.rex" >"$WORK/$name.oracle"
    cmp "$FIX/$name.expected" "$WORK/$name.oracle"
    CXX="$CXX" "$ROOT/build.sh" "$FIX/$name.rex" "$WORK/$name.bin" "$WORK/$name.cpp" >"$WORK/$name.buildlog" 2>&1 || {
        cat "$WORK/$name.buildlog" >&2; exit 1;
    }
    "$WORK/$name.bin" >"$WORK/$name.native" 2>"$WORK/$name.stderr"
    if [[ -s "$WORK/$name.stderr" ]]; then cat "$WORK/$name.stderr" >&2; exit 1; fi
    cmp "$WORK/$name.oracle" "$WORK/$name.native"
    if [[ "$name" == nil_native ]]; then
        if grep -q 'rx_host_tier.hpp' "$WORK/$name.cpp"; then
            echo 'FAIL .NIL alone linked hosted interpreter' >&2; exit 1;
        fi
    else
        if ! grep -q 'rx_host_tier.hpp' "$WORK/$name.cpp"; then
            echo 'FAIL .OUTPUT/.ROUTINES did not use hosted tier' >&2; exit 1;
        fi
    fi
    echo "PASS $CXX $name (byte-exact ooRexx output)"
done
# Opt out must refuse hosted environment objects (not silently stringify them).
if RX2CPP_HOSTED=0 "$ROOT/run-compiler.sh" "$FIX/hosted_symbols.rex" "$WORK/disabled.cpp" >"$WORK/disabled.log" 2>&1; then
    echo 'FAIL hosted special objects accepted with RX2CPP_HOSTED=0' >&2; exit 1
fi
[[ ! -f "$WORK/disabled.cpp" ]] || { echo 'FAIL rejected build wrote C++' >&2; exit 1; }
echo "PASS $CXX hosted opt-out fails closed"
