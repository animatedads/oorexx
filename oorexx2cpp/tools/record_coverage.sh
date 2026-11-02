#!/usr/bin/env bash
# tools/record_coverage.sh OUT-DIR [JOBS [SCRIPT...]]: run the test scripts (all by default) with coverage and write
# OUT-DIR/<script>.cov for each: the lines of tracked C/C++ files it ran, and the function ranges gcov saw
# (tools/coverage/g++ compiles, tools/coverage/extract.sh reads the profiles after each script).
# Run it on a snapshot of a commit, on an otherwise idle machine. RESUME=1 continues a stopped run.
# Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-11-02.
set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OUT=${1:?usage: record_coverage.sh OUT-DIR [JOBS [SCRIPT...]]}; JOBS=${2:-2}
shift; (( $# > 0 )) && shift
mkdir -p "$OUT"; OUT=$(cd -- "$OUT" && pwd)
export COVROOT=$OUT/profiles COVOUT=$OUT PATH=$ROOT/tools/coverage:$PATH
export CXX=g++ AFTER_EACH=$ROOT/tools/coverage/extract.sh
cd "$ROOT"
# profiles left by scripts a stopped run cut short would add to their rerun: a script's profiles count only whole
rm -rf -- "$COVROOT"
which="ALL"
if (( $# > 0 )); then printf '%s\n' "$@" > "$OUT/scripts"; which="@$OUT/scripts"; fi
RESUME=${RESUME:-0} JOBS=$JOBS LOGS=$OUT/logs bash tools/run_selected.sh "$which"
