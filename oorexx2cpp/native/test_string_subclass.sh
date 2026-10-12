#!/usr/bin/env bash
# A compiled class that subclasses the interpreter's .String (external parent): overrides, SELF sends and ~method:SUPER match the interpreter.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}; REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cp "$ROOT/native/fixtures/string_subclass.cls" "$T/ref.rex"
printf '%s\n' 's = .MyString~new("hello")' 'say s~shout' 'say s~twice' 'say s~describe' 'say s~length' 'say s~class~id' > "$T/body"
{ cat "$T/body"; echo '::requires "ref.rex"'; } > "$T/ref_main.rex"
{ cat "$T/body"; echo '::requires "mysub" library'; } > "$T/nat_main.rex"
(cd "$T" && "$REXX_BIN" ref_main.rex > ref.out)
OO_ROOT="$OO_ROOT" REXX_BIN="$REXX_BIN" "$ROOT/native/build.sh" "$ROOT/native/fixtures/string_subclass.cls" "$T/out" mysub >/dev/null
(cd "$T" && LD_LIBRARY_PATH="$OO_ROOT/lib:$T/out${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$REXX_BIN" nat_main.rex > nat.out)
cmp "$T/ref.out" "$T/nat.out" || { echo "FAIL string subclass"; diff "$T/ref.out" "$T/nat.out"; exit 1; }
echo "PASS compiled subclass of .String: overrides, SELF sends and ~length:SUPER match the interpreter"
