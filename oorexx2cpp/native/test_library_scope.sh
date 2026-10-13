#!/usr/bin/env bash
# Class resolution across two compiled libraries: the required library's public classes come before .LOCAL, so a public
# class ERROR wins over the .ERROR stream inside the requiring library's compiled code, as interpreted.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
export LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
F="$ROOT/native/fixtures"
cp "$F/scope_base.cls" "$F/scope_user.cls" "$OUT/"
printf 'say .User~new~run\n::requires "scope_user.cls"\n' > "$OUT/interpreted.rex"
printf 'say .User~new~run\n::requires "rxscopeuser" library\n' > "$OUT/compiled.rex"
(cd "$OUT" && REXX_PATH="$OUT" "$REXX_BIN" interpreted.rex > expected.txt 2>&1)
"$ROOT/native/build.sh" "$OUT/scope_base.cls" "$OUT" rxscopebase > "$OUT/build1.log" 2>&1 || { tail -30 "$OUT/build1.log"; echo "FAIL build base"; exit 1; }
RX2CPP_LIBMAP="scope_base.cls=rxscopebase" "$ROOT/native/build.sh" "$OUT/scope_user.cls" "$OUT" rxscopeuser > "$OUT/build2.log" 2>&1 \
    || { tail -30 "$OUT/build2.log"; echo "FAIL build user"; exit 1; }
(cd "$OUT" && "$REXX_BIN" compiled.rex > actual.txt 2>&1) || true
diff -u "$OUT/expected.txt" "$OUT/actual.txt" || { echo "FAIL output differs from the interpreter"; exit 1; }
grep -q 'error success 0' "$OUT/actual.txt" || { echo "FAIL .Error did not resolve to the public class"; exit 1; }
# A program that requires the library through its <lib>_requires.cls sees the classes before .LOCAL too.
mkdir -p "$OUT/client"
cp "$OUT/rxscopebase_requires.cls" "$OUT/client/scope_base.cls"
printf 'say .Error~SUCCESS\n::requires "scope_base.cls"\n' > "$OUT/client/client.rex"
mkdir -p "$OUT/orig"; cp "$F/scope_base.cls" "$OUT/orig/"; cp "$OUT/client/client.rex" "$OUT/orig/"
(cd "$OUT/orig" && REXX_PATH="$OUT/orig" "$REXX_BIN" client.rex > ../client_expected.txt 2>&1) || true
(cd "$OUT/client" && REXX_PATH="$OUT/client" "$REXX_BIN" client.rex > ../client_actual.txt 2>&1) || true
diff -u "$OUT/client_expected.txt" "$OUT/client_actual.txt" || { echo "FAIL client through _requires.cls differs"; exit 1; }
echo "PASS library scope: required library classes before .LOCAL ($(wc -l < "$OUT/expected.txt") lines identical)"
