#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
: "${OO_ROOT:?set OO_ROOT to ooRexx staged/usr/local}"
BUILD=${TEST_OUTPUT_DIR:-"${TMPDIR:-/tmp}/rx2cpp-hosted-test"}
mkdir -p "$BUILD"
for CXX in g++ clang++; do
  command -v "$CXX" >/dev/null || { echo "missing $CXX" >&2; exit 1; }
  "$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -pthread \
    -I"$OO_ROOT/include" -I"$ROOT" "$ROOT/test_hosted_session.cpp" \
    -L"$OO_ROOT/lib" -Wl,-rpath,"$OO_ROOT/lib" -lrexx -lrexxapi \
    -o "$BUILD/test-hosted-$(basename "$CXX")"
  "$BUILD/test-hosted-$(basename "$CXX")" > "$BUILD/test-hosted-$(basename "$CXX").out"
  cat "$BUILD/test-hosted-$(basename "$CXX").out"
done
cmp "$BUILD/test-hosted-g++.out" "$BUILD/test-hosted-clang++.out"
printf 'PASS GCC/Clang hosted bridge parity\n'
