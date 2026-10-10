#!/usr/bin/env bash
# Qualify real ::OPTIONS package numeric defaults in loaded class .so files.
# Non-OFF tracing and unsupported condition options remain fail-closed.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OO_LIB=${OO_LIB:-$OO_ROOT/lib}
CXX=${CXX:-g++}
OUT=${PACKAGE_TEST_DIR:-$(mktemp -d)}
mkdir -p "$OUT"
export REXX_PATH="$ROOT:$ROOT/native/fixtures:$OO_ROOT/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$ROOT/native/build.sh" "$ROOT/native/fixtures/package_options.cls" "$OUT" rx2cpp_pkgoptions
"$REXX_BIN" "$ROOT/native/fixtures/package_options_oracle.rex" > "$OUT/options.reference.out"
"$REXX_BIN" "$ROOT/native/fixtures/package_options_client.rex" > "$OUT/options.native.out"
cmp "$OUT/options.reference.out" "$OUT/options.native.out"
grep -Fqx '12345678901234567891' "$OUT/options.native.out"
# Numeric default is applied to native class methods, not caller activation.
grep -Fqx '333.3333333333333333333333' "$OUT/options.native.out"
accepted=$(sha256sum "$OUT/librx2cpp_pkgoptions.so")
for declaration in \
  '::options trace all' \
  '::options all condition' \
  '::options digits outside' \
  '::options digits 0' \
  '::options digits 100001' \
  '::options digits 9 fuzz 9' \
  '::options fuzz 1 form nonsense' \
  '::options digits 25 fuzz 25' \
  '::options digits (10 + 10)' \
  '::options trace intermediate'; do
  printf '%s\n' "$declaration" '::class OptionsProbe public' '::method init' '::method get' '  return 1' > "$OUT/reject.cls"
  if "$ROOT/native/build.sh" "$OUT/reject.cls" "$OUT" rx2cpp_pkgoptions > "$OUT/reject.log" 2>&1; then
    echo "FAIL: accepted unsupported ::OPTIONS: $declaration" >&2; exit 1
  fi
  [[ "$accepted" == "$(sha256sum "$OUT/librx2cpp_pkgoptions.so")" ]] || {
    echo 'FAIL: invalid ::OPTIONS replaced an accepted library' >&2; exit 1;
  }
done
# High precision: 1800-digit multiplication expression under ::OPTIONS DIGITS 2000.
python - "$OUT" <<'PY2'
from pathlib import Path
import sys
p=Path(sys.argv[1]); big='9'*180
(p/'digits2000.cls').write_text('::options digits 2000\n::class BigCalc public\n::method init\n::method run\n  return '+(' * '.join([big]*10))+'\n')
(p/'digits2000_oracle.rex').write_text("say .BigCalc~new~run\n::requires 'digits2000.cls'\n")
(p/'digits2000_client.rex').write_text("say .BigCalc~new~run\n::requires 'rx2cpp_digits2000' library\n")
PY2
"$ROOT/native/build.sh" "$OUT/digits2000.cls" "$OUT" rx2cpp_digits2000
export REXX_PATH="$OUT:$REXX_PATH"
"$REXX_BIN" "$OUT/digits2000_oracle.rex" > "$OUT/digits2000.reference.out"
"$REXX_BIN" "$OUT/digits2000_client.rex" > "$OUT/digits2000.native.out"
cmp "$OUT/digits2000.reference.out" "$OUT/digits2000.native.out"
echo "PASS $CXX ::OPTIONS native DIGITS/FORM/FUZZ parity, high-precision arithmetic, 10 rollback-protected rejections"
