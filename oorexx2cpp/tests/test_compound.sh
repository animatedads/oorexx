#!/usr/bin/env bash
# Narrow, reproducible interpreter-vs-native compound-variable qualification.
set -euo pipefail
# Legacy standalone qualification links only the original runtime.
# Exercise external BIF integration separately in test_bif_dynamic_v028.sh.
export RX2CPP_BIF_DISABLED=1
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/compound-$($CXX -dumpmachine 2>/dev/null || echo cxx)"}
mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
passed=0
for name in compound_semantics compound_loop compound_multitail compound_trailing; do
    src="$ROOT/examples/$name.rex"
    "$REXX_BIN" "$src" >"$WORK/$name.expected"
    "$ROOT/run-compiler.sh" "$src" "$WORK/$name.cpp"
    "$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$ROOT/include" "$WORK/$name.cpp" -o "$WORK/$name.native"
    "$WORK/$name.native" >"$WORK/$name.actual"
    cmp "$WORK/$name.expected" "$WORK/$name.actual" || { diff -u "$WORK/$name.expected" "$WORK/$name.actual"; exit 1; }
    echo "PASS $name"
    passed=$((passed+1))
done
# Ensure future BIF/macro features are not silently interpreted as compounds.
printf 'x = .environment~of(1,2)\n' > "$WORK/unsupported.rex"
rm -f "$WORK/unsupported.cpp"
# Without the hosted tier (RX2CPP_HOSTED=0) environment objects do not exist: the compile must fail, leaving nothing.
if RX2CPP_HOSTED=0 "$ROOT/run-compiler.sh" "$WORK/unsupported.rex" "$WORK/unsupported.cpp" >"$WORK/unsupported.log" 2>&1; then
    echo 'FAIL unsupported object syntax accepted' >&2; exit 1
fi
[[ ! -e "$WORK/unsupported.cpp" ]] || { echo 'FAIL partial C++ created' >&2; exit 1; }
grep -Eq 'rx2cpp:[0-9]+:[0-9]+:' "$WORK/unsupported.log"
echo "PASS fail-closed unimplemented object syntax"
# With the hosted tier (the default) it is a message to the interpreter's own .ENVIRONMENT, never a compound variable.
"$ROOT/run-compiler.sh" "$WORK/unsupported.rex" "$WORK/hosted.cpp" >"$WORK/hosted.log" 2>&1 || { cat "$WORK/hosted.log" >&2; echo 'FAIL hosted .ENVIRONMENT message rejected' >&2; exit 1; }
grep -q 'rx::host::environmentDirectory("ENVIRONMENT")' "$WORK/hosted.cpp" && grep -q '"OF"' "$WORK/hosted.cpp" \
    || { echo 'FAIL .ENVIRONMENT~OF not compiled as a message to the interpreter' >&2; exit 1; }
echo "PASS hosted .ENVIRONMENT message (not a compound)"
echo "QUALIFIED $passed output parity fixtures, 1 rejection; CXX=$CXX"
