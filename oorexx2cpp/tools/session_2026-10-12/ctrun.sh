#!/bin/bash
cd /tmp/cc/ct
OR=$(cat /tmp/claude-0/-home-claude-oorexx/*/scratchpad/orpath)
export PATH=$OR/bin:$PATH LD_LIBRARY_PATH=/tmp/cc/libs/nat:$OR/lib
T=/tmp/cc/libs/oorexx_crypto_v0.8.3/oorexx_crypto_v0.8.3/tests
S=/tmp/cc/libs/oorexx_crypto_v0.8.3/oorexx_crypto_v0.8.3/src
: > summary.txt
for t in test_hashes test_sha256 test_hmac_sha512 test_siphash128 test_chacha20 test_input_validation test_asymmetric_misc test_ed25519; do
  sed 's/::requires *["'"'"']crypto.cls["'"'"'].*/::requires "cryptolib" library/I' $T/$t.rex > n_$t.rex
  s=$(date +%s.%N); REXX_PATH=$S timeout 1200 rexx $T/$t.rex > $t.interp 2>&1; ri=$?; e=$(date +%s.%N); ti=$(echo "$e - $s" | bc)
  s=$(date +%s.%N); timeout 1200 rexx n_$t.rex > $t.native 2>&1; rn=$?; e=$(date +%s.%N); tn=$(echo "$e - $s" | bc)
  if cmp -s $t.interp $t.native; then same=SAME; else same=DIFF; fi
  echo "$t interp rc=$ri ${ti}s native rc=$rn ${tn}s $same" >> summary.txt
done
echo DONE >> summary.txt
