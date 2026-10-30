#!/usr/bin/env bash
# tools/run_selected.sh [BASE]: run the test scripts the changes since BASE (default origin/main) can affect.
# The changed files are the commits since BASE plus uncommitted and untracked work. The selection is
# tools/select_tests.rex over ootest/test_reads.tsv (what each test was measured to read). On ALL it runs every test.
# For checks while working: the merge gate stays the full regression.
# Architecture: Tom Dyer (the blast-radius check). Code: Claude (Opus 5.5), 2026-10-30.
set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
BASE=${1:-origin/main}
REXX_BIN=${REXX_BIN:-rexx}
cd "$ROOT"
changed=$( { git diff --name-only --relative "$BASE"; git diff --name-only --relative; git ls-files --others --exclude-standard; } | sort -u)
if [[ -z "$changed" ]]; then echo "no changes since $BASE"; exit 0; fi
selection=$(printf '%s\n' "$changed" | "$REXX_BIN" tools/select_tests.rex)
printf '%s\n' "$selection"
if grep -q '^ALL' <<<"$selection"; then scripts=$(ls native/test_*.sh tests/test_*.sh)
elif grep -q '^NONE' <<<"$selection"; then exit 0
else scripts=$(awk '$1 == "RUN" {print $2}' <<<"$selection"); fi
pass=0; fail=0; s0=$SECONDS
for t in $scripts; do
  s=$SECONDS
  if timeout 3600 bash "$t" > "/tmp/run_selected.$(basename "$t").log" 2>&1; then pass=$((pass+1)); r=PASS; else fail=$((fail+1)); r=FAIL; fi
  echo "$r $t ($((SECONDS-s)) s)$([[ $r == FAIL ]] && echo "  log: /tmp/run_selected.$(basename "$t").log")"
done
echo "selected tests: $pass passed, $fail failed, $((SECONDS-s0)) s"
(( fail == 0 ))
