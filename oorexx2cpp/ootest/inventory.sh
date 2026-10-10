#!/usr/bin/env bash
# Source-only corpus survey. No upstream test program is executed.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SUITE=${OO_TEST_ROOT:?Set OO_TEST_ROOT to ooTest snapshot root}
REXX_BIN=${REXX_BIN:-rexx}
REXX_LIB=${REXX_LIB:-${OO_ROOT:-/usr/local}/lib}
OUTPUT_DIR=${OUTPUT_DIR:-$ROOT/build/ootest-inventory}
mkdir -p "$OUTPUT_DIR"
# Deliberately limit to the ooRexx tests (not framework/ example groups).
find "$SUITE/ooRexx" -type f -name '*.testGroup' -print | LC_ALL=C sort >"$OUTPUT_DIR/testgroups.list"
export REXX_PATH="$ROOT/ootest${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$REXX_BIN" "$ROOT/ootest/inventory.rex" "$OUTPUT_DIR/testgroups.list" "$OUTPUT_DIR/inventory.tsv" | tee "$OUTPUT_DIR/summary.txt"
