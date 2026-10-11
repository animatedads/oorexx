#!/usr/bin/env bash
# One statement body, five code contexts: main program, internal label routine, ::ROUTINE, ::METHOD, and the same body
# ending in EXIT. Output and exit status of the native program must equal the interpreter in every context -
# a statement must not work in one context and not in another. Plus EXIT semantics per context.
set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}; CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/claude-scope-$(basename "$CXX")"}; rm -rf "$WORK"; mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
BODY='x = 3
do i = 1 to 2
  x = x + i
end
if x > 3 then say "big" x
else say "small" x
parse value "a b" with p q
say q p
select
  when x = 6 then say "six"
  otherwise say "other"
end
say right(x, 4, "*") abs(-2)'
ind() { printf '%s\n' "$BODY" | sed "s/^/$1/"; }
{ printf '%s\n' "$BODY"; } > "$WORK/main.rex"
{ echo "call f"; echo "say 'back'"; echo "exit"; echo "f:"; ind "  "; echo "  return"; } > "$WORK/label.rex"
{ echo "call f"; echo "say 'back'"; echo "exit"; echo "::routine f"; ind "  "; echo "  return"; } > "$WORK/routine.rex"
{ echo "o = .c~new"; echo "o~m"; echo "say 'back'"; echo "exit"; echo "::class c"; echo "::method m"; ind "  "; echo "  return"; } > "$WORK/method.rex"
# EXIT per context (interpreter: ::ROUTINE and ::METHOD leave the unit with the value, a label ends the program)
printf '%s\n' "r = rt(); say 'routine returned' r" "say 'after'" "exit 0" "::routine rt" "  exit 5" > "$WORK/exit_routine.rex"
printf '%s\n' "o = .c~new; m = o~m; say 'method returned' m" "say 'after'" "exit 0" "::class c" "::method m" "  exit 6" > "$WORK/exit_method.rex"
printf '%s\n' "call lb" "say 'not reached'" "exit 0" "lb: exit 7" > "$WORK/exit_label.rex"
for src in "$WORK"/*.rex; do
  f=$(basename "$src" .rex)
  "$REXX_BIN" "$src" >"$WORK/$f.exp" 2>&1; erc=$?
  RX2CPP_HOSTED=0 "$ROOT/build.sh" "$src" "$WORK/$f.bin" "$WORK/$f.cpp" >"$WORK/$f.blog" 2>&1 || { cat "$WORK/$f.blog"; echo "FAIL build $f"; exit 1; }
  "$WORK/$f.bin" >"$WORK/$f.act" 2>&1; arc=$?
  cmp "$WORK/$f.exp" "$WORK/$f.act" || { diff -u "$WORK/$f.exp" "$WORK/$f.act"; exit 1; }
  [[ $erc == $arc ]] || { echo "FAIL $f exit status interpreter=$erc native=$arc"; exit 1; }
  echo "PASS $f ($(wc -l <"$WORK/$f.exp") lines, status $arc identical)"
done
