#!/usr/bin/env bash
# (delegates to native/build.sh) Compile a Rexx file with a class and routines to libNAME.so and call it from an interpreted script with ::requires "NAME" library.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
printf '::class Counter public\n::method init\n  expose n\n  n = 0\n::method bump\n  expose n\n  n = n + 1\n  return n\n::routine sq public\n  use arg x\n  return x*x\n::routine greet public\n  use arg w\n  return "hi" w\n' > "$T/sqlib.cls"
printf 'c = .Counter~new\nsay c~bump c~bump sq(7) greet("Tom")\n::requires "sqlib" library\n' > "$T/use.rex"
RX2CPP_LIBRARY=sqlib "$ROOT/build.sh" "$T/sqlib.cls" "$T/out/sqlib.bin" 2>/dev/null
got=$(LD_LIBRARY_PATH="$T/out:${LD_LIBRARY_PATH:-}" rexx "$T/use.rex")
[[ "$got" == "1 2 49 hi Tom" ]] || { echo "FAIL library mode: [$got]"; exit 1; }
echo "PASS library mode: ::requires library exports classes and routines"
