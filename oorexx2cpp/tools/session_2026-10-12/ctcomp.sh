#!/bin/bash
# crypto test suite compiled with rx2cpp, crypto as native library
cd /tmp/cc/ct
OR=$(cat /tmp/claude-0/-home-claude-oorexx/*/scratchpad/orpath)
export OO_ROOT=$OR REXX_BIN=$OR/bin/rexx REXX_LIB=$OR/lib PATH=$OR/bin:$PATH LD_LIBRARY_PATH=/tmp/cc/libs/nat:$OR/lib REXX_PATH=/home/claude/animatedads_oorexx/oorexx2cpp
: > compsum.txt
for t in test_hashes test_sha256 test_hmac_sha512 test_siphash128 test_chacha20 test_input_validation test_asymmetric_misc test_ed25519; do
  /home/claude/animatedads_oorexx/oorexx2cpp/build.sh n_$t.rex c_$t.bin > c_$t.build 2>&1 || { echo "$t BUILD-FAIL $(grep -m1 rx2cpp c_$t.build)" >> compsum.txt; continue; }
  s=$(date +%s.%N); timeout 1200 ./c_$t.bin > $t.comp 2>&1; rc=$?; e=$(date +%s.%N)
  if cmp -s $t.interp $t.comp; then same=SAME; else same=DIFF; fi
  echo "$t compiled rc=$rc $(echo "$e - $s" | bc)s $same" >> compsum.txt
done
echo DONE >> compsum.txt
