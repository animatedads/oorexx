#!/usr/bin/env bash
# Whole-tree qualification ledger. Runs every tests/test_*.sh and native/test_*.sh ONE AT A TIME (they share build dirs),
# each under a timeout, and writes docs/qualification_ledger.md (commit, date, per-script PASS/FAIL/TIMEOUT, seconds).
# Usage: tests/qualify.sh [timeout_seconds=900] [name-filter]
set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
LIMIT=${1:-900}; FILTER=${2:-}
OUT="$ROOT/build/qualify"; mkdir -p "$OUT" "$ROOT/docs"
LEDGER="$ROOT/docs/qualification_ledger.md"
rows=(); pass=0; fail=0
for t in "$ROOT"/tests/test_*.sh "$ROOT"/native/test_*.sh; do
  [[ -f $t ]] || continue
  n=${t#"$ROOT/"}; [[ -z $FILTER || $n == *$FILTER* ]] || continue
  log="$OUT/$(echo "$n" | tr '/' '_').log"; s=$(date +%s)
  timeout "$LIMIT" bash "$t" >"$log" 2>&1; rc=$?; e=$(( $(date +%s) - s ))
  if [[ $rc == 0 ]]; then st=PASS; pass=$((pass+1)); elif [[ $rc == 124 ]]; then st=TIMEOUT; fail=$((fail+1)); else st="FAIL($rc)"; fail=$((fail+1)); fi
  rows+=("| \`$n\` | $st | ${e}s | $(tail -n 1 "$log" | tr '|' '/' | cut -c1-110) |")
  echo "$st $n ${e}s"
done
{
  echo "# Qualification ledger"; echo
  echo "Commit: \`$(git -C "$ROOT" rev-parse --short HEAD)\`  Date: $(date -u +%F\ %H:%MZ)  Timeout: ${LIMIT}s  Filter: ${FILTER:-none}"
  echo "Result: $pass pass, $fail not passing. Architecture: Tom Dyer. Coding: ChatGPT / Claude."; echo
  echo "| Script | Status | Time | Last line |"; echo "|---|---|---|---|"
  printf '%s\n' "${rows[@]}"
} >"$LEDGER"
echo "ledger: $LEDGER ($pass pass, $fail not passing)"
[[ $fail == 0 ]]
