#!/usr/bin/env bash
# Fast compile/dispatch gate, NOT a substitute for a live interpreter oracle.
# Each native/test_native_{class}.sh handles the real ooRexx differential.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OUT=$(mktemp -d); trap 'rm -rf -- "$OUT"' EXIT
compilers=()
if [[ -n ${CXX:-} ]]; then compilers+=("$CXX"); else
  command -v g++ >/dev/null && compilers+=(g++)
  command -v clang++ >/dev/null && compilers+=(clang++)
fi
((${#compilers[@]})) || { echo "No C++17 compiler installed" >&2; exit 2; }
for cc in "${compilers[@]}"; do
  "$cc" -std=c++17 -O1 -Wall -Wextra -Werror -pedantic \
      "$ROOT/native/tests/native_nine_smoke.cpp" -o "$OUT/dispatch"
  "$OUT/dispatch"
  echo "PASS $cc standalone RX2CPP native-nine object dispatch"
done
