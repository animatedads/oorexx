/* mkpkg.rex -- make the next Autobuild package of the ooDialog Designer
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
   usage: rexx tools/mkpkg.rex PREVIOUS_PACKAGE_DIR NEW_VERSION [WORK_DIR]

   PREVIOUS_PACKAGE_DIR is the last package (…/oorexx_oodialog_designer_vX.Y);
   NEW_VERSION is X.Z.  WORK_DIR (default: this tool's folder's parent) is the
   designer's work folder.  The new package is made next to the previous one:
     1. every file of the previous package is copied;
     2. a file the work folder also has (not vendor/, shots/, integration.json)
        is taken from the work folder when it differs;
     3. a file of the work folder's src/, plugins/, tests/, tools/, data/ that
        the package does not have is added (v0.16 lost tools/pkgcheck.rex at
        this step when it was done by hand);
     4. integration.json's package version and publish path are set;
     5. tools/pkgcheck.rex is run on it.
   Each step says what it did.  A screenshot is not taken from the work
   folder (they change on every run): copy a new one by hand and say so. */
parse arg prev ver work
prev = prev~strip; ver = ver~strip; work = work~strip
if prev == "" | ver == "" then do
  say "usage: rexx tools/mkpkg.rex PREVIOUS_PACKAGE_DIR NEW_VERSION [WORK_DIR]"
  return 2
end
sep = .File~separator
if work == "" then do
  parse source . . me
  work = .File~new(me)~parentFile~parent
end
if prev~right(1) == sep then prev = prev~left(prev~length - 1)
base = .File~new(prev)~parent
new = base || sep || "oorexx_oodialog_designer_v" || ver
if .File~new(new)~exists then do
  say "mkpkg: STOP" new "exists: a version is never made twice"
  return 1
end

-- 1. the previous package
files = treeOf(prev)
do f over files
  call copyFile prev || sep || f, new || sep || f
end
say "mkpkg: 1. copied" files~items "files from" prev

-- 2. what changed in the work folder
n = 0
do f over files
  if f~left(7) == "vendor" || sep | f~left(6) == "shots" || sep | f == "integration.json" then iterate
  w = work || sep || f
  if \.File~new(w)~exists then do
    say "mkpkg:    not in the work folder (kept from the package):" f
    iterate
  end
  if readAll(w) == readAll(new || sep || f) then iterate
  call copyFile w, new || sep || f
  say "mkpkg:    updated" f
  n += 1
end
say "mkpkg: 2. updated" n "files"

-- 3. new files of the source folders
n = 0
have = .set~new~union(files)
do d over .array~of("src", "plugins", "tests", "tools", "data")
  if \.File~new(work || sep || d)~isDirectory then iterate
  do f over treeOf(work || sep || d)
    rel = d || sep || f
    if have~hasIndex(rel) then iterate
    if rel~right(9) == "_fail.png" then iterate
    call copyFile work || sep || rel, new || sep || rel
    say "mkpkg:    added" rel
    n += 1
  end
end
say "mkpkg: 3. added" n "files"

-- 4. integration.json: version and publish path
p = new || sep || "integration.json"
json = readAll(p)
parse var json head '"version"' ':' '"' old '"' rest
json = head || '"version": "' || ver || '"' || rest
name = "oorexx_oodialog_designer_v" || ver
parse var json head '"path"' ':' '"' oldPath '"' rest
json = head || '"path": "packages/' || name || '"' || rest
call writeAll p, json
say "mkpkg: 4. integration.json: version" old "->" ver", publish path" oldPath "-> packages/" || name

-- 5. the check
say "mkpkg: 5. pkgcheck"
call (work || sep || "tools" || sep || "pkgcheck.rex") new
return result

-- the files under dir, as paths relative to it
treeOf: procedure
  use strict arg dir
  sep = .File~separator
  out = .array~new
  call SysFileTree dir || sep || "*", "t.", "FSO"
  do i = 1 to t.0
    out~append(t.i~substr(dir~length + 2))
  end
  return out

copyFile: procedure
  use strict arg from, to
  call SysMkDir .File~new(to)~parent        -- one level; deeper below
  if \.File~new(to)~parentFile~isDirectory then .File~new(to)~parentFile~makeDirs
  call writeAll to, readAll(from)
  return

readAll: procedure
  use strict arg path
  s = .Stream~new(path)
  s~open("READ")
  text = s~charIn(1, s~chars)
  s~close
  return text

writeAll: procedure
  use strict arg path, text
  call SysFileDelete path
  s = .Stream~new(path)
  s~open("WRITE REPLACE")
  s~charOut(text)
  s~close
  return
