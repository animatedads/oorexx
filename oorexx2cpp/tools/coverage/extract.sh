#!/usr/bin/env bash
# tools/coverage/extract.sh TEST: after a test ran under tools/coverage/g++, write $COVOUT/<test>.cov and delete the
# raw profiles. Lines: "L file line" for each line of a tracked C/C++ file that ran (count > 0), and "F file start
# end" for each function gcov saw (its line range; executed or not). file is relative to oorexx2cpp/.
# gcov's machine-readable output is JSON; jq reduces it to these lines. Code: Claude (Opus 5.5), 2026-11-02.
set -uo pipefail
t=${1##*/}; ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
src=$COVROOT/$t; out=$COVOUT/$t.cov
: > "$out.tmp"
# A .gcda lands under its compile's directory either "#"-mangled or in subdirectories (GCC does both, depending on
# the object path); its .gcno, copied there by the wrapper, has the same base name after the last "#".
for dir in "$src"/*/; do
  [[ -d $dir ]] || continue
  find "$dir" -name '*.gcda' | while read -r d; do
    b=$(basename -- "$d" .gcda); b=${b##*#}
    for n in "$dir"/*.gcno; do
      [[ -f $n ]] || continue
      nb=$(basename -- "$n" .gcno); nb=${nb##*#}
      if [[ $nb == "$b" ]]; then cp -- "$n" "${d%.gcda}.gcno"; break; fi
    done
    ( cd "$(dirname -- "$d")" && gcov --json-format --stdout "$(basename -- "$d")" 2>/dev/null )
  done | jq -r --arg root "$ROOT/" '
      .files[] | select(.file | startswith($root)) | (.file | ltrimstr($root)) as $f |
      ((.lines[] | select(.count > 0) | "L \($f) \(.line_number)"),
       (.functions[] | "F \($f) \(.start_line) \(.end_line)"))' >> "$out.tmp"
done
sort -u "$out.tmp" > "$out"; rm -f "$out.tmp"
[[ ${COV_KEEP:-0} == 1 ]] || rm -rf -- "$src"     # COV_KEEP=1 keeps the raw profiles (debugging)
echo "$t: $(grep -c '^L' "$out") lines ran, $(grep -c '^F' "$out") functions seen"
