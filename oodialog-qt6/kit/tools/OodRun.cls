/* OodRun.cls -- runs an ooDialog program natively on Linux with the kit's Qt6 renderer.
 * Used by oodrun.rex, kitcheck.rex and kittest.rex.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-23.
 *
 * A program runs as its own rexx process, with the kit on its paths:
 *   LD_LIBRARY_PATH  KIT/lib                  (liboodqt.so, the renderer)
 *   REXX_PATH        KIT/rexx                 (ooDialog.cls, oodWeb.cls, ooShapes.cls, js.cls)
 *                    KIT/designer/data/lib    (the object layer a bound design requires)
 *                    KIT/packages/.../src     (the logging and resource-reader packages)
 * By default it runs in a fresh directory under TMPDIR, as the Designer page runs it in a fresh
 * /home/rexx: the program, and for a bound design (one that requires MappedObjects.cls) a fresh copy
 * of the example database, ent/.  So every run starts from the example data, as in the page.
 * With here = .true it runs in its own directory instead, for a program that needs files beside it.
 */
::class OodRun public
::attribute kit get
::attribute work get                   -- the directory of the last run
::method init
  expose kit log
  use strict arg kit
  log = .LogNullLogger~instance
::method useLogger
  expose log
  use strict arg log

::method rexxPath                       -- the kit's part of REXX_PATH, then the caller's
  expose kit
  p = kit"/rexx:"kit"/designer/data/lib:"kit"/packages/oorexx_win_resources_v0.1/src:" ||,
      kit"/packages/oorexx_logging_stream_target_v0.1/src:"kit"/packages/oorexx_logging_v0.7/src:"kit"/tools"
  old = value("REXX_PATH",, "ENVIRONMENT")
  if old \== "" then p = p":"old
  return p

::method environment                    -- the variables a program's process needs, as a shell prefix
  expose kit
  use strict arg platform = "", steps = "", home = ""
  ld = value("LD_LIBRARY_PATH",, "ENVIRONMENT")
  libs = kit"/lib"
  if ld \== "" then libs = libs":"ld
  env = 'LD_LIBRARY_PATH="'libs'" REXX_PATH="'self~rexxPath'"'
  if platform \== "" then env = env "QT_QPA_PLATFORM="platform
  if steps \== "" then env = env 'OODQT_STEPS="'steps'"'
  if home \== "" then env = env 'OODQT_HOME="'home'" OODQT_DELIVER="'home'/.deliver"'
  return env

/* run: answers a directory with code (the program's exit code), error (its first Rexx error line and
 * the message after it, or ""), shown (did a "wait .ood-dlg" step pass), stderr (all of it). */
::method run
  expose kit log work
  use strict arg program, here = .false, platform = "", steps = "", seconds = 0
  path = qualify(program)
  if \sysFileExists(path) then raise syntax 93.900 array("oodrun: no such program:" program)
  name = filespec("name", path)
  base = name~left(name~lastPos(".") - 1)
  text = self~readFile(path)
  bound = text~caselessPos('"MappedObjects.cls"') > 0
  if here then work = filespec("location", path)~strip("T", "/")
  else do
    tmp = value("TMPDIR",, "ENVIRONMENT")
    if tmp == "" then tmp = "/tmp"
    work = tmp"/oodrun-"base"-"random(1, 99999)
    address system 'mkdir -p "'work'" && cp "'path'" "'work'/"'
    if bound then address system 'cp -r "'kit'/designer/data/ent" "'work'/ent"'
  end
  log~log(.Log~INFO, "program" path)
  note = ""
  if bound then note = " (a bound design: with a fresh copy of the example database, ent/)"
  log~log(.Log~INFO, "runs in" work || note)
  err = work"/.oodrun-"random(1, 99999)".err"
  limit = ""
  if seconds > 0 then limit = "timeout -k 2" seconds
  address system 'cd "'work'" &&' self~environment(platform, steps, work) limit 'rexx "'work"/"name'" 2> "'err'"'
  code = rc
  problems = self~readFile(err)
  call sysFileDelete err
  answer = .directory~new
  answer["CODE"] = code
  answer["STDERR"] = problems
  answer["SHOWN"] = problems~pos("ok: wait .ood-dlg") > 0      -- the steps' "wait .ood-dlg" passed: a dialog showed
  errorLine = ""
  do line over problems~makeArray("0a"x)
    -- Error 4 (HALT) is a time limit stopping the program, not the program failing
    if line~word(1) == "Error" & line~word(2) \== "4" & line~pos(" running ") > 0 then do
      errorLine = line~strip
      at = problems~pos(line) + line~length
      errorLine = errorLine problems~substr(at)~strip("L", "0a"x)~makeArray("0a"x)[1]~strip
      leave
    end
  end
  answer["ERROR"] = errorLine
  return answer

::method readFile
  use strict arg path
  if \sysFileExists(path) then return ""
  s = .stream~new(path)
  text = s~charIn(1, s~chars)
  s~close
  return text~changeStr("0d0a"x, "0a"x)

::method interesting                   -- error lines worth showing, without Qt's platform chatter and the player's steps
  use strict arg text
  out = .array~new
  do line over text~makeArray("0a"x)
    if line~pos("XDG_RUNTIME_DIR") > 0 | line~pos("This plugin does not support") > 0 then iterate
    if line~pos("step") > 0 & line~pos(" ok: ") > 0 then iterate
    if line~strip == "" then iterate
    out~append(line)
  end
  return out

::requires "../packages/oorexx_logging_stream_target_v0.1/src/LogStreamTarget.cls"
