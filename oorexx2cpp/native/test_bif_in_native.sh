#!/usr/bin/env bash
# BIFs called from native package methods and routines run through the shared rx::dispatchBif path.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}; REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=${TEST_OUTPUT_DIR:-$(mktemp -d)}; mkdir -p "$OUT"
cat > "$OUT/b.cls" <<'EOC'
::class B public
::method init
::method f
  use arg h, n
  return x2d(h) + length(n) + abs(-3)
::method g
  return right(c2x('A'), 4, '0') substr('hello', 2, 3) left('ab', 4, '.')
::routine r public
  numeric digits 30
  use arg h
  return x2d(h) * 2
EOC
printf 'say .B~new~f("ff","abc")\nsay .B~new~g\nsay r("1f")\n' > "$OUT/driver.rex"
{ cat "$OUT/driver.rex"; echo '::requires "b_ref.cls"'; } > "$OUT/ref.rex"; cp "$OUT/b.cls" "$OUT/b_ref.cls"
{ cat "$OUT/driver.rex"; echo '::requires "rxbifnat" library'; } > "$OUT/nat.rex"
(cd "$OUT" && REXX_PATH="$OUT${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" ref.rex > ref.out)
"$ROOT/native/build.sh" "$OUT/b.cls" "$OUT" rxbifnat >/dev/null
(cd "$OUT" && LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib" "$REXX_BIN" nat.rex > nat.out)
cmp "$OUT/ref.out" "$OUT/nat.out" || { echo "FAIL BIF parity in native lane"; diff "$OUT/ref.out" "$OUT/nat.out"; exit 1; }
echo "PASS BIFs inside native methods and routines match the interpreter (X2D, ABS, LENGTH, RIGHT, C2X, SUBSTR, LEFT)"
