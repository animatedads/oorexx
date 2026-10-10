#!/usr/bin/env bash
# Actual ooRexx 5.3 vs native byte-level decimal qualification (no BIF changes).
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export RX2CPP_BIF_DISABLED=1
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/numeric-v029-$(basename "$CXX")"}
mkdir -p "$WORK"
count=0
for source in "$ROOT"/examples/numeric_v029/*.rex; do
    if [[ "${RX2CPP_NUMERIC_ONLY_NEGATIVES:-0}" == 1 ]]; then break; fi
    name=$(basename "$source" .rex)
    "$REXX_BIN" "$source" >"$WORK/$name.expected" 2>"$WORK/$name.oracle.err"
    "$ROOT/run-compiler.sh" "$source" "$WORK/$name.cpp"
    "$CXX" -std=c++17 "${RX2CPP_NUMERIC_OPT:--O0}" -Wall -Wextra -Werror -I"$ROOT/include" "$WORK/$name.cpp" -o "$WORK/$name.native"
    "$WORK/$name.native" >"$WORK/$name.actual" 2>"$WORK/$name.native.err"
    cmp "$WORK/$name.expected" "$WORK/$name.actual"
    printf 'PASS decimal %s (%s lines)\n' "$name" "$(wc -l < "$WORK/$name.expected")"
    count=$((count+1))
done
reject() {
    local label=$1 input=$2 file="$WORK/reject_$1.cpp"
    printf '%s\n' '// existing output must survive' > "$file"
    printf '%s\n' "$input" > "$WORK/reject_$label.rex"
    if "$ROOT/run-compiler.sh" "$WORK/reject_$label.rex" "$file" >"$WORK/reject_$label.err" 2>&1; then
        echo "FAIL accepted invalid source: $label" >&2; exit 1
    fi
    [[ "$(cat "$file")" == '// existing output must survive' ]] || {
        echo "FAIL changed output on failed parse: $label" >&2; exit 1;
    }
    grep -q 'rx2cpp:' "$WORK/reject_$label.err"
    echo "PASS protected rejection $label"
}
reject malformed_exponent $'say 1.5E+'
reject numeric_bad_form $'numeric form ENGINEERISH\nsay 1'
reject numeric_bad_mode $'numeric FLOAT 2\nsay 1'
reject numeric_bad_atom $'say (1.2e+)'
for code in 'numeric digits 0' $'numeric digits 4\nnumeric fuzz 4' 'say 2.0 / 0' 'say 10000000000 % 1'; do
    name=$(printf '%s' "$code" | tr -cs 'A-Za-z0-9' '_')
    printf '%s\n' "$code" > "$WORK/runtime_$name.rex"
    "$ROOT/run-compiler.sh" "$WORK/runtime_$name.rex" "$WORK/runtime_$name.cpp"
    "$CXX" -std=c++17 -O0 -Wall -Wextra -Werror -I"$ROOT/include" "$WORK/runtime_$name.cpp" -o "$WORK/runtime_$name.native"
    if "$WORK/runtime_$name.native" >"$WORK/runtime_$name.out" 2>"$WORK/runtime_$name.err"; then
        echo "FAIL runtime accepted invalid decimal operation: $code" >&2; exit 1
    fi
    grep -q 'rx2cpp runtime error:' "$WORK/runtime_$name.err"
done
printf 'PASS numeric v0.29: %s native/interpreter fixtures, 4 protected parser rejects, 5 runtime rejects; %s\n' "$count" "$CXX"
