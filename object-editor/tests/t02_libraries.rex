/* t02_libraries.rex -- library providers, install and goodies, without a browser.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
   usage: rexx t02_libraries.rex INDEX_FILE WORK_DIR
     INDEX_FILE  catalogue/alchemy.idx (read when the GitHub API refuses)
     WORK_DIR    an empty folder to install into
   Needs the network to raw.githubusercontent.com (the Alchemy files).      */
parse arg index work
if work == "" then do
  say "usage: rexx t02_libraries.rex INDEX_FILE WORK_DIR"
  return 2
end
fails = 0
checks = 0

-- 1. versions
call check "0.21 is later than 0.8", oxCompareVersions("0.21", "0.8") = 1
call check "a release is later than its dev builds", oxCompareVersions("0.1", "0.1-dev51") = 1
call check "dev51 is later than dev3", oxCompareVersions("0.1-dev51", "0.1-dev3") = 1
call check "a version is later than none", oxCompareVersions("0.7", "") = 1
call check "split name and version", oxSplitVersion("oorexx_physics_world_v0.1-dev51") == "oorexx_physics_world" || "09"x || "0.1-dev51"

-- 2. the shelf and its providers
shelf = .OxLibraryShelf~new(work"/lib")
shelf~register(.OxAlchemyProvider~new(index))
shelf~register(.OxLocalProvider~new("local", "Files on this machine", work"/local"))
call check "two providers registered", shelf~providerLines~makeArray("0a"x)~items = 2
call refuses "a second provider with the same id", "shelf~register(.OxLocalProvider~new('local', 'again', work'/x'))"
cat = shelf~catalogueLines("alchemy", "logging")
call check "Alchemy catalogue finds the logging framework", cat~pos("alchemy:oorexx_logging" || "09"x || "oorexx_logging" || "09"x || "0.7") > 0
say "  (the Alchemy catalogue was read from the" shelf~provider("alchemy")~source || ")"
call check "only the latest version of a package", shelf~catalogueLines("alchemy", "oorexx_maths")~pos("0.21") > 0 & shelf~catalogueLines("alchemy", "oorexx_maths")~pos("0.8" || "09"x) = 0
d = shelf~details("alchemy:oorexx_logging")
call check "details: description", d~pos("description" || "09"x || "ooRexx Logging Framework v0.7") > 0
call check "details: main file", d~pos("main" || "09"x || "packages/oorexx_logging_v0.7/src/LoggingCore.cls") > 0

-- 3. install: the file and what its ::requires reach
path = shelf~install("alchemy:oorexx_logging")
call check "installed flat under lib/alchemy", path == work"/lib/alchemy/LoggingCore.cls"
call check "its ::requires came with it", shelf~notesText~pos("installed MethodInterposition.cls") > 0
call check "the files are there", .stream~new(work"/lib/alchemy/MethodInterposition.cls")~query("exists") \== ""

-- 4. goodies, found by loading and examining
g = shelf~goodies(path)
call check "goodies: class Log", g~pos("class" || "09"x || "Log" || "09"x) > 0
call check "goodies: LogService~loggerFor", g~pos("member" || "09"x || "LogService" || "09"x || "loggerFor") > 0
call check "goodies: Log's constant WARN", g~pos("member" || "09"x || "Log" || "09"x || "WARN" || "09"x || "constant" || "09"x || "class") > 0

-- 5. use it: a ::requires in a file, and completion knows it
userFile = work"/App.cls"
w = .OxWorkspace~new(userFile, "::class App public" || "0a"x || "::method run" || "0a"x || "  return" || "0a"x)
req = shelf~requiresName(path, work)
call check "the ::requires name is relative", req == "lib/alchemy/LoggingCore.cls"
w~addRequires(req)
call check "the ::requires loads", w~requiresInfo~pos("LogService") > 0
c = w~complete("App", "INSTANCE", "  s = .LogSer")
call check ".LogSer completes to LogService", c~left(10) == "LogService"
c = w~complete("App", "INSTANCE", "  s = .LogService~new('app')" || "0a"x || "  s~loggerF")
call check "s~ after s = .LogService~new knows loggerFor", c~left(9) == "loggerFor"

-- 6. a local provider: a file handed in
lp = shelf~provider("local")
lp~addFile("greeting/Greeter.cls", "::class Greeter public" || "0a"x || "::method hello" || "0a"x || "  use strict arg who" || "0a"x || "  return 'Hello,' who" || "0a"x)
call check "local catalogue lists the handed-in library", shelf~catalogueLines("local")~pos("local:greeting") > 0
gp = shelf~install("local:greeting")
call check "local install", gp == work"/lib/local/Greeter.cls"
call check "local goodies", shelf~goodies(gp)~pos("member" || "09"x || "Greeter" || "09"x || "hello") > 0
call refuses "a path outside the folder", "lp~addFile('../escape.cls', 'x')"

-- 7. the installed files, for a run to carry
call check "installed list", shelf~installedLines~pos("LoggingCore.cls") > 0 & shelf~installedLines~pos("Greeter.cls") > 0

say "t02_libraries:" checks - fails "of" checks "checks passed"
if fails > 0 then return 1
return 0

check: procedure expose fails checks
  use arg ckLabel, ckOk
  checks = checks + 1
  if ckOk then say "  ok  " ckLabel
  else do
    say "  FAIL" ckLabel
    fails = fails + 1
  end
  return

refuses: procedure expose fails checks shelf lp work
  use arg rfLabel, rfCode
  checks = checks + 1
  signal on syntax name rfRefused
  interpret rfCode
  say "  FAIL not refused:" rfLabel
  fails = fails + 1
  return
rfRefused:
  -- the editor's own refusal: Error 93.900 with its message, not any error
  if condition("O")~at("CODE") \== "93.900" | condition("O")~at("ADDITIONAL")~isA(.Array) = .false then do
    say "  FAIL refused, but not by the editor:" rfLabel "--" condition("O")~at("MESSAGE")
    fails = fails + 1
    return
  end
  say "  ok   refuses" rfLabel "--" condition("O")~at("ADDITIONAL")[1]~left(100)
  return

::requires "LibraryProviders.cls"
