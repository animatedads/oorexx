#!/usr/bin/env bash
# Qualified extension to the interpreter-loaded ooRexx native-package source.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OO_ROOT=${OO_ROOT:-/usr/local}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
CXX=${CXX:-g++}
OUT=${PACKAGE_TEST_DIR:-$(mktemp -d)}
if [[ -z ${PACKAGE_TEST_DIR:-} ]]; then trap 'rm -rf "$OUT"' EXIT; fi
mkdir -p "$OUT"
export REXX_PATH="$OUT:$ROOT:$ROOT/native/fixtures:$OO_ROOT/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OUT:$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$REXX_BIN" "$ROOT/native/fixtures/native_extras_oracle.rex" > "$OUT/oracle.out"
"$ROOT/native/build.sh" "$ROOT/native/fixtures/native_extras.cls" "$OUT" rx2cpp_metaextra
"$REXX_BIN" "$ROOT/native/fixtures/native_extras_client.rex" > "$OUT/native.out"
cmp "$OUT/oracle.out" "$OUT/native.out"
# Require the actual interpreter to report annotations, resources and the
# loaded namespace; merely printing a precomputed expected string is not enough.
grep -Fx 'external marker' "$OUT/native.out" >/dev/null
grep -Fx '; semicolon and ::constant are raw resource data' "$OUT/native.out" >/dev/null
[[ $(wc -l < "$OUT/native.out") -eq 13 ]]
accepted=$(sha256sum "$OUT/librx2cpp_metaextra.so" | cut -d' ' -f1)
check_fail() {
  local label=$1 source=$2
  printf '%s\n' "$source" > "$OUT/reject.cls"
  if "$ROOT/native/build.sh" "$OUT/reject.cls" "$OUT" rx2cpp_metaextra > "$OUT/reject.log" 2>&1; then
    echo "FAIL: accepted $label" >&2; exit 1
  fi
  [[ $accepted == "$(sha256sum "$OUT/librx2cpp_metaextra.so" | cut -d' ' -f1)" ]] || {
    echo "FAIL: $label replaced a qualified library" >&2; exit 1;
  }
}
class='::class MetaWidget public
::method init
::method greet
  return "hello"'
check_fail 'duplicate RESOURCE' "$class
::resource same
text
::END
::resource SAME
text
::END"
check_fail 'missing RESOURCE terminator' "$class
::resource unfinished
not a directive"
check_fail 'missing REQUIRES file' "$class
::requires 'rx2cpp_nonexistent_package_cls' namespace EXT"
check_fail 'quoted namespace' "$class
::requires 'native_extras_dependency.cls' namespace 'EXT'"
check_fail 'unsupported ATTRIBUTE annotation' "$class
::annotate attribute greet X 'cannot map this to native methods'"
check_fail 'unknown ANNOTATE method target' "$class
::annotate method nosuch METHOD yes"
check_fail 'unknown ANNOTATE class target' "$class
::annotate class WrongClass TEAM yes"
check_fail 'bad ANNOTATE value' "$class
::annotate package PERSON 1 + 2"
check_fail 'non-OFF TRACE' "::options trace intermediate
$class"
check_fail 'REQUIRES without namespace' "$class
::requires 'native_extras_dependency.cls'"
check_fail 'same-line package directive' "$class
::annotate package WHO 'a'; ::constant D 1"
check_fail 'malformed resource option' "$class
::resource thing end
nothing
::END"
echo "PASS $CXX native ::ANNOTATE/::RESOURCE/::REQUIRES NAMESPACE + ::OPTIONS OFF/NOPROLOG: byte parity 13 lines, 12 protected rejections"
