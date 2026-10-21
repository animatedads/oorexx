#!/usr/bin/env bash
# Cycle collection of compiled objects (native_package_template.cpp.in collectCycles): cyclic structures of native
# instances are freed once unreachable, while objects compiled code or the interpreter still holds stay intact.
# Run with a collection every 400 new instances (RX2CPP_GC_EVERY), combined and one library per package; output identical
# to the interpreter, and the collector must have freed instances (RX2CPP_GC_STATS).
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
cp -r "$ROOT/native/fixtures/cycles" "$OUT/src"
(cd "$OUT/src" && LD_LIBRARY_PATH="$OO_ROOT/lib" "$REXX_BIN" cycles.rex) > "$OUT/expected" 2>&1
for mode in combined separate; do
  sep=""; [[ $mode == separate ]] && sep=1
  RX2CPP_SEPARATE_PACKAGES="$sep" "$ROOT/native/compile_program.sh" "$OUT/src/cycles.rex" "$OUT/$mode" > "$OUT/$mode.build" 2>&1 || { echo "FAIL build $mode"; tail -20 "$OUT/$mode.build"; exit 1; }
  (cd "$OUT/src" && RX2CPP_GC_EVERY=400 RX2CPP_GC_STATS=1 LD_LIBRARY_PATH="$OUT/$mode:$OO_ROOT/lib" "$REXX_BIN" "$OUT/$mode/cycles.rex") > "$OUT/$mode.actual" 2> "$OUT/$mode.stats"
  diff -u "$OUT/expected" "$OUT/$mode.actual" || { echo "FAIL $mode differs from the interpreter"; exit 1; }
  freed=$(grep -o '[0-9]* freed' "$OUT/$mode.stats" | awk '{s += $1} END {print s + 0}')
  [[ $freed -gt 500 ]] || { echo "FAIL $mode: the collector freed $freed instances"; cat "$OUT/$mode.stats" | tail -5; exit 1; }
  echo "$mode: $freed instances freed"
done
echo "PASS cycle collection: $(wc -l < "$OUT/expected") lines identical, cyclic instances freed (combined, separate packages)"
