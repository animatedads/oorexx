#!/usr/bin/env bash
# STRICT gate. Nonzero exit means compiled-stream fidelity is NOT qualified.
# Never interpret a successful frontend parse alone as a stream pass.
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
: "${RX2CPP_BASE:?set RX2CPP_BASE to your freshly pulled GitHub main oorexx2cpp directory}"
: "${REXX_BIN:?set REXX_BIN to the qualification ooRexx interpreter}"
[[ -f "$RX2CPP_BASE/build.sh" ]] || { echo 'missing checked compiler build.sh' >&2; exit 64; }
if ! revision=$(git -C "$RX2CPP_BASE" rev-parse HEAD 2>/dev/null); then
    echo 'Cannot prove GitHub checkout revision; do not qualify an untracked ZIP as main' >&2
    exit 65
fi
printf 'Current compiler source: %s\n' "$revision"
work=${STREAM_TEST_OUTPUT_DIR:-$(mktemp -d)}
mkdir -p "$work"
if [[ -z "${STREAM_TEST_OUTPUT_DIR:-}" ]]; then trap 'rm -rf -- "$work"' EXIT; fi
fail=0
pass=0
for src in "$HERE"/cases/[0-9][0-9]_*.rex; do
    name=$(basename "$src" .rex)
    dir="$work/$name"
    mkdir -p "$dir"
    executable="$dir/program"
    if ! (cd "$dir" && "$RX2CPP_BASE/build.sh" "$src" "$executable" "$dir/program.cpp") \
         > "$dir/build.log" 2>&1; then
        printf 'UNQUALIFIED %-24s compile rejected (see build.log)\n' "$name"
        fail=$((fail+1))
        continue
    fi
    if ! (cd "$dir" && "$executable" < "$HERE/cases/stdin_fixture.bin") \
         > "$dir/actual.trace" 2> "$dir/actual.stderr"; then
        printf 'UNQUALIFIED %-24s runtime failed (see actual.stderr)\n' "$name"
        fail=$((fail+1))
        continue
    fi
    expected_hex=$(awk -F '\t' -v n="$name" '$1==n {print $2}' "$HERE/expected_traces.tsv")
    [[ -n "$expected_hex" ]] || { echo "missing oracle baseline for $name" >&2; exit 1; }
    python3 -c 'import sys; sys.stdout.buffer.write(bytes.fromhex(sys.argv[1]))' \
      "$expected_hex" > "$dir/expected.trace"
    if [[ -s "$dir/actual.stderr" ]] || ! cmp -s "$dir/expected.trace" "$dir/actual.trace"; then
        printf 'UNQUALIFIED %-24s output or stderr mismatch\n' "$name"
        fail=$((fail+1))
        continue
    fi
    printf 'PASS        %-24s exact stream behaviour\n' "$name"
    pass=$((pass+1))
done
printf 'Compiled stream fidelity: %d PASS, %d UNQUALIFIED on checkout %s\n' "$pass" "$fail" "$revision"
[[ "$fail" -eq 0 && "$pass" -eq 11 ]] || exit 1
