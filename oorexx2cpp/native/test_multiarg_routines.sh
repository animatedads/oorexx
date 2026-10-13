#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}; REXX_BIN=${REXX_BIN:-rexx}; CXX=${CXX:-g++}
OUT=${TEST_OUTPUT_DIR:-"$ROOT/build/many-$(basename "$CXX")"}
mkdir -p "$OUT"
export LD_LIBRARY_PATH="$OO_ROOT/lib:$OUT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/native/fixtures:$ROOT${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" "$ROOT/native/fixtures/routine_many_oracle.rex" > "$OUT/oracle.out"
OO_ROOT="$OO_ROOT" CXX="$CXX" REXX_BIN="$REXX_BIN" "$ROOT/native/build.sh" "$ROOT/native/fixtures/routine_many.cls" "$OUT" rx2cpp_many
"$REXX_BIN" "$ROOT/native/fixtures/routine_many_client.rex" > "$OUT/native.out"
cmp "$OUT/oracle.out" "$OUT/native.out"
[[ $(wc -l < "$OUT/native.out") -eq 15 ]]
echo "PASS $CXX 0/3/4/6/16/17 positional scalar arguments including missing, omitted and extras, private non-export parity"
accepted=$(sha256sum "$OUT/librx2cpp_many.so" | cut -d' ' -f1)
for kind in duplicate omission; do
  case "$kind" in
    duplicate) header='::routine RX_DUP PUBLIC'; body=$'  use arg a,b,a\n  return a' ;;
    omission) header='::routine RX_OMIT PUBLIC'; body=$'  use arg a,,c\n  return a' ;;
    class_three) header='::class OrdinaryClass public'; body=$'::method init\n  return\n::method triplet\n  use arg a,b,c\n  return a' ;;
  esac
  printf '::class Simple public\n::method init\n  return\n%s\n%s\n' "$header" "$body" > "$OUT/reject_$kind.cls"
  if OO_ROOT="$OO_ROOT" CXX="$CXX" REXX_BIN="$REXX_BIN" "$ROOT/native/build.sh" "$OUT/reject_$kind.cls" "$OUT" rx2cpp_many >"$OUT/reject_$kind.log" 2>&1; then
    echo "FAIL accepted $kind" >&2; exit 1
  fi
  [[ $(sha256sum "$OUT/librx2cpp_many.so" | cut -d' ' -f1) == "$accepted" ]] || { echo "FAIL rollback $kind" >&2; exit 1; }
  echo "PASS $CXX rejects $kind without replacing library"
done
# A call to a routine that does not exist is not a compile error: as interpreted, it raises 43.1 when it runs
# (the traceback location differs: compiled code has no source lines).
U="$OUT/unknown_routine"; mkdir -p "$U"
printf '::class Simple public\n::method init\n  return\n::routine RX_CALL PUBLIC\n  use arg a,b,c\n  return not_supported_here(a)\n' > "$U/unknown.cls"
printf 'say RX_CALL(1)\n::requires "unknown.cls"\n' > "$U/interpreted.rex"
printf 'say RX_CALL(1)\n::requires "rx2cpp_many_unknown" library\n' > "$U/compiled.rex"
(cd "$U" && REXX_PATH="$U" "$REXX_BIN" interpreted.rex > interpreted.out 2>&1) || true
OO_ROOT="$OO_ROOT" CXX="$CXX" REXX_BIN="$REXX_BIN" "$ROOT/native/build.sh" "$U/unknown.cls" "$U" rx2cpp_many_unknown > "$U/build.log" 2>&1 \
  || { tail -20 "$U/build.log"; echo "FAIL unknown routine call rejected at compile time" >&2; exit 1; }
(cd "$U" && LD_LIBRARY_PATH="$U:$LD_LIBRARY_PATH" "$REXX_BIN" compiled.rex > compiled.out 2>&1) || true
want='Error 43.1:  Could not find routine "NOT_SUPPORTED_HERE".'
if ! grep -qxF "$want" "$U/interpreted.out" || ! grep -qxF "$want" "$U/compiled.out"; then
  diff -u "$U/interpreted.out" "$U/compiled.out" >&2 || true; echo "FAIL unknown routine: expected $want" >&2; exit 1
fi
echo "PASS $CXX unknown routine function_call: Error 43.1 at run time, as interpreted"
