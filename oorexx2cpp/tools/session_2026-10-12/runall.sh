#!/bin/bash
cd /home/claude/animatedads_oorexx/oorexx2cpp
OR=$(cat /tmp/claude-0/-home-claude-oorexx/*/scratchpad/orpath)
export OO_ROOT=$OR REXX_BIN=$OR/bin/rexx REXX_LIB=$OR/lib PATH=$OR/bin:$PATH LD_LIBRARY_PATH=$OR/lib REXX_PATH=$PWD
out=$1; shift
: > $out
for t in "$@"; do
  timeout 900 bash $t > /tmp/cc/log.$(basename $t).txt 2>&1
  echo "$(basename $t) rc=$?" >> $out
done
echo DONE >> $out
