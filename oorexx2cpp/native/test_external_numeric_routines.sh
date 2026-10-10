#!/usr/bin/env bash
# Native-private EXTERNAL routine delegation and NUMERIC activation parity.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
OUT=${TEST_OUTPUT_DIR:-"$ROOT/build/external-numeric-$(basename "$CXX")"}
PKG=rx2cpp_routine_ext
mkdir -p "$OUT"
export LD_LIBRARY_PATH="$OO_ROOT/lib:$OUT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/native/fixtures:$ROOT${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" "$ROOT/native/fixtures/routine_external_oracle.rex" >"$OUT/oracle.out"
cmp "$ROOT/native/fixtures/routine_external.expected" "$OUT/oracle.out"
OO_ROOT="$OO_ROOT" REXX_BIN="$REXX_BIN" CXX="$CXX" \
  "$ROOT/native/build.sh" "$ROOT/native/fixtures/routine_external.cls" "$OUT" "$PKG"
"$REXX_BIN" "$ROOT/native/fixtures/routine_external_client.rex" >"$OUT/native.out"
cmp "$OUT/oracle.out" "$OUT/native.out"
# PRIVATE and implicit-private EXTERNAL declarations must remain interpreted
# package declarations, not C++ native routine exports.
grep -Fq '::routine RX_MATH_SIN EXTERNAL ' "$OUT/generated_package.cpp"
grep -Fq '::routine RX_MATH_SECRET PRIVATE EXTERNAL ' "$OUT/generated_package.cpp"
! grep -q 'REXX_TYPED_ROUTINE(RX_MATH_SIN,' "$OUT/generated_package.cpp"
echo "PASS $CXX high-precision NUMERIC + interpreter-owned EXTERNAL routine package"
# Interpreter package metadata/handle probe is generated only in a test build.
mkdir -p "$OUT/probe"
awk -v source="$ROOT/native/fixtures/routine_external_registry_probe.inc" '
  /    auto classes = ctx->GetPackagePublicClasses\(pkg\);/ {
    while ((getline line < source) > 0) print line
    close(source)
    count++
  }
  {print}
  END { if (count != 1) exit 10 }
' "$OUT/generated_package.cpp" > "$OUT/probe/instrumented.cpp"
"$CXX" -std=c++17 -O0 -fPIC -shared -Wall -Wextra -Werror \
 -I"$OO_ROOT/include" -I"$ROOT/include" -I"$ROOT/hybrid" -I"$OUT" \
 "$OUT/generated.cpp" "$OUT/probe/instrumented.cpp" -o "$OUT/probe/lib${PKG}.so"
LD_LIBRARY_PATH="$OO_ROOT/lib:$OUT/probe${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  "$REXX_BIN" "$ROOT/native/fixtures/routine_external_client.rex" >"$OUT/probe/native.out"
cmp "$OUT/oracle.out" "$OUT/probe/native.out"
echo "PASS $CXX PRIVATE external routine callable from ooRexx package handle"
# Rejections cannot overwrite a previously accepted shared library.
prior=$(sha256sum "$OUT/lib${PKG}.so" | cut -d' ' -f1)
for kind in public_external malformed_external unknown_carrier external_body duplicate_external numeric_zero numeric_invalid_form numeric_dynamic; do
  bad="$OUT/reject_$kind.cls"
  cat >"$bad" <<'REXX'
::class RoutineHost public
::method init
  expose marker
  marker = 'present'
REXX
  case "$kind" in
   public_external) printf '\n::routine bad public external "LIBRARY rxmath RxCalcSin"\n' >>"$bad";;
   malformed_external) printf '\n::routine bad external "LIBRARY rxmath"\n' >>"$bad";;
   unknown_carrier) printf '\n::routine bad external "SYSTEM rxmath RxCalcSin"\n' >>"$bad";;
   external_body) printf '\n::routine bad external "LIBRARY rxmath RxCalcSin"\n say 1\n' >>"$bad";;
   duplicate_external) printf '\n::routine bad external "LIBRARY rxmath RxCalcSin"\n::routine bad private\n return 1\n' >>"$bad";;
   numeric_zero) printf '\n::routine bad private\n numeric digits 0\n return 1\n' >>"$bad";;
   numeric_invalid_form) printf '\n::routine bad private\n numeric form EXTREME\n return 1\n' >>"$bad";;
   numeric_dynamic) printf '\n::routine bad private\n numeric digits x\n return 1\n' >>"$bad";;
  esac
  if OO_ROOT="$OO_ROOT" REXX_BIN="$REXX_BIN" CXX="$CXX" \
      "$ROOT/native/build.sh" "$bad" "$OUT" "$PKG" >"$OUT/reject_$kind.log" 2>&1; then
    echo "FAIL unexpectedly accepted $kind" >&2; exit 1
  fi
  actual=$(sha256sum "$OUT/lib${PKG}.so" | cut -d' ' -f1)
  [[ $actual == "$prior" ]] || { echo "FAIL rejected $kind replaced accepted library" >&2; exit 1; }
  echo "PASS $CXX reject $kind without replacing accepted .so"
done
