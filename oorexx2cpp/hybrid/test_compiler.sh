#!/usr/bin/env bash
# Compiler acceptance and fail-closed syntactic/semantic boundary.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
pass=0
reject() {
    local title=$1 source=$2
    local prefix="$TEMP_DIR/generated"
    rm -f "$prefix.cpp" "$prefix.hpp" "${prefix}_proxy.rex"
    printf '%s\n' "$source" >"$TEMP_DIR/test.cls"
    if "$ROOT/run-hybrid-compiler.sh" "$TEMP_DIR/test.cls" "$prefix" >"$TEMP_DIR/output.log" 2>&1; then
        echo "FAIL: rejected class compiled: $title" >&2; exit 1
    fi
    [[ ! -e "$prefix.cpp" && ! -e "$prefix.hpp" && ! -e "${prefix}_proxy.rex" ]] || {
        echo "FAIL: partial output was written for $title" >&2; exit 1;
    }
    grep -Eq 'rx2cpp:[0-9]+:[0-9]+:' "$TEMP_DIR/output.log" || {
        echo "FAIL: missing source location for $title" >&2
        cat "$TEMP_DIR/output.log" >&2
        exit 1
    }
    printf 'PASS rejected %s\n' "$title"
    pass=$((pass + 1))
}
reject 'unknown method instruction' $'::class Invalid public\n::method current\n  say 1\n  return 1'
reject 'multiple positional arguments' $'::class Invalid public\n::method both\n use arg a, b\n return a'
reject 'missing method RETURN' $'::class Invalid public\n::method current\n x=1'
reject 'late EXPOSE' $'::class Invalid public\n::method current\n x=1\n expose x\n return x'
reject 'statement after RETURN' $'::class Invalid public\n::method current\n return 1\n x=2'
reject 'duplicate methods' $'::class Invalid public\n::method current\n return 1\n::method current\n return 2'
reject 'unsupported directive' $'::class Invalid public\n::method current\n return 1\n::requires "other.cls"'
reject 'unsupported message send' $'::class Invalid public\n::method current\n return self~class'
reject 'unsupported class ancestry' $'::class Invalid subclass .Object\n::method current\n return 1'
reject 'duplicate EXPOSE field' $'::class Invalid public\n::method current\n expose x x\n return x'
# Invalid input must not overwrite a previous good output.
"$ROOT/run-hybrid-compiler.sh" "$ROOT/hybrid/accumulator.cls" "$TEMP_DIR/preserve" > /dev/null
sha_before=$(sha256sum "$TEMP_DIR/preserve.cpp" "$TEMP_DIR/preserve.hpp" "$TEMP_DIR/preserve_proxy.rex")
if "$ROOT/run-hybrid-compiler.sh" "$TEMP_DIR/test.cls" "$TEMP_DIR/preserve" >/dev/null 2>&1; then
    echo 'FAIL: rejected source overwrote good artifacts' >&2; exit 1
fi
sha_after=$(sha256sum "$TEMP_DIR/preserve.cpp" "$TEMP_DIR/preserve.hpp" "$TEMP_DIR/preserve_proxy.rex")
[[ "$sha_before" == "$sha_after" ]] || { echo 'FAIL: prior artifacts modified' >&2; exit 1; }
printf 'PASS rejected compilation preserves previous artifacts\n'
pass=$((pass + 1))
echo "$pass class compiler rejection checks passed"
