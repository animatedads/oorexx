#!/usr/bin/env bash
# Explicitly selected historical interpreter test groups. These ooTest 4.2
# groups are NOT a 5.3 conformance certificate. No wholesale suite execution.
set -euo pipefail
SUITE=${OO_TEST_ROOT:?Set OO_TEST_ROOT to the unzipped ooTest root}
REXX_BIN=${REXX_BIN:-rexx}
REXX_LIB=${REXX_LIB:-${OO_ROOT:-/usr/local}/lib}
OUTPUT_DIR=${OUTPUT_DIR:-${RX2CPP_OOTEST_SMOKE_DIR:-$(pwd)/build/ootest-reference-smoke}}
mkdir -p "$OUTPUT_DIR"
export PATH="$(dirname -- "$REXX_BIN"):$PATH" LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$SUITE:$SUITE/framework:$(dirname -- "$REXX_BIN")${REXX_PATH:+:$REXX_PATH}"
cd "$SUITE"
for pair in 'ooRexx/base:Assignments' 'ooRexx/base/bif:ABS' 'ooRexx/base/bif:ABBREV'; do
  path=${pair%%:*}
  name=${pair##*:}
  logfile="$OUTPUT_DIR/$name.official-ootest.txt"
  if ! timeout 90 "$REXX_BIN" testOORexx.rex -R "$path" -f "$name" >"$logfile" 2>&1; then
    echo "FAIL official runner for $name" >&2
    tail -25 "$logfile" >&2
    exit 1
  fi
  if ! grep -Eq '^Failures:[[:space:]]+0$' "$logfile" || \
     ! grep -Eq '^Errors:[[:space:]]+0$' "$logfile" || \
     ! grep -Eq '^Tests ran:[[:space:]]+[1-9][0-9]*$' "$logfile"; then
    echo "FAIL ooTest assertions for $name" >&2
    tail -25 "$logfile" >&2
    exit 1
  fi
  echo "PASS $name: $(grep -E '^Tests ran:' "$logfile" | head -1 | xargs); $(grep -E '^Assertions:' "$logfile" | head -1 | xargs)"
done
