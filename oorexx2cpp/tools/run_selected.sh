#!/usr/bin/env bash
# tools/run_selected.sh [BASE]: run the test scripts the changes since BASE (default origin/main) can affect.
# The changed files are the commits since BASE plus uncommitted and untracked work. The selection is
# tools/select_tests.rex over ootest/test_reads.tsv (what each test was measured to read). On ALL it runs every test.
# BASE=ALL runs every test without selecting (the full regression).
# JOBS=N runs N scripts at a time (default 1), longest first by the measured seconds. Each script builds in its own
# build/<name> directory, so scripts do not share files.
# For checks while working: the merge gate stays the full regression.
# Architecture: Tom Dyer (the blast-radius check). Code: Claude (Opus 5.5), 2026-10-30, 2026-10-31.
set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
BASE=${1:-origin/main}
REXX_BIN=${REXX_BIN:-rexx}
JOBS=${JOBS:-1}
LOGS=${LOGS:-/tmp/run_selected}
READS=$ROOT/ootest/test_reads.tsv
cd "$ROOT"
mkdir -p "$LOGS"
if [[ $BASE == ALL ]]; then selection='ALL requested'
else
  changed=$( { git diff --name-only --relative "$BASE"; git diff --name-only --relative; git ls-files --others --exclude-standard; } | sort -u)
  if [[ -z "$changed" ]]; then echo "no changes since $BASE"; exit 0; fi
  selection=$(printf '%s\n' "$changed" | "$REXX_BIN" tools/select_tests.rex)
fi
printf '%s\n' "$selection"
if grep -q '^ALL' <<<"$selection"; then scripts=$(ls native/test_*.sh tests/test_*.sh)
elif grep -q '^NONE' <<<"$selection"; then exit 0
else scripts=$(awk '$1 == "RUN" {print $2}' <<<"$selection"); fi
# longest first, so the long scripts do not finish last on their own; unmeasured scripts count as long
order=$(for t in $scripts; do
  s=$(awk -v t="$t" '$1 == "#seconds" && $2 == t {print $3}' "$READS" 2>/dev/null)
  echo "${s:-99999} $t"
done | sort -rn | awk '{print $2}')
s0=$SECONDS
run_one() {   # one script: its log, and one result line in $LOGS/results
  local t=$1 s=$SECONDS r log="$LOGS/$(basename "$1").log"
  if timeout 3600 bash "$t" > "$log" 2>&1; then r=PASS; else r=FAIL; fi
  echo "$r $t ($((SECONDS-s)) s)$([[ $r == FAIL ]] && echo "  log: $log")" | tee -a "$LOGS/results"
}
export -f run_one; export LOGS
# RESUME=1 keeps $LOGS/results and skips the scripts it already has (for runs longer than one sitting)
if [[ ${RESUME:-0} == 1 && -f "$LOGS/results" ]]; then
  order=$(for t in $order; do grep -q "^[A-Z]* $t " "$LOGS/results" || echo "$t"; done)
else : > "$LOGS/results"; fi
trap 'kill 0' TERM INT    # stopped (e.g. by timeout): stop the running scripts too; they are not recorded
[[ -n "$order" ]] && printf '%s\n' $order | xargs -P "$JOBS" -I{} bash -c 'run_one "$1"' _ {}
pass=$(grep -c '^PASS' "$LOGS/results"); fail=$(grep -c '^FAIL' "$LOGS/results")
echo "selected tests: $pass passed, $fail failed, $((SECONDS-s0)) s this sitting, $JOBS at a time"
(( fail == 0 ))
