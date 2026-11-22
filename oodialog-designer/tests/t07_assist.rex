/* t07_assist.rex -- the code assistance plugin (plugins/assist), without a
   browser, against a local stand-in for both providers
   (tests/fixtures/assist_mock_server.mjs, which this test starts and stops):
   keys held back, proposals checked before they may be applied, cost shown,
   both providers, the designer's language.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx t07_assist.rex PLUGINS_DIR [PORT]
     PLUGINS_DIR: the built site/plugins (tools/build.rex lays the estate's
     files out there).  REXX_PATH: src, and PLUGINS_DIR/<each of the assist
     entry's paths = > (tests/run_all.rex sets them from plugins/index.txt).
   Needs ooRexx/WASM (ADDRESS FETCH) and node: under native ooRexx it says
   SKIP and passes. */
-- the plugins' folder may hold blanks; a port, if given, is the last word
parse arg dir
dir = dir~strip
port = ""
if dir~words > 1, dir~word(dir~words)~datatype("W") then do
  port = dir~word(dir~words)
  dir = dir~subWord(1, dir~words - 1)~strip
end
if dir~left(1) == '"' & dir~right(1) == '"' & dir~length > 1 then dir = dir~substr(2, dir~length - 2)
dir = dir~strip
if dir == "" then dir = "site/plugins"
if port == "" then port = 8973
fails = 0
checks = 0
mock = .File~new(.context~package~name)~parentFile~absolutePath"/fixtures/assist_mock_server.mjs"
base = "http://127.0.0.1:"port
.OodUi~use("en")
host = .OodPluginHost~new(dir, "en")
call check "the index lists assist, off", host~catalogueLines~pos("assist" || "09"x || "Code assistance") > 0 & host~enabledIds == ""
p = host~enable("assist")
call check "switched on: AssistPlugin, provides assist", p~class~id~caselessEquals("AssistPlugin") & p~provides == "assist"
call check "the host finds it by what it provides", host~enabledFor("assist") == "assist" & host~enabledFor("scm") == ""
call check "module_version", p~class~module_version == "0.9.0" & p~module_version == "0.9.0" & p~class~package~findClass("OodSecretsProvider")~module_version == "0.8.0"
if \fetchHere() then do
  say "t07_assist: SKIP the provider checks (no ADDRESS FETCH: native ooRexx)"
  say "t07_assist:" checks - fails "of" checks "checks passed"
  return fails
end
address system 'node "'mock'"' port '> /dev/null 2>&1 & echo $! > /tmp/t07_assist_mock.pid'
address system 'sleep 1'
signal on syntax name stopMock
call runChecks
stopMock:
address system 'kill $(cat /tmp/t07_assist_mock.pid) 2>/dev/null; rm -f /tmp/t07_assist_mock.pid'
if condition("C") == "SYNTAX" then do
  say "  FAIL syntax error:" condition("O")~at("MESSAGE")
  fails = fails + 1
end
say "t07_assist:" checks - fails "of" checks "checks passed"
exit fails      -- (exit: a syntax error inside the checks lands here)

