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
for kind in duplicate omission function_call; do
  case "$kind" in
    duplicate) header='::routine RX_DUP PUBLIC'; body=$'  use arg a,b,a\n  return a' ;;
    omission) header='::routine RX_OMIT PUBLIC'; body=$'  use arg a,,c\n  return a' ;;
    class_three) header='::class OrdinaryClass public'; body=$'::method init\n  return\n::method triplet\n  use arg a,b,c\n  return a' ;;
    function_call) header='::routine RX_CALL PUBLIC'; body=$'  use arg a,b,c\n  return not_supported_here(a)' ;;
  esac
  printf '::class Simple public\n::method init\n  return\n%s\n%s\n' "$header" "$body" > "$OUT/reject_$kind.cls"
  if OO_ROOT="$OO_ROOT" CXX="$CXX" REXX_BIN="$REXX_BIN" "$ROOT/native/build.sh" "$OUT/reject_$kind.cls" "$OUT" rx2cpp_many >"$OUT/reject_$kind.log" 2>&1; then
    echo "FAIL accepted $kind" >&2; exit 1
  fi
  if [[ "$kind" == function_call ]]; then
    grep -q 'native package routine/function invocation is not yet supported' "$OUT/reject_$kind.log" || { echo 'FAIL missing function diagnostic'; cat "$OUT/reject_$kind.log"; exit 1; }
    grep -qE 'rx2cpp:[0-9]+:[0-9]+:' "$OUT/reject_$kind.log" || { echo 'FAIL missing diagnostic location'; exit 1; }
  fi
  [[ $(sha256sum "$OUT/librx2cpp_many.so" | cut -d' ' -f1) == "$accepted" ]] || { echo "FAIL rollback $kind" >&2; exit 1; }
  echo "PASS $CXX rejects $kind without replacing library"
done
