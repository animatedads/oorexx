#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export RX2CPP_BIF_ROOT="$ROOT/external/bif"
export REXX_BIN=${REXX_BIN:-rexx}
export REXX_LIB=${REXX_LIB:-}
if [[ -n "$REXX_LIB" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
if [[ $(($(wc -l < "$RX2CPP_BIF_ROOT/catalog/bifs.tsv") - 1)) -ne 81 ]]; then echo 'BIF registration count incorrect'; exit 1; fi
# Compiler admission for each of the 81 catalogue names, without executing
# functions whose activation semantics have not yet been implemented.
"$ROOT/run-compiler.sh" "$ROOT/tests/bif_all_81_compile.rex" "$TMP/all81.cpp"
[[ "$(grep -c 'rx::dispatchBif(' "$TMP/all81.cpp")" -eq 81 ]]
cat > "$TMP/native.rex" <<'EOF'
s = 'abcdef'
say substr(s,2,3)
say left(s,3)
say reverse(s)
say words('one two three')
say c2x('AB')
say abs(-15)
say length('abc')
call upper 'hello'
say result
exit 0
EOF
cat > "$TMP/isolated.rex" <<'EOF'
say c2d('123')
say datatype('123','N')
say trunc('123.876', 1)
say format('1.234', 2, 2)
say format('12.345',,2)
exit 0
EOF
cat > "$TMP/host.rex" <<'EOF'
say arg()
exit 0
EOF
cat > "$TMP/missing.rex" <<'EOF'
say READER_INVENTED_BIF('x')
exit 0
EOF
cat > "$TMP/shadow.rex" <<'EOF'
say length('foo')
exit 0
length:
  parse arg x
  return 117
EOF
# A link-only native implementation must remain independent of the interpreter.
CXX=${CXX:-g++}
CXX="$CXX" "$ROOT/build.sh" "$TMP/native.rex" "$TMP/native" "$TMP/native.cpp" > /dev/null
"$REXX_BIN" "$TMP/native.rex" > "$TMP/native.expected"
"$TMP/native" > "$TMP/native.actual"
cmp "$TMP/native.expected" "$TMP/native.actual"
if command -v ldd >/dev/null && ldd "$TMP/native" | grep -E 'librexx[.]so|librexxapi[.]so'; then
  echo 'Native BIF build unexpectedly links ooRexx' >&2; exit 1
fi
# Internal function names still take precedence.
CXX="$CXX" "$ROOT/build.sh" "$TMP/shadow.rex" "$TMP/shadow" "$TMP/shadow.cpp" >/dev/null
"$REXX_BIN" "$TMP/shadow.rex" > "$TMP/shadow.expected"
"$TMP/shadow" > "$TMP/shadow.actual"
cmp "$TMP/shadow.expected" "$TMP/shadow.actual"
# An unsupported host activation function may be in the catalogue but it
# must not silently fake the caller's activation.
CXX="$CXX" "$ROOT/build.sh" "$TMP/host.rex" "$TMP/host" "$TMP/host.cpp" >/dev/null
if "$TMP/host" > "$TMP/host.out" 2> "$TMP/host.err"; then
    echo 'HOST_ACTIVATION BIF succeeded without a host' >&2; exit 1
fi
grep -q 'BIF ARG:' "$TMP/host.err"
# An unknown function must not overwrite the existing C++ target.
printf 'protected\n' > "$TMP/rejected.cpp"
if "$ROOT/run-compiler.sh" "$TMP/missing.rex" "$TMP/rejected.cpp" > "$TMP/missing.out" 2>&1; then
    echo 'Unknown BIF was accepted' >&2; exit 1
fi
[[ "$(cat "$TMP/rejected.cpp")" == protected ]]
# An incomplete/incorrect BIF manifest must fail transactionally.
mkdir -p "$TMP/bad/catalog"
head -n 80 "$RX2CPP_BIF_ROOT/catalog/bifs.tsv" > "$TMP/bad/catalog/bifs.tsv"
if RX2CPP_BIF_ROOT="$TMP/bad" "$ROOT/run-compiler.sh" "$TMP/native.rex" "$TMP/rejected.cpp" > "$TMP/bad.out" 2>&1; then
    echo 'Incomplete BIF catalog was accepted' >&2; exit 1
fi
[[ "$(cat "$TMP/rejected.cpp")" == protected ]]
# Activation-sensitive isolated chainback requires a caller-context snapshot,
# here proven default DIGITS 9, FUZZ 0, SCIENTIFIC (compiler rejects NUMERIC).
: "${OO_ROOT:?Set OO_ROOT to staged ooRexx prefix for pass-through tests}"
export RX2CPP_BIF_ISOLATED=1
export RX2CPP_BIF_ISOLATED_SCRIPT="$RX2CPP_BIF_ROOT/native/isolated_chainback.rex"
CXX="$CXX" "$ROOT/build.sh" "$TMP/isolated.rex" "$TMP/isolated" "$TMP/isolated.cpp" >/dev/null
"$REXX_BIN" "$TMP/isolated.rex" > "$TMP/isolated.expected"
"$TMP/isolated" > "$TMP/isolated.actual"
cmp "$TMP/isolated.expected" "$TMP/isolated.actual"
printf 'PASS BIF dynamic: catalogue=81 native=8 isolated=5 host-reject=1 shadow=1 manifest-reject=1 unknown-reject=1, compiler=%s\n' "$CXX"
