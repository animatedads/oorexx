/* t03_nls.rex -- the designer's languages: ::RESOURCE string tables, without a browser.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
   usage: rexx t03_nls.rex            (OodDesigner.cls and the example builders on REXX_PATH) */
fails = 0
checks = 0
nl = "0a"x

-- 1. turning languages on: the keys, the base texts are the design's own
d = .viewsDesign~build
call check "no languages: texts are literals", d~generate~pos('self~nls(') = 0
call refuses "a bad language code", "d~setLanguages('english')"
d~setLanguages("en de")
call check "base language", d~baseLanguage == "en" & d~isNls
keys = d~nlsKeys~makeString("L", " ")
call check "keys: title, tabs, columns, label, button, menus and items (not the entry field, not a separator)", -
  keys == "form.title tabMain.tabs lvPeople.columns lblInfo.text btnClose.text mnuAdd.popup mnuAdd.text mnuExit.text mnuGrid.popup mnuGrid.text"
call check "base text is the property", d~stringIn("en", "btnClose.text") == "Close"
call check "no German yet", d~stringIn("de", "btnClose.text") == ""

-- 2. German
d~setString("de", "form.title", "Kontakte")
d~setString("de", "btnClose.text", "Schließen")
d~setString("de", "tabMain.tabs", "Personen|Notizen")
d~setString("de", "lvPeople.columns", "Name:80|Rolle:84|Seit:30")
d~setString("de", "mnuAdd.popup", "&Personen")
d~setString("de", "mnuAdd.text", "Rexx-Person &hinzufügen")
d~setString("de", "mnuExit.text", "&Beenden")
call check "a German text", d~stringIn("de", "btnClose.text") == "Schließen"
call check "keys are caseless", d~stringIn("de", "BTNCLOSE.TEXT") == "Schließen"
d~setString("en", "btnClose.text", "Close it")
call check "the base language's text sets the property", d~getProp("btnClose", "text") == "Close it"
d~setString("en", "btnClose.text", "Close")
call refuses "the base language changed", "d~setLanguages('de en')"

-- 3. event strings
d~addString("msg.count", "%1 people")
call check "an event string is a key", d~nlsKeys~lastItem == "msg.count"
call refuses "a key taken", "d~addString('MSG.COUNT', 'x')"
call refuses "a control's key", "d~addString('btnClose.tip', 'x')"
call refuses "removing a control's key", "d~removeString('btnClose.text')"
d~setString("de", "msg.count", "%1 Personen")
d~setEventCode("mnuAdd", "CLICKED", -
  'self~lvPeople~addRow( , , "Rony Flatscher", "BSF4ooRexx", 2000)' || nl || -
  'self~lblInfo~setText(self~nls("msg.count", self~lvPeople~items))')

-- 4. the program
src = d~generate
call write "Contacts_nls.rex", src
call check "argument chooses the language", src~pos('.Contacts~nlsChosen = lang~strip') > 0
call check "init loads the table", src~pos('self~nlsUse(self~class~nlsChosen, "en")') > 0
call check "title from the table", src~pos('self~nls("form.title")') > 0
call check "button text from the table", src~pos('self~createPushButton(IDCANCEL, 156, 120, 56, 14, "", self~nls("btnClose.text"))') > 0
call check "tabs from the table", src~pos('do t over self~nls("tabMain.tabs")~makeArray("|")') > 0
call check "columns from the table", src~pos('do col over self~nls("lvPeople.columns")~makeArray("|")') > 0
call check "menu from the table", src~pos('menu~addPopup(9001, self~nls("mnuAdd.popup"), "")') > 0
call check "the entry field's text stays data", src~pos('self~txtNotes_data = "Notes go here."') > 0
call check "a ::RESOURCE per language", src~pos("::resource strings.en" || nl || "form.title = Contacts" || nl) > 0 & -
  src~pos("::resource strings.de" || nl || "form.title = Kontakte" || nl) > 0
call check "untranslated keys left out of de", src~pos("mnuGrid.text = ") = src~lastPos("mnuGrid.text = ")
call check "the program parses", parses(src)

-- 5. read back: byte-identical, translations and event strings kept
d2 = .OodDesign~fromSource(src)
call check "round trip gives the same program", d2~generate == src
call check "round trip keeps German", d2~stringIn("de", "mnuAdd.text") == "Rexx-Person &hinzufügen"
call check "round trip keeps the event string", d2~stringIn("en", "msg.count") == "%1 people"
-- a table edited by hand in the saved program is read
hand = src~changeStr("btnClose.text = Close" || nl, "btnClose.text = Close the list" || nl)
call check "a hand edit of the base table is kept", .OodDesign~fromSource(hand)~getProp("btnClose", "text") == "Close the list"

-- 6. the translator's file
x = d~exportLanguage("de")
call check "export: key = text, base above", x~pos("-- en: Close" || nl || "btnClose.text = Schließen") > 0
call check "export: untranslated key is empty", x~pos(nl || "mnuGrid.text =" || nl) > 0
x = x~changeStr("mnuGrid.text =" || nl, "mnuGrid.text = &Gitterlinien" || nl) || "nonsense.key = x" || nl
r = d~importLanguage("de", x)
call check "import sets the texts", d~stringIn("de", "mnuGrid.text") == "&Gitterlinien"
call check "import reports keys the design lacks", r~pos("not in the design: nonsense.key") > 0
call refuses "import into the base language", "d~importLanguage('en', 'x = y')"

