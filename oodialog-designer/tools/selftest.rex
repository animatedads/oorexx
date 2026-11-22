/* selftest.rex -- run the ooDialog Designer's own tests with this ooRexx
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage, from the designer's folder (the one with README.md):
     rexx tools/selftest.rex

   It puts src, tests and vendor on REXX_PATH (with this system's path
   separator), then runs tests/run_all.rex (t01-t10) and
   tests/catchcheck.rex.  Needs ooRexx 5; Node.js 18 or later for the
   stand-in servers of t07-t09.  On 2026-11-22: 10 of 10 on ooRexx 5.3.0
   (trunk 5f066c9, Linux); on trunk at the 5.1.0 release point, 9 of 10
   (t09 uses .JsonString~new, which that build lacks).  On Windows t07-t09
   are skipped (their stand-in servers need a POSIX shell): use
   tests/wincheck.rex there, which runs the examples under real ooDialog.
   Exit 0 when everything passes. */
parse source . . me
dir = .File~new(me)~parentFile~parent        -- tools/ is under the designer's folder
sep = .File~separator
ps = .File~pathSeparator
path = dir || sep || "src" || ps || dir || sep || "tests" || ps || dir || sep || "vendor"
old = value("REXX_PATH", , "ENVIRONMENT")
if old \== "" then path = path || ps || old
call value "REXX_PATH", path, "ENVIRONMENT"
parse version v
say "selftest: ooDialog Designer" readVersion(dir) "on" v "(" || .RexxInfo~platform || ")"
address system 'node --version'
if rc \== 0 then say "selftest: no node: t07-t09 need Node.js 18+ for their stand-in servers"
say "selftest: 1. tests/run_all.rex"
address system 'rexx "' || dir || sep || 'tests' || sep || 'run_all.rex" "' || dir || '"'
r1 = rc
say "selftest: 2. tests/catchcheck.rex (CATCH and FINALLY; skipped on an ooRexx that does not know them)"
address system 'rexx "' || dir || sep || 'tests' || sep || 'catchcheck.rex"'
r2 = rc
if r1 = 0 & r2 = 0 then do
  say "selftest: PASS"
  return 0
end
say "selftest: FAIL (run_all rc" r1", catchcheck rc" r2")"
return 1

readVersion: procedure
  use strict arg dir
  s = .Stream~new(dir || .File~separator || "README.md")
  s~open("READ")
  line = s~lineIn
  s~close
  parse var line . "— v" ver .
  return "v" || ver
