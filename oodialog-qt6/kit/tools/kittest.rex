#!/usr/bin/env rexx
/* kittest.rex -- qualify the ooDialog Linux kit on this computer: the renderer, the ooDialog Designer's
 * tests, and the Designer's examples, each run natively.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-23.
 *
 *   rexx tools/kittest.rex [--desktop] [--shots DIR]
 *
 * Offscreen by default (no windows); --desktop runs every program on your desktop through X (xcb;
 * XWayland on a Wayland desktop), where you see each dialog open, worked by its steps, and close.
 * Groups:
 *   kit           tests/kit/Hello: a dialog opened, clicked and closed
 *   designer-qt   the Designer's tests/qt: NewKinds, Resizer, Catcher, written by its generator
 *   designer-gen  the Designer's tests/gen: Calculator, Contacts, Gadgets
 *   examples      the six examples in the Designer page (designer/examples): each must show its dialog
 *                 with no Rexx error; nothing is clicked
 * The first three play .steps and compare the output with .expect, as the renderer's own suite does.
 * Exit 0 when everything passes.
 */
parse arg argline
platform = "offscreen"
shots = ""
do while argline \= ""
  parse var argline word argline
  if word == "--desktop" then platform = "xcb"
  else if word == "--shots" then parse var argline shots argline
  else do
    .error~lineout("usage: rexx tools/kittest.rex [--desktop] [--shots DIR]")
    exit 2
  end
end
trace off                               -- failing commands are reported, not traced
kit = filespec("location", .context~package~name)~strip("T", "/")
kit = kit~left(kit~lastPos("/") - 1)
runner = .OodRun~new(kit)
tester = .OodQtTest~new
progress = .ToolProgress~new("kittest", tester, "RUN")
log = progress~logger
tester~useLogger(log)
runner~useLogger(log)
if platform == "xcb" & value("DISPLAY",, "ENVIRONMENT") == "" then do
  log~log(.Log~ERROR, "--desktop needs a desktop: DISPLAY is empty in this terminal")
  exit 2
end
-- every program this starts finds the kit: the renderer library and the classes
ld = value("LD_LIBRARY_PATH",, "ENVIRONMENT")
libs = kit"/lib"
if ld \== "" then libs = libs":"ld
call value "LD_LIBRARY_PATH", libs, "ENVIRONMENT"
call value "REXX_PATH", runner~rexxPath, "ENVIRONMENT"
if shots \== "" then do
  address system 'mkdir -p "'shots'"'
  shots = qualify(shots)
  call value "OODQT_SHOTS", shots, "ENVIRONMENT"     -- the player writes its pictures there
end
log~log(.Log~INFO, "kit" kit", on" platform)

address system 'rexx "'kit'/tools/catchprobe.rex" > /dev/null 2>&1'
if rc \= 0 then log~log(.Log~WARN, "this ooRexx does not run CATCH and FINALLY: designer-qt/Catcher will fail (kitcheck.rex says which ooRexx has them)")
results = .array~new
do group over .array~of("kit", "designer-qt", "designer-gen")
  tests = .array~new
  call SysFileTree kit"/tests/"group"/*.rex", "found", "FO"
  do i = 1 to found.0
    tests~append(found.i)
  end
  tests = tests~sort
  log~log(.Log~INFO, "group" group":" tests~items "programs")
  tester~run(tests, shots, "", platform)
  results~append(.array~of(group, tester~passed, tests~items, tester~failed~makeString("L", ", ")))
end

-- the examples: shown, with no Rexx error
call SysFileTree kit"/designer/examples/*.rex", "found", "FO"
examples = .array~new
do i = 1 to found.0
  examples~append(found.i)
end
examples = examples~sort
log~log(.Log~INFO, "group examples:" examples~items "programs, each must show its dialog")
shown = 0
failed = .array~new
tmp = value("TMPDIR",, "ENVIRONMENT")
if tmp == "" then tmp = "/tmp"
do p over examples
  name = filespec("name", p)
  steps = kit"/tests/kit/shown.steps"
  if shots \== "" then do                  -- and a picture of it, as shots/example_NAME.png
    steps = tmp"/kittest-"random(1, 99999)".steps"
    call lineout steps, "wait .ood-dlg"
    call lineout steps, "sleep 1500"
    call lineout steps, "shot example_"name~left(name~lastPos(".") - 1)
    call lineout steps, "sleep 300"
    call stream steps, "c", "close"
  end
  r = runner~run(p, .false, platform, steps, 12)
  if shots \== "" then call sysFileDelete steps
  address system 'rm -rf "'runner~work'"'
  if r["SHOWN"] & r["ERROR"] == "" then do
    shown += 1
    log~log(.Log~INFO, "  PASS" name)
  end
  else do
    failed~append(name)
    why = r["ERROR"]
    if why == "" then why = "no dialog showed:" runner~interesting(r["STDERR"])~makeString("L", " | ")
    log~log(.Log~WARN, "  FAIL" name "-" why)
  end
end
results~append(.array~of("examples", shown, examples~items, failed~makeString("L", ", ")))

total = 0
all = 0
log~log(.Log~INFO, "summary on" platform":")
do r over results
  line = "  " r[1]":" r[2] "of" r[3]
  if r[4] \== "" then line = line "  (failed:" r[4]")"
  log~log(.Log~INFO, line)
  total += r[2]
  all += r[3]
end
log~log(.Log~INFO, "  all:" total "of" all "passed")
if total == all then exit 0
exit 1

::requires "OodQtTest.cls"
::requires "OodRun.cls"
