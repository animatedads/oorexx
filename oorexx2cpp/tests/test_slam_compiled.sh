#!/usr/bin/env bash
# SLAM's ooTest groups (tests/slam/groups), run twice: on the routine as the interpreter runs it, and on the
# same routine compiled by rx2cpp. Each group asserts what the interpreter returned, so a group that passes
# compiled means rx2cpp matches the interpreter on every case SLAM chose. A group that fails interpreted means
# SLAM's expectation no longer holds (the oracle drifted): that is reported separately.
# Cases chosen by SLAM (animatedads/alchemy packages/oorexx_slam_v0.1); see tests/slam/README.md.
# Needs OOTEST_ROOT: an unzipped ooTest snapshot (holding ooTest.frm and framework/). Without it: SKIP.
set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OT=${OOTEST_ROOT:-}
if [[ -z "$OT" || ! -f "$OT/ooTest.frm" ]]; then echo "SKIP slam compiled: set OOTEST_ROOT to an unzipped ooTest snapshot"; exit 0; fi
OUT=$(mktemp -d); trap 'rm -rf -- "$OUT"' EXIT
mkdir -p "$OUT/lib" "$OUT/src" "$OUT/groups"
export LD_LIBRARY_PATH="$OUT/lib:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
counts() { grep -E '^(Tests ran|Failures|Errors):' | tr -s ' ' | awk -F': *' '{v[$1]=$2} END {print v["Tests ran"]+0, v["Failures"]+0, v["Errors"]+0}'; }
groups=0; cases=0; bad=0; drift=0
for g in "$ROOT"/tests/slam/groups/*.testGroup; do
  b=$(basename "$g")
  read -r name rel < <(sed -n 's/^ *Unit under test: routine \([^ ]*\) in \(.*\)$/\1 \2/p' "$g" | head -1)
  [[ -n "${name:-}" ]] || continue
  lib=slamfx_$(echo "$rel" | tr '/.' '__' | tr -cd 'A-Za-z0-9_')
  if [[ ! -f "$OUT/lib/lib$lib.so" ]]; then
    # (a copy of the file with every ::ROUTINE public, so the library exports the routine under test)
    mkdir -p "$OUT/src/$(dirname "$rel")"
    sed -E 's/^(::routine[ \t]+[A-Za-z0-9_.!?]+)([ \t]+(private|public))?[ \t]*$/\1 public/I' "$ROOT/$rel" > "$OUT/src/$rel"
    (cd "$ROOT" && OO_ROOT="$OO_ROOT" REXX_BIN="$REXX_BIN" native/build.sh "$OUT/src/$rel" "$OUT/lib" "$lib" > "$OUT/build_$lib.log" 2>&1) \
      || { echo "FAIL build $rel"; tail -20 "$OUT/build_$lib.log"; exit 1; }
  fi
  # interpreted: the group as SLAM wrote it, lifting the routine from this tree
  read -r t f e < <(cd "$(dirname "$g")" && SLAM_UNDER_TEST="$ROOT/$rel" REXX_PATH="$OT:$OT/framework" \
    timeout -s KILL 300 "$REXX_BIN" "$b" 2>&1 | counts)
  if (( f + e )); then echo "DRIFT $b: interpreted $f failures, $e errors (SLAM's expectation no longer holds)"; drift=$((drift+1)); fi
  # compiled: the same group, its underTest given the routine from the rx2cpp library
  awk -v lib="$lib" -v nm="$name" '
    /^::method underTest/ {print; print "  return .Package~new(\"slamwrap\", .array~of(\"::requires '\''" lib "'\'' library\"))~findRoutine(\"" nm "\")"; skip=1; next}
    skip && /^::/ {skip=0}
    skip && /^\/\*/ {skip=0}
    !skip {print}' "$g" > "$OUT/groups/$b"
  read -r t2 f2 e2 < <(cd "$OUT/groups" && REXX_PATH="$OT:$OT/framework" timeout -s KILL 300 "$REXX_BIN" "$b" 2>&1 | counts)
  if (( f2 + e2 )) || (( t2 != t )); then echo "FAIL $b: compiled $f2 failures, $e2 errors ($t2 tests; interpreted $t)"; bad=$((bad+1)); fi
  groups=$((groups+1)); cases=$((cases+t2))
done
(( groups > 0 )) || { echo "FAIL no SLAM groups found"; exit 1; }
(( bad == 0 && drift == 0 )) || { echo "FAIL slam compiled: $bad groups differ compiled, $drift drifted interpreted"; exit 1; }
echo "PASS slam compiled: $groups groups (SLAM and random), $cases tests, compiled routines identical to the interpreter"
