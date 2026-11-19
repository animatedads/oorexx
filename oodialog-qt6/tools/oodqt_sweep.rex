/* oodqt_sweep.rex -- start every ooDialog program under a directory on the Qt6 renderer and report which show.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-15.
 *
 *   rexx tools/oodqt_sweep.rex --samples DIR [--platform offscreen|xcb] [--shots DIR] [--seconds N] [--report FILE]
 *                                [--only a.rex,dir/b.rex]   (only these, relative to DIR)
 *
 * Every .rex file under DIR that names ooDialog is started in a fresh directory holding its own directory's
 * files (as oodqt_test.rex stages a test), with a three-step script: wait for a dialog, wait 600 ms, take a
 * screenshot.  Nothing is clicked; the program is stopped after N seconds (8).  Verdicts:
 *   SHOWN   a dialog came up and no Rexx error was raised
 *   ERROR   a Rexx error was raised (the first one is reported)
 *   NOSHOW  no dialog and no error: a program that needs arguments, or one that ended at once
 *   MODULE  not started: another file under DIR requires or calls it
 * This is a coverage sweep, not a test: a SHOWN program may still draw wrongly.  The report (Markdown) lists
 * every program; the ERROR lines are where the renderer, oodWeb.cls or the Linux interpreter fall short.
 */
parse arg argline
opts = .stringtable~new
opts["PLATFORM"] = "offscreen"; opts["SECONDS"] = 8; opts["SHOTS"] = ""; opts["REPORT"] = ""
do while argline \= ""
  parse var argline word value argline
  select
    when word == "--samples" then opts["SAMPLES"] = value
    when word == "--platform" then opts["PLATFORM"] = value
    when word == "--shots" then opts["SHOTS"] = value
    when word == "--seconds" then opts["SECONDS"] = value
    when word == "--report" then opts["REPORT"] = value
    when word == "--only" then opts["ONLY"] = value~changeStr(",", " ")
    otherwise do
      .error~lineout("oodqt_sweep: unknown argument" word)
      exit 2
    end
  end
end
if \opts~hasIndex("SAMPLES") then do
  .error~lineout("usage: rexx oodqt_sweep.rex --samples DIR [--platform offscreen|xcb] [--shots DIR] [--seconds N] [--report FILE]")
  exit 2
end
root = opts["SAMPLES"]~strip("T", "/")
call SysFileTree root"/*.rex", "f.", "FSO"
programs = .array~new
do i = 1 to f.0
  text = charin(f.i, 1, chars(f.i))
  call stream f.i, "c", "close"
  if text~caselessPos("ooDialog") = 0 then iterate
  if opts~hasIndex("ONLY") then if opts["ONLY"]~wordPos(f.i~substr(root~length + 2)) = 0 then iterate
  programs~append(f.i)
end
programs = programs~sort

-- a module another file requires or calls is not a program of its own: listed as MODULE, not started
wn = .WindowsNames~new(root)
used = .set~new
do i = 1 to f.0
  do n over wn~names(f.i)
    last = n~changeStr("\", "/")
    last = last~substr(last~lastPos("/") + 1)~lower
    used~put(last); used~put(last".rex"); used~put(last".cls")
  end
end
modules = .array~new
mains = .array~new
do p over programs
  if used~hasIndex(filespec("name", p)~lower) then modules~append(p); else mains~append(p)
end
programs = mains

runner = .OodQtTest~new
log = .ToolProgress~new("oodqt-sweep", runner, "SWEEP")~logger
runner~useLogger(log)
log~log(.Log~INFO, programs~items "programs under" root)
results = runner~sweep(programs, opts["SHOTS"], opts["PLATFORM"], opts["SECONDS"])

count = .stringtable~new
count["SHOWN"] = 0; count["ERROR"] = 0; count["NOSHOW"] = 0
count["MODULE"] = modules~items
lines = .array~new
lines~append("# ooDialog samples on the Qt6 renderer: sweep of" date("S") time())
lines~append("")
lines~append("Platform:" opts["PLATFORM"]". Each program started, nothing clicked, stopped after" opts["SECONDS"] "s.")
lines~append("")
lines~append("| Program | Verdict | First Rexx error |")
lines~append("|---|---|---|")
do r over results
  count[r[2]] += 1
  lines~append("|" r[1]~substr(root~length + 2) "|" r[2] "|" r[3]~changeStr("|", "/") "|")
end
do m over modules
  lines~append("|" m~substr(root~length + 2) "| MODULE | required or called by another file; not started |")
end
summary = count["SHOWN"] "shown," count["ERROR"] "with a Rexx error," count["NOSHOW"] "no dialog, of" results~items "programs started;" modules~items "modules not started"
lines~insert("**" || summary || "**", 2)
lines~insert("", 3)
log~log(.Log~INFO, summary)
if opts["REPORT"] \== "" then do
  call sysFileDelete opts["REPORT"]
  do l over lines; call lineout opts["REPORT"], l; end
  call stream opts["REPORT"], "c", "close"
  log~log(.Log~INFO, "report:" opts["REPORT"])
end
exit 0

::requires "OodQtTest.cls"
::requires "LogStreamTarget.cls"
::requires "WindowsNames.cls"
