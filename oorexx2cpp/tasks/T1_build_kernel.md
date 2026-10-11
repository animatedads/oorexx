# T1: build the compiled-in kernel and the probe

Goal: produce `$W/probe` (calls the real ooRexx built-in function handlers) in a work directory.
Needs: cmake, g++, make, the ooRexx 5.3.0 SOURCE tree (call its path SRC; it contains CMakeLists.txt and `interpreter/`).
Time: 15-40 minutes. Run it in the background so your tool call does not time out.

Steps
1. `W=/tmp/kernel_work; SRC=<path to ooRexx source>`
2. `setsid nohup bash experiments/kernel_spike/build.sh "$SRC" "$W" > tasks/results/T1_build.log 2>&1 < /dev/null &`
3. Check progress every few minutes with: `tail -n 2 tasks/results/T1_build.log` (do not loop; one check per message).
4. The build is finished when the log ends with these lines (order may differ):
       [ello]
       [ello**]
       substr('hello',2,,'*') -> [ello]
5. Confirm the files exist: `ls -la $W/probe $W/builtin_call $W/direct_call $W/rexx.img`  (all four must be listed).

Expect: the 4 files above exist and the log contains `[ello**]`.
If a file is missing or the log has `error`: copy the last 40 lines of the log into the report and stop.
Report: `tasks/results/T1.md`. Do not commit the build directory.
