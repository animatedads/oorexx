#!/usr/bin/env bash
# Native library uses the HOST interpreter's real objects: .ARRAY/.DIRECTORY/.LIST, message sends and message statements.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}; REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=${TEST_OUTPUT_DIR:-$(mktemp -d)}; mkdir -p "$OUT"
cat > "$OUT/h.cls" <<'EOC'
::class H public
::method init
::method build
  a = .array~of(10,20,30)
  d = .directory~new
  d~put(a~at(2),"k")
  return a~items d~at("k") a~class~id
::routine mk public
  l = .list~new
  l~append("x"); l~append("y")
  return l~items l~firstitem
EOC
printf 'say .H~new~build\nsay mk()\n' > "$OUT/driver.rex"
cp "$OUT/h.cls" "$OUT/h_ref.cls"
{ cat "$OUT/driver.rex"; echo '::requires "h_ref.cls"'; } > "$OUT/ref.rex"
{ cat "$OUT/driver.rex"; echo '::requires "rxhostobj" library'; } > "$OUT/nat.rex"
(cd "$OUT" && REXX_PATH="$OUT${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" ref.rex > ref.out)
"$ROOT/native/build.sh" "$OUT/h.cls" "$OUT" rxhostobj >/dev/null
(cd "$OUT" && LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib" "$REXX_BIN" nat.rex > nat.out)
cmp "$OUT/ref.out" "$OUT/nat.out" || { echo "FAIL host objects"; diff "$OUT/ref.out" "$OUT/nat.out"; exit 1; }
echo "PASS host objects in a native library: array, directory, list, class messages identical to the interpreter"
