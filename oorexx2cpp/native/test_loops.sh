#!/usr/bin/env bash
# Control flow in native methods uses the standalone rules: counted DO (TO/BY in either order), WHILE, count, ITERATE, LEAVE, IF/ELSE blocks.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}; REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=${TEST_OUTPUT_DIR:-$(mktemp -d)}; mkdir -p "$OUT"
cat > "$OUT/l.cls" <<'EOC'
::class L public
::method init
::method s
  use arg n
  t = 0
  do i = 1 to n
    if i == 3 then iterate
    if i > 6 then leave
    t = t + i
  end
  k = 0
  do while k < 3
    k = k + 1
  end
  do 2
    k = k + 10
  end
  do t = 5 by -2 to 1
    if t == 3 then do
      k = k + 100
    end
    else k = k + t
  end
  return t k
EOC
printf 'say .L~new~s(10)\nsay .L~new~s(4)\n' > "$OUT/driver.rex"
cp "$OUT/l.cls" "$OUT/l_ref.cls"
{ cat "$OUT/driver.rex"; echo '::requires "l_ref.cls"'; } > "$OUT/ref.rex"
{ cat "$OUT/driver.rex"; echo '::requires "rxloops" library'; } > "$OUT/nat.rex"
(cd "$OUT" && REXX_PATH="$OUT${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" ref.rex > ref.out)
"$ROOT/native/build.sh" "$OUT/l.cls" "$OUT" rxloops >/dev/null
(cd "$OUT" && LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib" "$REXX_BIN" nat.rex > nat.out)
cmp "$OUT/ref.out" "$OUT/nat.out" || { echo "FAIL loops"; diff "$OUT/ref.out" "$OUT/nat.out"; exit 1; }
echo "PASS native loops/IF match the interpreter (TO/BY either order, WHILE, count, ITERATE, LEAVE)"
