#!/bin/bash
# usage: czrun.sh pkgdir libdir shimdir testlist...
P=$1; L=$2; N=$3; shift 3
cd $P/tests
OR=$(cat /tmp/claude-0/-home-claude-oorexx/*/scratchpad/orpath)
export PATH=$OR/bin:$PATH
S=$L/../summary.txt; : > $S
for t in "$@"; do
  s=$(date +%s.%N); LD_LIBRARY_PATH=$OR/lib REXX_PATH=../src:$EXTRA timeout 1800 rexx $t.rex > $L/../$t.interp 2>&1; ri=$?; e=$(date +%s.%N); ti=$(echo "$e - $s" | bc)
  s=$(date +%s.%N); LD_LIBRARY_PATH=$L:$EXTRALIB:$OR/lib REXX_PATH=$N:../src:$EXTRA timeout 1800 rexx n_$t.rex > $L/../$t.native 2>&1; rn=$?; e=$(date +%s.%N); tn=$(echo "$e - $s" | bc)
  if cmp -s $L/../$t.interp $L/../$t.native; then same=SAME; else same=DIFF; fi
  echo "$t interp rc=$ri ${ti}s native rc=$rn ${tn}s $same" >> $S
done
echo DONE >> $S
