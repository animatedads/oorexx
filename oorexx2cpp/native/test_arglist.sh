#!/usr/bin/env bash
# Arguments are an array: methods and routines take any number, omitted slots stay unset, SELF sends pass N arguments.
# Expected output comes from the interpreter running the same source as plain ooRexx.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}; REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=${TEST_OUTPUT_DIR:-$(mktemp -d)}; mkdir -p "$OUT"
cat > "$OUT/args.cls" <<'EOC'
::class Args public
::method init
::method five
  use arg a, b, c, d, e
  return a b c d e
::method mid
  use arg a, b, c
  return a '|' b '|' c
::method viaSelf
  return self~five(1, 2, 3, 4, 5)
::routine sum4 public
  use arg a, b, c, d
  return a + b + c + d
EOC
printf 'o = .Args~new\nsay o~five(1,2,3,4,5)\nsay o~mid(1,,3)\nsay o~viaSelf\nsay sum4(1,2,3,4)\n' > "$OUT/driver.rex"
"$REXX_BIN" -e 2>/dev/null || true
cp "$OUT/args.cls" "$OUT/args_ref.cls"
{ cat "$OUT/driver.rex"; echo '::requires "args_ref.cls"'; } > "$OUT/ref.rex"
{ cat "$OUT/driver.rex"; echo '::requires "rxarglist" library'; } > "$OUT/nat.rex"
(cd "$OUT" && REXX_PATH="$OUT${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" ref.rex > ref.out)
"$ROOT/native/build.sh" "$OUT/args.cls" "$OUT" rxarglist >/dev/null
(cd "$OUT" && LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib" "$REXX_BIN" nat.rex > nat.out)
cmp "$OUT/ref.out" "$OUT/nat.out" || { echo "FAIL arglist parity"; diff "$OUT/ref.out" "$OUT/nat.out"; exit 1; }
echo "PASS arglist: 5-arg method, omitted middle argument, SELF send with 5 args, 4-arg routine match the interpreter"
