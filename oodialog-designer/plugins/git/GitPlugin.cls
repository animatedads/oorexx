/* GitPlugin.cls -- an optional extra for the ooDialog Designer and the ooRexx
   Object Editor: git source control, the program or class file in a git
   repository.  Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
   German: Claude (Opus 5.5).

   Two ways to the repository, chosen in the settings:
   - github: GitHub's REST API (contents and commits), by ADDRESS FETCH, from
     the page.  The token is a secret setting: the editor's secret store, the
     estate's Secret Broker (plugins/common/OodBroker.cls), a header set from
     a variable for one request and dropped after it.  A commit is one file's
     new content on the branch, refused by GitHub when the branch moved on
     since the file was opened (its blob sha is sent).
   - cli: the git command, in a working copy (ADDRESS SYSTEM).  Not in a
     browser: for ooRexx outside one (native, or ooRexx/WASM in Node).  It
     commits, and pushes when the settings say so; its credentials are git's
     own.

   Every operation answers lines, as OodPluginHost~scm says; what fails is
   refused (93.900) with the reason in the designer's language. */

::requires "OodPlugins.cls"
::requires "OodBroker.cls"

::class GitPlugin public subclass OodPlugin
::method module_version class
  return "0.8.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.8.0"
::method module_lastChanged
  return "2026-11-15"

::method init
  use strict arg id
  self~init:super(id)
  self~setSetting("backend", "github")
  self~setSetting("repo", "")
  self~setSetting("branch", "main")
  self~setSetting("folder", "")
  self~setSetting("token", "GIT.TOKEN")
  self~setSetting("api", "https://api.github.com")
  self~setSetting("workdir", "")
  self~setSetting("push", "no")

::method resources
  return .resources

::method provides
  return "scm"

::method settingLines
  out = .array~new
  out~append("backend" || "09"x || "choice:github|cli" || "09"x || self~nls("set.backend"))
  out~append("repo" || "09"x || "text" || "09"x || self~nls("set.repo"))
  out~append("branch" || "09"x || "text" || "09"x || self~nls("set.branch"))
  out~append("folder" || "09"x || "text" || "09"x || self~nls("set.folder"))
  out~append("token" || "09"x || "secret" || "09"x || self~nls("set.token"))
  out~append("api" || "09"x || "text" || "09"x || self~nls("set.api"))
  out~append("workdir" || "09"x || "text" || "09"x || self~nls("set.workdir"))
  out~append("push" || "09"x || "choice:no|yes" || "09"x || self~nls("set.push"))
  return out~makeString("L", "0a"x)

-- the backend the settings choose
::method backend private
  if self~setting("backend")~caselessEquals("cli") then return .GitCliBackend~new(self)
  return .GitHubBackend~new(self)

::method scmList
  return self~backend~list
::method scmOpen
  use strict arg path
  return self~backend~open(self~checked(path))
::method scmStatus
  use strict arg path, ref
  return self~backend~status(self~checked(path), ref)
::method scmCommit
  use strict arg path, text, message, ref
  if message~strip == "" then return "STATUS refused" || "0a"x || "REF" ref || "0a"x || "NOTE" self~nls("err.noMessage")
  return self~backend~commit(self~checked(path), text, message, ref)
::method scmHistory
  use strict arg path
  return self~backend~history(self~checked(path))
::method scmAt
  use strict arg path, ref
  return self~backend~at(self~checked(path), ref)

