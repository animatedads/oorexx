#!/usr/bin/env bash
# ooRexx permits ::OPTIONS between and after class definitions; options
# apply to the package as a whole, not lexically to the following class.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OO_LIB=${OO_LIB:-$OO_ROOT/lib}
CXX=${CXX:-g++}
OUT=${PACKAGE_TEST_DIR:-$(mktemp -d)}
if [[ -z ${PACKAGE_TEST_DIR:-} ]]; then trap 'rm -rf "$OUT"' EXIT; fi
mkdir -p "$OUT"
export REXX_PATH="$ROOT:$ROOT/native/fixtures:$OO_ROOT/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$ROOT/native/build.sh" "$ROOT/native/fixtures/package_options_late.cls" "$OUT" rx2cpp_late >"$OUT/build.log"
"$REXX_BIN" "$ROOT/native/fixtures/package_options_late_oracle.rex" >"$OUT/reference.out"
"$REXX_BIN" "$ROOT/native/fixtures/package_options_late_client.rex" >"$OUT/native.out"
cmp "$OUT/reference.out" "$OUT/native.out"
[[ $(wc -l <"$OUT/native.out") -eq 2 ]]
[[ $(grep -c '^0.333333333333333333$' "$OUT/native.out") -eq 2 ]]
accepted=$(sha256sum "$OUT/librx2cpp_late.so" | cut -d' ' -f1)
for declaration in \
  '::options digits 18; ::options digits 20' \
  '::options digits 18; ::class Clash public' \
  '::method another; ::options digits 19' \
  '::options trace all'; do
  printf '::class Sample public\n::method init\n::method get\n  return 1 / 3\n%s\n' "$declaration" >"$OUT/reject.cls"
  if "$ROOT/native/build.sh" "$OUT/reject.cls" "$OUT" rx2cpp_late >"$OUT/reject.log" 2>&1; then
    printf 'FAIL: accepted unsafe/unsupported package declaration: %s\n' "$declaration" >&2
    exit 1
  fi
  [[ $accepted == "$(sha256sum "$OUT/librx2cpp_late.so" | cut -d' ' -f1)" ]] || {
    echo 'FAIL: rejected package overwrote the previously accepted library' >&2
    exit 1
  }
done
printf 'PASS %s late/interleaved ::OPTIONS (2-line byte parity, 4 fail-closed builds)\n' "$CXX"
