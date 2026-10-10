#!/usr/bin/env bash
# Hosted directive unit: when the directive section (::CLASS with options, ::REQUIRES of Rexx programs, ::ROUTINE
# next to them, ...) cannot be translated natively, the main program stays native and the section runs in the
# embedded interpreter. Output and status must equal the interpreter, including run from another working
# directory (relative ::REQUIRES resolve against the source), shared object state and private routines.
# A rejection in the MAIN code must stay final, and RX2CPP_HOSTED=0 must restore fail-closed behaviour.
set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}; CXX=${CXX:-g++}
: "${OO_ROOT:?OO_ROOT (ooRexx install) is required}"
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/claude-hostedunit-$(basename "$CXX")"}; rm -rf "$WORK"; mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
src="$ROOT/examples/claude/hosted_unit.rex"
"$REXX_BIN" "$src" >"$WORK/exp" 2>&1; erc=$?
"$ROOT/build.sh" "$src" "$WORK/unit.bin" "$WORK/unit.cpp" >"$WORK/build.log" 2>&1 || { cat "$WORK/build.log"; echo "FAIL build"; exit 1; }
grep -q 'hosted tier: .*directive unit' "$WORK/build.log" || { echo "FAIL build did not announce the hosted unit"; exit 1; }
( cd / && "$WORK/unit.bin" >"$WORK/act" 2>&1 ); arc=$?
cmp "$WORK/exp" "$WORK/act" || { diff -u "$WORK/exp" "$WORK/act"; exit 1; }
[[ $erc == $arc ]] || { echo "FAIL exit status interpreter=$erc native=$arc"; exit 1; }
echo "PASS hosted_unit ($(wc -l <"$WORK/exp") lines, status $arc identical, run from /)"
# the same program with the opt-out must be rejected at the directive section, with a source location
if RX2CPP_HOSTED=0 "$ROOT/build.sh" "$src" "$WORK/off.bin" "$WORK/off.cpp" >"$WORK/off.log" 2>&1; then echo "FAIL RX2CPP_HOSTED=0 accepted the unit"; exit 1; fi
grep -Eq 'rx2cpp:[0-9]+:[0-9]+:' "$WORK/off.log" || { cat "$WORK/off.log"; echo "FAIL opt-out rejection lacks a source location"; exit 1; }
echo "PASS RX2CPP_HOSTED=0 rejects the unit"
# an unsupported construct in the MAIN code is not rescued by the hosted tier
printf 'x = 1 ?? 2\n::class A public subclass object\n' > "$WORK/badmain.rex"
if "$ROOT/build.sh" "$WORK/badmain.rex" "$WORK/bad.bin" "$WORK/bad.cpp" >"$WORK/bad.log" 2>&1; then echo "FAIL bad main code was accepted"; exit 1; fi
grep -Eq 'rx2cpp:1:' "$WORK/bad.log" || { cat "$WORK/bad.log"; echo "FAIL main-code rejection should point at line 1"; exit 1; }
echo "PASS main-code rejection stays final"
