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
# (A quoted routine name is valid, upper case as interpreted: compared with the interpreter below.)
# (use arg a,,c is valid Rexx - an empty position skips an argument: native/test_use_arg.sh compares it)
for kind in external duplicate expose; do
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
# A quoted routine name ("foo") names routine FOO, as the interpreter registers it.
printf '::class QuotedHost public\n::routine "foo" public\n  return "quoted" arg()\n' > "$OUT/quoted.cls"
printf 'say foo(1, 2) "foo"(3)\n::requires "quoted.cls"\n' > "$OUT/quoted_i.rex"
printf 'say foo(1, 2) "foo"(3)\n::requires "rx2cpp_quoted" library\n' > "$OUT/quoted_c.rex"
(cd "$OUT" && "$REXX_BIN" quoted_i.rex > quoted.expected 2>&1)
OO_ROOT="$OO_ROOT" REXX_BIN="$REXX_BIN" CXX="$CXX" "$ROOT/native/build.sh" "$OUT/quoted.cls" "$OUT" rx2cpp_quoted > "$OUT/quoted.log" 2>&1 ||
  { echo "FAIL quoted routine name build" >&2; tail -5 "$OUT/quoted.log" >&2; exit 1; }
(cd "$OUT" && "$REXX_BIN" quoted_c.rex > quoted.actual 2>&1)
cmp "$OUT/quoted.expected" "$OUT/quoted.actual" || { diff "$OUT/quoted.expected" "$OUT/quoted.actual" >&2; exit 1; }
echo "PASS quoted routine name: identical to the interpreter"
