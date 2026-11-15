/* t09_ssc.rex -- the Semantic Source Control plugin (plugins/ssc), without a
   browser, against a local stand-in for a store's MCP endpoint
   (tests/fixtures/ssc_mock_server.mjs, which this test starts and stops):
   the package opened, each changed method proposed against the revision it
   was opened at, new and removed pieces reported and not sent, a stale base
   left to the store's conflict branch, the unit's history and an earlier
   revision, the session token held back.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx t09_ssc.rex PLUGINS_DIR [PORT]
     REXX_PATH: src, and PLUGINS_DIR/<the ssc entry's paths = > (run_all.rex).
   Needs ooRexx/WASM (ADDRESS FETCH) and node: else SKIP. */
parse arg dir port .
dir = dir~strip
if dir == "" then dir = "site/plugins"
if port == "" then port = 8977
fails = 0
checks = 0
here = .File~new(.context~package~name)~parentFile~absolutePath
base = "http://127.0.0.1:"port
.OodUi~use("en")
host = .OodPluginHost~new(dir, "en")
p = host~enable("ssc")
call check "switched on: SscPlugin, provides scm", p~class~id~caselessEquals("SscPlugin") & host~enabledFor("scm") == "ssc"
call check "module_version", p~class~module_version == "0.8.0"
call check "the session is a secret setting", host~settingLines("ssc")~pos("session" || "09"x || "secret") > 0
call refusesWith "no store named", "host~scm('ssc', 'LIST')", "MCP address"
if \fetchHere() then do
  say "t09_ssc: SKIP the store checks (no ADDRESS FETCH: native ooRexx)"
  call refusesWith "no ADDRESS FETCH: said plainly", "host~setSetting('ssc', 'endpoint', 'http://127.0.0.1:1/mcp'); host~setSetting('ssc', 'root', 'x'); host~scm('ssc', 'LIST')", "No ADDRESS FETCH"
  say "t09_ssc:" checks - fails "of" checks "checks passed"
  return fails
end
address system 'node "'here'/fixtures/ssc_mock_server.mjs"' port '> /dev/null 2>&1 & echo $! > /tmp/t09_ssc_mock.pid'
address system 'sleep 1'
signal on syntax name stopMock
call storeChecks
stopMock:
address system 'kill $(cat /tmp/t09_ssc_mock.pid) 2>/dev/null; rm -f /tmp/t09_ssc_mock.pid'
if condition("C") == "SYNTAX" then do
  say "  FAIL syntax error:" condition("O")~at("MESSAGE") condition("O")~at("POSITION")
  fails = fails + 1
end
say "t09_ssc:" checks - fails "of" checks "checks passed"
exit fails      -- (exit: a syntax error inside the checks lands here)

