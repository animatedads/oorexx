#!/usr/bin/env bash
# ooTest testGroups compiled as native libraries, compared with the same groups interpreted.
#
#   OO_TEST_ROOT=/path/ooTest-4.2.0-snapshot06 OO_ROOT=/path/ooRexx ootest/run_native_groups.sh [list-file | subdir/name ...]
#
# For each group (default list: ootest/native_groups.txt, one "subdir/Name" per line, # comments):
#   1. the group runs interpreted (the oracle), from a copy of the suite;
#   2. the group minus its prolog is compiled with native/build.sh into lib<oot_...>.so; the ooTest framework
#      (ooTest.frm, OOREXXUNIT.CLS, FileUtils.cls) stays interpreted;
#   3. in a second copy of the suite the group file becomes a stub: import of the library's package scope, the
#      original prolog, ::REQUIRES of the library; the same driver runs it;
#   4. the results must match: totals (tests, assertions, failures, errors) and, for every failure and error, the
#      test, class, event and message (time stamps, line numbers and tracebacks are not compared: compiled code has
#      no source lines).
# RX2CPP_COMPILER_LIB=dir uses the self-compiled compiler (native/build_self.sh).
set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
T=${OO_TEST_ROOT:?Set OO_TEST_ROOT to the unzipped ooTest snapshot root}
OO_ROOT=${OO_ROOT:-/usr/local}
REXX_BIN=${REXX_BIN:-$OO_ROOT/bin/rexx}
WORK=${TEST_OUTPUT_DIR:-$(mktemp -d)}
mkdir -p "$WORK"
groups=()
if (( $# == 0 )); then set -- "$ROOT/ootest/native_groups.txt"; fi
for a in "$@"; do
  if [[ -f "$a" ]]; then while read -r g; do [[ -z "$g" || "$g" == \#* ]] || groups+=("$g"); done < "$a"
  else groups+=("$a"); fi
done
rm -rf "$WORK/itree" "$WORK/ctree"; cp -a "$T" "$WORK/itree"; cp -a "$T" "$WORK/ctree"
mkdir -p "$WORK/libs" "$WORK/src" "$WORK/out"
# Standard input is an empty regular file for both runs: LINES() of a terminal, pipe or /dev/null depends on timing
# (StreamInfo::lines of a transient stream asks whether data is ready), in the interpreter as well.
: > "$WORK/empty.stdin"
cat > "$WORK/norm.awk" <<'AWK'
/^Tests ran:|^Assertions:|^Failures:|^Errors:|^Skipped files:/ { print; next }
/^\[(failure|error)\]/ { sub(/ \[.*\]/, ""); print; inblk=1; msg=0; next }
inblk && /^  Test:/  { print; next }
inblk && /^  Class:/ { print; next }
inblk && /^  Event:/ { print; msg=1; next }
inblk && msg==1 && /^    / && !/^    Line:/ && !/\*-\*/ { print; msg=2; next }
/^Test execution:/ { inblk=0 }
AWK
run() {  # tree subdir name out
  (cd "$1/ooRexx/base/$2" && env PATH="$1:$1/framework:$(dirname "$REXX_BIN"):/usr/bin:/bin" \
     LD_LIBRARY_PATH="$WORK/libs:$1/bin/LINUX:$OO_ROOT/lib" timeout 600 "$REXX_BIN" "$3.testGroup" < "$WORK/empty.stdin" > "$4.raw" 2>&1)
  awk -f "$WORK/norm.awk" "$4.raw" > "$4.norm"
}
pass=0; fail=0
for g in "${groups[@]}"; do
  sub=${g%/*}; n=${g#*/}
  src="$T/ooRexx/base/$sub/$n.testGroup"
  [[ -f "$src" ]] || { echo "MISSING $g"; fail=$((fail+1)); continue; }
  lib=oot_$(printf '%s' "$sub$n" | tr -c 'A-Za-z0-9' '_' | tr 'A-Z' 'a-z')
  run "$WORK/itree" "$sub" "$n" "$WORK/out/$sub.$n.i"
  first=$(grep -n '^[[:space:]]*::' "$src" | head -1 | cut -d: -f1)
  # a combine marker names the group file where it runs (PARSE SOURCE; SOURCELINE embeds that file, still the original
  # at this point); the prolog lines are blanked so line numbers stay the same
  { printf '/* ---- rx2cpp combined: %s ---- */\n' "$WORK/ctree/ooRexx/base/$sub/$n.testGroup"
    awk -v f="$first" 'NR < f { print ""; next } { print }' "$src"; } > "$WORK/src/$n.cls"
  if ! env PATH="$(dirname "$REXX_BIN"):/usr/bin:/bin" OO_ROOT="$OO_ROOT" REXX_BIN="$REXX_BIN" \
       LD_LIBRARY_PATH="$WORK/libs:$T/bin/LINUX:$OO_ROOT/lib" REXX_PATH="$T:$T/framework:$T/ooRexx/base/$sub" \
       RX2CPP_KEEP_INTERPRETED="ooTest.frm OOREXXUNIT.CLS FileUtils.cls" \
       "$ROOT/native/build.sh" "$WORK/src/$n.cls" "$WORK/libs" "$lib" > "$WORK/out/$sub.$n.build.log" 2>&1; then
    echo "FAIL $g: compile ($(grep -m1 'rx2cpp:' "$WORK/out/$sub.$n.build.log" | cut -c1-160))"; fail=$((fail+1)); continue
  fi
  up=$(printf '%s' "$lib" | tr 'a-z' 'A-Z')
  { head -1 "$src" | grep '^#!'   # a #! first line stays first (programs that read their own file)
    printf "rx2cppPackage = .environment['RX2CPP.PACKAGE.%s']\nif rx2cppPackage \\\\== .nil then .context~package~addPackage(rx2cppPackage)\n" "$up"
    awk -v f="$first" 'NR < f' "$src" | grep -v '^#!'
    printf "::requires 'ooTest.frm'\n::requires '%s' library\n" "$lib"; } > "$WORK/ctree/ooRexx/base/$sub/$n.testGroup"
  run "$WORK/ctree" "$sub" "$n" "$WORK/out/$sub.$n.c"
  if grep -q '^Tests ran' "$WORK/out/$sub.$n.i.norm" && cmp -s "$WORK/out/$sub.$n.i.norm" "$WORK/out/$sub.$n.c.norm"; then
    echo "PASS $g: $(awk '/^Tests ran/{print $3}' "$WORK/out/$sub.$n.c.norm") tests, results identical"; pass=$((pass+1))
  else
    echo "FAIL $g: results differ"; diff "$WORK/out/$sub.$n.i.norm" "$WORK/out/$sub.$n.c.norm" | head -12; fail=$((fail+1))
  fi
done
echo "ooTest native groups: $pass identical, $fail failing"
(( fail == 0 ))
