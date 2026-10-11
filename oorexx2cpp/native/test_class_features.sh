#!/usr/bin/env bash
# Method options as the ooRexx directive parser defines them: ABSTRACT, PRIVATE, CLASS methods, CLASS attributes, INIT CLASS.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}; REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=${TEST_OUTPUT_DIR:-$(mktemp -d)}; mkdir -p "$OUT"
cat > "$OUT/cm.cls" <<'EOC'
::class Base public
::method update abstract
::method init
  expose n
  n = 0
::method bump
  expose n
  n = n + 1
  return self~secret(n)
::method secret private
  use arg v
  return v * 100
::method make class
  use arg x
  return "made" x self~arch
::attribute arch class
::method init class
  self~arch = "little"
::method counter class
  expose total
  if \datatype(total, 'W') then total = 0
  total = total + 1
  return total
EOC
cat > "$OUT/driver.rex" <<'EOD'
say .Base~make(7)
say .Base~counter .Base~counter
b = .Base~new
say b~bump b~bump
say .Base~arch
signal on syntax name blocked
b~secret(1)
say "no error"
exit
blocked: say "private blocked" condition('C')
EOD
cp "$OUT/cm.cls" "$OUT/cm_ref.cls"
{ cat "$OUT/driver.rex"; echo '::requires "cm_ref.cls"'; } > "$OUT/ref.rex"
{ cat "$OUT/driver.rex"; echo '::requires "rxclassfeat" library'; } > "$OUT/nat.rex"
(cd "$OUT" && REXX_PATH="$OUT${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" ref.rex > ref.out 2>&1)
"$ROOT/native/build.sh" "$OUT/cm.cls" "$OUT" rxclassfeat >/dev/null
(cd "$OUT" && LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib" "$REXX_BIN" nat.rex > nat.out 2>&1)
cmp "$OUT/ref.out" "$OUT/nat.out" || { echo "FAIL class features"; diff "$OUT/ref.out" "$OUT/nat.out"; exit 1; }
echo "PASS class features: abstract, private, class methods, class attributes, INIT CLASS match the interpreter"
