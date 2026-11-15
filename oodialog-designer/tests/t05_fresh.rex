/* t05_fresh.rex -- the designer's model used with nothing set up first, as a
   program outside the page uses it: a refusal still comes as the designer's
   message, in the language of the environment (LC_ALL, LC_MESSAGES, LANG).
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
   usage: rexx t05_fresh.rex            (OodDesigner.cls on REXX_PATH)      */
fails = 0
checks = 0
call value "LC_ALL", "", "ENVIRONMENT"
call value "LC_MESSAGES", "", "ENVIRONMENT"
call value "LANG", "de_DE.UTF-8", "ENVIRONMENT"
d = .OodDesign~new("T")
signal on syntax name refused
d~setProp("form", "name", "1abc")
say "  FAIL not refused"
fails = 1
signal done
refused:
m = condition("O")~at("ADDITIONAL")[1]
checks = checks + 1
if m == "Der Name 1abc muss mit einem Buchstaben oder _ beginnen" then say "  ok   first refusal, no setup, LANG=de_DE.UTF-8:" m
else do
  say "  FAIL first refusal, no setup:" m
  fails = fails + 1
end
done:
say "t05_fresh:" checks - fails "of" checks "checks passed"
return fails
::requires "OodDesigner.cls"
