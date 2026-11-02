#!/usr/bin/env bash
# tools/estate/node_suite.sh REPO COMMIT [JOBS]: run the rx2cpp test suite of COMMIT on an ED209 node.
#   REPO:   a clone of animatedads/oorexx on the node (any commit checked out; it is not changed)
#   COMMIT: the commit to test (git rev-parse must know it: fetch first)
#   JOBS:   scripts at a time; default: the number of cores
# Builds ooRexx 5.3.0 r13196 (GitHub 4b66b3558f7c, the reference interpreter) once into ~/rx2cpp_estate/oorexx,
# then runs tools/run_all_recording.sh on a snapshot of COMMIT. Prints a summary at the end; send that back.
# Needs: git, g++, cmake, make. Nothing outside ~/rx2cpp_estate is written; no sudo.
# Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-11-02.
set -euo pipefail
REPO=$(cd -- "${1:?usage: node_suite.sh REPO COMMIT [JOBS]}" && pwd)
COMMIT=${2:?usage: node_suite.sh REPO COMMIT [JOBS]}
JOBS=${3:-$(nproc)}
E=$HOME/rx2cpp_estate
mkdir -p "$E"
for tool in git g++ cmake make; do command -v "$tool" >/dev/null || { echo "MISSING TOOL: $tool"; exit 2; }; done

# 1. ooRexx r13196, built once
OR=$E/oorexx/usr/local
if [[ ! -x $OR/bin/rexx ]]; then
  echo "building ooRexx r13196 (once; about 10-20 minutes)"
  rm -rf "$E/oorexx_src" "$E/oorexx_build" "$E/oorexx"
  git clone -q https://github.com/ooRexx/ooRexx.git "$E/oorexx_src"
  git -C "$E/oorexx_src" checkout -q 4b66b3558f7c6c7688005a2d7e05ab2404f5e42e
  cmake -S "$E/oorexx_src" -B "$E/oorexx_build" -DCMAKE_BUILD_TYPE=Release > "$E/oorexx_cmake.log" 2>&1
  make -C "$E/oorexx_build" -j"$(nproc)" > "$E/oorexx_make.log" 2>&1
  make -C "$E/oorexx_build" install DESTDIR="$E/oorexx" > "$E/oorexx_install.log" 2>&1
fi
export OO_ROOT=$OR REXX_BIN=$OR/bin/rexx PATH=$OR/bin:$PATH LD_LIBRARY_PATH=$OR/lib REXX_LIB=$OR/lib
"$OR/bin/rexx" -v | head -1

# 2. a snapshot of COMMIT, and the run
short=$(git -C "$REPO" rev-parse --short "$COMMIT")
SNAP=$E/snap_$short; OUT=$E/run_$short
if [[ ! -d $SNAP ]]; then
  mkdir -p "$SNAP"
  git -C "$REPO" archive "$COMMIT" oorexx2cpp | tar -x -C "$SNAP" --strip-components=1
fi
set +e
(cd "$SNAP" && bash tools/run_all_recording.sh "$SNAP" "$OUT" "$JOBS")
rc=$?
set -e

# 3. the summary to send back
echo "===== rx2cpp node_suite summary ====="
echo "node $(hostname)  $(uname -m)  $(nproc) cores  commit $short  jobs $JOBS"
"$OR/bin/rexx" -v | head -1
echo "passed $(grep -c '^PASS' "$OUT/results")  failed $(grep -c '^FAIL' "$OUT/results")  of $(ls "$SNAP"/native/test_*.sh "$SNAP"/tests/test_*.sh | wc -l)"
grep '^FAIL' "$OUT/results" || true
echo "skipped: $(grep -l '^SKIP' "$OUT"/logs/*.log 2>/dev/null | xargs -r -n1 basename | sed 's/\.log$//' | tr '\n' ' ')"
for f in $(grep '^FAIL' "$OUT/results" | awk '{print $2}'); do
  echo "----- last lines of $(basename "$f").log"; tail -15 "$OUT/logs/$(basename "$f").log"
done
echo "===== end ====="
exit $rc
