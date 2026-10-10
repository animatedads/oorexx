#!/usr/bin/env bash
# Same unmodified Gemini source against interpreter 5.3 and compiled standalone C++.
# No interpreter runtime is linked to the generated executable.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
FIX="$ROOT/tests/fixtures/developer_registry"
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-$(mktemp -d)}
if [[ -z ${TEST_OUTPUT_DIR:-} ]]; then trap 'rm -rf "$WORK"' EXIT; fi
mkdir -p "$WORK"
export RX2CPP_BIF_DISABLED=1
if [[ -n ${REXX_LIB:-} ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
"$REXX_BIN" "$FIX/developer_registry.rex" >"$WORK/interpreter.out"
cmp "$FIX/developer_registry.expected" "$WORK/interpreter.out"
[[ $(wc -l <"$WORK/interpreter.out") -eq 12 ]]
for name in developer_registry object_identity; do
  input="$FIX/$name.rex"
  "$REXX_BIN" "$input" >"$WORK/$name.oracle"
  cmp "$FIX/$name.expected" "$WORK/$name.oracle"
  CXX="$CXX" "$ROOT/build.sh" "$input" "$WORK/$name.native" "$WORK/$name.cpp" >"$WORK/$name.build.log"
  "$WORK/$name.native" >"$WORK/$name.native.out" 2>"$WORK/$name.native.err"
  [[ ! -s "$WORK/$name.native.err" ]] || { cat "$WORK/$name.native.err" >&2; exit 1; }
  cmp "$WORK/$name.oracle" "$WORK/$name.native.out"
  echo "PASS $CXX $name ($(wc -l <"$WORK/$name.oracle") lines, byte-exact)"
done
# Failed compilation must neither replace a previously accepted output nor
# accept syntax by ignoring directives or executing it through the interpreter.
accepted=$(sha256sum "$WORK/developer_registry.cpp")
for declaration in \
  '::class Example public' \
  '::class Example subclass Object' \
  '::class ARRAY' \
  '::class Example' ; do
  printf 'say "before"\nexit\n%s\n::attribute field\n::attribute field\n' "$declaration" >"$WORK/reject.rex"
  if "$ROOT/run-compiler.sh" "$WORK/reject.rex" "$WORK/developer_registry.cpp" >"$WORK/reject.log" 2>&1; then
    echo "FAIL: accepted unsupported or duplicate class syntax: $declaration" >&2; exit 1
  fi
  [[ $accepted == "$(sha256sum "$WORK/developer_registry.cpp")" ]] || {
    echo 'FAIL: failed class compilation replaced accepted output' >&2; exit 1;
  }
done
printf 'say 1\nexit\n::class Plain\n::method show abstract\n' >"$WORK/reject.rex"
if "$ROOT/run-compiler.sh" "$WORK/reject.rex" "$WORK/developer_registry.cpp" >"$WORK/reject.log" 2>&1; then
  echo 'FAIL: accepted abstract method' >&2; exit 1
fi
[[ $accepted == "$(sha256sum "$WORK/developer_registry.cpp")" ]]
printf 'say 1\nexit\n::class Plain\n::method show\n  forward\n' >"$WORK/reject.rex"
if "$ROOT/run-compiler.sh" "$WORK/reject.rex" "$WORK/developer_registry.cpp" >"$WORK/reject.log" 2>&1; then
  echo 'FAIL: accepted unsupported FORWARD' >&2; exit 1
fi
[[ $accepted == "$(sha256sum "$WORK/developer_registry.cpp")" ]]
echo "PASS $CXX six fail-closed class declarations with artifact rollback"
