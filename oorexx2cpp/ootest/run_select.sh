#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SUITE=${OO_TEST_ROOT:?Set OO_TEST_ROOT to the unzipped ooTest snapshot root}
REXX_BIN=${REXX_BIN:-rexx}
REXX_LIB=${REXX_LIB:-${OO_ROOT:-/usr/local}/lib}
CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/select-ootest-$($CXX -dumpmachine 2>/dev/null || echo cxx)"}
mkdir -p "$WORK"
TEST_OUTPUT_DIR="$WORK" CXX="$CXX" "$ROOT/tests/test_select.sh" | tee "$WORK/select-qualification.log"
export RX2CPP_SELECT_RESULTS_DIR="$WORK"
export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PATH="$(dirname -- "$REXX_BIN"):$PATH"
export REXX_PATH="$SUITE:$SUITE/framework:$(dirname -- "$REXX_BIN"):$ROOT${REXX_PATH:+:$REXX_PATH}"
(
  cd "$SUITE"
  "$REXX_BIN" testOORexx.rex -R "$ROOT/ootest" -f RX2CPPSelect
) | tee "$WORK/ootest-select.result"
grep -Eq '^Failures:[[:space:]]+0$' "$WORK/ootest-select.result"
grep -Eq '^Errors:[[:space:]]+0$' "$WORK/ootest-select.result"
