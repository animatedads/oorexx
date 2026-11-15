/* run_all.rex -- the ooDialog Designer's ooRexx tests, each in a process of
   its own (t05 must start with nothing set up), in a scratch directory (t01
   and t03 write files).  A running log: one line as each test starts and
   one as it ends, with its result.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx run_all.rex PACKAGE_ROOT [test ...]
     REXX_PATH must hold PACKAGE_ROOT/src, PACKAGE_ROOT/tests and
     PACKAGE_ROOT/vendor (the Rexx Parser, for t02).  t06 to t09 need the
     plugins laid out with the estate files they use: with ESTATE_PACKAGES
     set (the estate's packages/), tools/plugins.rex lays them out in the
     scratch directory (if that fails, they fail); else the built
     site/plugins is used; else they are skipped, and say so.  For t07 to t09 this adds the plugin's paths (plugins/index.txt) to REXX_PATH, since ooRexx
     reads REXX_PATH only as it starts.
   Exit: the number of tests that failed.

   The log is written with SAY, not through oorexx_logging: its v0.7 targets
   are memory and queue targets, which hold events for later; none writes a
   line as it happens, and a run log that appears only at the end is the black
   box this log exists to avoid. */
parse arg root names
root = root~strip
if root == "" then do
  say "usage: rexx run_all.rex PACKAGE_ROOT [test ...]"
  return 99
end
root = .File~new(root)~absolutePath       -- the tests run in a scratch directory
tests = .array~new
if names~strip == "" then names = "t01_model t02_graph t03_nls t04_ui t05_fresh t06_plugins t07_assist t08_git t09_ssc t10_binding"
do t over names~space~makeArray(" ")
  tests~append(t)
end
scratch = SysTempFileName("/tmp/oodd-tests-?????")
call SysMkDir scratch
parse version v
say "run_all: ooRexx" v
say "run_all:" tests~items "tests, in" scratch
-- the plugins, with the estate files they use
plugins = ""
estate = value("ESTATE_PACKAGES", , "ENVIRONMENT")
if estate \== "" then do
  say "run_all: plugins laid out from" estate
  address system 'rexx "'root'/tools/plugins.rex" "'root'" "'estate'" "'scratch'/plugins" > "'scratch'/plugins.log" 2>&1'
  if rc = 0 then plugins = scratch"/plugins"
  else do
    say "run_all: tools/plugins.rex failed ("rc"): see" scratch"/plugins.log"
    plugins = "FAILED"            -- asked for, and not there: t06 to t09 fail
  end
end
else if SysFileExists(root"/site/plugins/index.txt") then plugins = root"/site/plugins"
if plugins == "" then say "run_all: no plugins laid out (ESTATE_PACKAGES, or tools/build.rex): t06 to t09 are skipped"
-- what each needs as arguments
needs = .directory~new
needs["T04_UI"] = root"/site"
needs["T06_PLUGINS"] = plugins
needs["T07_ASSIST"] = plugins
needs["T08_GIT"] = plugins
needs["T09_SSC"] = plugins
-- REXX_PATH entries a test needs beyond the caller's
paths = .directory~new
if plugins \== "" & plugins \== "FAILED" then do
  paths["T07_ASSIST"] = pluginPaths(root, plugins, "assist")
  paths["T08_GIT"] = pluginPaths(root, plugins, "git")
  paths["T09_SSC"] = pluginPaths(root, plugins, "ssc")
end
skipped = .array~new
failed = .array~new
do t over tests
  file = root"/tests/"t".rex"
  if \SysFileExists(file) then do
    say "run_all: MISSING" t
    failed~append(t)
    iterate
  end
  if needs~hasIndex(t~upper) & needs[t~upper] == "FAILED" then do
    say "run_all: FAIL" t "-- the plugins could not be laid out"
    failed~append(t)
    iterate
  end
  if needs~hasIndex(t~upper) & needs[t~upper] == "" then do
    say "run_all: SKIP" t "(no plugins laid out)"
    skipped~append(t)
    iterate
  end
  say "run_all: RUN" t
  started = time("E")
  args = ""
  if needs~hasIndex(t~upper) then args = '"'needs[t~upper]'"'
  env = ""
  if paths~hasIndex(t~upper) then env = 'REXX_PATH="'paths[t~upper]':$REXX_PATH"'
  address system 'cd "'scratch'" &&' env 'rexx "'file'"' args
  code = rc
  took = format(time("E") - started, , 2)
  if code = 0 then say "run_all: PASS" t "("took"s)"
  else do
    say "run_all: FAIL" t "-- exit" code "("took"s)"
    failed~append(t)
  end
end
if skipped~items > 0 then say "run_all: skipped:" skipped~makeString("L", " ")
say "run_all:" tests~items - failed~items - skipped~items "of" tests~items "tests passed" || -
  copies(";  failed: " || failed~makeString("L", " "), failed~items > 0)
return failed~items

-- a plugin's paths = entries in plugins/index.txt, as REXX_PATH entries
-- under the laid-out plugins
pluginPaths: procedure
  use arg ppRoot, ppPlugins, ppId
  ppIn = .stream~new(ppRoot"/plugins/index.txt")
  ppCur = ""
  ppOut = ""
  do ppLine over ppIn~arrayIn
    ppS = ppLine~strip
    if ppS~word(1) == "plugin" then ppCur = ppS~word(2)
    if ppCur \== ppId then iterate
    parse var ppS ppKey "=" ppValue
    if ppKey~strip \== "paths" then iterate
    do ppP over ppValue~space~makeArray(" ")
      if ppOut \== "" then ppOut = ppOut":"
      ppOut = ppOut || ppPlugins"/"ppP
    end
  end
  ppIn~close
  return ppOut
