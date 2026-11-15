/* t08_git.rex -- the git source control plugin (plugins/git), without a
   browser, both ways: GitHub's API against a local stand-in
   (tests/fixtures/github_mock_server.mjs, which this test starts and stops)
   and the git command against a repository made here.  Opened, compared,
   committed, refused when the branch moved on, history, earlier versions,
   the token held back.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx t08_git.rex PLUGINS_DIR [PORT]
     PLUGINS_DIR: the built site/plugins.  REXX_PATH: src, and PLUGINS_DIR/<the
     git entry's paths = > (tests/run_all.rex sets them).
   The GitHub checks need ooRexx/WASM (ADDRESS FETCH) and node; the git
   command checks need git.  Each part says SKIP when it cannot run. */
parse arg dir port .
dir = dir~strip
if dir == "" then dir = "site/plugins"
if port == "" then port = 8976
fails = 0
checks = 0
here = .File~new(.context~package~name)~parentFile~absolutePath
base = "http://127.0.0.1:"port
.OodUi~use("en")
host = .OodPluginHost~new(dir, "en")
p = host~enable("git")
call check "switched on: GitPlugin, provides scm", p~class~id~caselessEquals("GitPlugin") & host~enabledFor("scm") == "git"
call check "module_version", p~class~module_version == "0.8.0"
s = host~settingLines("git")
call check "settings: the way is a choice, the token a secret", s~pos("backend" || "09"x || "choice:github|cli") > 0 & s~pos("token" || "09"x || "secret") > 0
call refuses "no repository named", "host~scm('git', 'LIST')"
call refuses "a path out of the repository", "host~setSetting('git', 'repo', 'owner/demo'); host~scm('git', 'OPEN', '../x.rex')"
call refuses "scm from a plugin that has none", "host~enable('bostoncrab'); host~scm('bostoncrab', 'LIST')"

-- GitHub's API
if fetchHere() then call gitHubWithMock
else do
  say "t08_git: SKIP the GitHub checks (no ADDRESS FETCH: native ooRexx)"
  call refusesWith "the github way with no ADDRESS FETCH: said plainly", "host~setSetting('git', 'backend', 'github'); host~scm('git', 'LIST')", "No ADDRESS FETCH"
end

-- the git command
address system "git --version > /dev/null 2>&1"
if rc = 0 then call gitCli
else say "t08_git: SKIP the git command checks (no git)"

say "t08_git:" checks - fails "of" checks "checks passed"
return fails

-- the stand-in started, the checks, the stand-in stopped (a syntax error too)
gitHubWithMock:
address system 'node "'here'/fixtures/github_mock_server.mjs"' port '> /dev/null 2>&1 & echo $! > /tmp/t08_git_mock.pid'
address system 'sleep 1'
signal on syntax name stopMock
call gitHub
stopMock:
address system 'kill $(cat /tmp/t08_git_mock.pid) 2>/dev/null; rm -f /tmp/t08_git_mock.pid'
if condition("C") == "SYNTAX" then do
  say "  FAIL syntax error:" condition("O")~at("MESSAGE") condition("O")~at("POSITION")
  fails = fails + 1
end
signal off syntax
return

gitHub:
host~setSetting("git", "backend", "github")
host~setSetting("git", "api", base)
host~setSetting("git", "repo", "owner/demo")
host~setSetting("git", "folder", "designs")
call refusesWith "no token: GitHub's refusal", "host~scm('git', 'LIST')", "401"
host~setSetting("git", "token", "FAKE-GITHUB-TOKEN-73")
call check "the token: shown as (set) only", host~settingLines("git")~pos("FAKE-") = 0 & host~secrets~referenceLines == "GIT.TOKEN"
l = host~scm("git", "LIST")
call check "LIST: the programs in the folder, not the README:" l~makeArray("0a"x)~items, l~makeArray("0a"x)~items = 1 & l~word(1) == "designs/Hello.rex"
o = opened(host~scm("git", "OPEN", "designs/Hello.rex"))
call check "OPEN: the text, and its blob", o["TEXT"] == 'say "hello"' || "0a"x & o["REF"]~length = 40
call check "STATUS: current", host~scm("git", "STATUS", "designs/Hello.rex", o["REF"]) == "STATE CURRENT"
call check "COMMIT with no message: refused", lines(host~scm("git", "COMMIT", "designs/Hello.rex", "x", " ", o["REF"]))["STATUS"] == "refused"
c = lines(host~scm("git", "COMMIT", "designs/Hello.rex", 'say "hello, world"' || "0a"x, "Greet the world", o["REF"]))
call check "COMMIT: ok:" c["NOTE"], c["STATUS"] == "ok" & c["REF"] \== o["REF"] & c["NOTE"]~pos("on main") > 0
call check "  the branch has it", opened(host~scm("git", "OPEN", "designs/Hello.rex"))["TEXT"] == 'say "hello, world"' || "0a"x
c2 = lines(host~scm("git", "COMMIT", "designs/Hello.rex", 'say "old"' || "0a"x, "From the old version", o["REF"]))
call check "COMMIT on a blob the branch has moved past: refused:" c2["NOTE"], c2["STATUS"] == "refused" & c2["NOTE"]~pos("moved on") > 0
address fetch "GET" base"/move?path=designs/Hello.rex INTO ignore"
call check "STATUS: the branch moved on", lines(host~scm("git", "STATUS", "designs/Hello.rex", c["REF"]))["STATE"] == "MOVED"
n = lines(host~scm("git", "COMMIT", "designs/New.rex", 'say "new"' || "0a"x, "A new design", ""))
call check "COMMIT of a new file", n["STATUS"] == "ok"
call check "  a message that is a number goes as text", lines(host~scm("git", "COMMIT", "designs/Num.rex", "say 1", "42", ""))["STATUS"] == "ok"
h = host~scm("git", "HISTORY", "designs/Hello.rex")~makeArray("0a"x)
parse value h[h~items] with first "09"x when "09"x who "09"x msg
call check "HISTORY: newest first, the first last:" msg "by" who, h~items = 3 & msg == "First design" & who == "Tom Dyer"
call check "AT: the first version", host~scm("git", "AT", "designs/Hello.rex", first) == 'say "hello"' || "0a"x
seen = seenRequests()
call check "the first request had no token; the rest a bearer, with the API version", seen[1]["auth"] == "" & seen[2]["auth"] == "Bearer FAKE-GITHUB-TOKEN-73" & seen[seen~items]["auth"] == "Bearer FAKE-GITHUB-TOKEN-73" & seen[seen~items]["version"] == "2022-11-28"
return

