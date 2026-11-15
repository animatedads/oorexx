/*----------------------------------------------------------------------------*/
/* LibraryProviders.cls -- where ::requires libraries come from.              */
/*                                                                            */
/* Architecture: Tom Dyer.  Code: Claude (Opus 5.5).                          */
/*                                                                            */
/* A provider offers a catalogue of ooRexx libraries and hands out their      */
/* files.  Providers are registered on a shelf (OxLibraryShelf) the app       */
/* holds:                                                                     */
/*   OxAlchemyProvider  the Alchemy estate (animatedads/alchemy): the latest  */
/*                      version of each package, its .cls files            */
/*   OxGitHubProvider   any GitHub repository, by owner, repo and branch      */
/*   OxLocalProvider    a folder, or files handed in (uploaded)               */
/* A GitHub provider reads the repository's tree from the GitHub API; when    */
/* the API refuses (no network to it, or its limit of 60 requests an hour    */
/* without a token) it reads a published index (tools/libindex.rex writes     */
/* one).  Files come from raw.githubusercontent.com.                          */
/*                                                                            */
/* Installing a file fetches it and, from the same provider, every file its   */
/* ::requires reach (the closure), flat into lib/<provider>/, so the          */
/* libraries' own ::requires resolve beside them as they do in the estate.    */
/* What an installed file offers -- its public classes and their public      */
/* members -- is found by loading it and examining the objects (the Object    */
/* Editor's OxWorkspace), not by reading its text.                            */
/*----------------------------------------------------------------------------*/

/* One library a provider offers. */
::class OxLibrary public inherit OxModule
::attribute provider
::attribute name
::attribute version
::attribute dir
::attribute description
::attribute files           -- .Array of paths in the provider, under dir
::attribute main            -- the file offered first
::method init
  expose provider name version dir description files main
  use strict arg provider, name, version = "", dir = "", description = "", files = (.array~new), main = ""
::method id
  expose provider name
  return provider":"name
::method asLine
  expose name version dir description files main
  return "library name="oodQ(name) "version="oodQ(version) "dir="oodQ(dir) "main="oodQ(main) "description="oodQ(description) "files="oodQ(files~makeString("L", " "))
::method fromLine class
  use strict arg provider, line
  f = oodFields(line)
  lib = self~new(provider, f["NAME"], oodAt(f, "VERSION"), oodAt(f, "DIR"), oodAt(f, "DESCRIPTION"))
  do p over oodAt(f, "FILES")~makeArray(" ")
    if p \== "" then lib~files~append(p)
  end
  lib~main = oodAt(f, "MAIN")
  if lib~main == "" then do
    if lib~files~items > 0 then lib~main = lib~files[1]
  end
  return lib


/* The protocol every provider follows. */
::class OxLibraryProvider public inherit OxModule
::attribute id
::attribute title
::attribute cache           -- the catalogue, once read
::attribute readmes         -- descriptions read, by dir
::method init
  expose id title cache readmes
  use strict arg id, title
  cache = .nil
  readmes = .directory~new
::method catalogue abstract       -- .Array of OxLibrary
::method fetchFile abstract       -- (path) -> the file's text
-- a line about a library: its own, else the first heading of its README
::method describe
  expose readmes
  use strict arg lib
  if lib~description \== "" then return lib~description
  if readmes~hasIndex(lib~dir) then return readmes[lib~dir]
  d = ""
  signal on syntax name noReadme
  do l over self~fetchFile(lib~dir"/README.md")~changeStr("0d0a"x, "0a"x)~makeArray("0a"x)
    if l~left(2) == "# " then do
      d = l~substr(3)~strip
      leave
    end
  end
noReadme:
  readmes[lib~dir] = d
  return d
::method kind
  return "provider"
::method refresh
  expose cache
  cache = .nil
  return 0

-- Text from a URL (http:, https:) or a file in this interpreter's file system.
::method readText
  use strict arg where
  if where~left(5)~caselessEquals("http:") | where~left(6)~caselessEquals("https:") then do
    address fetch "TIMEOUT 30"
    address fetch "GET" where "INTO body"
    if rc \= 0 then raise syntax 93.900 array(oxT("ox.err.http", rc, where))
    return body
  end
  s = .stream~new(where)
  if s~query("exists") == "" then raise syntax 93.900 array(oxT("ox.err.noFile", where))
  s~open("read")
  t = s~charIn(1, s~chars)
  s~close
  return t

