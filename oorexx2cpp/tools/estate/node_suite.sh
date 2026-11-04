#!/usr/bin/env bash
# tools/estate/node_suite.sh COMMIT SHARD [JOBS]: run one share of the rx2cpp test suite of COMMIT on an ED209 node.
#   COMMIT: the commit of animatedads/oorexx to test
#   SHARD:  k/N, this node's share (e.g. 3/10); every node computes the same split from the measured run times
#   JOBS:   scripts at a time (default 1: the small nodes have little memory)
# Clones animatedads/oorexx (public) into ~/rx2cpp_estate/repo, at the branch head for the tools; builds ooRexx 5.3.0
# r13196 (GitHub 4b66b3558f7c, the reference interpreter) once into ~/rx2cpp_estate/oorexx; runs the share with
# tools/run_all_recording.sh; prints a summary between "===== rx2cpp node_suite summary" and "===== end".
# Run it again with the same arguments to continue after a stop (failed scripts run again). Needs git, g++,
# cmake, make and the Boost headers. Writes only under
# ~/rx2cpp_estate; no sudo. Architecture: Tom Dyer (the ED209 estate). Code: Claude (Opus 5.5), 2026-11-02.
set -euo pipefail
COMMIT=${1:?usage: node_suite.sh COMMIT SHARD [JOBS]}; SHARD=${2:?usage: node_suite.sh COMMIT SHARD [JOBS]}
JOBS=${3:-1}
TOOLS_BRANCH=${TOOLS_BRANCH:-wip-2026-10-29}
E=$HOME/rx2cpp_estate
mkdir -p "$E"
# a step that fails says so, with the end of its log, and the run ends with the marker the reader waits for
step="checking the tools"; steplog=
failed() {
  local rc=$?
  echo "===== rx2cpp node_suite FAILED while $step (exit $rc)"
  if [[ -n $steplog && -f $steplog ]]; then echo "----- last lines of $steplog"; tail -25 "$steplog"; fi
  echo "memory: $(awk '/MemTotal|MemAvailable|SwapTotal|SwapFree/ {printf "%s %d MB  ", $1, $2 / 1024}' /proc/meminfo)"
  dmesg 2>/dev/null | grep -iE 'out of memory|killed process' | tail -3 || true
  echo "===== end"
}
trap failed ERR
for tool in git g++ cmake make; do command -v "$tool" >/dev/null || { echo "MISSING TOOL: $tool"; exit 2; }; done
# the runtime includes Boost.Multiprecision (headers only)
echo '#include <boost/multiprecision/cpp_int.hpp>' | g++ -std=c++17 -x c++ -fsyntax-only - 2>/dev/null ||
  { echo "MISSING TOOL: boost headers (boost/multiprecision/cpp_int.hpp)"; exit 2; }
# small machines: build with one job when there is under 2 GB of memory
mem_mb=$(awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo)
if (( mem_mb < 2048 )); then MAKEJ=1; else MAKEJ=$(nproc); fi

# 1. the repository: the tools from the branch head, the commit to test
step="fetching animatedads/oorexx"
R=$E/repo
if [[ ! -d $R/.git ]]; then git clone -q https://github.com/animatedads/oorexx.git "$R"; fi
git -C "$R" fetch -q origin "$TOOLS_BRANCH" main
git -C "$R" checkout -q --detach "origin/$TOOLS_BRANCH"
git -C "$R" cat-file -e "$COMMIT^{commit}" 2>/dev/null || git -C "$R" fetch -q origin "$COMMIT"
short=$(git -C "$R" rev-parse --short "$COMMIT")

# 2. ooRexx r13196, built once
OR=$E/oorexx/usr/local
if [[ ! -x $OR/bin/rexx ]]; then
  echo "building ooRexx r13196 (once; make -j$MAKEJ, can take an hour on a small node)"
  rm -rf "$E/oorexx_src" "$E/oorexx_build" "$E/oorexx"
  step="fetching ooRexx"; steplog=
  git clone -q https://github.com/ooRexx/ooRexx.git "$E/oorexx_src"
  git -C "$E/oorexx_src" checkout -q 4b66b3558f7c6c7688005a2d7e05ab2404f5e42e
  step="configuring ooRexx (cmake)"; steplog=$E/oorexx_cmake.log
  cmake -S "$E/oorexx_src" -B "$E/oorexx_build" -DCMAKE_BUILD_TYPE=Release > "$steplog" 2>&1
  step="building ooRexx (make)"; steplog=$E/oorexx_make.log
  make -C "$E/oorexx_build" -j"$MAKEJ" > "$steplog" 2>&1
  step="installing ooRexx"; steplog=$E/oorexx_install.log
  make -C "$E/oorexx_build" install DESTDIR="$E/oorexx" > "$steplog" 2>&1
  steplog=
fi
export OO_ROOT=$OR REXX_BIN=$OR/bin/rexx PATH=$OR/bin:$PATH LD_LIBRARY_PATH=$OR/lib REXX_LIB=$OR/lib
unset OOTEST_ROOT    # test_slam_compiled needs an ooTest snapshot: it skips here and runs on the main machine

# 3. a snapshot of COMMIT, and this node's share
SNAP=$E/snap_$short; OUT=$E/run_${short}_${SHARD/\//of}
step="making the snapshot of $short"
if [[ ! -d $SNAP ]]; then
  rm -rf "$SNAP.tmp"; mkdir -p "$SNAP.tmp"
  git -C "$R" archive "$COMMIT" oorexx2cpp | tar -x -C "$SNAP.tmp" --strip-components=1
  mv "$SNAP.tmp" "$SNAP"
fi
set +e; trap - ERR
SHARD=$SHARD bash "$R/oorexx2cpp/tools/run_all_recording.sh" "$SNAP" "$OUT" "$JOBS"
rc=$?
set -e

# 4. the summary to send back
echo "===== rx2cpp node_suite summary"
echo "node $(hostname)  $(uname -m)  $(nproc) cores  ${mem_mb} MB  commit $short  share $SHARD  jobs $JOBS"
"$OR/bin/rexx" -v | head -1
echo "passed $(grep -c '^PASS' "$OUT/results")  failed $(grep -c '^FAIL' "$OUT/results")  still queued $(grep -c . "$OUT/queue")"
cat "$OUT/results"
echo "skipped: $(grep -l '^SKIP' "$OUT"/logs/*.log 2>/dev/null | xargs -r -n1 basename | sed 's/\.log$//' | tr '\n' ' ')"
for f in $(grep '^FAIL' "$OUT/results" | awk '{print $2}'); do
  echo "----- last lines of $(basename "$f").log"; tail -15 "$OUT/logs/$(basename "$f").log"
done
echo "===== end"
exit $rc
