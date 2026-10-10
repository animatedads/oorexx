#!/usr/bin/env bash
# rx2cpp threading v0.1: GUARDED/UNGUARDED on compiled methods + per-scope memory-safety lock
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:?}; REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}; CXX=${CXX:-g++}
OUT=${OUT:-$ROOT/build/threads_$(basename "$CXX")}; rm -rf "$OUT"; mkdir -p "$OUT"
export LD_LIBRARY_PATH="$OO_ROOT/lib:$OUT${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
CXX=$CXX "$ROOT/native/build.sh" "$ROOT/native/fixtures/threads_guard.cls" "$OUT" rx2cpp_threads >/dev/null
actual=$("$REXX_BIN" "$ROOT/native/fixtures/threads_guard_client.rex")
expected=$'ADD  guarded? 0\nGADD guarded? 1\nCURRENT guarded? (default) 1\nADD total (expect 100000): 100000\nGADD total (expect 100000): 100000'
[ "$actual" == "$expected" ] || { echo "FAIL flags/counts"; diff <(echo "$expected") <(echo "$actual") || true; exit 1; }
echo "PASS $CXX guard flags reach ooRexx; 4 activities x 25000 on guarded and unguarded compiled methods = exact"
# fail-closed checks: nothing may be published for an unsupported option
reject() { # name source
  printf '%s\n' "$2" > "$OUT/$1.cls"
  if CXX=$CXX "$ROOT/native/build.sh" "$OUT/$1.cls" "$OUT/rej_$1" rx2cpp_rej_$1 >/dev/null 2>&1; then
    echo "FAIL $1 was accepted"; exit 1; fi
  [ ! -e "$OUT/rej_$1/librx2cpp_rej_$1.so" ] || { echo "FAIL $1 published a library"; exit 1; }
  echo "PASS reject $1"
}
reject private_option $'::class A public\n::method init\n  expose v\n  use arg s\n  v = s\n::method get private\n  expose v\n  return v'
reject two_guards     $'::class A public\n::method init\n  expose v\n  use arg s\n  v = s\n::method get guarded unguarded\n  expose v\n  return v'
# single-class hybrid compiler cannot honour the option, so it must refuse
printf '::class A public\n::method init\n  expose v\n  use arg s\n  v = s\n::method get unguarded\n  expose v\n  return v\n' > "$OUT/single.cls"
if (cd "$ROOT" && "$REXX_BIN" rx2cpp_native.rex "$OUT/single.cls" "$OUT/single_out" x >/dev/null 2>&1); then echo "FAIL single-class path accepted guard"; exit 1; fi
echo "PASS reject guard option on single-class compiler path"
