# T3: profile the compiled rexxcps and report the hot spots

Goal: find where a compiled Rexx program spends its time. Do NOT change any source. Only measure and report.
Needs: T1 finished (`/tmp/kernel_work` has `b/lib/librexx.a`, `b/lib/rexx.img`), `rexx` 5.3 on PATH, `valgrind` installed
(`valgrind --version`; if missing: `sudo apt-get install -y valgrind`, if that fails STOP and report).

Steps (run each exactly; stop and report on the first error, quoting the FIRST error line, not the last 20 lines)
0. `git pull`
1. Set up (one shell, keep it): 
       export RX2CPP_KERNEL=/tmp/kernel_work
       mkdir -p /tmp/prof && cd - >/dev/null
2. Build the small benchmark (5 averaging loops, about 1 minute under valgrind):
       ./build.sh tasks/results/cps_small.rex /tmp/prof/small.bin /tmp/prof/small.cpp
       cp /tmp/kernel_work/b/lib/rexx.img /tmp/prof/
   Check: `/tmp/prof/small.bin` exists. Run `cd /tmp/prof && ./small.bin | tail -3`: it must print `Performance:`.
3. Profile (takes several minutes, wait for it, do not poll):
       cd /tmp/prof && valgrind --tool=callgrind --callgrind-out-file=cg.out ./small.bin > run.log 2>&1
   Check: `ls -l cg.out` is not empty.
4. Report: `callgrind_annotate cg.out | head -60 > top.txt` and `callgrind_annotate --inclusive=yes cg.out | head -60 > incl.txt`
5. Write `tasks/results/T3_profile.md` using this layout:
       Machine: (uname -m, cpu model from /proc/cpuinfo, one line)
       Performance line from step 2: (copy it)
       Top 15 functions by self cost: (copy from top.txt, keep the name and the percentage only)
       Top 15 by inclusive cost: (from incl.txt, same)
   Then answer in one line each, using the percentages: what share is
       (a) names containing `rxkernel::` or `ApiContext` or `ProtectedObject`   (BIF entry)
       (b) names containing `unordered_map` or `hash` or `basic_string`          (variable store and strings)
       (c) names containing `Decimal` or `decimal`                                (number engine)
       (d) anything else big: name it
6. `git add tasks/results/T3_profile.md && git commit -m "T3 profile report"` then `git push`. If push fails, say so; do not fix it.
Never edit files other than the report. Never run `git push --force`.
