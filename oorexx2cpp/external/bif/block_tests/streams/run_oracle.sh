#!/usr/bin/env bash
# Interpreter-reference contract: no rx2cpp/native implementation is exercised.
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
: "${REXX_BIN:?set REXX_BIN to a real ooRexx interpreter (version 5.3 baseline)}"
work=${STREAM_TEST_OUTPUT_DIR:-$(mktemp -d)}
mkdir -p "$work"
if [[ -z "${STREAM_TEST_OUTPUT_DIR:-}" ]]; then trap 'rm -rf -- "$work"' EXIT; fi
pass=0
for source in "$HERE"/cases/[0-9][0-9]_*.rex; do
    testname=$(basename "$source" .rex)
    run="$work/$testname"
    mkdir -p "$run"
    if ! (cd "$run" && "$REXX_BIN" "$source" < "$HERE/cases/stdin_fixture.bin") \
             > "$run/actual.trace" 2> "$run/actual.stderr"; then
        printf 'FAIL %s: interpreter itself failed\n' "$testname" >&2
        cat "$run/actual.stderr" >&2
        exit 1
    fi
    if [[ -s "$run/actual.stderr" ]]; then
        printf 'FAIL %s: unexpected interpreter stderr\n' "$testname" >&2
        cat "$run/actual.stderr" >&2
        exit 1
    fi
    expected_hex=$(awk -F '\t' -v n="$testname" '$1==n {print $2}' "$HERE/expected_traces.tsv")
    [[ -n "$expected_hex" ]] || { echo "missing oracle baseline for $testname" >&2; exit 1; }
    python3 -c 'import sys; sys.stdout.buffer.write(bytes.fromhex(sys.argv[1]))' \
      "$expected_hex" > "$run/expected.trace"
    if ! cmp -s "$run/expected.trace" "$run/actual.trace"; then
        printf 'FAIL %s: interpreter trace drift\n' "$testname" >&2
        diff -u "$run/expected.trace" "$run/actual.trace" >&2 || true
        exit 1
    fi
    printf 'PASS %-24s %3s reference lines\n' "$testname" "$(wc -l < "$run/actual.trace")"
    pass=$((pass+1))
done
[[ "$pass" -eq 11 ]] || { echo "expected 11 stream cases, got $pass" >&2; exit 1; }
echo "PASS stream oracle contract: $pass/11 cases, byte-identical ooRexx traces"
