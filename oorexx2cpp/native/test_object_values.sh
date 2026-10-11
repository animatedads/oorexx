#!/usr/bin/env bash
# Object-valued arguments and results cross the native ABI as the interpreter's own objects (no string marshalling),
# including .NIL, class attributes, derived INIT with INIT:SUPER and omitted arguments forwarded to the parent.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}; REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=${TEST_OUTPUT_DIR:-$(mktemp -d)}; mkdir -p "$OUT"
cat > "$OUT/o.cls" <<'EOC'
::class Holder public
::attribute slot class
::method init class
  self~slot = .nil
::method init
  expose kept
  use strict arg kept = 0
::method pass
  use arg thing
  return thing
::method make
  return .array~of(1,2,3)
::method keep
  expose kept
  use arg v
  kept = v
  return kept
::method stems
  expose K.
  do i = 0 to 3
    K.i = .array~of(i, i*i)
  end
  w. = 0
  total = 0
  do i = 0 to 3
    j = 3 - i
    total += K.j~at(2)
    w.i = w.i + K.i~at(1)
  end
  return total w.2
::class Sub subclass Holder public
::method init
  expose own
  use strict arg own = 7
  self~init:super(own)
::method own
  expose own
  return own
::method '+'
  use arg o
  return 100 + o
::method chain
  return self~pass(.array~of(4,5))~items
EOC
cat > "$OUT/driver.rex" <<'EOD'
h = .Holder~new
say h~pass(.nil)~class~id
say h~make~items h~make~at(2)
say .Holder~slot~class~id
s = .Sub~new
say s~own s~keep(9) (s + 5) s~chain
say h~pass(.array~of('a'))~items h~stems
EOD
cp "$OUT/o.cls" "$OUT/o_ref.cls"
{ cat "$OUT/driver.rex"; echo '::requires "o_ref.cls"'; } > "$OUT/ref.rex"
{ cat "$OUT/driver.rex"; echo '::requires "rxobjvals" library'; } > "$OUT/nat.rex"
(cd "$OUT" && REXX_PATH="$OUT${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" ref.rex > ref.out)
"$ROOT/native/build.sh" "$OUT/o.cls" "$OUT" rxobjvals >/dev/null
(cd "$OUT" && LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib" "$REXX_BIN" nat.rex > nat.out)
cmp "$OUT/ref.out" "$OUT/nat.out" || { echo "FAIL object values"; diff "$OUT/ref.out" "$OUT/nat.out"; exit 1; }
echo "PASS object values across the native ABI, derived INIT with INIT:SUPER, operator method, class attribute"
