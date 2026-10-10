#!/usr/bin/env bash
# Concatenation (||): interpreter-vs-native parity, class-path strings, fail-closed forms.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}; CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/concat-$(basename "$CXX")"}; rm -rf "$WORK"; mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
name=concat_basic; src="$ROOT/examples/$name.rex"
"$REXX_BIN" "$src" >"$WORK/$name.expected"
CXX="$CXX" "$ROOT/build.sh" "$src" "$WORK/$name.native" "$WORK/$name.cpp" >/dev/null
"$WORK/$name.native" >"$WORK/$name.actual"
cmp "$WORK/$name.expected" "$WORK/$name.actual" || { diff -u "$WORK/$name.expected" "$WORK/$name.actual"; exit 1; }
echo "PASS $name ($(wc -l <"$WORK/$name.expected") lines identical to the interpreter)"
for bad in 'say "a" ||' 'say || "a"' 'say "a" ||| "b"'; do
  printf '%s\n' "$bad" > "$WORK/bad.rex"; rm -f "$WORK/bad.cpp"
  if "$ROOT/run-compiler.sh" "$WORK/bad.rex" "$WORK/bad.cpp" >/dev/null 2>&1; then echo "FAIL accepted: $bad"; exit 1; fi
  [[ ! -e "$WORK/bad.cpp" ]] || { echo "FAIL partial C++ for: $bad"; exit 1; }
done
echo "PASS 3 malformed concatenations rejected with no output"
# class path
export LD_LIBRARY_PATH="${OO_ROOT:?}/lib:$WORK${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
OUT="$WORK/pkg"; mkdir -p "$OUT"
bo=$(CXX=$CXX "$ROOT/native/build.sh" "$ROOT/native/fixtures/strings.cls" "$OUT" rx2cpp_strings 2>&1) || { echo "BUILD FAILED"; echo "$bo"; exit 1; }
actual=$(LD_LIBRARY_PATH="$OUT:$LD_LIBRARY_PATH" "$REXX_BIN" "$ROOT/native/fixtures/strings_client.rex" 2>&1)
expected=$'-a\n-ab\nA>x/xy'
[ "$actual" == "$expected" ] || { echo "FAIL class strings"; diff <(echo "$expected") <(echo "$actual") || true; exit 1; }
echo "PASS $CXX compiled class: string state, || and SELF sends compose (A>x/xy)"
