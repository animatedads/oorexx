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
for kind in missing_parenthesis; do
    cat > "$OUT/reject_$kind.cls" <<'REXX'
::class RoutineLocalHost public
::method init
REXX
    case "$kind" in
      external) printf '::routine LIBEX PRIVATE EXTERNAL "LIBRARY rxmath RxCalcSin"\n::routine A PUBLIC\n  return LIBEX(1)\n' >> "$OUT/reject_$kind.cls";;
      missing_parenthesis) printf '::routine A PUBLIC\n  return A(1,2\n' >> "$OUT/reject_$kind.cls";;
    esac
    if OO_ROOT="$OO_ROOT" REXX_BIN="$REXX_BIN" CXX="$CXX" "$ROOT/native/build.sh" "$OUT/reject_$kind.cls" "$OUT" rx2cpp_localcalls > "$OUT/reject_$kind.log" 2>&1; then
      echo "FAIL accepted $kind" >&2; exit 1
    fi
    [[ $(sha256sum "$OUT/librx2cpp_localcalls.so" | cut -d' ' -f1) == "$prior" ]] || { echo "FAIL rollback $kind"; exit 1; }
    grep -q 'rx2cpp' "$OUT/reject_$kind.log"
    echo "PASS $CXX reject $kind without replacing library"
done
# A call to a routine that does not exist is not a compile error: as interpreted, it raises 43.1 when it runs
# (the traceback location differs: compiled code has no source lines).
U="$OUT/unknown_routine"; mkdir -p "$U"
printf '::class RoutineLocalHost public\n::method init\n::routine A PUBLIC\n  return UNDEFINED(1)\n' > "$U/unknown.cls"
printf 'call A\n::requires "unknown.cls"\n' > "$U/interpreted.rex"
printf 'call A\n::requires "rx2cpp_localcalls_unknown" library\n' > "$U/compiled.rex"
(cd "$U" && REXX_PATH="$U" "$REXX_BIN" interpreted.rex > interpreted.out 2>&1) || true
OO_ROOT="$OO_ROOT" CXX="$CXX" REXX_BIN="$REXX_BIN" "$ROOT/native/build.sh" "$U/unknown.cls" "$U" rx2cpp_localcalls_unknown > "$U/build.log" 2>&1 \
  || { tail -20 "$U/build.log"; echo "FAIL unknown routine call rejected at compile time" >&2; exit 1; }
(cd "$U" && LD_LIBRARY_PATH="$U:$LD_LIBRARY_PATH" "$REXX_BIN" compiled.rex > compiled.out 2>&1) || true
want='Error 43.1:  Could not find routine "UNDEFINED".'
if ! grep -qxF "$want" "$U/interpreted.out" || ! grep -qxF "$want" "$U/compiled.out"; then
  diff -u "$U/interpreted.out" "$U/compiled.out" >&2 || true; echo "FAIL unknown routine: expected $want" >&2; exit 1
fi
echo "PASS $CXX unknown routine unknown: Error 43.1 at run time, as interpreted"
# A package routine named like a built-in function: ABS(-1) still calls the built-in (search order: internal,
# built-in, then package/external routines), compiled as interpreted.
B="$OUT/builtin_name"; mkdir -p "$B"
printf '::class RoutineLocalHost public\n::method init\n::routine ABS PRIVATE\n  use arg x\n  return "mine" x\n::routine A PUBLIC\n  return ABS(-1)\n' > "$B/bi.cls"
printf 'say A()\n::requires "bi.cls"\n' > "$B/interpreted.rex"
printf 'say A()\n::requires "rx2cpp_localcalls_bi" library\n' > "$B/compiled.rex"
(cd "$B" && REXX_PATH="$B" "$REXX_BIN" interpreted.rex > interpreted.out 2>&1) || true
OO_ROOT="$OO_ROOT" CXX="$CXX" REXX_BIN="$REXX_BIN" "$ROOT/native/build.sh" "$B/bi.cls" "$B" rx2cpp_localcalls_bi > "$B/build.log" 2>&1 \
  || { tail -20 "$B/build.log"; echo "FAIL routine named like a built-in rejected" >&2; exit 1; }
(cd "$B" && LD_LIBRARY_PATH="$B:$LD_LIBRARY_PATH" "$REXX_BIN" compiled.rex > compiled.out 2>&1) || true
cmp -s "$B/interpreted.out" "$B/compiled.out" && [[ $(cat "$B/compiled.out") == 1 ]] \
  || { diff -u "$B/interpreted.out" "$B/compiled.out" >&2 || true; echo "FAIL routine named like a built-in" >&2; exit 1; }
echo "PASS $CXX routine named like a built-in: the built-in runs, as interpreted"
