#!/usr/bin/env rexx
/* kitcheck.rex -- check every item the ooDialog Linux kit needs, before using it.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-23.
 *
 *   rexx tools/kitcheck.rex
 *
 * Each check says PASS, WARN (the kit works without it, with less) or FAIL (fix it first), and what
 * to do.  Exit 0 when nothing failed.
 */
trace off                               -- a check that fails is reported below, not traced
kit = filespec("location", .context~package~name)~strip("T", "/")
kit = kit~left(kit~lastPos("/") - 1)
runner = .OodRun~new(kit)
progress = .ToolProgress~new("kitcheck", runner, "RUN")
log = progress~logger
fails = 0
warns = 0
log~log(.Log~INFO, "kit" kit)

-- 1. ooRexx 5
parse version v
parse var v "REXX-ooRexx_" major "." minor "." . "(" .
if datatype(major, "W") & major >= 5 then call pass "ooRexx:" v
else call fail "ooRexx:" v, "the kit needs ooRexx 5 (https://sourceforge.net/projects/oorexx/files/oorexx/)"

-- 2. CATCH and FINALLY (the Designer's Catcher test, and a guard in programs it writes)
address system 'rexx "'kit'/tools/catchprobe.rex" > /dev/null 2>&1'
if rc == 0 then call pass "ooRexx runs CATCH and FINALLY"
else call warn "this ooRexx does not run CATCH and FINALLY", "the Designer's Catcher test will fail; ooRexx trunk from r13591 (or 5.3 builds from GitHub after 2026-11-15) has them"

-- 3. the renderer library and the Qt libraries it needs
lib = kit"/lib/liboodqt.so"
if \sysFileExists(lib) then call fail "the renderer library" lib "is missing", "rexx tools/buildlib.rex"
else do
  out = kit"/.kitcheck.ldd"
  address system 'ldd "'lib'" > "'out'" 2>&1'
  text = runner~readFile(out)
  call sysFileDelete out
  missing = .array~new
  bad = ""
  do line over text~makeArray("0a"x)
    if line~pos("not found") > 0 then missing~append(line~word(1))
    if line~pos("version") > 0 & line~pos("not found") > 0 then bad = bad line~strip
  end
  if missing~items == 0 then call pass "the renderer library loads: Qt 6 Widgets, PrintSupport and the C++ library are found"
  else call fail "the renderer library cannot load:" missing~makeString("L", " "), -
    "install Qt 6 (Debian/Ubuntu: sudo apt install libqt6widgets6 libqt6printsupport6;" -
    "Fedora: sudo dnf install qt6-qtbase-gui; openSUSE: sudo zypper install libQt6Widgets6 libQt6PrintSupport6)," -
    "or build the library for this system: rexx tools/buildlib.rex"
end

-- 4. a desktop to show windows on
if value("DISPLAY",, "ENVIRONMENT") \== "" | value("WAYLAND_DISPLAY",, "ENVIRONMENT") \== "" then call pass "a desktop: DISPLAY="value("DISPLAY",, "ENVIRONMENT") "WAYLAND_DISPLAY="value("WAYLAND_DISPLAY",, "ENVIRONMENT")
else call warn "no desktop in this terminal (DISPLAY and WAYLAND_DISPLAY are empty)", "the tests run offscreen; to see dialogs, run from a terminal on the desktop"

-- 5. a dialog, end to end, offscreen: the renderer, the classes, the steps player
if fails == 0 then do
  outcome = runner~run(kit"/tests/kit/Hello.rex", .false, "offscreen", kit"/tests/kit/Hello.steps", 30)
  address system 'rm -rf "'runner~work'"'
  if outcome["CODE"] == 1 & outcome["ERROR"] == "" then call pass "a dialog opened, was clicked and closed (offscreen)"
  else call fail "the test dialog did not run: exit" outcome["CODE"] outcome["ERROR"] runner~interesting(outcome["STDERR"])~makeString("L", " | "), -
    "send this output to Claude"
end

-- 6. Node.js for the Designer page
address system 'node --version > "'kit'/.kitcheck.node" 2>&1'
nodeRc = rc
nv = runner~readFile(kit"/.kitcheck.node")~strip
call sysFileDelete kit"/.kitcheck.node"
if nodeRc \= 0 then nv = "none"
parse var nv "v" nodeMajor "."
if nodeRc == 0 & datatype(nodeMajor, "W") & nodeMajor >= 18 then call pass "Node.js" nv "(serves the Designer page)"
else call warn "no Node.js 18 or later (found:" nv")", "the Designer page needs it: install Node.js 18+, then: node designer/serve.mjs"

-- 7. what the standby printer uses (optional)
do tool over .array~of("lp", "xdg-open", "pdftoppm")
  address system 'command -v' tool '> /dev/null 2>&1'
  if rc == 0 then call pass tool "found (the standby printer's" word("Print Open PDF-pages", wordpos(tool, "lp xdg-open pdftoppm"))")"
  else call warn tool "not found", "only the standby printer's" word("Print Open PDF-pages", wordpos(tool, "lp xdg-open pdftoppm")) "needs it"
end

log~log(.Log~INFO, "checked:" fails "failed," warns "warnings")
if fails > 0 then exit 1
exit 0

pass:
  use arg what
  log~log(.Log~INFO, "PASS" what)
  return
warn:
  use arg what, todo
  warns += 1
  log~log(.Log~WARN, "WARN" what)
  log~log(.Log~WARN, "     " todo)
  return
fail:
  use arg what, todo
  fails += 1
  log~log(.Log~ERROR, "FAIL" what)
  log~log(.Log~ERROR, "     do:" todo)
  return

::requires "OodRun.cls"
