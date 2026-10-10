#!/usr/bin/env bash
# A tested BIF-boundary smoke against the native ooRexx API; not a compiler test.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bif=$(cd -- "$here/../.." && pwd)
: "${RX2CPP_BASE:?set RX2CPP_BASE to the checked GitHub oorexx2cpp source tree}"
: "${OO_ROOT:?set OO_ROOT to an ooRexx installation with headers/libraries}"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
build=${BUILD_DIR:-$(mktemp -d)}
mkdir -p "$build"
for cc in ${CXX_LIST:-g++ clang++}; do
  binary="$build/hosted_scalar_${cc//+/x}"
  "$cc" -std=c++17 -O2 -Wall -Wextra -Werror \
      -I"$OO_ROOT/include" -I"$RX2CPP_BASE/include" -I"$RX2CPP_BASE/hosted_tier" -I"$bif/native" \
      "$here/hosted_scalar_bif.cpp" "$bif/native/rxbif.cpp" "$bif/native/rxbif_breadth.cpp" \
      -L"$OO_ROOT/lib" -Wl,-rpath,"$OO_ROOT/lib" -lrexx -lrexxapi -o "$binary"
  "$binary"
done
