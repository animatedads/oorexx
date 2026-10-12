#!/bin/bash
cd /tmp/cc/libs/oorexx_maths_v0.82/oorexx_maths_v0.8/tests
OR=$(cat /tmp/claude-0/-home-claude-oorexx/*/scratchpad/orpath)
export PATH=$OR/bin:$PATH
S=/tmp/cc/mt/summary.txt; : > $S
for t in test_core test_claims test_rational test_exact_numbers test_decimal_expansion test_rational_roundtrip test_quantization test_mixed_precision test_math3d test_rational_matrix test_proof_planner; do
  s=$(date +%s.%N); LD_LIBRARY_PATH=$OR/lib REXX_PATH=../rexx timeout 1200 rexx $t.rex > /tmp/cc/mt/$t.interp 2>&1; ri=$?; e=$(date +%s.%N); ti=$(echo "$e - $s" | bc)
  s=$(date +%s.%N); LD_LIBRARY_PATH=/tmp/cc/mt/nat:$OR/lib REXX_PATH=/tmp/cc/mt/nrexx:../rexx timeout 1200 rexx $t.rex > /tmp/cc/mt/$t.native 2>&1; rn=$?; e=$(date +%s.%N); tn=$(echo "$e - $s" | bc)
  if cmp -s /tmp/cc/mt/$t.interp /tmp/cc/mt/$t.native; then same=SAME; else same=DIFF; fi
  echo "$t interp rc=$ri ${ti}s native rc=$rn ${tn}s $same" >> $S
done
echo DONE >> $S
