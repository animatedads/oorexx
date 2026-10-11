#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT HUP INT TERM
"${CXX:-c++}" -std=c++11 -Wall -Wextra -pedantic "$ROOT/tests/guard_scope_test.cpp" -o "$OUT"
"$OUT"
python3 "$ROOT/tests/test_dev20_api_guard.py"