-- Group .cls paths into libraries: one per directory under prefix (the
-- latest version of each, where the directory name ends _vN...).  Paths in
-- tests, examples and the like are left out.
::method groupLibraries
  use strict arg paths, prefix
  skip = "TESTS TEST EXAMPLES EXAMPLE QUALIFICATION QUAL VENDOR DEPENDENCIES DEPS AUTOBUILD SCRIPTS TOOLS"
  byDir = .directory~new
  order = .array~new
  do p over paths
    if p~right(4)~caselessEquals(".cls") == .false then iterate
    if prefix \== "" then do
      if \p~left(prefix~length)~caselessEquals(prefix) then iterate
    end
    rest = p~substr(prefix~length + 1)
    if rest~pos("/") = 0 then dir = prefix~strip("T", "/")
    else dir = prefix || rest~left(rest~pos("/") - 1)
    if dir == "" then inner = p
    else inner = p~substr(dir~length + 2)
    bad = .false
    do seg over inner~makeArray("/")
      if wordpos(seg~upper, skip) > 0 then bad = .true
    end
    if bad then iterate
    if \byDir~hasIndex(dir) then do
      byDir[dir] = .array~new
      order~append(dir)
    end
    byDir[dir]~append(p)
  end
  latest = .directory~new
  stems = .array~new
  do dir over order
    leaf = dir~substr(dir~lastPos("/") + 1)
    if leaf == "" then leaf = self~id
    parse value oxSplitVersion(leaf) with stem "09"x version
    lib = .OxLibrary~new(self~id, stem, version, dir)
    do f over byDir[dir]~sortWith(.CaselessComparator~new)
      lib~files~append(f)
    end
    lib~main = oxMainFile(stem, lib~files)
    old = latest~at(stem~upper)
    if old == .nil then do
      latest[stem~upper] = lib
      stems~append(stem~upper)
    end
    else do
      if oxCompareVersions(version, old~version) > 0 then latest[stem~upper] = lib
    end
  end
  out = .array~new
  do s over stems~sortWith(.CaselessComparator~new)
    out~append(latest[s])
  end
  return out


/* A GitHub repository. */
::class OxGitHubProvider public subclass OxLibraryProvider
::attribute owner
::attribute repo
::attribute branch
::attribute prefix          -- where libraries are ("packages/"), or "" for the whole repo
::attribute indexUrl        -- an index to read when the API refuses ("" for none)
::attribute source          -- how the catalogue was read: "api" or "index"
::attribute preferApi       -- .true: read the tree even when there is an index
::method init
  expose owner repo branch prefix indexUrl preferApi
  use strict arg id, title, owner, repo, branch = "main", prefix = "", indexUrl = ""
  self~init:super(id, title)
  preferApi = .false
::method kind
  return "github"
-- An index, when there is one, is read first: one small file, where the API
-- would send the whole tree (and allows 60 requests an hour without a token).
-- refreshFromGitHub reads the tree itself.
::method catalogue
  expose owner repo branch prefix indexUrl source preferApi
  if self~cache \== .nil then return self~cache
  if indexUrl \== "" & \preferApi then do
    source = "index"
    self~cache = self~readIndex(indexUrl)
    return self~cache
  end
  signal on syntax name apiRefused
  paths = self~treePaths
  signal off syntax
  source = "api"
  self~cache = self~groupLibraries(paths, prefix)
  return self~cache
apiRefused:
  if indexUrl == "" then raise propagate
  source = "index (the GitHub API refused)"
  self~cache = self~readIndex(indexUrl)
  return self~cache
::method refreshFromGitHub
  expose preferApi
  preferApi = .true
  self~refresh
  return self~catalogue~items

-- every blob path of the branch, from the GitHub API (one request)
::method treePaths
  expose owner repo branch
  address fetch "TIMEOUT 30"
  address fetch "HEADER Accept application/vnd.github+json"
  address fetch "GET https://api.github.com/repos/"owner"/"repo"/git/trees/"branch"?recursive=1 INTO body"
  if rc \= 0 then raise syntax 93.900 array(oxT("ox.err.github", rc, owner"/"repo))
  address fetch "JSON tree INTO tree"
  paths = .array~new
  do e over tree
    if e["type"] == "blob" then paths~append(e["path"])
  end
  return paths

