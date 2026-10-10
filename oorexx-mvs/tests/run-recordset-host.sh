#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
RECORDSET_ROOT=${1:-${RECORDSET_ROOT:-}}
if [ -z "$RECORDSET_ROOT" ] || [ ! -f "$RECORDSET_ROOT/include/RecordSetNative.h" ]; then
  echo 'Supply extracted RecordSet v0.1-dev11 root as argument.' >&2
  exit 2
fi
OUT="${TMPDIR:-/tmp}/rx_mvs_record_dev18_$$"
trap 'rm -f "$OUT"' EXIT HUP INT TERM
run_test() {
  "${CC:-cc}" -std=c90 -Wall -Wextra -Werror -pedantic \
    -I"$RECORDSET_ROOT/include" -I"$ROOT/port/mvs" \
    "$ROOT/port/mvs/MvsRecordProvider.c" \
    "$RECORDSET_ROOT/platform/mvs/RecordSetNativeMvs.c" \
    "$RECORDSET_ROOT/platform/mvs/RecordSetMvsDriverQsam.c" \
    "$RECORDSET_ROOT/platform/mvs/RecordSetMvsAllocationSvc99.c" \
    "$RECORDSET_ROOT/tests/dev9_fake_dynalloc.c" \
    "$RECORDSET_ROOT/tests/dev10_fake_qsam.c" \
    "$ROOT/tests/$1" -o "$OUT"
  "$OUT"
}
run_test mvs_record_provider_test.c
run_test mvs_record_metadata_test.c
