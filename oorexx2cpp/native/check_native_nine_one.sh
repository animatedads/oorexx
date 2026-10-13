#!/usr/bin/env bash
# A true differential of an unchanged ooRexx class, interpreted and compiled.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
NAME=${1:?one of list queue table set bag relation supplier message datetime}
case "$NAME" in list|queue|table|set|bag|relation|supplier|message|datetime);; *) echo "bad class" >&2; exit 64;; esac
OO_ROOT=${OO_ROOT:-${OO_REXX_ROOT:-/usr/local}}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
CXX=${CXX:-g++}
[[ -x "$REXX_BIN" ]] || { echo "missing ooRexx: $REXX_BIN" >&2; exit 2; }
OUT=$(mktemp -d); trap 'rm -rf -- "$OUT"' EXIT
export REXX_PATH="$OUT:$ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cp "$ROOT/native/fixtures/native_nine/$NAME.cls" "$OUT/$NAME.cls"
cp "$ROOT/native/fixtures/native_nine/${NAME}_client.rex" "$OUT/client.rex"
{ cat "$OUT/client.rex"; printf '\n::requires "%s.cls"\n' "$NAME"; } > "$OUT/oracle.rex"
{ cat "$OUT/client.rex"; printf '\n::requires "rxnine_%s" library\n' "$NAME"; } > "$OUT/compiled.rex"
(cd "$OUT" && "$REXX_BIN" oracle.rex > oracle.out)
cmp "$ROOT/native/fixtures/native_nine/$NAME.expected" "$OUT/oracle.out"
if ! CXX="$CXX" "$ROOT/native/build.sh" "$OUT/$NAME.cls" "$OUT" "rxnine_$NAME" >"$OUT/build.log" 2>&1; then
  echo "FAIL $NAME native build $CXX" >&2; tail -n 50 "$OUT/build.log" >&2; exit 1
fi
# Prevent a completely hosted implementation from passing this qualification:
# generated methods must construct RX2CPP's native nine-class adapter.
grep -Fq "rx::nativeNineClass(\"${NAME^^}\")" "$OUT/generated.cpp" || {
  echo "FAIL $NAME silently compiled through interpreter-only class lookup" >&2; exit 1;
}
(cd "$OUT" && "$REXX_BIN" compiled.rex > compiled.out)
if ! cmp "$OUT/oracle.out" "$OUT/compiled.out"; then
  echo "FAIL $NAME native/interpreted difference" >&2
  diff -u "$OUT/oracle.out" "$OUT/compiled.out" >&2 || true; exit 1
fi
echo "PASS $NAME $CXX native methods with exact ooRexx output and interpreter handoff"
