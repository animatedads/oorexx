# T1: build the compiled-in kernel and the probe

Goal: produce `$W/probe` (calls the real ooRexx built-in function handlers) in a work directory.
Needs: cmake, g++, make, git, and the ooRexx 5.3 SOURCE tree (call its path SRC).
Check the tools first: `cmake --version && g++ --version && make --version` (each must print a version; if one is missing, stop and report which).
Get the 5.3 source (the 5.3 trunk is the `master` branch of ooRexx/ooRexx, NOT RexxLA/oorexx which is 5.2.0):
    git clone --depth 1 https://github.com/ooRexx/ooRexx.git ~/ooRexx_master
    SRC=~/ooRexx_master
Check the version: `grep -E "ORX_MAJOR|ORX_MINOR" $SRC/CMakeLists.txt | head -4` must show MAJOR 5 and MINOR 3.
Record the source commit: `git -C $SRC rev-parse --short HEAD` and put it in the report.
Time: 15-40 minutes. Run it in the background so your tool call does not time out.

Steps
1. `W=/tmp/kernel_work` (SRC is set above)
2. `setsid nohup bash experiments/kernel_spike/build.sh "$SRC" "$W" > tasks/results/T1_build.log 2>&1 < /dev/null &`
3. Check progress every few minutes with: `tail -n 2 tasks/results/T1_build.log` (do not loop; one check per message).
4. The build is finished when the log ends with these lines (order may differ):
       [ello]
       [ello**]
       substr('hello',2,,'*') -> [ello]
5. Confirm the files exist: `ls -la $W/probe $W/builtin_call $W/direct_call $W/rexx.img`  (all four must be listed).

Expect: the 4 files above exist and the log contains `[ello**]`.
If a file is missing or the log has `error`: copy the last 40 lines of the log into the report and stop.
Report: create `tasks/results/T1.md` with the Write/Edit tool (a file-writing tool, NOT a chain of echo commands).
Contents: source commit, work dir, PASS or FAIL, and these three things (the log's last lines are only compiler warnings, do not use them):
  a. `ls -la $W/probe $W/builtin_call $W/direct_call $W/rexx.img`  (paste the output)
  b. `grep -n "ello" tasks/results/T1_build.log`  (paste the output; it must show [ello] and [ello**])
  c. `grep -c "error:" $W/b/make.log`  (paste the number; it must be 0)
The "left('abc',,'*') -> Rexx error raised by the kernel" line is CORRECT and is not a failure. Check it exists with `ls -la tasks/results/T1.md`.
Self-check before finishing: `grep -c FAIL tasks/results/T1.md` must print 0 when the result is PASS (remove any old FAIL text from an earlier run).
Do not commit the build directory. Commit only `tasks/results/T1.md` and `tasks/results/T1_build.log`.
