#!/usr/bin/env bash
# ::REQUIRES "x" LIBRARY: compiled native programs call real ooRexx API libraries (rxmath, rxsock) through the
# external-library host. Output must be byte-identical to the interpreter. Needs OO_ROOT (headers) and RX2CPP_LIBPATH
# is set here to $OO_ROOT/lib. The executables never link the interpreter (only libdl).
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}; CXX=${CXX:-g++}; : "${OO_ROOT:?set OO_ROOT to the ooRexx install prefix}"
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/extlib-$(basename "$CXX")"}; rm -rf "$WORK"; mkdir -p "$WORK"
export LD_LIBRARY_PATH="$OO_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; export RX2CPP_LIBPATH="$OO_ROOT/lib"
build() { "$ROOT/build.sh" "$1.rex" "$1.native" "$1.cpp" >/dev/null; }
for name in math_sock loopback; do
  cp "$ROOT/examples/extlib/$name.rex" "$WORK/$name.rex"
  "$REXX_BIN" "$WORK/$name.rex" >"$WORK/$name.expected"; build "$WORK/$name"; "$WORK/$name.native" >"$WORK/$name.actual"
  cmp "$WORK/$name.expected" "$WORK/$name.actual" || { diff -u "$WORK/$name.expected" "$WORK/$name.actual"; exit 1; }
  echo "PASS $name ($(wc -l <"$WORK/$name.expected") lines identical to the interpreter)"
done
! ldd "$WORK/loopback.native" | grep -qi "rexx" || { echo "FAIL native executable links the interpreter"; exit 1; }
echo "PASS native executable has no interpreter dynamic-link dependency"
# library routine errors surface as runtime errors with the interpreter's code (88.901 = missing argument)
printf 'say SockClose()\n::requires "rxsock" LIBRARY\n' > "$WORK/err.rex"; build "$WORK/err"
set +e; "$WORK/err.native" >"$WORK/err.out" 2>"$WORK/err.err"; rc=$?; set -e
[ $rc -ne 0 ] && grep -q "88.901" "$WORK/err.err" || { echo "FAIL routine error not propagated"; cat "$WORK/err.err"; exit 1; }
echo "PASS library argument error propagates (88.901)"
printf 'say 1\n::requires "nosuchlib_zz" LIBRARY\n' > "$WORK/nolib.rex"; build "$WORK/nolib"
set +e; "$WORK/nolib.native" >/dev/null 2>"$WORK/nolib.err"; rc=$?; set -e
[ $rc -eq 158 ] && grep -q "98.903" "$WORK/nolib.err" || { echo "FAIL missing library not reported with interpreter status 158 / 98.903 (rc=$rc)"; exit 1; }
echo "PASS missing library fails at start (98.903, status 158 like the interpreter)"
# a bare symbol is upper-cased and library names are case-sensitive on Unix: ::requires rxsock library must NOT load rxsock
printf 'say 1\n::requires rxsock library\n' > "$WORK/symlib.rex"; build "$WORK/symlib"
set +e; "$WORK/symlib.native" >"$WORK/symlib.out" 2>/dev/null; rc=$?; set -e
[ $rc -eq 158 ] && [ ! -s "$WORK/symlib.out" ] || { echo "FAIL symbol-form library name must be upper-cased and fail (rc=$rc)"; exit 1; }
echo "PASS symbol-form library name is upper-cased and fails like the interpreter"
# fail-closed source forms
n=0
reject() { n=$((n+1)); printf '%b\n' "$1" > "$WORK/rej$n.rex"; rm -f "$WORK/rej$n.cpp"
  if RX2CPP_HOSTED=0 "$ROOT/run-compiler.sh" "$WORK/rej$n.rex" "$WORK/rej$n.cpp" >/dev/null 2>&1; then echo "FAIL accepted: $1"; exit 1; fi
  [[ ! -e "$WORK/rej$n.cpp" ]] || { echo "FAIL partial C++ for: $1"; exit 1; }; }
reject 'say Foo(1)'                                              # external name without any LIBRARY declared
reject 'say 1\n::requires "other.rex"'                           # Rexx program requires: not implemented
reject 'say 1\n::requires "rxsock" LIBRARY EXTENSIVE'            # unknown option
reject 'say 1\n::constant pi 3'                                   # other directives fail closed
reject 'say 1\n::requires "../x" LIBRARY'                        # no path in the library name
reject 'say 1\n::requires "rxsock" LIBRARY\nsay 2'               # code after directives
echo "PASS $n fail-closed forms rejected with no output"
# a real BIF name is never routed to an external library (built-ins win), whichever way this build treats it
printf 'say Substr("abc",1,1)\n::requires "rxmath" LIBRARY\n' > "$WORK/bif.rex"
"$ROOT/run-compiler.sh" "$WORK/bif.rex" "$WORK/bif.cpp" >/dev/null 2>&1 || true
if [[ -e "$WORK/bif.cpp" ]] && grep -q 'ext::callValue(vars, "SUBSTR"' "$WORK/bif.cpp"; then echo "FAIL BIF routed to external library"; exit 1; fi
echo "PASS built-in names are never external routines"