-- a path in the repository: no "..", no leading /, the folder's if it names none
::method checked
  use strict arg path
  path = path~strip~changeStr("\", "/")
  if path == "" then self~refuse("err.noPath")
  if path~left(1) == "/" | ("/"path"/")~pos("/../") > 0 then self~refuse("err.badPath", path)
  return path

::method refuse
  use strict arg key, a1 = "", a2 = ""
  raise syntax 93.900 array(self~nls(key, a1, a2))


/* GitHub's REST API, by ADDRESS FETCH. */
::class GitHubBackend public
::method init
  expose plugin
  use strict arg plugin
  if plugin~setting("repo")~pos("/") = 0 then plugin~refuse("err.noRepo")
  if \.local~hasIndex("OODFETCHLOADED") then do
    .context~package~loadPackage("fetch.cls")
    .local~oodFetchLoaded = .true
  end

::method base private
  expose plugin
  return plugin~setting("api")~strip("T", "/") || "/repos/" || plugin~setting("repo")

-- one request: verb, url, body (a Directory, or .nil).  Answers the status;
-- the answer, read as JSON, in ANSWER (.nil if there is none)
::method call
  expose plugin answer
  use strict arg verb, url, body = .nil
  token = .OodSecretUse~value(plugin~host, plugin~setting("token"))
  address fetch
  "TIMEOUT 30"
  "HEADER Accept application/vnd.github+json"
  "HEADER X-GitHub-Api-Version 2022-11-28"
  if token \== .nil then do
    auth = "Bearer" token
    token = ""
    "HEADER Authorization FROM auth"
    auth = ""
  end
  if body == .nil then verb url "INTO text"
  else verb url "JSON FROM body INTO text"
  status = rc
  "HEADER Authorization"
  "HEADER X-GitHub-Api-Version"
  "HEADER Accept"
  answer = .nil
  if status >= 0 then if text~strip \== "" then "JSON INTO answer"
  if status < 0 then plugin~refuse("err.network", url)
  return status

::method answer
  expose answer
  return answer

-- what GitHub said, for a refusal
::method said private
  expose answer
  if answer~isA(.Directory) then if answer["message"] \== .nil then return answer["message"]
  return ""

::method list
  expose plugin
  folder = plugin~setting("folder")~strip("B", "/")
  url = self~base"/contents/"enc(folder)"?ref="enc(plugin~setting("branch"))
  status = self~call("GET", url)
  if status \= 0 then plugin~refuse("err.http", status, self~said)
  out = .array~new
  if \self~answer~isA(.Array) then return ""
  do e over self~answer
    if e["type"] \== "file" then iterate
    name = e["name"]
    if \wordpos(name~substr(name~lastPos(".") + 1)~lower, "rex cls rexx") > 0 then iterate
    out~append(e["path"] || "09"x || e["sha"])
  end
  return out~makeString("L", "0a"x)

::method open
  expose plugin
  use strict arg path
  status = self~call("GET", self~base"/contents/"enc(path)"?ref="enc(plugin~setting("branch")))
  if status = 404 then plugin~refuse("err.noFile", path, plugin~setting("branch"))
  if status \= 0 then plugin~refuse("err.http", status, self~said)
  a = self~answer
  return "REF" a["sha"] || "0a"x || "TEXT" || "0a"x || a["content"]~changeStr("0a"x, "")~decodeBase64

::method status
  expose plugin
  use strict arg path, ref
  status = self~call("GET", self~base"/contents/"enc(path)"?ref="enc(plugin~setting("branch")))
  if status = 404 then return "STATE NEW" || "0a"x || "NOTE" plugin~nls("st.new", plugin~setting("branch"))
  if status \= 0 then plugin~refuse("err.http", status, self~said)
  if self~answer["sha"] == ref then return "STATE CURRENT"
  return "STATE MOVED" || "0a"x || "NOTE" plugin~nls("st.moved", plugin~setting("branch"))

::method commit
  expose plugin
  use strict arg path, text, message, ref
  body = .directory~new
  body["message"] = .JsonString~new(message)
  body["content"] = .JsonString~new(text~encodeBase64)
  body["branch"] = .JsonString~new(plugin~setting("branch"))
  -- the blob as opened: GitHub refuses the commit if the branch has another
  if ref \== "" then body["sha"] = .JsonString~new(ref)
  status = self~call("PUT", self~base"/contents/"enc(path), body)
  if status = 409 | status = 422 then return "STATUS refused" || "0a"x || "REF" || "0a"x || "NOTE" plugin~nls("err.moved", self~said)
  if status \= 0 then return "STATUS failed" || "0a"x || "REF" || "0a"x || "NOTE" plugin~nls("err.http", status, self~said)
  a = self~answer
  return "STATUS ok" || "0a"x || "REF" a["content"]["sha"] || "0a"x || "NOTE" plugin~nls("ok.commit", a["commit"]["sha"]~left(7), plugin~setting("branch"))

::method history
  expose plugin
  use strict arg path
  status = self~call("GET", self~base"/commits?path="enc(path)"&sha="enc(plugin~setting("branch"))"&per_page=20")
  if status \= 0 then plugin~refuse("err.http", status, self~said)
  out = .array~new
  do c over self~answer
    msg = c["commit"]["message"]~changeStr("0d"x, "")
    if msg~pos("0a"x) > 0 then msg = msg~left(msg~pos("0a"x) - 1)
    out~append(c["sha"] || "09"x || c["commit"]["author"]["date"] || "09"x || c["commit"]["author"]["name"] || "09"x || msg)
  end
  return out~makeString("L", "0a"x)

::method at
  expose plugin
  use strict arg path, ref
  status = self~call("GET", self~base"/contents/"enc(path)"?ref="enc(ref))
  if status \= 0 then plugin~refuse("err.http", status, self~said)
  return self~answer["content"]~changeStr("0a"x, "")~decodeBase64


/* The git command, in a working copy (ADDRESS SYSTEM): outside a browser. */
::class GitCliBackend public
::method init
  expose plugin dir
  use strict arg plugin
  dir = plugin~setting("workdir")~strip
  if dir == "" then plugin~refuse("err.noWorkdir")
  if \SysIsFileDirectory(dir"/.git") then plugin~refuse("err.notRepo", dir)

-- one git command; its output lines (an array); refused when it fails
::method git private
  expose plugin dir
  use strict arg args, okCodes = "0"
  out. = ""; err. = ""
  signal on failure name noGit
  address system 'git -C "'dir'"' args with output stem out. error stem err.
  if wordpos(rc, okCodes) = 0 then do
    msg = ""
    do i = 1 to err.0
      msg = msg err.i
    end
    plugin~refuse("err.git", args~word(1), msg~strip)
  end
  lines = .array~new
  do i = 1 to out.0
    lines~append(out.i)
  end
  return lines
noGit:
  plugin~refuse("err.noGitHere")

::method list
  expose plugin
  folder = plugin~setting("folder")~strip("B", "/")
  where = ""
  if folder \== "" then where = '"'folder'/"'
  out = .array~new
  do l over self~git('ls-tree --name-only "'plugin~setting("branch")'"' where)
    if \wordpos(l~substr(l~lastPos(".") + 1)~lower, "rex cls rexx") > 0 then iterate
    out~append(l || "09"x || self~git('rev-parse "'plugin~setting("branch")':'l'"')[1])
  end
  return out~makeString("L", "0a"x)

::method open
  expose plugin
  use strict arg path
  ref = self~blob(plugin~setting("branch"), path)
  if ref == "" then plugin~refuse("err.noFile", path, plugin~setting("branch"))
  return "REF" ref || "0a"x || "TEXT" || "0a"x || self~show(plugin~setting("branch"), path)

-- the blob of a path at a ref, "" if it has none
::method blob private
  use strict arg ref, path
  r = self~git('rev-parse --verify --quiet "'ref':'path'"', "0 1")
  if r~items = 0 then return ""
  return r[1]

-- a file's text at a ref, as it is (its blob written to a file and read back:
-- no line ending is lost, as it would be in an output stem)
::method show private
  expose dir
  use strict arg ref, path
  tmp = SysTempFileName(dir"/.git/oodshow-?????")
  self~git('cat-file blob "'ref':'path'" > "'tmp'"')
  s = .stream~new(tmp)
  s~open("read")
  t = s~charIn(1, s~chars)
  s~close
  call SysFileDelete tmp
  return t

