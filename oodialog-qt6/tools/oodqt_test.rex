#!/usr/bin/env rexx
/* oodqt_test.rex -- run ooDialog test programs on the Qt6 renderer, offscreen.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14.
 *
 *   rexx tools/oodqt_test.rex [--shots DIR] [--tree DIR] test.rex [test.rex ...]
 *
 * Each program runs in a fresh directory under TMPDIR, as the page runs it in a
 * fresh /home/rexx: the program, its TEST.files/, and ooDialog.cls, oodWeb.cls and
 * ooShapes.cls.  --tree DIR adds a whole directory (upstream's samples), as the
 * browser harness's --tree does.  /home/rexx in the steps and the .expect means
 * that directory.
 *
 * The same tests as the browser harness (oodialog-wasm/tools/oodtest.py):
 * test.steps beside a test drives it (played by the renderer, OODQT_STEPS),
 * and its output must equal test.expect when that exists.  Each program runs
 * as a separate rexx process with a 90-second limit.
 * Needs on REXX_PATH: oodialog-qt6/src (js.cls), oodialog-wasm/dist
 * (ooDialog.cls, oodWeb.cls, ooShapes.cls), and the alchemy logging packages
 * (oorexx_logging_stream_target_v0.1/src) for the progress log; liboodqt.so
 * on LD_LIBRARY_PATH.  Exit 0 only if every test passes.
 */
parse arg argline
shots = ""
tree = ""
tests = .array~new
do while argline \= ""
  parse var argline word argline
  if word == "--shots" then parse var argline shots argline
  else if word == "--tree" then parse var argline tree argline
  else tests~append(word)
end
if tests~items == 0 then do
  .error~lineout("usage: rexx oodqt_test.rex [--shots DIR] test.rex [test.rex ...]")
  exit 2
end
runner = .OodQtTest~new
runner~useLogger(.ToolProgress~new("oodqt-test", runner, "RUN")~logger)
exit runner~run(tests, shots, tree)

::class OodQtTest
::method init
  expose log
  log = .LogNullLogger~instance
::method useLogger
  expose log
  use strict arg log

::method run
  expose log
  use strict arg tests, shots, tree = ""
  tmp = value("TMPDIR",, "ENVIRONMENT")
  if tmp == "" then tmp = "/tmp"
  passed = 0
  failed = .array~new
  do test over tests
    path = qualify(test)
    dir = filespec("location", path)
    name = filespec("name", path)
    base = name~left(name~lastPos(".") - 1)
    stepsFile = dir || base".steps"
    qtSteps = filespec("location", .context~package~name)"../tests/steps/"base".qt.steps"
    if sysFileExists(qtSteps) then stepsFile = qtSteps     -- the Qt dialect where the browser steps use JavaScript
    expectFile = dir || base".expect"
    out = tmp"/oodqt_"base"_"random(1, 99999)".out"
    err = out~left(out~length - 4)".err"
    env = "QT_QPA_PLATFORM=offscreen"
    if sysFileExists(stepsFile) then env = env 'OODQT_STEPS="'stepsFile'"'
    if shots \== "" then env = env 'OODQT_SHOTS="'shots'"'
    log~log(.Log~INFO, "running" test)
    -- every program runs in a fresh directory, as the page runs it in a fresh /home/rexx: the program, its
    -- TEST.files, the --tree, and ooDialog.cls, oodWeb.cls, ooShapes.cls beside it (oodWeb's srcDir is the
    -- directory of oodWeb.cls itself).  Nothing a test writes lands in the source tree.  /home/rexx in the
    -- steps and the .expect means this directory.
    work = tmp"/oodqt-"base"-"time("S")random(99999)
    address system 'mkdir -p "'work'" && cp "'path'" "'work'"/'
    if tree \== "" then address system 'cp -r "'tree'"/. "'work'"/'
    dist = filespec("location", SysSearchPath("REXX_PATH", "oodWeb.cls"))
    do f over .array~of("ooDialog.cls", "oodWeb.cls", "ooShapes.cls")
      address system 'cp "'dist || f'" "'work'"/'
    end
    if sysIsFileDirectory(dir || base".files") then address system 'cp -r "'dir || base'.files"/. "'work'"/'
    added = .WindowsNames~new(work)~apply           -- Windows names, as the page's oodfiles.js adds them
    if added > 0 then log~log(.Log~INFO, "  " added "Windows file name(s) added")
    path = work"/"name
    env = env 'OODQT_HOME="'work'"'
    command = 'cd "'work'" &&' env 'timeout -k 5 90 rexx "'path'" > "'out'" 2> "'err'"'
    address system command
    code = rc
    output = self~readFile(out)~changeStr(work, "/home/rexx")
    problems = self~readFile(err)
    verdict = "PASS"
    reason = ""
    -- as the browser harness: a program may return a value (2 when Close is IDCANCEL) once its output is checked;
    -- an error ends it with its own message, and a program without an .expect must end with 0
    rexxError = problems~caselessPos("Error ") > 0 & problems~caselessPos(" running ") > 0
    if code \= 0 & (\sysFileExists(expectFile) | rexxError) then do
      verdict = "FAIL"
      reason = "exit code" code
    end
    if verdict == "PASS" & problems~pos("STEP FAILED") > 0 then do
      verdict = "FAIL"
      reason = "a step failed"
    end
    if verdict == "PASS" & sysFileExists(expectFile) then
      if output~strip \== self~readFile(expectFile)~strip then do
        verdict = "FAIL"
        reason = "output differs from" base".expect"
      end
    if verdict == "PASS" then do
      passed += 1
      log~log(.Log~INFO, "PASS" test)
    end
    else do
      failed~append(test)
      log~log(.Log~WARN, "FAIL" test "-" reason)
      do line over self~interesting(problems)
        log~log(.Log~WARN, "   " line)
      end
      if output \== "" then log~log(.Log~WARN, "    output:" output~changeStr("0a"x, " | ")~left(300))
    end
    call sysFileDelete out
    call sysFileDelete err
    address system 'rm -r "'work'"'
  end
  log~log(.Log~INFO, passed "of" tests~items "passed")
  if failed~items > 0 then log~log(.Log~WARN, "failed:" failed~makeString("L", " "))
  if failed~items > 0 then return 1
  return 0

::method readFile private
  use strict arg path
  if \sysFileExists(path) then return ""
  s = .stream~new(path)
  text = s~charIn(1, s~chars)
  s~close
  return text~changeStr("0d0a"x, "0a"x)

::method interesting private        -- error lines worth showing, without Qt's platform chatter
  use strict arg text
  out = .array~new
  do line over text~makeArray("0a"x)
    if line~pos("XDG_RUNTIME_DIR") > 0 | line~pos("This plugin does not support") > 0 then iterate
    if line~pos("step") > 0 & line~pos(" ok: ") > 0 then iterate
    if line~strip == "" then iterate
    out~append(line~left(200))
    if out~items >= 8 then leave
  end
  return out

::requires "LogStreamTarget.cls"
::requires "WindowsNames.cls"
