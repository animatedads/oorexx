#!/usr/bin/env bash
# Package-local ::ROUTINE calls: ordered positional args, holes and fresh activations.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}; REXX_BIN=${REXX_BIN:-rexx}; CXX=${CXX:-g++}
OUT=${TEST_OUTPUT_DIR:-"$ROOT/build/localcalls-$(basename "$CXX")"}
mkdir -p "$OUT"
export LD_LIBRARY_PATH="$OO_ROOT/lib:$OUT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/native/fixtures:$ROOT${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" "$ROOT/native/fixtures/routine_localcalls_oracle.rex" > "$OUT/oracle.out"
OO_ROOT="$OO_ROOT" REXX_BIN="$REXX_BIN" CXX="$CXX" "$ROOT/native/build.sh" "$ROOT/native/fixtures/routine_localcalls.cls" "$OUT" rx2cpp_localcalls
"$REXX_BIN" "$ROOT/native/fixtures/routine_localcalls_client.rex" > "$OUT/native.out"
cmp "$OUT/oracle.out" "$OUT/native.out"
[[ $(wc -l < "$OUT/native.out") == 8 ]]
echo "PASS $CXX package-local calls, recursion, omission, extras, nested scalar results (8 lines)"
prior=$(sha256sum "$OUT/librx2cpp_localcalls.so" | cut -d' ' -f1)
for kind in unknown external builtin missing_parenthesis object_alias; do
    cat > "$OUT/reject_$kind.cls" <<'REXX'
::class RoutineLocalHost public
::method init
REXX
    case "$kind" in
      unknown) printf '::routine A PUBLIC\n  return UNDEFINED(1)\n' >> "$OUT/reject_$kind.cls";;
      external) printf '::routine LIBEX PRIVATE EXTERNAL "LIBRARY rxmath RxCalcSin"\n::routine A PUBLIC\n  return LIBEX(1)\n' >> "$OUT/reject_$kind.cls";;
      builtin) printf '::routine ABS PRIVATE\n  use arg x\n  return x\n::routine A PUBLIC\n  return ABS(1)\n' >> "$OUT/reject_$kind.cls";;
      missing_parenthesis) printf '::routine A PUBLIC\n  return A(1,2\n' >> "$OUT/reject_$kind.cls";;
      object_alias) printf '::routine A PUBLIC\n  return .NIL~unknown(1)\n' >> "$OUT/reject_$kind.cls";;
    esac
    if OO_ROOT="$OO_ROOT" REXX_BIN="$REXX_BIN" CXX="$CXX" "$ROOT/native/build.sh" "$OUT/reject_$kind.cls" "$OUT" rx2cpp_localcalls > "$OUT/reject_$kind.log" 2>&1; then
      echo "FAIL accepted $kind" >&2; exit 1
    fi
    [[ $(sha256sum "$OUT/librx2cpp_localcalls.so" | cut -d' ' -f1) == "$prior" ]] || { echo "FAIL rollback $kind"; exit 1; }
    grep -q 'rx2cpp' "$OUT/reject_$kind.log"
    echo "PASS $CXX reject $kind without replacing library"
done
