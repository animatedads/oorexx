# Session harness scripts (2026-10-12)

Copied as used; they assume the packages were unpacked under /tmp/cc/libs and the ooRexx install path is in the
scratchpad file `orpath`. Adjust paths before reuse. See ../../HANDOFF_2026-10-12.md.

- runall.sh: run a list of test scripts, one result line each
- cbuild.sh / ctrun.sh / ctcomp.sh: build crypto natively, run its tests native vs interpreter, and as compiled programs
- mtrun.sh: Maths tests native vs interpreter
- czrun.sh: compress / archive tests native vs interpreter
- jb.rex / j2.rex: json.cls benchmark (open item 1) and behaviour check
