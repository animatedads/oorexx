#!/usr/bin/env bash
# Compile a Rexx file to libNAME.so and call it from an interpreted script with ::requires "NAME" library.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
printf 'exit\n::routine sq public\n  use arg n\n  return n*n\n::routine greet public\n  use arg w\n  return "hi" w\n' > "$T/sqlib.rex"
printf 'say sq(7) greet("Tom")\n::requires "sqlib" library\n' > "$T/use.rex"
RX2CPP_LIBRARY=sqlib "$ROOT/build.sh" "$T/sqlib.rex" "$T/out/sqlib.bin" 2>/dev/null
got=$(LD_LIBRARY_PATH="$T/out:${LD_LIBRARY_PATH:-}" rexx "$T/use.rex")
[[ "$got" == "49 hi Tom" ]] || { echo "FAIL library mode: [$got]"; exit 1; }
echo "PASS library mode: ::requires library calls compiled routines"
