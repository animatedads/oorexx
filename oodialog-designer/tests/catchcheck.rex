/* catchcheck.rex -- does this ooRexx run CATCH and FINALLY (RFE #31, ooRexx
   r13514 or later) as the ooDialog Designer's graph and guard expect?
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage:  rexx catchcheck.rex
   (v0.18: which checks run is asked of the ooRexx, by compiling a lone CATCH
   or FINALLY clause, not read from its revision: a build from git answers
   r0.  The old FINALLY argument is ignored.)
   CATCH is in ooRexx trunk since r13514, FINALLY by 2026-11-21 (git trunk
   5f066c9 runs both).  No ooDialog needed.  The code under test is compiled
   from strings (.Routine~new), so this file itself loads on any ooRexx 5.
   On an ooRexx that does not know them it says so and skips their checks;
   the designer refuses to run such code there, and the programs it writes
   refuse to start.
   Output: one line per check, then "catchcheck: N of M checks passed".
   Exit 0 when all pass, 1 otherwise.                                        */
parse upper arg wantFinally .
parse version v
say "catchcheck: ooRexx" v "r" || .RexxInfo~revision "on" .RexxInfo~platform
fails = 0
checks = 0
nl = "0a"x
call check "the revision is a number (a build from git answers 0)", datatype(.RexxInfo~revision, "W")
-- asked of this ooRexx by compiling a lone clause, as the designer's guard
-- does: one that knows CATCH (FINALLY) refuses it outside a block
knowsCatch = knows("catch syntax"); knowsFinally = knows("finally")
say "catchcheck: this ooRexx knows CATCH:" knowsCatch", FINALLY:" knowsFinally
if \knowsCatch then do
  say "catchcheck: SKIP the CATCH checks: this ooRexx does not know CATCH"
  signal done
end

-- a SYNTAX condition caught, its object named, the rest of the block skipped
r = run('s = ""' || nl || 'do' || nl || '  x = 1 + "a"' || nl || '  s = s "after"' || nl || -
        'catch co = syntax' || nl || '  s = s "caught" co~code' || nl || 'end' || nl || 'return s~strip')
call check "CATCH co = SYNTAX: caught, the rest of the block skipped", r == "caught 41.1"

-- the first CATCH whose condition matches is the one that runs
r = run('do' || nl || '  raise user mine' || nl || 'catch syntax' || nl || '  return "syntax"' || nl || -
        'catch user mine' || nl || '  return "mine"' || nl || 'end' || nl || 'return "none"')
call check "CATCH USER name: the matching clause runs", r == "mine"

-- a condition no CATCH names goes on out of the block
r = run('signal on syntax name outer' || nl || 'do' || nl || '  x = 1 + "a"' || nl || 'catch error' || nl || -
        '  return "wrong"' || nl || 'end' || nl || 'return "not raised"' || nl || 'outer:' || nl || 'return "raised"')
call check "a condition no CATCH names goes out of the block", r == "raised"

-- CATCH on a LOOP: reported, not checked (does a caught condition end the
-- loop, or only that turn?  The line says which this ooRexx does)
r = run('s = ""' || nl || 'loop i = 1 to 3' || nl || '  if i = 2 then x = 1 + "a"' || nl || '  s = s i' || nl || -
        'catch syntax' || nl || '  s = s "c"i' || nl || 'end' || nl || 'return s~strip')
say "catchcheck: NOTE a LOOP i = 1 to 3 whose turn 2 raises SYNTAX, with CATCH SYNTAX, gives:" r

if \knowsFinally then do
  say "catchcheck: SKIP the FINALLY checks: this ooRexx does not know FINALLY"
  signal done
end

-- FINALLY runs after a normal end, and after a caught condition
r = run('s = ""' || nl || 'do' || nl || '  s = s "body"' || nl || 'finally' || nl || '  s = s "finally"' || nl || 'end' || nl || 'return s~strip')
call check "FINALLY after a normal end", r == "body finally"
r = run('s = ""' || nl || 'do' || nl || '  raise syntax 40.1' || nl || 'catch syntax' || nl || '  s = s "caught"' || nl || -
        'finally' || nl || '  s = s "finally"' || nl || 'end' || nl || 'return s~strip')
call check "FINALLY after a CATCH", r == "caught finally"

-- a LOOP with FINALLY: LEAVE from its body still ends the loop, FINALLY runs
r = run('n = 0' || nl || 's = ""' || nl || 'loop i = 1 to 5' || nl || '  n = i' || nl || '  if i = 3 then leave' || nl || -
        'finally' || nl || '  s = "finally" n' || nl || 'end' || nl || 'return s')
call check "LOOP ... FINALLY: LEAVE ends the loop, FINALLY runs once", r == "finally 3"

-- a condition not caught goes on out of the block (FINALLY still runs)
r = run('s = ""' || nl || 'signal on syntax name outer' || nl || 'do' || nl || '  x = 1 + "a"' || nl || -
        'catch error' || nl || '  s = "wrong"' || nl || 'finally' || nl || '  s = "finally"' || nl || 'end' || nl || -
        'return "not raised"' || nl || 'outer:' || nl || 'return s "then raised"')
call check "an uncaught condition goes out, after FINALLY", r == "finally then raised"

done:
say "catchcheck:" checks - fails "of" checks "checks passed"
if fails > 0 then exit 1
exit 0

-- compile and run code; its result, or "error n.n: message" when it fails
run: procedure
  use arg runCode
  signal on syntax name runFailed
  return .Routine~new("catchcheck", runCode~makeArray("0a"x))~call
runFailed:
  c = condition("O")
  return "error" c["CODE"]":" c["MESSAGE"]

check: procedure expose fails checks
  use arg ckLabel, ckOk
  checks = checks + 1
  if ckOk == 1 then say "  ok  " ckLabel
  else do
    say "  FAIL" ckLabel
    fails = fails + 1
  end
  return

-- does this ooRexx know the clause?  It refuses it alone, outside a block
knows: procedure
  use arg clause
  signal on syntax name refused
  probe = .Routine~new("probe", .array~of(clause))
  return .false
refused:
  return .true
