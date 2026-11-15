/* OodQtTest.cls -- runs ooDialog test programs on the Qt6 renderer; used by oodqt_test.rex and oodqt_suite.rex.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).  See oodqt_test.rex for what a run does. */
::class OodQtTest public
::attribute passed get       -- the last run's count of passing tests
::attribute failed get       -- the last run's failing tests, an array
::method init
  expose log
  log = .LogNullLogger~instance
::method useLogger
  expose log
  use strict arg log

::method run
  expose log passed failed
  use strict arg tests, shots, tree = "", platform = "offscreen"
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
    env = "QT_QPA_PLATFORM="platform
    if sysFileExists(stepsFile) then env = env 'OODQT_STEPS="'stepsFile'"'
    if shots \== "" then env = env 'OODQT_SHOTS="'shots'"'
    log~log(.Log~INFO, "running" test)
    -- every program runs in a fresh directory, as the page runs it in a fresh /home/rexx: the program, its
    -- TEST.files, the --tree, and ooDialog.cls, oodWeb.cls, ooShapes.cls beside it (oodWeb's srcDir is the
    -- directory of oodWeb.cls itself).  Nothing a test writes lands in the source tree.  /home/rexx in the
    -- steps and the .expect means this directory.
    work = self~stage(path, tree, tmp)
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

::method stage private                      -- a fresh directory with the program, its TEST.files, the tree, the classes
  expose log
  use strict arg path, tree, tmp
  dir = filespec("location", path)
  name = filespec("name", path)
  base = name~left(name~lastPos(".") - 1)
  work = tmp"/oodqt-"base"-"time("S")random(99999)
  address system 'mkdir -p "'work'"'
  if tree \== "" then address system 'cp -r "'tree'"/. "'work'"/'
  address system 'cp "'path'" "'work'"/'
  dist = filespec("location", SysSearchPath("REXX_PATH", "oodWeb.cls"))
  do f over .array~of("ooDialog.cls", "oodWeb.cls", "ooShapes.cls")
    address system 'cp "'dist || f'" "'work'"/'
  end
  if sysIsFileDirectory(dir || base".files") then address system 'cp -r "'dir || base'.files"/. "'work'"/'
  added = .WindowsNames~new(work)~apply           -- Windows names, as the page's oodfiles.js adds them
  if added > 0 then log~log(.Log~INFO, "  " added "Windows file name(s) added")
  return work

::method sweep                              -- start each program, see whether a dialog shows; nothing is clicked
  expose log
  use strict arg programs, shots, platform = "offscreen", seconds = 8
  tmp = value("TMPDIR",, "ENVIRONMENT")
  if tmp == "" then tmp = "/tmp"
  results = .array~new                      -- each: program, SHOWN | ERROR | NOSHOW, detail
  steps = tmp"/oodqt-sweep-"random(99999)".steps"
  do p over programs
    name = filespec("name", p)
    base = name~left(name~lastPos(".") - 1)
    -- the program's own directory is its tree: upstream samples find their files beside them.  A program
    -- whose header says it "must be run from the parent folder" (userGuide exercises) is run so: the parent
    -- directory is the tree, the working directory, and the program stays in its own folder below it.
    own = filespec("location", p)~strip("T", "/")
    text = self~readFile(p)
    runAs = name
    if text~left(8000)~caselessPos("run from the parent folder") > 0 then do     -- in the header comment
      parent = own~left(own~lastPos("/") - 1)
      work = self~stage(p, parent, tmp)
      runAs = own~substr(parent~length + 2)"/"name
    end
    else work = self~stage(p, own, tmp)
    call sysFileDelete steps
    call lineout steps, "wait .ood-dlg"
    call lineout steps, "sleep 600"
    call lineout steps, "shot sweep_"base
    call stream steps, "c", "close"
    err = work"/.sweep.err"
    env = "QT_QPA_PLATFORM="platform 'OODQT_STEPS="'steps'"' 'OODQT_HOME="'work'"'
    if shots \== "" then env = env 'OODQT_SHOTS="'shots'"'
    log~log(.Log~INFO, "starting" p)
    address system 'cd "'work'" &&' env 'timeout -k 2' seconds 'rexx "'work"/"runAs'" > /dev/null 2> "'err'"'
    problems = self~readFile(err)
    errorLine = ""
    do line over problems~makeArray("0a"x)
      -- Error 4 (HALT) is the sweep stopping the program after its seconds, not the program failing
      if line~word(1) == "Error" & line~word(2) \== "4" & line~pos(" running ") > 0 then do
        errorLine = line~strip
        leave
      end
    end
    shownLine = problems~pos("step 3 ok: shot") > 0 | problems~pos("step 2 ok: sleep") > 0
    if errorLine \== "" then verdict = "ERROR"
    else if shownLine then verdict = "SHOWN"
    else verdict = "NOSHOW"
    detail = errorLine
    if detail \== "" then do                -- the message line after it says what went wrong
      at = problems~pos(errorLine) + errorLine~length
      detail = detail problems~substr(at)~strip("L", "0a"x)~makeArray("0a"x)[1]~strip
    end
    log~log(.Log~INFO, "  " verdict detail)
    results~append(.array~of(p, verdict, detail))
    address system 'rm -r "'work'"'
  end
  call sysFileDelete steps
  return results

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