-- an index: "library ..." lines (tools/libindex.rex)
::method readIndex
  use strict arg where
  out = .array~new
  do l over self~readText(where)~changeStr("0d0a"x, "0a"x)~makeArray("0a"x)
    if l~word(1) == "library" then out~append(.OxLibrary~fromLine(self~id, l))
  end
  return out

::method rawUrl
  expose owner repo branch
  use strict arg path
  return "https://raw.githubusercontent.com/"owner"/"repo"/"branch"/"path
::method fetchFile
  use strict arg path
  return self~readText(self~rawUrl(path))

/* The Alchemy estate: animatedads/alchemy, its packages/. */
::class OxAlchemyProvider public subclass OxGitHubProvider
::method init
  use strict arg indexUrl = ""
  self~init:super("alchemy", "Alchemy (animatedads/alchemy)", "animatedads", "alchemy", "main", "packages/", indexUrl)


/* A folder of this interpreter's file system; files can be handed in. */
::class OxLocalProvider public subclass OxLibraryProvider
::attribute root
::attribute prefix          -- where libraries are under root ("packages/"), or ""
::method init
  expose root prefix
  use strict arg id, title, root, prefix = ""
  self~init:super(id, title)
  root = root~strip("T", "/")
  call oxMakeDirs root
::method kind
  return "local"
