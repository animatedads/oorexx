#!/usr/bin/env bash
# Whole programs with their packages (Josep Maria Blasco's report, 2026-10-20): a routine body on its directive line,
# the prologs of required packages (combined: each runs, in load order), packages next to the program compiled with it,
# and a warning for a ::REQUIRES left to the interpreter. Output identical to the interpreter.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
OUT=$(mktemp -d)
trap 'rm -rf -- "$OUT"' EXIT
F="$ROOT/native/fixtures/program_packages"
cp -r "$F" "$OUT/src"
check() {   # name program-path [REXX_PATH]
  local name=$1 prog=$2 rp=${3:-}
  (cd "$OUT" && REXX_PATH="$rp" LD_LIBRARY_PATH="$OO_ROOT/lib" "$REXX_BIN" "$prog") > "$OUT/$name.expected" 2>&1
  REXX_PATH="$rp${REXX_PATH:+:$REXX_PATH}" RX2CPP_SEPARATE_PACKAGES="${SEPARATE:-}" "$ROOT/native/compile_program.sh" "$prog" "$OUT/$name" > "$OUT/$name.build" 2>&1 || { echo "FAIL build $name"; tail -20 "$OUT/$name.build"; exit 1; }
  grep -q "warning: not compiled" "$OUT/$name.build" && { echo "FAIL $name: a package was left interpreted"; cat "$OUT/$name.build"; exit 1; }
  (cd "$OUT" && LD_LIBRARY_PATH="$OUT/$name:$OO_ROOT/lib" "$REXX_BIN" "$OUT/$name/$(basename "$prog")") > "$OUT/$name.actual" 2>&1
  diff -u "$OUT/$name.expected" "$OUT/$name.actual" || { echo "FAIL $name differs from the interpreter"; exit 1; }
}
check inline "$OUT/src/inline_routine.rex"
check prologs "$OUT/src/prologs.rex" "$OUT/src/lib"
check neighbours "$OUT/src/side/neighbours.rex"
check constructs "$OUT/src/constructs.rex"
# RX2CPP_SEPARATE_PACKAGES=1: one library per required package, each its own package (name, findRoutine of a routine
# that is not public, a class that is not public reaching the main program, prologs)
SEPARATE=1 check sep_main "$OUT/src/separate/pkgmain.rex"
SEPARATE=1 check sep_prolog "$OUT/src/separate/pkgprolog.rex"
SEPARATE=1 check sep_prologs "$OUT/src/prologs.rex" "$OUT/src/lib"
ls "$OUT/sep_prolog"/librxp_pkgp.so "$OUT/sep_prolog"/librxp_pkgsep.so >/dev/null || { echo "FAIL separate libraries not built"; exit 1; }
# a ::REQUIRES that cannot be found: built, with the warning
printf 'say 1\n::requires "nowhere.cls"\n' > "$OUT/missing.rex"
"$ROOT/native/compile_program.sh" "$OUT/missing.rex" "$OUT/missing" > "$OUT/missing.build" 2>&1 || true
grep -q 'warning: not compiled, loaded by the interpreter at run time: ::requires "nowhere.cls"' "$OUT/missing.build" || { echo "FAIL no warning for a package left interpreted"; cat "$OUT/missing.build"; exit 1; }
echo "PASS program packages: inline routine body, prologs in load order, neighbouring packages, warning, parser constructs, separate packages ($(cat "$OUT"/*.expected | wc -l) lines identical)"
