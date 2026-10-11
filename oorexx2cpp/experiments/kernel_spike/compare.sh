#!/usr/bin/env bash
# usage: compare.sh WORKDIR cases.txt   (WORKDIR is the build.sh work dir that holds ./probe and rexx.img)
# Prints DIFF lines for every case where the compiled-in handler and the interpreter disagree. Exit 0 = all equal.
set -uo pipefail
W=${1:?workdir}; CASES=$(realpath "${2:?cases file}"); HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
( cd "$W" && ./probe "$CASES" ) > "$W/probe.out" 2>&1
# run BOTH sides from the same directory (some functions, e.g. QUALIFY, depend on the working directory)
INTERP=$(rexx -v 2>&1 | head -1)
( cd "$W" && rexx "$HERE/expected.rex" "$CASES" ) > "$W/expected.out" 2>&1
echo "oracle: $INTERP"
if diff -a -u "$W/expected.out" "$W/probe.out" > "$W/diff.out"; then echo "ALL EQUAL ($(wc -l < "$W/probe.out") cases)"; exit 0; fi
grep '^[-+]' "$W/diff.out" | grep -v '^\(---\|+++\)'; echo "DIFFERENCES FOUND"; exit 1
