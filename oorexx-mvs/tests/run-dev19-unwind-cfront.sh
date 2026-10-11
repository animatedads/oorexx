#!/bin/sh
# Independent host-side cfront micro-probe.  NOT a cc370 or MVS qualification.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
CFRONT=${1:-${CFRONT:-}}
if [ -z "$CFRONT" ] || [ ! -x "$CFRONT" ]; then
    echo 'Usage: run-dev19-unwind-cfront.sh /path/to/cfront-patched' >&2
    exit 2
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
"$CFRONT" "+x$ROOT/mvs370.size" < "$ROOT/runtime/MvsUnwind.cpp" \
    > "$TMP/unwind.c" 2> "$TMP/cfront.log"
if [ ! -s "$TMP/unwind.c" ]; then
    echo 'FAIL cfront produced no C output' >&2
    cat "$TMP/cfront.log" >&2
    exit 1
fi
"${CC:-cc}" -std=gnu89 -fsyntax-only \
    -Wno-implicit-int -Wno-implicit-function-declaration "$TMP/unwind.c"
echo "PASS MvsUnwind cfront translation and host C syntax ($(wc -c < "$TMP/unwind.c") bytes)"
