#!/usr/bin/env bash
# Generated C++ free of the warnings newer compilers make errors of (builds use -Werror): g++ 16 counts ++x as a
# set for -Wunused-but-set-variable, as clang does. The generated code of fixtures with every DO form, internal
# routines and EXIT is checked with clang++ (-fsyntax-only); no clang++: SKIP.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
command -v clang++ >/dev/null || { echo "SKIP generated warnings: no clang++"; exit 0; }
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
export REXX_PATH="$OUT:$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
F="$ROOT/native/fixtures"
cp "$F/do_forms.cls" "$OUT/"
"$ROOT/native/build.sh" "$OUT/do_forms.cls" "$OUT/doforms" rxdoforms > "$OUT/build1.log" 2>&1 || { echo "FAIL build do_forms"; tail -20 "$OUT/build1.log"; exit 1; }
cp "$F/program_constructs/internal_exit.rex" "$OUT/"
"$ROOT/native/compile_program.sh" "$OUT/internal_exit.rex" "$OUT/exit" > "$OUT/build2.log" 2>&1 || { echo "FAIL build internal_exit"; tail -20 "$OUT/build2.log"; exit 1; }
bif=( ); [[ -d "$ROOT/external/bif/native" ]] && bif=( -I"$ROOT/external/bif/native" -I"$ROOT/external/bif/variables" )
for d in "$OUT/doforms" "$OUT/exit"; do
  clang++ -std=c++17 -fsyntax-only -Wunused-but-set-variable -Wunused-variable -Werror=unused-but-set-variable \
    -Werror=unused-variable -I"$OO_ROOT/include" -I"$ROOT/include" -I"$ROOT/hybrid" -I"$d" -DRX2CPP_HOST_API "${bif[@]}" \
    "$d/generated.cpp" > "$OUT/clang.log" 2>&1 || { echo "FAIL $(basename "$d"): clang++ warnings"; grep -m5 "error:" "$OUT/clang.log"; exit 1; }
done
echo "PASS generated warnings: DO forms and internal routines compile under clang++ without unused-variable warnings"
