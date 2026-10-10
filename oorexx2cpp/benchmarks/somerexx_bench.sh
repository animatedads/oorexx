#!/usr/bin/env bash
# Benchmark the SAME Rexx source both interpreted and compiled to C++.
# Bash time measures execution wall-time, excluding C++ compilation and cmp.
# Redirect stdout to files to avoid terminal rendering costs.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
RUNS=${RUNS:-7}
DIR=${BENCH_DIR:-build/somerexx-benchmark}
[[ $RUNS =~ ^[1-9][0-9]*$ ]] || { echo 'RUNS must be positive integer' >&2; exit 64; }
mkdir -p "$DIR"
if [[ -n ${REXX_LIB:-} ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
"$REXX_BIN" -v >/dev/null 2>&1 || { echo 'Missing ooRexx interpreter' >&2; exit 69; }
./build.sh examples/somerexx.rex "$DIR/somerexx.native" "$DIR/somerexx.cpp"
"$REXX_BIN" examples/somerexx.rex >"$DIR/interpreter.oracle"
"$DIR/somerexx.native" >"$DIR/native.oracle"
cmp "$DIR/interpreter.oracle" "$DIR/native.oracle"
[[ $(wc -l < "$DIR/interpreter.oracle") -eq 100002 ]] || { echo 'Unexpected output line count' >&2; exit 1; }
# Execute each once first for process/file cache warmup.
"$REXX_BIN" examples/somerexx.rex > /dev/null
"$DIR/somerexx.native" > /dev/null
: >"$DIR/interpreter.times"
: >"$DIR/native.times"
measure() {
    local category=$1; shift
    local output="$DIR/$category.output" timing="$DIR/$category.timing"
    { TIMEFORMAT='%3R'; time "$@" >"$output"; } 2>"$timing"
    cat "$timing" >>"$DIR/$category.times"
    cmp "$output" "$DIR/interpreter.oracle" || { echo "Output mismatch ($category)" >&2; exit 1; }
}
for ((i=1;i<=RUNS;i++)); do
    # Swap execution order to spread transient thermal/cache effects.
    if (( i % 2 )); then
        measure interpreter "$REXX_BIN" examples/somerexx.rex
        measure native "$DIR/somerexx.native"
    else
        measure native "$DIR/somerexx.native"
        measure interpreter "$REXX_BIN" examples/somerexx.rex
    fi
done
median() { sort -n "$1" | awk '{ a[NR]=$1 } END { if(NR % 2) printf "%.3f",a[(NR+1)/2]; else printf "%.3f",(a[NR/2]+a[NR/2+1])/2 }'; }
im=$(median "$DIR/interpreter.times")
nm=$(median "$DIR/native.times")
ratio=$(awk -v a="$im" -v b="$nm" 'BEGIN { if(b==0) print "undefined"; else printf "%.2f", a/b }')
printf '\nSource: examples/somerexx.rex | %d measured pairs + warmups | stdout -> files\n' "$RUNS"
printf 'ooRexx wall times (s): '; awk '{ printf "%s%s", (NR == 1 ? "" : ", "), $0 } END { print "" }' "$DIR/interpreter.times"
printf 'Native wall times (s): '; awk '{ printf "%s%s", (NR == 1 ? "" : ", "), $0 } END { print "" }' "$DIR/native.times"
printf 'ooRexx median: %s s\nNative median: %s s\nNative speedup: %sx\n' "$im" "$nm" "$ratio"
printf 'Output: 100002 matching lines | SHA-256: '
sha256sum "$DIR/interpreter.oracle" | awk '{print $1}'
printf 'Build artifacts: %s\n' "$DIR"
