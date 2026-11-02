#!/usr/bin/env bash
# tools/run_all_recording.sh SNAPSHOT OUT [JOBS]: the full regression, JOBS scripts at a time (default 2), recording
# the tracked files each script reads and how long it takes, for tools/record_reads.sh:
#   bash tools/record_reads.sh OUT/deps ootest/test_reads.tsv COMMIT
# SNAPSHOT: oorexx2cpp/ of one commit, unbuilt (git archive COMMIT oorexx2cpp | tar -x --strip-components=1).
# Each worker runs in a copy of its own (OUT/w1, OUT/w2, ...), so one script's reads cannot be taken for another's:
# before each script every tracked file of the worker's copy gets access time 2000-01-01, and after it the files
# whose access time moved were read (the filesystem must update access times: relatime does, for times this old).
# Results: OUT/results ("PASS script (s)" or "FAIL ..."), logs in OUT/logs. Run again with the same OUT to continue
# after a stop: passed scripts are kept, failed ones run again. Set REXX_LIB, OO_ROOT etc. as for the tests; REXX_PATH is set per copy.
# SHARD=k/N runs only the k-th of N shares of the scripts (balanced by the measured seconds), for N machines.
# Architecture: Tom Dyer (the blast-radius check). Code: Claude (Opus 5.5), 2026-11-02.
set -uo pipefail
shopt -s nullglob
SNAP=$(cd -- "${1:?usage: run_all_recording.sh SNAPSHOT OUT [JOBS]}" && pwd)
OUT=${2:?usage: run_all_recording.sh SNAPSHOT OUT [JOBS]}; JOBS=${3:-2}
mkdir -p "$OUT/logs" "$OUT/deps" "$OUT/pids"; OUT=$(cd -- "$OUT" && pwd)
touch "$OUT/results"
if [[ ! -s $OUT/deps/files.txt ]]; then
  (cd "$SNAP" && find . -type f ! -path './build/*' | sed 's#^\./##' | sort) > "$OUT/deps/files.txt"
fi
for ((k = 1; k <= JOBS; k++)); do
  [[ -d $OUT/w$k ]] || cp -a "$SNAP" "$OUT/w$k"
done
# the queue: scripts not yet finished, longest first by the measured seconds (unmeasured: 600 s)
# SHARD=k/N keeps the k-th of N shares: scripts go, longest first, to the share with the least seconds so far, so
# every machine that runs one share computes the same split
READS=$SNAP/ootest/test_reads.tsv
SHARD=${SHARD:-1/1}; sk=${SHARD%/*}; sn=${SHARD#*/}
(cd "$SNAP" && for t in native/test_*.sh tests/test_*.sh; do
   s=$(awk -v t="$t" '$1 == "#seconds" && $2 == t {print $3}' "$READS" 2>/dev/null)
   echo "${s:-600} $t"
 done | sort -k1,1rn -k2,2 | awk -v k="$sk" -v n="$sn" '
   { best = 1; for (i = 2; i <= n; i++) if (load[i] < load[best]) best = i
     load[best] += $1; if (best == k) print $2 }') |
 while read -r t; do grep -q "^PASS $t " "$OUT/results" || echo "$t"; done > "$OUT/queue"
# a run again retries what failed: only passes are kept
grep '^PASS ' "$OUT/results" > "$OUT/results.kept" || true; mv "$OUT/results.kept" "$OUT/results"
echo "$(wc -l < "$OUT/queue") scripts to run (share $SHARD)"
rm -f "$OUT"/pids/*
worker() {   # worker k: take scripts from the queue until it is empty
  local k=$1 W=$OUT/w$1 t s rc pid r
  while :; do
    t=$(flock "$OUT/queue.lock" sh -c 'head -1 "$1"; sed -i 1d "$1"' _ "$OUT/queue")
    [[ -z $t ]] && return 0
    (cd "$W" && xargs -a "$OUT/deps/files.txt" -d '\n' touch -a -d '2000-01-01 00:00:00' 2>/dev/null)
    s=$SECONDS
    (cd "$W" && REXX_PATH=$W RUN_SELECTED_TEST=$t exec timeout 3600 bash "$t") > "$OUT/logs/$(basename "$t").log" 2>&1 &
    pid=$!; echo "$pid" > "$OUT/pids/$pid"; wait "$pid"; rc=$?; rm -f "$OUT/pids/$pid"
    (cd "$W" && xargs -a "$OUT/deps/files.txt" -d '\n' stat -c '%X %n' 2>/dev/null) |
      awk '$1 > 946771200 { $1 = ""; sub(/^ /, ""); print }' > "$OUT/deps/$(basename "$t").deps"
    echo $((SECONDS - s)) > "$OUT/deps/$(basename "$t").seconds"
    if (( rc == 0 )); then r=PASS; else r=FAIL; fi
    flock "$OUT/results.lock" sh -c 'echo "$1" >> "$2"' _ "$r $t ($((SECONDS - s)) s)" "$OUT/results"
    echo "$r $t ($((SECONDS - s)) s) [w$k]"
  done
}
wpids=()
stop() {   # TERM or INT: stop the workers first (no result lines for cut-short scripts), then the scripts
  trap - TERM INT
  kill -TERM "${wpids[@]}" 2>/dev/null
  for p in "$OUT"/pids/*; do [[ -f $p ]] && kill -TERM "$(basename "$p")" 2>/dev/null; done
  exit 143
}
trap stop TERM INT
s0=$SECONDS
for ((k = 1; k <= JOBS; k++)); do worker "$k" & wpids+=($!); done
wait "${wpids[@]}"
total=$(( $(grep -c . "$OUT/results") + $(grep -c . "$OUT/queue" 2>/dev/null || echo 0) ))   # this share
pass=$(grep -c '^PASS' "$OUT/results"); fail=$(grep -c '^FAIL' "$OUT/results")
echo "full regression: $pass passed, $fail failed of $total, $((SECONDS - s0)) s this sitting, $JOBS at a time"
(( pass == total ))