-- 7. renames and removals carry the strings
d~setProp("btnClose", "name", "btnDone")
call check "rename: key follows", d~stringIn("de", "btnDone.text") == "Schließen"
d~setString("en", "mnuAdd.popup", "&Folk")
call check "renaming a menu renames it for all its items", d~getProp("mnuExit", "popup") == "&Folk"
call check "  and its German stays", d~stringIn("de", "mnuAdd.popup") == "&Personen"
d~removeControl("btnDone")
call check "remove: its keys go", d~nlsKeys~makeString("L", " ")~caselessPos("btnDone") = 0
d~removeString("msg.count")
call check "remove an event string", d~nlsKeys~lastItem == "mnuGrid.text"
d~setLanguages("en")
call check "a language taken out goes", d~generate~pos("::resource strings.de") = 0

-- 8. the language support at run time (the generated methods, without a dialog)
d = .viewsDesign~build
d~setLanguages("en de fr")
d~setString("de", "btnClose.text", "Schließen")
d~setString("fr", "btnClose.text", "Fermer")
d~addString("msg.of", "%1 of %2")
d~setString("de", "msg.of", "%1 von %2")
d~addString("msg.pct", "%1 % more, %9 stays")
d~setString("de", "msg.pct", "%1 % mehr, %9 bleibt")
call writeProbe d
call check "German by argument", probe("de", 'btnClose.text') == "Schließen"
call check "a region falls back to its language", probe("de_AT", 'btnClose.text') == "Schließen"
call check "an unknown language falls back to the base", probe("xx", 'btnClose.text') == "Close"
call check "de-AT is read as de_AT", probe("de-AT", 'btnClose.text') == "Schließen"
-- no argument: LC_ALL, LC_MESSAGES, then LANG; C and POSIX name no language
call value "LC_MESSAGES", "", "ENVIRONMENT"
call value "LC_ALL", "", "ENVIRONMENT"
call value "LANG", "de_DE.UTF-8", "ENVIRONMENT"
call check "no argument: LANG de_DE.UTF-8 gives German", probe("", 'btnClose.text') == "Schließen"
call value "LC_ALL", "C", "ENVIRONMENT"
call check "  LC_ALL=C is passed over", probe("", 'btnClose.text') == "Schließen"
call value "LC_ALL", "fr_CA.UTF-8", "ENVIRONMENT"
call check "  LC_ALL comes first", probe("", 'btnClose.text') == "Fermer"
call value "LC_ALL", "", "ENVIRONMENT"
call value "LANG", "", "ENVIRONMENT"
call check "  none set: the base", probe("", 'btnClose.text') == "Close"
call check "a key German lacks takes English", probe("de", 'form.title') == "Contacts"
call check "arguments fill %1 and %2", probe("de", 'msg.of', 3, 10) == "3 von 10"
call check "an argument holding %2 is put in as it is", probe("de", 'msg.of', "50%2", 10) == "50%2 von 10"
call check "a % that is no argument stays", probe("de", 'msg.pct', 7) == "7 % mehr, %9 bleibt"
call check "a missing key shows itself", probe("fr", 'no.such') == "<no.such>"
call check "an empty base text is a text, not a missing key", probe("de", 'lblInfo.text') == ""
call check "UTF-8 to Windows-1252 for ooDialog on Windows", probe("ansi", "Schließen Größe € …") == "Schlie" || "DF"x || "en Gr" || "F6DF"x || "e " || "80"x || " " || "85"x

say "t03_nls:" checks - fails "of" checks "checks passed"
return fails

-- the generated language support in a plain class, with the tables
writeProbe: procedure
  use arg pd
  out = .array~of("use arg lang, key, a1, a2", -
    "if lang == 'ansi' then return nlsAnsi(key)", -
    "t = .Probe~new", "t~nlsUse(lang)", -
    "if arg() = 2 then return t~nls(key)", "if arg() = 3 then return t~nls(key, a1)", "return t~nls(key, a1, a2)", -
    "::class Probe")
  pd~nlsMethods(out)
  pd~nlsRoutine(out)
  do lang over pd~languages
    out~append("::resource strings."lang)
    do l over pd~resourceTable(lang)
      out~append(l)
    end
    out~append("::END")
  end
  call write "nlsprobe.rex", out~makeString("L", "0a"x) || "0a"x
  return

probe: procedure
  use arg lang, key, a1, a2
  if arg() = 2 then return nlsprobe(lang, key)
  if arg() = 3 then return nlsprobe(lang, key, a1)
  return nlsprobe(lang, key, a1, a2)

parses: procedure
  use arg text
  signal on syntax name parseFailed
  -- without ooDialog here: parse it as a plain class
  text = text~changeStr('::requires "ooDialog.cls"', "")~changeStr("subclass UserDialog", "")
  r = .Routine~new("check", text~makeArray("0a"x))
  return .true
parseFailed:
  say "  (parse:" condition("O")~at("MESSAGE")")"
  return .false

write: procedure
  use arg file, text
  st = .stream~new(file)
  st~open("write replace")
  st~charOut(text)
  st~close
  return

check: procedure expose fails checks
  use arg ckLabel, ckOk
  checks = checks + 1
  if ckOk then say "  ok  " ckLabel
  else do
    say "  FAIL" ckLabel
    fails = fails + 1
  end
  return

refuses: procedure expose fails checks d
  use arg rfLabel, rfCode
  checks = checks + 1
  signal on syntax name rfRefused
  interpret rfCode
  say "  FAIL not refused:" rfLabel
  fails = fails + 1
  return
rfRefused:
  -- the designer's own refusal: Error 93.900 with its message, not any error
  if condition("O")~at("CODE") \== "93.900" | condition("O")~at("ADDITIONAL")~isA(.Array) = .false then do
    say "  FAIL refused, but not by the designer:" rfLabel "--" condition("O")~at("MESSAGE")
    fails = fails + 1
    return
  end
  say "  ok   refuses" rfLabel "--" condition("O")~at("ADDITIONAL")[1]~left(90)
  return

::requires "OodDesigner.cls"
::requires "views.rex"