::method catalogue
  expose root prefix
  if self~cache \== .nil then return self~cache
  call SysFileTree root"/*.cls", "found.", "FSO"
  paths = .array~new
  do i = 1 to found.0
    p = found.i~changeStr("\", "/")
    if p~left(root~length + 1) == root"/" then paths~append(p~substr(root~length + 2))
  end
  self~cache = self~groupLibraries(paths, prefix)
  return self~cache
::method fetchFile
  expose root
  use strict arg path
  return self~readText(root"/"path)
-- a file handed in (an upload): kept under the folder, catalogue read again
::method addFile
  expose root
  use strict arg relPath, text
  relPath = relPath~changeStr("\", "/")~strip("L", "/")
  if relPath~pos("..") > 0 then raise syntax 93.900 array(oxT("ox.err.path", relPath))
  full = root"/"relPath
  call oxMakeDirs full~left(full~lastPos("/") - 1)
  call oxWriteFile full, text
  self~refresh
  return relPath


/* The shelf: the providers the app has, and what has been installed. */
::class OxLibraryShelf public inherit OxModule
::attribute providers       -- .Array, in the order registered
::attribute installRoot     -- lib/<provider>/<file>
::attribute installed       -- .Directory  full path -> "provider:library"
::attribute notes           -- the last install's remarks
::method init
  expose providers installRoot installed notes
  use strict arg installRoot = "/home/rexx/lib"
  providers = .array~new
  installed = .directory~new
  notes = .array~new
  installRoot = installRoot~strip("T", "/")
::method register
  expose providers
  use strict arg p
  do q over providers
    if q~id~caselessEquals(p~id) then raise syntax 93.900 array(oxT("ox.err.providerExists", p~id))
  end
  providers~append(p)
  return p~id
::method provider
  expose providers
  use strict arg id
  do q over providers
    if q~id~caselessEquals(id) then return q
  end
  raise syntax 93.900 array(oxT("ox.err.noProvider", id))
-- "id<tab>kind<tab>title" lines
::method providerLines
  expose providers
  out = .array~new
  do q over providers
    out~append(q~id || "09"x || q~kind || "09"x || q~title)
  end
  return out~makeString("L", "0a"x)

-- "id<tab>name<tab>version<tab>files<tab>description" for a provider's
-- libraries whose name or description holds filter (any case)
::method catalogueLines
  use strict arg providerId, filter = ""
  p = self~provider(providerId)
  out = .array~new
  do lib over p~catalogue
    if filter \== "" then do
      if lib~name~caselessPos(filter) = 0 & lib~description~caselessPos(filter) = 0 then iterate
    end
    out~append(lib~id || "09"x || lib~name || "09"x || lib~version || "09"x || lib~files~items || "09"x || lib~description)
  end
  return out~makeString("L", "0a"x)

::method library
  use strict arg libId
  parse var libId pid ":" name
  do lib over self~provider(pid)~catalogue
    if lib~name~caselessEquals(name) then return lib
  end
  raise syntax 93.900 array(oxT("ox.err.noLibrary", libId))

-- name, version, dir, description (read now if needed), main, then the files
::method details
  use strict arg libId
  lib = self~library(libId)
  p = self~provider(lib~provider)
  out = .array~new
  out~append("name" || "09"x || lib~name)
  out~append("version" || "09"x || lib~version)
  out~append("dir" || "09"x || lib~dir)
  out~append("description" || "09"x || p~describe(lib))
  out~append("main" || "09"x || lib~main)
  do f over lib~files
    out~append("file" || "09"x || f)
  end
  return out~makeString("L", "0a"x)

::method installDir
  expose installRoot
  use strict arg pid
  return installRoot"/"pid

-- Install one file of a library (its main one by default) and the files its
-- ::requires reach, from the same provider.  Answers the installed path of
-- the file asked for; notes tells what came with it, and what did not.
::method install
  expose installed notes
  use strict arg libId, file = ""
  lib = self~library(libId)
  p = self~provider(lib~provider)
  if file == "" then file = lib~main
  if lib~files~index(file) == .nil then raise syntax 93.900 array(oxT("ox.err.notLibFile", file, libId))
  dir = self~installDir(p~id)
  call oxMakeDirs dir
  notes = .array~new
  todo = .queue~new
  todo~queue(.array~of(lib, file))
  first = ""
  done = .set~new
  do while todo~items > 0
    job = todo~pull
    jl = job[1]
    jf = job[2]
    base = oxBaseName(jf)
    if done~hasIndex(base~upper) then iterate
    done~put(base~upper)
    target = dir"/"base
    if first == "" then first = target
    if installed~hasIndex(target) then do
      if installed[target] \== jl~id then notes~append("kept" base "from" installed[target] "(" || jl~id "has one too)")
      text = p~readText(target)
    end
    else do
      text = p~fetchFile(jf)
      call oxWriteFile target, text
      installed[target] = jl~id
      notes~append("installed" base "from" jl~id)
    end
    do req over oxRequiresOf(text)
      rb = oxBaseName(req)
      if done~hasIndex(rb~upper) then iterate
      found = self~findFile(p, jl, rb)
      if found == .nil then notes~append("not from" p~id":" req "(needed by" base || ")")
      else todo~queue(found)
    end
  end
  return first

-- a file by its base name: in the same library first, else the provider's
-- other libraries (latest versions)
::method findFile
  use strict arg p, lib, baseName
  do f over lib~files
    if oxBaseName(f)~caselessEquals(baseName) then return .array~of(lib, f)
  end
  do other over p~catalogue
    do f over other~files
      if oxBaseName(f)~caselessEquals(baseName) then return .array~of(other, f)
    end
  end
  return .nil

::method notesText
  expose notes
  return notes~makeString("L", "0a"x)

-- the ::requires name for an installed path, from a file in directory fromDir
::method requiresName
  use strict arg path, fromDir
  fromDir = fromDir~strip("T", "/")
  if path~left(fromDir~length + 1) == fromDir"/" then return path~substr(fromDir~length + 2)
  return path

-- What an installed file offers, found by loading it and examining the
-- objects: "class<tab>Name<tab>superclass" then "member<tab>Class<tab>name<tab>kind<tab>side"
-- for its public classes and their own public members.
::method goodies
  use strict arg path
  s = .stream~new(path)
  if s~query("exists") == "" then raise syntax 93.900 array(oxT("ox.err.notInstalled", path))
  s~open("read")
  text = s~charIn(1, s~chars)
  s~close
  w = .OxWorkspace~new(path, text)
  out = .array~new
  do c over w~classNames~makeArray(" ")
    if c == "" then iterate
    parse value w~classInfo(c) with nm "09"x sup "09"x . "09"x . "09"x isPublic "09"x .
    if isPublic \== "1" then iterate
    out~append("class" || "09"x || nm || "09"x || sup)
    do side over .array~of("CLASS", "INSTANCE")
      do m over w~members(c, side, 0)~makeArray("0a"x)
        parse var m mn "09"x kind "09"x vis "09"x .
        if vis \== "public" then iterate
        if mn~right(1) == "=" then iterate
        out~append("member" || "09"x || nm || "09"x || mn || "09"x || kind~lower || "09"x || side~lower)
      end
    end
  end
  return out~makeString("L", "0a"x)

-- the installed files: "path" lines (a run carries them with it)
::method installedLines
  expose installed
  return installed~allIndexes~sort~makeString("L", "0a"x)
::method fileText
  use strict arg path
  s = .stream~new(path)
  s~open("read")
  t = s~charIn(1, s~chars)
  s~close
  return t


/* ---- routines ---------------------------------------------------------------- */

-- "name_v1.2-dev3" -> "name<tab>1.2-dev3"; no version: "name<tab>"
::routine oxSplitVersion public
  use strict arg leaf
  p = leaf~caselessLastPos("_v")
  if p > 1 then do
    if leaf~substr(p + 2, 1)~verify("0123456789") = 0 then return leaf~left(p - 1) || "09"x || leaf~substr(p + 2)
  end
  return leaf || "09"x

-- 1 when a is the later version, -1 when b is, 0 when the same.  Numbers
-- compare as numbers; a -devN is earlier than the release it leads to.
::routine oxCompareVersions public
  use strict arg a, b
  ka = oxVersionKey(a)
  kb = oxVersionKey(b)
  n = max(ka~items, kb~items)
  do i = 1 to n
    x = 0
    y = 0
    if i <= ka~items then x = ka[i]
    if i <= kb~items then y = kb[i]
    if x > y then return 1
    if x < y then return -1
  end
  return 0
::routine oxVersionKey public
  use strict arg v
  key = .array~new
  num = ""
  v = v~lower~changeStr("-dev", ".-1.")
  do i = 1 to v~length + 1
    ch = v~substr(i, 1)
    if ch \== "" & ("0123456789-"~pos(ch) > 0) then num = num || ch
    else do
      if num \== "" then do
        if datatype(num, "W") then key~append(num)
        num = ""
      end
    end
  end
  -- a release (no -dev) sorts after its dev builds
  if v~pos("-1") = 0 then key~append(0)
  return key

-- the file offered first: one named for the library ("maths" -> Maths.cls),
-- else one the library's last name word is part of ("logging" -> LoggingCore.cls)
::routine oxMainFile public
  use strict arg stem, files
  if files~items = 0 then return ""
  last = stem~substr(stem~lastPos("_") + 1)~lower
  best = ""
  do f over files
    b = oxBaseName(f)~lower
    b = b~left(b~length - 4)
    if b == last | b == stem~lower then return f
    if b~pos(last) > 0 then do
      if best == "" then best = f
      else if oxBaseName(f)~length < oxBaseName(best)~length then best = f
    end
  end
  if best \== "" then return best
  return files[1]

::routine oxBaseName public
  use strict arg path
  path = path~changeStr("\", "/")
  return path~substr(path~lastPos("/") + 1)

-- the files a text's ::requires name, as written
::routine oxRequiresOf public
  use strict arg text
  out = .array~new
  do l over text~changeStr("0d0a"x, "0a"x)~makeArray("0a"x)
    s = l~strip
    if \s~left(10)~caselessEquals("::requires") then iterate
    parse var s . rest
    rest = rest~strip
    q = rest~left(1)
    if q == '"' | q == "'" then parse var rest (q) name (q) .
    else parse var rest name .
    if name~right(4)~caselessEquals(".cls") | name~right(4)~caselessEquals(".rex") then out~append(name)
  end
  return out

::routine oxMakeDirs public
  use strict arg dir
  dir = dir~strip("T", "/")
  if dir == "" then return 0
  path = ""
  do part over dir~makeArray("/")
    if part == "" then do
      path = path || "/"
      iterate
    end
    if path == "" | path~right(1) == "/" then path = path || part
    else path = path"/"part
    call SysMkDir path
  end
  return 0

::routine oxWriteFile public
  use strict arg path, text
  s = .stream~new(path)
  s~open("write replace")
  s~charOut(text)
  s~close
  return 0

::requires "fetch.cls"
::requires "ObjectEditor.cls"
::requires "OodDesigner.cls"
::requires "OxUi.cls"
