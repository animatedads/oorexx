#!/usr/bin/env rexx
/* oodrun.rex -- run an ooDialog program natively on Linux, with the kit's Qt6 renderer.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-23.
 *
 *   rexx tools/oodrun.rex [--here] [--offscreen] [--steps FILE] PROGRAM.rex
 *
 * The program runs on your desktop, in a fresh directory under TMPDIR (as the Designer page runs it
 * in a fresh /home/rexx); a program the Designer bound to its example database gets a fresh copy of
 * that database.  --here runs it in its own directory instead.  --offscreen runs it with no window
 * (for scripts; give --steps).  --steps FILE plays a steps file against it (the Qt player's dialect,
 * as in the kit's tests).  The exit code is the program's.
 */
parse arg argline
here = .false
platform = ""
steps = ""
program = ""
do while argline \= ""
  argline = argline~strip
  if argline~left(1) == '"' then parse var argline '"' word '"' argline
  else parse var argline word argline
  select
    when word == "--here" then here = .true
    when word == "--offscreen" then platform = "offscreen"
    when word == "--steps" then parse var argline steps argline
    otherwise program = word
  end
end
if program == "" then do
  .error~lineout("usage: rexx tools/oodrun.rex [--here] [--offscreen] [--steps FILE] PROGRAM.rex")
  exit 2
end
trace off                               -- failing commands are reported, not traced
kit = filespec("location", .context~package~name)~strip("T", "/")
kit = kit~left(kit~lastPos("/") - 1)
runner = .OodRun~new(kit)
progress = .ToolProgress~new("oodrun", runner, "RUN")
runner~useLogger(progress~logger)
log = progress~logger
if platform == "" & value("DISPLAY",, "ENVIRONMENT") == "" & value("WAYLAND_DISPLAY",, "ENVIRONMENT") == "" then do
  log~log(.Log~ERROR, "no desktop here (neither DISPLAY nor WAYLAND_DISPLAY is set): run it from a desktop terminal, or give --offscreen with --steps")
  exit 2
end
if steps \== "" then steps = qualify(steps)
outcome = runner~run(program, here, platform, steps)
do line over runner~interesting(outcome["STDERR"])
  .error~lineout(line)
end
if outcome["ERROR"] \== "" then log~log(.Log~ERROR, outcome["ERROR"])
log~log(.Log~INFO, "ended with" outcome["CODE"])
if \here then address system 'rm -rf "'runner~work'"'
exit outcome["CODE"]

::requires "OodRun.cls"
