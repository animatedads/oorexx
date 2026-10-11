#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${OO_ROOT:?ooRexx installation required}"
export REXX_PATH="$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
run() { "$REXX_BIN" "$ROOT/inspector/inspect.rex" "$1" "$2"; }
# Exercise real compiled objects, including private methods, class methods,
# routines, original package options, and a wrapped prologue never executed.
run "$ROOT/tests/fixtures/object_inspection/prologue.cls" "$TMP/one.cls" >"$TMP/one.map"
run "$ROOT/tests/fixtures/object_inspection/prologue.cls" "$TMP/two.cls" >"$TMP/two.map"
cmp "$TMP/one.map" "$TMP/two.map"
! test -e "$TMP/one.cls" && ! test -e "$TMP/two.cls"
grep -q '^RX2CPP_OBJECT_MODEL/0.1$' "$TMP/one.map"
grep -q "$(printf '^PACKAGE\t.*\t9\t0\tSCIENTIFIC\tNOPROLOG\t3$')" "$TMP/one.map"
grep -q "$(printf '^PROLOGUE\t.*')" "$TMP/one.map"
grep -q "$(printf '^METHOD\t53414D504C45\t534543524554\t50524956415445\t')" "$TMP/one.map"
grep -q "$(printf '^CLASS_METHOD\t53414D504C45\t5554494C495459\t50524956415445\t')" "$TMP/one.map"
grep -q "$(printf '^ROUTINE\t\t494E5445524E414C\t50524956415445\t')" "$TMP/one.map"
! grep -q 'DO NOT EXECUTE PROLOGUE' "$TMP/one.map"  # source encoded
! grep -q '^CLASS.*46414B45' "$TMP/one.map"     # quoted ::class Fake
# Verify class-side INIT is neutralised but its method source and original
# selector are available in the model.  Instance INIT remains independent.
run "$ROOT/tests/fixtures/object_inspection/class_init.cls" "$TMP/init.cls" >"$TMP/init.map"
! grep -q 'SHOULD NOT RUN CLASS INIT' "$TMP/init.map"
grep -q "$(printf '^CLASS_METHOD\t41\t494E4954\t5055424C4943\t.*494E5350454354494F4E5F414C494153')" "$TMP/init.map"
grep -q "$(printf '^METHOD\t41\t494E4954\t')" "$TMP/init.map"
# Fail closed before trying to execute prologues from imported packages.
if run "$ROOT/tests/fixtures/object_inspection/requires.cls" "$TMP/requires.cls" >"$TMP/failed.out" 2>&1; then
  echo 'FAIL: inspector accepted a potentially executing ::REQUIRES' >&2; exit 1
fi
grep -q '::REQUIRES executes dependencies' "$TMP/failed.out"
! test -e "$TMP/requires.cls"
# Optional unmodified Crypto source differential inventory.
if [[ -n ${CRYPTO_SOURCE:-} ]]; then
  run "$CRYPTO_SOURCE" "$TMP/crypto.cls" >"$TMP/crypto.map"
  grep -q "$(printf '\t2000\t0\tSCIENTIFIC\tPROLOG\t')" "$TMP/crypto.map"
  grep -q "$(printf '^ROUTINE\t\t52585F4D4F445F494E5645525345\t50524956415445\t')" "$TMP/crypto.map"
  ! test -e "$TMP/crypto.cls"
  echo 'PASS unchanged crypto.cls object inventory'
fi
echo 'PASS ooRexx package/method/routine/prologue introspection, privacy, class INIT isolation, deterministic map and cleanup'
