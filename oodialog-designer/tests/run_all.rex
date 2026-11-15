/* run_all.rex -- the ooDialog Designer's ooRexx tests, each in a process of
   its own (t05 must start with nothing set up), in a scratch directory (t01
   and t03 write files).  A running log: one line as each test starts and
   one as it ends, with its result.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx run_all.rex PACKAGE_ROOT [test ...]
     REXX_PATH must hold PACKAGE_ROOT/src, PACKAGE_ROOT/tests and
     PACKAGE_ROOT/vendor (the Rexx Parser, for t02).
   Exit: the number of tests that failed.

   The log is written with SAY, not through oorexx_logging: its v0.7 targets
   are memory and queue targets, which hold events for later; none writes a
   line as it happens, and a run log that appears only at the end is the black
   box this log exists to avoid. */
parse arg root names
root = root~strip
if root == "" then do
  say "usage: rexx run_all.rex PACKAGE_ROOT [test ...]"
  return 99
end
root = .File~new(root)~absolutePath       -- the tests run in a scratch directory
tests = .array~new
if names~strip == "" then names = "t01_model t02_graph t03_nls t04_ui t05_fresh"
do t over names~space~makeArray(" ")
  tests~append(t)
end
-- what each needs as arguments
needs = .directory~new
needs["T04_UI"] = root"/site"

scratch = SysTempFileName("/tmp/oodd-tests-?????")
call SysMkDir scratch
parse version v
say "run_all: ooRexx" v
say "run_all:" tests~items "tests, in" scratch
failed = .array~new
do t over tests
  file = root"/tests/"t".rex"
  if \SysFileExists(file) then do
    say "run_all: MISSING" t
    failed~append(t)
    iterate
  end
  say "run_all: RUN" t
  started = time("E")
  args = ""
  if needs~hasIndex(t~upper) then args = '"'needs[t~upper]'"'
  address system 'cd "'scratch'" && rexx "'file'"' args
  code = rc
  took = format(time("E") - started, , 2)
  if code = 0 then say "run_all: PASS" t "("took"s)"
  else do
    say "run_all: FAIL" t "-- exit" code "("took"s)"
    failed~append(t)
  end
end
say "run_all:" tests~items - failed~items "of" tests~items "tests passed" || -
  copies(";  failed: " || failed~makeString("L", " "), failed~items > 0)
return failed~items
