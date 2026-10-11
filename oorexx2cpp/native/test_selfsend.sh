#!/usr/bin/env bash
# rx2cpp threading v0.2: SELF~selector(...) from compiled methods
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:?}; REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}; CXX=${CXX:-g++}
OUT=${OUT:-$ROOT/build/selfsend_$(basename "$CXX")}; rm -rf "$OUT"; mkdir -p "$OUT"
export LD_LIBRARY_PATH="$OO_ROOT/lib:$OUT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
bo=$(CXX=$CXX "$ROOT/native/build.sh" "$ROOT/native/fixtures/selfsend.cls" "$OUT" rx2cpp_selfsend 2>&1) || { echo "BUILD FAILED"; echo "$bo"; exit 1; }
actual=$("$REXX_BIN" "$ROOT/native/fixtures/selfsend_client.rex" 2>&1)
expected=$'a: 1202\ntag after: 2\noverride: 701\nbump total (expect 10000): 10000\nbad -> 97.1'
[ "$actual" == "$expected" ] || { echo "FAIL"; diff <(echo "$expected") <(echo "$actual") || true; exit 1; }
echo "PASS $CXX SELF sends: state coherent both ways (1202), subclass override wins (701), 4x2500 threaded bumps exact, interpreter error passes through"
rej() { printf '%s\n' "$2" > "$OUT/$1.cls"
  if CXX=$CXX "$ROOT/native/build.sh" "$OUT/$1.cls" "$OUT/rej_$1" rx2cpp_rej_$1 >/dev/null 2>&1; then echo "FAIL $1 accepted"; exit 1; fi
  echo "PASS reject $1"; }
H=$'::class A public\n::method init\n  expose v\n  use arg s\n  v = s\n'
rej chained        "$H::method m
  return self~a()~b()"
rej cascade        "$H::method m
  return self~a()~~b()"
printf '%s::method m\n  return self~a()\n::method a\n  return 1\n' "$H" > "$OUT/single.cls"
if (cd "$ROOT" && "$REXX_BIN" rx2cpp_native.rex "$OUT/single.cls" "$OUT/single_out" x >/dev/null 2>&1); then echo "FAIL single-class path accepted SELF send"; exit 1; fi
echo "PASS reject SELF send on single-class compiler path"