runChecks:
s = settingsOf(host~settingLines("assist"))
call check "settings: provider is a choice", s["PROVIDER"]~word(1) == "choice:anthropic|openai"
call check "settings: no key set, none shown", s["ANTHROPIC.KEY"] == "secret" & s["OPENAI.KEY"] == "secret"
host~setSetting("assist", "anthropic.url", base)
call note "no key: no proposal", host~assist("assist", "GOOD", "say 1", ""), "failed", "No key: give the Anthropic API key"
host~setSetting("assist", "anthropic.key", "FAKE-ANTHROPIC-KEY-51")
s = settingsOf(host~settingLines("assist"))
call check "a key set: shown as (set), never as itself", s["ANTHROPIC.KEY"] == "secret (set)" & host~settingLines("assist")~pos("FAKE-") = 0
call check "the page sees its name only", host~secrets~referenceLines == "ASSIST.ANTHROPIC.KEY"
code = "use arg n" || "0a"x || "say n"
ctx = "Dialog Totals: a button btnSum, a static lblTotal. The method: on_btnSum_clicked."
a = answer(host~assist("assist", "GOOD: sum 1 to n", code, ctx))
call check "Anthropic: a proposal that passes:" a["STATUS"], a["STATUS"] == "ok" & a["CODE"]~pos("total = total + i") > 0 & a["NOTES"]~items = 0
call check "  its model:" a["MODEL"], a["MODEL"] == "claude-haiku-5-5"
call check "  its cost, from the rate card:" a["COST"], a["COST"]~left(1) == "$" & a["COST"]~pos("400 in, 60 out") > 0
call check "  only the method body, not the prose around it", a["CODE"]~left(9) == "use arg n" & a["CODE"]~pos("Here is") = 0
call note "a Boston Crab pitfall: shown, not to be applied", host~assist("assist", "TRAP", code, ctx), "refused", "Boston Crab: P1 on line 2"
call note "it does not compile: shown, not to be applied", host~assist("assist", "BROKEN", code, ctx), "refused", "does not compile"
call note "a :: directive: shown, not to be applied", host~assist("assist", "DIRECTIVE", code, ctx), "refused", "directive"
a = answer(host~assist("assist", "PROSE", code, ctx))
call check "no ``` block: the answer is the code", a["STATUS"] == "ok" & a["CODE"] == 'say "prose"'
call note "no task: nothing asked", host~assist("assist", "  ", code, ctx), "failed", "Say what the code should do"
-- the DOC kind: an ooRexxDoc comment for a member
member = "::method sum" || "0a"x || "  use arg n" || "0a"x || "  return n * (n + 1) / 2"
a = answer(host~assist("assist", "DOCOK", "", member, "DOC"))
call check "DOC: one /** */ comment passes:" a["STATUS"], a["STATUS"] == "ok" & a["CODE"]~left(3) == "/**" & a["CODE"]~pos("@param n") > 0 & a["CODE"]~right(2) == "*/"
a = answer(host~assist("assist", "", "", member, "doc"))
call check "DOC: no task is the standard task", a["STATUS"] == "ok" & a["CODE"]~pos("sum of 1 to n") > 0
call note "DOC: a plain /* */ comment is refused", host~assist("assist", "DOCNOT", "", member, "DOC"), "refused", "not an ooRexxDoc comment"
call note "DOC: two comments are refused", host~assist("assist", "DOCTWO", "", member, "DOC"), "refused", "more than one comment"
call note "DOC: a method body is refused", host~assist("assist", "GOOD", "", member, "DOC"), "refused", "not an ooRexxDoc comment"
call note "an unknown kind", host~assist("assist", "GOOD", code, ctx, "POEM"), "failed", "No such kind"
dce = p~class~package~findPublicRoutine("DOCCOMMENTERROR")
call check "docCommentError: --- lines", dce~call(.array~of("--- One.", "--- Two.")) == "" & dce~call(.array~of("--- One.", "say 1")) == "chk.doc.dashes"
call check "docCommentError: /**/ and /* */ are not docs", dce~call(.array~of("/**/")) == "chk.doc.notDoc" & dce~call(.array~of("/* x */")) == "chk.doc.notDoc"
call check "docCommentError: blank lines around are fine", dce~call(.array~of("", "/** x. */", "")) == ""
seen = seenRequests()
first = seen[1]
call check "the key went as x-api-key, from the page:" first["browser"], first["key"] == "FAKE-ANTHROPIC-KEY-51" & first["browser"] == "true"
host~setSetting("assist", "anthropic.key", "WRONG")
call note "a wrong key: the provider's refusal, shown", host~assist("assist", "GOOD", code, ctx), "failed", "AUTHENTICATION"
-- OpenAI-compatible
host~setSetting("assist", "provider", "openai")
host~setSetting("assist", "openai.endpoint", base"/v1/chat/completions")
call note "OpenAI: no key given", host~assist("assist", "GOOD", code, ctx), "failed", "No key: give the OpenAI API key"
host~setSetting("assist", "openai.key", "FAKE-OPENAI-KEY-62")
call note "OpenAI: no model given", host~assist("assist", "GOOD", code, ctx), "failed", "OpenAI model"
host~setSetting("assist", "openai.model", "fixture-model")
a = answer(host~assist("assist", "GOOD", code, ctx))
call check "OpenAI: a proposal that passes:" a["STATUS"], a["STATUS"] == "ok" & a["CODE"]~pos("total = total + i") > 0
call check "  its model and tokens:" a["MODEL"] a["COST"], a["MODEL"] == "fixture-model-actual" & a["COST"] == "300 in, 50 out"
call note "  a pitfall from OpenAI too", host~assist("assist", "TRAP", code, ctx), "refused", "P1"
seen = seenRequests()
call check "the OpenAI key went as a bearer, and no Anthropic key with it", seen[seen~items]["auth"] == "Bearer FAKE-OPENAI-KEY-62" & seen[seen~items]["key"] == ""
host~setSetting("assist", "provider", "anthropic")
host~setSetting("assist", "anthropic.key", "FAKE-ANTHROPIC-KEY-51")
ignore = host~assist("assist", "GOOD", code, ctx)
seen = seenRequests()
call check "the Anthropic request after it carries no bearer", seen[seen~items]["auth"] == "" & seen[seen~items]["key"] == "FAKE-ANTHROPIC-KEY-51"
-- the designer's language
host~setLanguage("de")
.OodUi~use("de")
call note "notes in the designer's language", host~assist("assist", "TRAP", code, ctx), "refused", "in Zeile 2"
call check "the settings in German", host~settingLines("assist")~pos("Anthropic-API-Schl") > 0
call refuses "assist from a plugin that does not assist", "host~enable('bostoncrab'); host~assist('bostoncrab', 'x', 'say 1', '')"
host~disable("assist")
call refuses "assist when switched off", "host~assist('assist', 'GOOD', 'say 1', '')"
return

