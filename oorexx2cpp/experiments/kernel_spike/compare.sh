#!/usr/bin/env bash
# usage: compare.sh WORKDIR cases.txt   (WORKDIR is the build.sh work dir that holds ./probe and rexx.img)
# Prints DIFF lines for every case where the compiled-in handler and the interpreter disagree. Exit 0 = all equal.
set -uo pipefail
W=${1:?workdir}; CASES=$(realpath "${2:?cases file}"); HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
( cd "$W" && ./probe "$CASES" ) > "$W/probe.out" 2>&1
rexx "$HERE/expected.rex" "$CASES" > "$W/expected.out" 2>&1
if diff -u "$W/expected.out" "$W/probe.out" > "$W/diff.out"; then echo "ALL EQUAL ($(wc -l < "$W/probe.out") cases)"; exit 0; fi
grep '^[-+]' "$W/diff.out" | grep -v '^\(---\|+++\)'; echo "DIFFERENCES FOUND"; exit 1