storeChecks:
host~setSetting("ssc", "endpoint", base"/mcp")
call refusesWith "no object named", "host~scm('ssc', 'LIST')", "object to open"
host~setSetting("ssc", "root", "oorexx://demo/Greeter")
call refusesWith "no session: the store's refusal", "host~scm('ssc', 'LIST')", "AUTHENTICATED_PRINCIPAL_REQUIRED"
host~setSetting("ssc", "session", "FAKE-SSC-SESSION-84")
call check "the session: its name only", host~secrets~referenceLines == "SSC.SESSION" & host~settingLines("ssc")~pos("FAKE-") = 0
call check "LIST: the class file, not the README", host~scm("ssc", "LIST")~makeArray("0a"x)~items = 1 & host~scm("ssc", "LIST")~word(1) == "src/Greeter.cls"
call refusesWith "STATUS before OPEN", "host~scm('ssc', 'STATUS', 'src/Greeter.cls', 'x')", "Open src/Greeter.cls"
o = opened(host~scm("ssc", "OPEN", "src/Greeter.cls"))
text = o["TEXT"]
call check "OPEN: the file the store makes", text~pos("::method greet") > 0 & text~right(1) == "0a"x & o["REF"] \== ""
call check "STATUS: current", lines(host~scm("ssc", "STATUS", "src/Greeter.cls", o["REF"]))["STATE"] == "CURRENT"
call check "COMMIT, nothing changed: refused", lines(host~scm("ssc", "COMMIT", "src/Greeter.cls", text, "nothing", o["REF"]))["NOTE"]~pos("Nothing changed") > 0
new = text~changeStr('return "Hello," name', 'return "Hello," name || "!"')
c = lines(host~scm("ssc", "COMMIT", "src/Greeter.cls", new, "An exclamation", o["REF"]))
call check "COMMIT: the changed method proposed:" c["NOTES"], c["STATUS"] == "ok" & c["NOTES"]~pos("method Greeter~greet: proposed as ssr_") > 0
call check "  for review, the REF unchanged", c["NOTES"]~pos("nothing is accepted until it is reviewed") > 0 & c["REF"] == o["REF"]
call check "  only greet was sent", proposals() = 1
new2 = new~changeStr('|| "!"', '|| "!!"')
c = lines(host~scm("ssc", "COMMIT", "src/Greeter.cls", new2, "Two", o["REF"]))
call check "a second edit builds on the first proposal", c["STATUS"] == "ok" & c["NOTES"]~pos("conflict") = 0
added = new2 || "::method bye" || "0a"x || "  return ""Bye""" || "0a"x
c = lines(host~scm("ssc", "COMMIT", "src/Greeter.cls", added, "Bye", o["REF"]))
call check "a new method: reported, not sent:" c["NOTES"], c["STATUS"] == "refused" & c["NOTES"]~pos("method Greeter~bye is new") > 0
gone = new2~changeStr("::method init" || "0a"x || "  expose name" || "0a"x || "  use arg name" || "0a"x, "")
c = lines(host~scm("ssc", "COMMIT", "src/Greeter.cls", gone, "No init", o["REF"]))
call check "a method gone: reported, not sent", c["STATUS"] == "refused" & c["NOTES"]~pos("method Greeter~init is gone") > 0
address fetch "GET" base"/accept-and-move INTO ignore"
call check "STATUS: the unit moved on", lines(host~scm("ssc", "STATUS", "src/Greeter.cls", o["REF"]))["STATE"] == "MOVED"
o2 = opened(host~scm("ssc", "OPEN", "src/Greeter.cls"))
stale = o2["TEXT"]~changeStr("-- reviewed", "-- mine")
o3 = opened(host~scm("ssc", "OPEN", "src/Greeter.cls"))      -- the same base, opened again
address fetch "GET" base"/accept-and-move INTO ignore"
c = lines(host~scm("ssc", "COMMIT", "src/Greeter.cls", stale, "Mine", o3["REF"]))
call check "a stale base: the store's conflict branch:" c["NOTES"], c["STATUS"] == "refused" & c["NOTES"]~pos("conflict branch br_conflict_") > 0
h = host~scm("ssc", "HISTORY", "src/Greeter.cls")~makeArray("0a"x)
call check "HISTORY: the unit's revisions, newest first:" h[1], h~items = 3 & h[1]~pos("ACCEPTED #3") > 0
first = h[h~items]~makeArray("09"x)[1]
at = host~scm("ssc", "AT", "src/Greeter.cls", first)
call check "AT: the first revision", at~pos("-- reviewed") = 0 & at~pos("::method greet") > 0
seen = seenRequests()
last = seen[seen~items]
call check "the bearer and Mcp-Name on each call", last["auth"] == "Bearer FAKE-SSC-SESSION-84" & last["mcpName"] == last["name"] & seen[1]["auth"] == ""
host~setLanguage("de")
.OodUi~use("de")
c = lines(host~scm("ssc", "COMMIT", "src/Greeter.cls", stale || "::method neu" || "0a"x, "neu", o3["REF"]))
call check "notes in German", c["NOTES"]~pos("ist neu") > 0
return

proposals: procedure expose base
  address fetch "GET" base"/seen INTO t"
  address fetch "JSON INTO seen"
  n = 0
  do s over seen
    if s["name"] == "source.propose_edit" then n = n + 1
  end
  return n

opened: procedure
  use arg t
  d = .directory~new
  parse var t "REF " ref "0a"x "TEXT" "0a"x text
  d["REF"] = ref; d["TEXT"] = text
  return d

lines: procedure
  use arg t
  d = .directory~new
  d["NOTES"] = ""
  do l over t~makeArray("0a"x)
    w = l~word(1)
    if w == "NOTE" then d["NOTES"] = d["NOTES"] "|" l~substr(6)
    else d[w] = l~substr(length(w) + 2)
  end
  d["NOTE"] = d["NOTES"]
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
