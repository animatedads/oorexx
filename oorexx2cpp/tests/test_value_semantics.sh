#!/usr/bin/env bash
# Value semantics checked against the interpreter: decimal add/sub/compare rounding (incl. the DIGITS place of the larger
# operand), padded string compare, compound tails, stems passed as shared stem objects (methods, internal routines,
# hosted interpreter methods incl. REPLY and ~START), and large-DIGITS modular arithmetic.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}; REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
for name in decimal_exactness compound_tails stem_object_method stem_object_sharing stem_object_hosted bignum_modmul; do
  F="$ROOT/tests/fixtures/$name.rex"
  "$REXX_BIN" "$F" > "$T/$name.ref" 2>&1
  "$ROOT/build.sh" "$F" "$T/$name.bin" >/dev/null 2>&1 || { echo "FAIL $name: build"; exit 1; }
  "$T/$name.bin" > "$T/$name.out" 2>&1
  cmp -s "$T/$name.ref" "$T/$name.out" || { echo "FAIL $name"; diff "$T/$name.ref" "$T/$name.out"; exit 1; }
done
echo "PASS value semantics: decimal exactness, compound tails, shared stem objects (native, internal, hosted), bignum mod-mul identical to the interpreter"
