#!/usr/bin/env bash
# External native typed-library host contract (rx2cpp_extlib v0.1b: separate hooks for a variable symbol and for a
# literal stem tail; tests/extlib_repair_poolstem.cpp asserts the difference). Fails closed: never passes on a header
# without the literal stem-tail hooks, and never runs against anything but the package it names.
#   default                    the repaired header carried in this tree (include/rx2cpp_extlib.hpp)
#   RX2CPP_EXTLIB_ROOT=dir|zip an external package instead (tools/resolve_extlib_root.py: its root, or a ZIP staged
#   RX2CPP_EXTLIB_ARCHIVE=zip  under the build directory); its include directory comes first, so its header is the one
#                              compiled
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${OO_ROOT:?Point OO_ROOT to an installed ooRexx prefix with include/oorexxapi.h}"
[[ -f "$OO_ROOT/include/oorexxapi.h" ]] || { echo "rx2cpp-extlib: OO_ROOT/include/oorexxapi.h not found: $OO_ROOT" >&2; exit 78; }
CXX=${CXX:-g++}
BUILD_DIR=${BUILD_DIR:-"${TMPDIR:-/tmp}/rx2cpp-extlib-repair-$(basename "$CXX")"}
mkdir -p "$BUILD_DIR"
if [[ -n "${RX2CPP_EXTLIB_ROOT:-}" || -n "${RX2CPP_EXTLIB_ARCHIVE:-}" ]]; then
    EXTLIB=$(python3 "$ROOT/tools/resolve_extlib_root.py" --repo-root "$ROOT" --staging "$BUILD_DIR/host-source")
    WHERE="external package $EXTLIB"
else
    EXTLIB=$ROOT
    WHERE="in-tree include/rx2cpp_extlib.hpp"
fi
grep -q 'tailSet' "$EXTLIB/include/rx2cpp_extlib.hpp" || { echo "FAIL $EXTLIB/include/rx2cpp_extlib.hpp is not the repaired library (no literal stem-tail hooks)"; exit 1; }
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -Wno-unused-parameter \
  -I"$EXTLIB/include" -I"$ROOT/include" -I"$OO_ROOT/include" \
  "$ROOT/tests/extlib_repair_poolstem.cpp" -ldl -o "$BUILD_DIR/extlib_repair_poolstem"
"$BUILD_DIR/extlib_repair_poolstem"
echo "(tested: $WHERE)"