-- the host's answer: STATUS, MODEL, COST, NOTES (array), CODE
answer: procedure
  use arg text
  r = .directory~new
  r["NOTES"] = .array~new
  lines = text~makeArray("0a"x)
  do i = 1 to lines~items
    l = lines[i]
    w = l~word(1)
    if w == "CODE" then do
      r["CODE"] = ""
      do j = i + 1 to lines~items
        if r["CODE"] \== "" then r["CODE"] = r["CODE"] || "0a"x
        r["CODE"] = r["CODE"] || lines[j]
      end
      leave
    end
    if w == "NOTE" then r["NOTES"]~append(l~substr(6))
    else r[w] = l~substr(length(w) + 2)
  end
  if \r~hasIndex("CODE") then r["CODE"] = ""
  return r

note: procedure expose fails checks
  use arg ntLabel, ntText, ntStatus, ntWords
  a = answer(ntText)
  notes = a["NOTES"]~makeString("L", " | ")
  call check ntLabel "--" a["STATUS"]":" notes, a["STATUS"] == ntStatus & notes~pos(ntWords) > 0
  return

settingsOf: procedure
  use arg text
  d = .directory~new
  do l over text~makeArray("0a"x)
    parse var l key "09"x kind "09"x label "09"x value
    d[key~upper] = (kind value)~strip
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
  checks = checks + 1
  signal on syntax name rfRefused
  interpret rfCode
  say "  FAIL not refused:" rfLabel
  fails = fails + 1
  return
rfRefused:
  if condition("O")~at("CODE") \== "93.900" | condition("O")~at("ADDITIONAL")~isA(.Array) = .false then do
    say "  FAIL refused, but not by the host:" rfLabel "--" condition("O")~at("MESSAGE")
    fails = fails + 1
    return
  end
  say "  ok   refuses" rfLabel "--" condition("O")~at("ADDITIONAL")[1]
  return

::requires "OodPlugins.cls"
