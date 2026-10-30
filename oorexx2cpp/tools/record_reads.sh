#!/usr/bin/env bash
# tools/record_reads.sh DEPS-DIR OUT: build ootest/test_reads.tsv from a full regression run that recorded, for each
# test script, the tracked files it read (DEPS-DIR/<script>.deps, one path a line; DEPS-DIR/files.txt, the tracked
# files then). How the run records them: before each test, every tracked file's access time is set to 2000-01-01;
# after it, a file whose access time moved was read (the filesystem must update access times: relatime does, when the
# access time is older than the modification time).
# Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-10-30.
set -euo pipefail
D=${1:?usage: record_reads.sh DEPS-DIR OUT [COMMIT]}; OUT=${2:?usage: record_reads.sh DEPS-DIR OUT [COMMIT]}; COMMIT=${3:-unknown}
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
{
  echo "# measured at $COMMIT: the tracked files each test script read during a full regression (tools/record_reads.sh)"
  sed 's/^/#tracked /' "$D/files.txt"
  for f in "$D"/*.deps; do
    s=$(basename "$f" .deps)
    if [[ -f "$ROOT/native/$s" ]]; then t=native/$s; elif [[ -f "$ROOT/tests/$s" ]]; then t=tests/$s; else continue; fi
    echo "#test $t"
    sed "s#^#$t\t#" "$f"
  done
} > "$OUT"
echo "$(grep -vc '^#' "$OUT") reads by $(ls "$D"/*.deps | wc -l) tests, $(wc -l < "$D/files.txt") tracked files: $OUT"
