#!/bin/bash
cd /tmp/cc/libs
OR=$(cat /tmp/claude-0/-home-claude-oorexx/*/scratchpad/orpath)
export OO_ROOT=$OR REXX_BIN=$OR/bin/rexx REXX_LIB=$OR/lib PATH=$OR/bin:$PATH LD_LIBRARY_PATH=$OR/lib REXX_PATH=/home/claude/animatedads_oorexx/oorexx2cpp
start=$(date +%s)
/home/claude/animatedads_oorexx/oorexx2cpp/native/build.sh oorexx_crypto_v0.8.3/oorexx_crypto_v0.8.3/src/crypto.cls nat cryptolib > /tmp/cc/cb.log 2>&1
echo "build rc=$? $(( $(date +%s) - start ))s" >> /tmp/cc/cb.log
export LD_LIBRARY_PATH=/tmp/cc/libs/nat:$LD_LIBRARY_PATH
rexx t1.rex >> /tmp/cc/cb.log 2>&1
rexx b1.rex >> /tmp/cc/cb.log 2>&1
echo done >> /tmp/cc/cb.log
