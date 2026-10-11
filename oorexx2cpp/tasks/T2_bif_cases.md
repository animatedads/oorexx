# T2: compare 56 built-in functions, compiled-in handler vs interpreter

Goal: a case file with at least 4 cases for each function in `experiments/kernel_spike/pure_bifs.txt`, run through
`experiments/kernel_spike/compare.sh`, and a report of every difference. Do NOT fix differences. Just report them.
Needs: the interpreter you compare against must be 5.3. Check: `rexx -v | head -1` must say `Version 5.3.0`.
If it says 5.2.0 (for example a portable 5.2 build), STOP and report; the compiled-in source is 5.3 so differences would be meaningless.
Needs: T1 finished (`$W/probe` and `$W/rexx.img` exist, W=/tmp/kernel_work) and `rexx` on PATH.

Case file format (one case per line, saved as `tasks/results/cases_bif.txt`)
    NAME|arg1|arg2|arg3
- Fields are separated by `|`. Never put `|` inside an argument.
- A field that is EMPTY means the argument is omitted:  `SUBSTR|hello|2||*`  omits argument 3.
- The field `<empty>` means the null string.
- All arguments are plain strings. Lines starting with # are comments.
- A line with only a name and one trailing `|` means NO arguments:  `USERID|`  is  `userid()`.
- Worked examples (copy this style):
      SUBSTR|hello|2||*          substr('hello',2,,'*')
      SUBSTR|hello|2|6|*
      POS|b|abcb||3
      X2D|ff
      LEFT|abc|5|.
      STRIP|xxabxx||x

Steps
0. Refresh the tools (ALWAYS do this first; an old probe binary gives false differences):
       git pull
       experiments/kernel_spike/rebuild_probe.sh /tmp/kernel_work
       experiments/kernel_spike/compare.sh /tmp/kernel_work experiments/kernel_spike/cases_regress.txt
   Expect the compare to print ONLY the `GC|` difference (`-GC| => [1]`, `+GC| => [0]`). If it prints BITXOR, USERID or QUALIFY
   lines, the probe is stale or the wrong directory is used: stop and report. Do not continue to step 1.
1. `cat experiments/kernel_spike/pure_bifs.txt` : this is the list of 56 function names. Do every one.
2. For each name, write 4 or more cases: (a) normal use, (b) an omitted middle argument if the function has
   optional arguments, (c) the null string `<empty>`, (d) a bad argument such as a letter where a number is expected.
   Look at the function in the ooRexx documentation or in `external/bif/catalog/bif_signatures.tsv`
   (columns: name pos arg kind need later) to see which positions are optional.
3. Save to `tasks/results/cases_bif.txt`. Check: `wc -l tasks/results/cases_bif.txt` must be at least 224.
4. Run: `experiments/kernel_spike/compare.sh /tmp/kernel_work tasks/results/cases_bif.txt | tee tasks/results/T2_compare.log`
5. Expect the last line to be `ALL EQUAL (N cases)`. If it says `DIFFERENCES FOUND`, that is a valid result: do not change anything.
   Lines starting with `-` are the interpreter's answer, lines starting with `+` are the compiled-in handler's answer.
6. If a line says `NOTPURE`, the name is not in the probe table: write its name in the report and move on.
7. Write `tasks/results/T2.md` with: number of cases, number of differences, and the list of differing cases (copy the - and + lines).
8. Commit `tasks/results/cases_bif.txt`, `tasks/results/T2_compare.log`, `tasks/results/T2.md`.

Stop rules: if `probe` crashes (Illegal instruction / Segmentation fault), copy the case line that ran last into the report
(the last line of `$W/probe.out`) and stop; that case is a finding.

Known differences (these are NOT findings; mention them in the report but do not count them)
- `GC|` (no argument): the interpreter build may return 1 (debug build) while the compiled-in Release kernel returns 0.
  The source returns .true only when forced or when built with _DEBUG.
Output with a NUL byte (for example BITXOR|ff|0f) is compared byte for byte; the compare script uses `diff -a`.
