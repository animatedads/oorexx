/* libindex.rex -- write a library index for a provider from a local clone.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx tools/libindex.rex CLONE_DIR PREFIX PROVIDER_ID OUT_FILE
     e.g. rexx tools/libindex.rex ~/alchemy packages/ alchemy catalogue/alchemy.idx
   One "library ..." line per library: the latest version of each package,
   its .cls files (tests and examples left out), its main file and the first
   heading of its README.  A GitHub provider reads it when the GitHub API
   refuses.  Progress is written as it goes.                                */
parse arg clone prefix pid outFile
if outFile == "" then do
  say "usage: rexx tools/libindex.rex CLONE_DIR PREFIX PROVIDER_ID OUT_FILE"
  return 1
end
if prefix == '""' then prefix = ""
p = .OxLocalProvider~new(pid, pid, clone, prefix)
say "libindex: reading" clone"/"prefix
libs = p~catalogue
out = .array~new
out~append("-- library index for provider" pid "made" date("S") time() "by libindex.rex from" clone)
n = 0
do lib over libs
  lib~description = p~describe(lib)
  out~append(lib~asLine)
  n = n + 1
  if n // 25 = 0 then say "libindex:" n "of" libs~items
end
s = .stream~new(outFile)
s~open("write replace")
s~arrayOut(out)
s~close
say "libindex:" libs~items "libraries written to" outFile
return 0
::requires "LibraryProviders.cls"
