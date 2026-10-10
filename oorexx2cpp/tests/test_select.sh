#!/usr/bin/env bash
# Language-only SELECT qualification. Every successful case uses the same
# unmodified ooRexx input under interpreter and generated native C++.
set -euo pipefail
# Legacy standalone qualification links only the original runtime.
# Exercise external BIF integration separately in test_bif_dynamic_v028.sh.
export RX2CPP_BIF_DISABLED=1
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
CXX=${CXX:-g++}
WORK=${TEST_OUTPUT_DIR:-"$ROOT/build/select-$($CXX -dumpmachine 2>/dev/null || echo cxx)"}
mkdir -p "$WORK"
if [[ -n "${REXX_LIB:-}" ]]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
passed=0
for name in select_basic select_otherwise select_nested select_compound select_no_otherwise select_short_circuit select_otherwise_do select_semicolon; do
    src="$ROOT/examples/$name.rex"
    "$REXX_BIN" "$src" >"$WORK/$name.expected"
    "$ROOT/run-compiler.sh" "$src" "$WORK/$name.cpp"
    "$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$ROOT/include" "$WORK/$name.cpp" -o "$WORK/$name.native"
    "$WORK/$name.native" >"$WORK/$name.actual"
    cmp "$WORK/$name.expected" "$WORK/$name.actual" || { diff -u "$WORK/$name.expected" "$WORK/$name.actual"; exit 1; }
    printf 'PASS %s (interpreter/native byte-identical)\n' "$name"
    passed=$((passed+1))
done
# A SELECT without an OTHERWISE is legal Rexx syntax. A nonmatching SELECT
# must fail instead of executing any following statement as if it succeeded.
cat >"$WORK/no_match.rex" <<'REXX'
select
  when 0 then say 'wrong'
end
say 'must not execute'
REXX
set +e
"$REXX_BIN" "$WORK/no_match.rex" >"$WORK/no_match.expected" 2>"$WORK/no_match.oracle_error"
oracle_rc=$?
set -e
[[ $oracle_rc -ne 0 && ! -s "$WORK/no_match.expected" ]] || { echo 'oracle unexpected no-match SELECT behaviour' >&2; exit 1; }
"$ROOT/run-compiler.sh" "$WORK/no_match.rex" "$WORK/no_match.cpp"
"$CXX" -std=c++17 -O2 -Wall -Wextra -Werror -I"$ROOT/include" "$WORK/no_match.cpp" -o "$WORK/no_match.native"
set +e
"$WORK/no_match.native" >"$WORK/no_match.actual" 2>"$WORK/no_match.native_error"
native_rc=$?
set -e
[[ $native_rc -ne 0 && ! -s "$WORK/no_match.actual" ]] || { echo 'native SELECT failed to stop on no-match' >&2; exit 1; }
echo 'PASS SELECT no-match signals an error (exact Rexx exception mapping not supported)'
# Reject malformed syntax without ever emitting a partial native source.
for case_name in no_when when_after_otherwise missing_then duplicate_otherwise stray_body empty_select; do
    case "$case_name" in
        no_when) printf 'select\notherwise say "bad"\nend\n' >"$WORK/$case_name.rex" ;;
        when_after_otherwise) printf 'select\nwhen 0 then say "x"\notherwise say "y"\nwhen 1 then say "z"\nend\n' >"$WORK/$case_name.rex" ;;
        missing_then) printf 'select\nwhen 1 say "bad"\notherwise say "fallback"\nend\n' >"$WORK/$case_name.rex" ;;
        duplicate_otherwise) printf 'select\nwhen 0 then say "x"\notherwise say "y"\notherwise say "z"\nend\n' >"$WORK/$case_name.rex" ;;
        stray_body) printf 'select\nwhen 1 then say "x"\nsay "stray"\nend\n' >"$WORK/$case_name.rex" ;;
        empty_select) printf 'select\nend\n' >"$WORK/$case_name.rex" ;;
    esac
    rm -f "$WORK/$case_name.cpp"
    if "$ROOT/run-compiler.sh" "$WORK/$case_name.rex" "$WORK/$case_name.cpp" >"$WORK/$case_name.err" 2>&1; then
        echo "FAIL rejected $case_name accepted" >&2; exit 1
    fi
    [[ ! -e "$WORK/$case_name.cpp" ]] || { echo "FAIL partial C++ generated for $case_name" >&2; exit 1; }
    grep -q 'rx2cpp:' "$WORK/$case_name.err" || { cat "$WORK/$case_name.err"; exit 1; }
    echo "PASS reject $case_name"
done
printf 'SELECT QUALIFIED: %d interpreter/native parity cases, no-match error, six syntactic rejections; CXX=%s\n' "$passed" "$CXX"
