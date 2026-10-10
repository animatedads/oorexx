#!/usr/bin/env bash
# Native package routine ABI: differential ooRexx oracle, fail-closed builds.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}
OO_LIB=${OO_LIB:-$OO_ROOT/lib}
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
PACKAGE=rx2cpp_routines
OUT=${TEST_OUTPUT_DIR:-$ROOT/build/native-routines-$(basename "$CXX")}
mkdir -p "$OUT"
export LD_LIBRARY_PATH="$OO_LIB:$OUT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/native/fixtures:$ROOT${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" "$ROOT/native/fixtures/routine_native_oracle.rex" >"$OUT/oracle.out"
OO_ROOT="$OO_ROOT" REXX_BIN="$REXX_BIN" CXX="$CXX" \
    "$ROOT/native/build.sh" "$ROOT/native/fixtures/routine_native.cls" "$OUT" "$PACKAGE"
"$REXX_BIN" "$ROOT/native/fixtures/routine_native_client.rex" >"$OUT/native.out"
cmp "$OUT/oracle.out" "$OUT/native.out"
echo "PASS native routine and class interpreter parity: $(wc -l <"$OUT/native.out") lines"
# A failed compile never overwrites the previous successfully built native library.
before=$(sha256sum "$OUT/lib${PACKAGE}.so" | cut -d' ' -f1)
for kind in external duplicate quoted missing_return malformed_use_arg expose complex_body; do
  file="$OUT/bad_$kind.cls"
  { cat <<'REXX'
::class RoutineHost public
::method init
  expose counter
  counter = 0
REXX
    case "$kind" in
      external) printf '\n::routine foo public external "LIBRARY rxmath sin"\n';;
      duplicate) printf '\n::routine foo public\n  return 1\n::routine foo public\n  return 2\n';;
      quoted) printf '\n::routine "foo" public\n  return 2\n';;
      missing_return) printf '\n::routine foo public\n  use arg a\n  a = 1\n';;
      malformed_use_arg) printf '\n::routine foo public\n  use arg a,,c\n  return a\n';;
      expose) printf '\n::routine foo public\n  expose value\n  return value\n';;
      complex_body) printf '\n::routine foo public\n  do i = 1 to 3\n    i = i + 1\n  end\n  return i\n';;
    esac
  } >"$file"
  if OO_ROOT="$OO_ROOT" REXX_BIN="$REXX_BIN" CXX="$CXX" \
    "$ROOT/native/build.sh" "$file" "$OUT" "$PACKAGE" >"$OUT/reject_$kind.log" 2>&1; then
    echo "FAIL unsupported $kind unexpectedly accepted" >&2; exit 1
  fi
  after=$(sha256sum "$OUT/lib${PACKAGE}.so" | cut -d' ' -f1)
  [[ "$before" == "$after" ]] || { echo "FAIL rollback $kind" >&2; exit 1; }
  echo "PASS reject $kind (prior .so intact)"
done
