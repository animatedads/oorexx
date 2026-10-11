#!/usr/bin/env bash
# Hosted tier: environment classes the native runtime lacks (.DateTime) are loaded from an embedded interpreter
# session and used through live handles. Output and exit status (incl. uncaught SYNTAX -> 256-N) must equal the
# interpreter; the binary must say it is hosted; RX2CPP_HOSTED=0 must restore the fail-closed rejection.
set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}; CXX=${CXX:-g++}
: "${OO_ROOT:?OO_ROOT (ooRexx install) is required}"
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/claude-hosted-$(basename "$CXX")"}; rm -rf "$WORK"; mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
for f in hosted_datetime hosted_misc hosted_uncaught; do
  "$REXX_BIN" "$ROOT/examples/claude/$f.rex" >"$WORK/$f.exp" 2>/dev/null; erc=$?
  "$ROOT/build.sh" "$ROOT/examples/claude/$f.rex" "$WORK/$f.bin" "$WORK/$f.cpp" >"$WORK/$f.blog" 2>&1 || { cat "$WORK/$f.blog"; echo "FAIL build $f"; exit 1; }
  grep -q 'hosted tier: .*DATETIME' "$WORK/$f.blog" || { echo "FAIL $f build did not announce the hosted tier"; exit 1; }
  "$WORK/$f.bin" >"$WORK/$f.act" 2>/dev/null; arc=$?
  cmp "$WORK/$f.exp" "$WORK/$f.act" || { diff -u "$WORK/$f.exp" "$WORK/$f.act"; exit 1; }
  [[ $erc == $arc ]] || { echo "FAIL $f exit status interpreter=$erc native=$arc"; exit 1; }
  echo "PASS $f ($(wc -l <"$WORK/$f.exp") lines, status $arc identical, hosted)"
done
linked=$(ldd "$WORK/hosted_datetime.bin"); [[ "$linked" == *librexx* ]] || { echo "FAIL hosted binary should link librexx"; exit 1; }
if RX2CPP_HOSTED=0 "$ROOT/build.sh" "$ROOT/examples/claude/hosted_datetime.rex" "$WORK/off.bin" "$WORK/off.cpp" >"$WORK/off.blog" 2>&1; then
  echo "FAIL RX2CPP_HOSTED=0 accepted a hosted class"; exit 1; fi
grep -q 'unsupported environment class .DATETIME' "$WORK/off.blog" || { cat "$WORK/off.blog"; echo "FAIL missing rejection text"; exit 1; }
echo "PASS RX2CPP_HOSTED=0 rejects with a source location"
printf 'say .ENVIRONMENT\n' > "$WORK/nil.rex"
if "$ROOT/build.sh" "$WORK/nil.rex" "$WORK/nil.bin" "$WORK/nil.cpp" >/dev/null 2>&1; then echo "FAIL .ENVIRONMENT must stay fail-closed"; exit 1; fi
echo "PASS non-class environment symbols stay fail-closed"