::method status
  expose plugin
  use strict arg path, ref
  now = self~blob(plugin~setting("branch"), path)
  if now == "" then return "STATE NEW" || "0a"x || "NOTE" plugin~nls("st.new", plugin~setting("branch"))
  if now == ref then return "STATE CURRENT"
  return "STATE MOVED" || "0a"x || "NOTE" plugin~nls("st.moved", plugin~setting("branch"))

::method commit
  expose plugin dir
  use strict arg path, text, message, ref
  branch = plugin~setting("branch")
  head = self~git("rev-parse --abbrev-ref HEAD")[1]
  if head \== branch then return "STATUS refused" || "0a"x || "REF" ref || "0a"x || "NOTE" plugin~nls("err.notOnBranch", head, branch)
  if self~blob(branch, path) \== ref then return "STATUS refused" || "0a"x || "REF" ref || "0a"x || "NOTE" plugin~nls("err.movedCli", branch)
  call makeDirsFor dir"/"path
  s = .stream~new(dir"/"path)
  s~open("write replace")
  s~charOut(text)
  s~close
  self~git('add -- "'path'"')
  if self~git('diff --cached --name-only -- "'path'"')~items = 0 then
    return "STATUS refused" || "0a"x || "REF" self~blob("HEAD", path) || "0a"x || "NOTE" plugin~nls("err.nothing")
  msgFile = SysTempFileName(dir"/.git/oodmsg-?????")
  m = .stream~new(msgFile)
  m~open("write replace")
  m~charOut(message)
  m~close
  self~git('commit --quiet -F "'msgFile'" -- "'path'"')
  call SysFileDelete msgFile
  sha = self~git("rev-parse --short HEAD")[1]
  note = plugin~nls("ok.commit", sha, branch)
  if plugin~setting("push")~caselessEquals("yes") then do
    self~git('push --quiet origin "'branch'"')
    note = note plugin~nls("ok.pushed")
  end
  return "STATUS ok" || "0a"x || "REF" self~blob("HEAD", path) || "0a"x || "NOTE" note