gitCli:
repo = SysTempFileName("/tmp/t08-repo-?????")
call SysMkDir repo
address system 'cd "'repo'" && git init --quiet -b main && git config user.email t08@example.invalid && git config user.name "t08" && mkdir designs && printf "say 1\n" > designs/One.rex && git add . && git commit --quiet -m "One"'
host~setSetting("git", "backend", "cli")
call refuses "cli: no working copy", "host~setSetting('git', 'workdir', ''); host~scm('git', 'LIST')"
host~setSetting("git", "workdir", repo)
host~setSetting("git", "folder", "designs")
call check "cli LIST", host~scm("git", "LIST")~word(1) == "designs/One.rex"
o = opened(host~scm("git", "OPEN", "designs/One.rex"))
call check "cli OPEN: the text as it is", o["TEXT"] == "say 1" || "0a"x
c = lines(host~scm("git", "COMMIT", "designs/One.rex", "say 2" || "0a"x, "Two, with 'quotes' and ""doubles""", o["REF"]))
call check "cli COMMIT:" c["NOTE"], c["STATUS"] == "ok"
h = host~scm("git", "HISTORY", "designs/One.rex")~makeArray("0a"x)
call check "cli HISTORY: the message as given", h~items = 2 & h[1]~makeArray("09"x)[4] == "Two, with 'quotes' and ""doubles"""
call check "cli AT: the first", host~scm("git", "AT", "designs/One.rex", h[2]~makeArray("09"x)[1]) == "say 1" || "0a"x
call check "cli COMMIT from a blob it moved past: refused", lines(host~scm("git", "COMMIT", "designs/One.rex", "say 3", "x", o["REF"]))["STATUS"] == "refused"
call check "cli COMMIT with nothing changed: refused", lines(host~scm("git", "COMMIT", "designs/One.rex", "say 2" || "0a"x, "same", c["REF"]))["STATUS"] == "refused"
call check "cli STATUS: current", host~scm("git", "STATUS", "designs/One.rex", c["REF"]) == "STATE CURRENT"
host~setLanguage("de")
.OodUi~use("de")
call refusesWith "cli: a file not there, in German", "host~scm('git', 'OPEN', 'designs/None.rex')", "nicht im Zweig"
address system 'rm -rf "'repo'"'
return

-- OPEN's answer: REF, TEXT
opened: procedure
  use arg t
  d = .directory~new
  parse var t "REF " ref "0a"x "TEXT" "0a"x text
  d["REF"] = ref; d["TEXT"] = text
  return d

-- STATUS, REF, NOTE lines
lines: procedure
  use arg t
  d = .directory~new
  d["NOTE"] = ""
  do l over t~makeArray("0a"x)
    d[l~word(1)] = l~substr(length(l~word(1)) + 2)
  end
  return d

seenRequests: procedure expose base
  address fetch "GET" base"/seen INTO seenText"
  address fetch "JSON INTO seen"
  return seen

fetchHere: procedure
  signal on syntax name noFetch
  .context~package~loadPackage("fetch.cls")
  return .true
noFetch:
  return .false

check: procedure expose fails checks
  use arg ckLabel, ckOk
  checks = checks + 1
  if ckOk then say "  ok  " ckLabel
  else do
    say "  FAIL" ckLabel
    fails = fails + 1
  end
  return

refuses: procedure expose fails checks host
  use arg rfLabel, rfCode
  call refusesWith rfLabel, rfCode, ""
  return

refusesWith: procedure expose fails checks host
  use arg rfLabel, rfCode, rfWords
  checks = checks + 1
  signal on syntax name rfRefused
  interpret rfCode
  say "  FAIL not refused:" rfLabel
  fails = fails + 1
  return
rfRefused:
  co = condition("O")
  if co~at("CODE") \== "93.900" | co~at("ADDITIONAL")~isA(.Array) = .false then do
    say "  FAIL refused, but not by the plugin:" rfLabel "--" co~at("MESSAGE")
    fails = fails + 1
    return
  end
  if rfWords \== "", co~at("ADDITIONAL")[1]~pos(rfWords) = 0 then do
    say "  FAIL refused, not saying" rfWords":" rfLabel "--" co~at("ADDITIONAL")[1]
    fails = fails + 1
    return
  end
  say "  ok   refuses" rfLabel "--" co~at("ADDITIONAL")[1]
  return

::requires "OodPlugins.cls"
