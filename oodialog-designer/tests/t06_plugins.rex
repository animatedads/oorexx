/* t06_plugins.rex -- the plugin host (OodPlugins.cls) and the Boston Crab
   plugin, without a browser: the index, nothing loaded until switched on,
   findings with their fixes, in the designer's language, secrets kept back.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
   usage: rexx t06_plugins.rex PLUGINS_DIR
     (REXX_PATH: src, and Boston Crab's tests/ for PitfallChecker.cls)      */
parse arg dir
dir = dir~strip
if dir == "" then dir = "plugins"
fails = 0
checks = 0
.OodUi~use("en")
host = .OodPluginHost~new(dir, "en")
cat = host~catalogueLines
call check "the index lists Boston Crab, off", cat~pos("bostoncrab" || "09"x || "Boston Crab: ooRexx pitfalls") = 1 & cat~right(1) == "0"
call check "nothing enabled", host~enabledIds == ""
call refuses "a plugin not switched on", "host~plugin('bostoncrab')"
call refuses "a plugin there is not", "host~enable('nosuch')"
p = host~enable("bostoncrab")
call check "switched on: its class", p~class~id~caselessEquals("BostonCrabPlugin") & host~enabledIds == "bostoncrab"
call check "it says what it does", p~provides == "diagnose fix"
call check "module_version", p~module_version == "0.8.0" & .OodPluginHost~module_version == "0.8.0"
code = "use arg n" || "0a"x || "say '""'(n)'""'" || "0a"x || "x = 'zz'x" || "0a"x || "Total = 1; total2 = TOTAL"
f = host~diagnose(code)~makeArray("0a"x)
call check "findings, in order:" f~items, f~items = 3
parse value f[1] with pl "09"x rule "09"x line "09"x col "09"x sev "09"x fixId "09"x msg
call check "  P1 on line 2, with a fix:" msg, pl == "bostoncrab" & rule == "P1" & line == 2 & fixId \== ""
fixed = host~fix("bostoncrab", code, fixId)
call check "  fixed:" fixed~makeArray("0a"x)[2], fixed~makeArray("0a"x)[2] == "say '""' || (n)'""'"
parse value f[2] with . "09"x rule2 "09"x line2 "09"x . "09"x . "09"x fix2 "09"x msg2
call check "  P2 on line 3:" msg2, rule2 == "P2" & line2 == 3 & msg2~pos("x is a hexadecimal") > 0
parse value f[3] with . "09"x rule3 "09"x . "09"x . "09"x . "09"x fix3 "09"x msg3
call check "  P3, no fix:" msg3, rule3 == "P3" & fix3 == ""
call check "fixing both leaves only P3", host~diagnose(host~fix("bostoncrab", fixed, host~diagnose(fixed)~makeArray("0a"x)[1]~makeArray("09"x)[6]))~makeArray("0a"x)~items = 1
call check "a fix that no longer applies changes nothing", host~fix("bostoncrab", fixed, "2:13") == fixed
host~setLanguage("de")
.OodUi~use("de")
parse value host~diagnose(code)~makeArray("0a"x)[1] with . "09"x . "09"x . "09"x . "09"x . "09"x . "09"x msgDe
call check "messages in the designer's language:" msgDe, msgDe~pos("ruft eine Routine") > 0
call check "the catalogue in German", host~catalogueLines~pos("ooRexx-Fallen") > 0
-- secrets: kept by the host, never handed back to the page
host~secrets~put("ANTHROPIC_KEY", "sk-test-123")
call check "a secret is held", host~secrets~acquire("anthropic_key") == "sk-test-123"
call check "the page sees its name only", host~secrets~referenceLines == "ANTHROPIC_KEY"
call refuses "a secret not set", "host~secrets~acquire('OPENAI_KEY')"
host~disable("bostoncrab")
call check "switched off", host~enabledIds == "" & host~diagnose(code) == ""
say "t06_plugins:" checks - fails "of" checks "checks passed"
return fails

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