::method history
  expose plugin
  use strict arg path
  return self~git('log -n 20 --format=%H%x09%aI%x09%an%x09%s "'plugin~setting("branch")'" -- "'path'"')~makeString("L", "0a"x)

::method at
  use strict arg path, ref
  return self~show(ref, path)


-- a URL's path or query part: %, blank, #, ?, & and + escaped
::routine enc
  use strict arg s
  out = ""
  do i = 1 to s~length
    c = s~subchar(i)
    if pos(c, "% #?&+") > 0 then out = out || "%" || c~c2x
    else out = out || c
  end
  return out

::routine makeDirsFor
  use strict arg file
  dir = file~left(file~lastPos("/") - 1)
  if dir == "" | SysIsFileDirectory(dir) then return
  call makeDirsFor dir
  call SysMkDir dir

::resource strings.en
set.backend = The way to the repository (github: GitHub's API, from the page; cli: git, outside a browser)
set.repo = Repository (owner/name)
set.branch = Branch
set.folder = Folder in the repository
set.token = GitHub token (contents: read and write)
set.api = GitHub API address
set.workdir = Working copy (cli)
set.push = Push after a commit (cli)
err.noRepo = Give the repository as owner/name in the git plugin's settings.
err.noPath = No file named.
err.badPath = %1 is not a path in the repository.
err.network = No answer from %1 (the network, or the address).
err.http = GitHub answered %1: %2
err.noFile = %1 is not on branch %2.
err.moved = The branch moved on since the file was opened; open it again (GitHub: %1).
err.noMessage = Say what the commit changes.
err.noWorkdir = Give the working copy in the git plugin's settings.
err.notRepo = %1 is not a git working copy.
err.git = git %1 failed: %2
err.noGitHere = No git here: the cli way needs ooRexx outside a browser.
err.notOnBranch = The working copy is on %1, not %2.
err.movedCli = %1 moved on since the file was opened; open it again.
err.nothing = Nothing to commit: the file is as it was.
st.new = Not on %1 yet: a commit adds it.
st.moved = %1 moved on since the file was opened.
ok.commit = Committed %1 on %2.
ok.pushed = Pushed.
::END

::resource strings.de
-- Deutsch: übersetzt von Claude (Opus 5.5); bitte von einem Muttersprachler prüfen
set.backend = Der Weg zum Repository (github: die API von GitHub, aus der Seite; cli: git, außerhalb eines Browsers)
set.repo = Repository (Besitzer/Name)
set.branch = Zweig
set.folder = Ordner im Repository
set.token = GitHub-Token (Inhalte: lesen und schreiben)
set.api = Adresse der GitHub-API
set.workdir = Arbeitskopie (cli)
set.push = Nach dem Commit pushen (cli)
err.noRepo = Das Repository als Besitzer/Name in den Einstellungen des git-Plugins angeben.
err.noPath = Keine Datei genannt.
err.badPath = %1 ist kein Pfad im Repository.
err.network = Keine Antwort von %1 (das Netz oder die Adresse).
err.http = GitHub antwortete %1: %2
err.noFile = %1 ist nicht im Zweig %2.
err.moved = Der Zweig hat sich seit dem Öffnen der Datei weiterbewegt; sie erneut öffnen (GitHub: %1).
err.noMessage = Sagen, was der Commit ändert.
err.noWorkdir = Die Arbeitskopie in den Einstellungen des git-Plugins angeben.
err.notRepo = %1 ist keine git-Arbeitskopie.
err.git = git %1 schlug fehl: %2
err.noGitHere = Hier gibt es kein git: der cli-Weg braucht ooRexx außerhalb eines Browsers.
err.notOnBranch = Die Arbeitskopie ist auf %1, nicht auf %2.
err.movedCli = %1 hat sich seit dem Öffnen der Datei weiterbewegt; sie erneut öffnen.
err.nothing = Nichts zu committen: die Datei ist unverändert.
st.new = Noch nicht in %1: ein Commit fügt sie hinzu.
st.moved = %1 hat sich seit dem Öffnen der Datei weiterbewegt.
ok.commit = %1 in %2 committet.
ok.pushed = Gepusht.
::END
