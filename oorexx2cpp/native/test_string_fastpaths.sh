#!/usr/bin/env bash
# In-place byte-string methods (BITXOR/BITAND/BITOR/REVERSE/LENGTH/SUBSTR/LEFT/RIGHT/C2X) equal the interpreter on edge shapes.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}; REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cp "$ROOT/native/fixtures/string_fastpaths.cls" "$T/ref.rex"
drive='o = .StrOps~new
as = .array~of("", "a", "abc", "hello world", "00ff10"x, "ffffffff"x, "0123456789abcdef"x)
bs = .array~of("", "z", "xyz", "00000000"x, "ff00ff00ff"x, "k")
ns = .array~of(1, 2, 3, 5, 9, 12)
ms = .array~of(0, 1, 2, 4, 7)
do a over as
  do b over bs
    do n over ns
      do m over ms
        say o~run(a, b, n, m)~c2x
      end
    end
  end
end'
{ echo "$drive"; echo '::requires "ref.rex"'; } > "$T/ref_main.rex"
{ echo "$drive"; echo '::requires "strfast" library'; } > "$T/nat_main.rex"
(cd "$T" && "$REXX_BIN" ref_main.rex > ref.out)
OO_ROOT="$OO_ROOT" REXX_BIN="$REXX_BIN" "$ROOT/native/build.sh" "$ROOT/native/fixtures/string_fastpaths.cls" "$T/out" strfast >/dev/null
(cd "$T" && LD_LIBRARY_PATH="$OO_ROOT/lib:$T/out${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$REXX_BIN" nat_main.rex > nat.out)
cmp "$T/ref.out" "$T/nat.out" || { echo "FAIL string fast paths"; diff "$T/ref.out" "$T/nat.out" | head; exit 1; }
echo "PASS string fast paths: $(wc -l < "$T/ref.out") edge cases identical to the interpreter"
