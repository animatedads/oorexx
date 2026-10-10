#!/usr/bin/env bash
# usage: run_corpus.sh <rexx-binary> [runs] [record|check]
#  record: write golden files when all runs agree (default)
#  check : compare runs against existing golden files (for a compiled build, pass a wrapper script as <rexx-binary>)
# Gated exactly: stdout and exit code. stderr is recorded as a sorted set for information only
# (the interpreter reports an async error from either the worker or the caller, run to run).
REXX=${1:?rexx binary}; RUNS=${2:-10}; MODE=${3:-record}; ROOT=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$ROOT/golden"; ok=0; bad=0
norm() { sed "s|$ROOT/tests/||g"; }
for t in "$ROOT"/tests/*.rex; do
  n=$(basename "$t" .rex); stable=1
  for i in $(seq "$RUNS"); do
    timeout 20 "$REXX" "$t" >"$ROOT/.o" 2>"$ROOT/.e"; rc=$?
    cur_out=$(cat "$ROOT/.o"); cur_err=$(norm <"$ROOT/.e" | sort -u)
    if [ $i -eq 1 ]; then f_out=$cur_out; f_err=$cur_err; f_rc=$rc
    elif [ "$cur_out" != "$f_out" ] || [ $rc -ne $f_rc ]; then stable=0; fi
  done
  if [ "$MODE" = record ]; then
    if [ $stable -eq 1 ]; then
      printf '%s\n' "$f_out" > "$ROOT/golden/$n.stdout"; echo "$f_rc" > "$ROOT/golden/$n.rc"
      printf '%s\n' "$f_err" > "$ROOT/golden/$n.stderr.set"
      printf 'STABLE   %-32s rc=%s\n' "$n" "$f_rc"; ok=$((ok+1))
    else printf 'UNSTABLE %-32s\n' "$n"; bad=$((bad+1)); fi
  else
    g_out=$(cat "$ROOT/golden/$n.stdout"); g_rc=$(cat "$ROOT/golden/$n.rc"); g_err=$(cat "$ROOT/golden/$n.stderr.set")
    if [ $stable -eq 1 ] && [ "$f_out" = "$g_out" ] && [ "$f_rc" = "$g_rc" ]; then
      note=""; [ "$f_err" = "$g_err" ] || note=" (stderr set differs)"
      printf 'PASS     %-32s%s\n' "$n" "$note"; ok=$((ok+1))
    else printf 'FAIL     %-32s stable=%s\n' "$n" "$stable"; bad=$((bad+1)); fi
  fi
done
rm -f "$ROOT/.o" "$ROOT/.e"; echo "ok=$ok bad=$bad mode=$MODE"
