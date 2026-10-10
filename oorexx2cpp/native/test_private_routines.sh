#!/usr/bin/env bash
# Package-private routine visibility and native C++17 ABI differential.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
OUT=${TEST_OUTPUT_DIR:-$ROOT/build/private-routines-$(basename "$CXX")}
mkdir -p "$OUT"
export LD_LIBRARY_PATH="$OO_ROOT/lib:$OUT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/native/fixtures:$ROOT${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" "$ROOT/native/fixtures/routine_private_oracle.rex" > "$OUT/oracle.out"
OO_ROOT="$OO_ROOT" REXX_BIN="$REXX_BIN" CXX="$CXX" \
  "$ROOT/native/build.sh" "$ROOT/native/fixtures/routine_private.cls" "$OUT" rx2cpp_private_test
"$REXX_BIN" "$ROOT/native/fixtures/routine_private_client.rex" > "$OUT/native.out"
cmp "$OUT/oracle.out" "$OUT/native.out"
[[ $(wc -l < "$OUT/native.out") == 5 ]]
# Explicit source-level privacy and lower-level ABI aliases are different.
grep -q '::routine HELPERPRIVATE private external' "$OUT/generated_package.cpp"
grep -q '::routine HELPEREXPLICIT private external' "$OUT/generated_package.cpp"
! grep -q 'REXX_TYPED_ROUTINE(HELPERPRIVATE,' "$OUT/generated_package.cpp"
! grep -q 'REXX_TYPED_ROUTINE(HELPEREXPLICIT,' "$OUT/generated_package.cpp"
grep -q 'REXX_TYPED_ROUTINE(RX2CPP_PRIVATE_HELPERPRIVATE,' "$OUT/generated_package.cpp"
echo "PASS $CXX implicit/explicit PRIVATE + PUBLIC native library: 5 byte-identical lines"
# Probe ooRexx's own package routine metadata and call a compiled private
# routine using the package-owned handle.  Instrumentation is *test only*;
# the distributed library is not modified.
mkdir -p "$OUT/instrumented"
awk -v testSource="$ROOT/native/fixtures/private_registry_probe.inc" '
  /    auto classes = ctx->GetPackagePublicClasses\(pkg\);/ {
    while ((getline line < testSource) > 0) print line;
    close(testSource);
    found++;
  }
  {print}
  END {if (found != 1) exit 10}
' "$OUT/generated_package.cpp" > "$OUT/instrumented/visibility_package.cpp"
"$CXX" -std=c++17 -O2 -fPIC -shared -Wall -Wextra -Werror \
    -I"$OO_ROOT/include" -I"$ROOT/include" -I"$ROOT/hybrid" -I"$OUT" \
    "$OUT/generated.cpp" "$OUT/instrumented/visibility_package.cpp" \
    -o "$OUT/instrumented/librx2cpp_private_test.so"
LD_LIBRARY_PATH="$OO_ROOT/lib:$OUT/instrumented${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    "$REXX_BIN" "$ROOT/native/fixtures/routine_private_client.rex" > "$OUT/instrumented/native.out"
cmp "$OUT/oracle.out" "$OUT/instrumented/native.out"
echo "PASS $CXX ooRexx GetPackageRoutines/GetPackagePublicRoutines + CallRoutine private handle"
prior=$(sha256sum "$OUT/librx2cpp_private_test.so" | cut -d' ' -f1)
for bad in duplicate conflicting_visibility external alias_collision non_scalar three_arg same_line return_missing; do
  src="$OUT/reject_$bad.cls"
  cat > "$src" <<'REXX'
::class RoutineHost public
::method init
  expose n
  n = 1
REXX
  case "$bad" in
    duplicate) printf '\n::routine hidden\n return 1\n::routine hidden private\n return 2\n' >> "$src";;
    conflicting_visibility) printf '\n::routine hidden private public\n return 1\n' >> "$src";;
    external) printf '\n::routine hidden external "LIBRARY rxmath RxCalcSin"\n' >> "$src";;
    alias_collision) printf '\n::routine hidden private\n return 1\n::routine RX2CPP_PRIVATE_HIDDEN public\n return 2\n' >> "$src";;
    non_scalar) printf '\n::routine hidden private\n use arg n\n return n~string\n' >> "$src";;
    three_arg) printf '\n::routine hidden\n use arg a,b,c\n return a\n' >> "$src";;
    same_line) printf '\n::routine hidden private; say "not standalone"\n return 1\n' >> "$src";;
    return_missing) printf '\n::routine hidden\n use arg n\n n = 1\n' >> "$src";;
  esac
  if OO_ROOT="$OO_ROOT" REXX_BIN="$REXX_BIN" CXX="$CXX" \
    "$ROOT/native/build.sh" "$src" "$OUT" rx2cpp_private_test > "$OUT/$bad.log" 2>&1; then
     echo "FAIL $bad was compiled" >&2; exit 1
  fi
  actual=$(sha256sum "$OUT/librx2cpp_private_test.so" | cut -d' ' -f1)
  [[ "$prior" == "$actual" ]] || { echo "FAIL $bad modified last known good .so" >&2; exit 1; }
  echo "PASS $CXX reject $bad without replacing .so"
done
