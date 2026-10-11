#!/usr/bin/env bash
# Scope categories, shared clause gateway, and real ooRexx prologue semantics.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT${REXX_PATH:+:$REXX_PATH}"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
"$REXX_BIN" "$ROOT/tests/test_when_dealing_with.rex" >"$WORK/scopes.out"
grep -q '^PASS when-dealing-with scope 26 assertions$' "$WORK/scopes.out"
cp "$ROOT/tests/prolog/"*.cls "$ROOT/tests/prolog/client.rex" "$WORK/"
(cd "$WORK" && "$REXX_BIN" client.rex >required.out)
printf 'EXECUTED PROLOG\nbegin\n' >"$WORK/required.expected"
cmp "$WORK/required.expected" "$WORK/required.out"
(cd "$WORK" && "$REXX_BIN" disabled.cls >direct.out)
printf 'MUST NOT EXECUTE PROLOG\n' >"$WORK/direct.expected"
cmp "$WORK/direct.expected" "$WORK/direct.out"
echo 'PASS shared scopes, prologue require/direct interpreter oracle'
