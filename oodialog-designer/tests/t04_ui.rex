/* t04_ui.rex -- the designer's own texts (OodUi.cls): every language has every
   key, with the same %n; the page and the graph use only keys there are; the
   designer refuses in the language chosen.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
   usage: rexx t04_ui.rex SITE_DIR      (OodUi.cls, OodNls.cls, OodDesigner.cls on REXX_PATH) */
parse arg site
site = site~strip
if site~left(1) == '"' & site~right(1) == '"' & site~length > 1 then site = site~substr(2, site~length - 2)   -- quotes a Windows shell leaves
if site == "" then site = "site"
fails = 0
checks = 0

-- 1. the tables: every language has every key of the base, with the same %n
langs = .OodUi~languages
call check "languages: en first, de there", langs~word(1) == "en" & langs~wordpos("de") > 0
base = tableOf("en")
do lang over langs~makeArray(" ")
  if lang == "en" then iterate
  t = tableOf(lang)
  missing = .array~new
  extra = .array~new
  badArgs = .array~new
  do k over base~allIndexes
    if \t~hasIndex(k) then missing~append(k)
    else if placeholders(base[k]) \== placeholders(t[k]) then badArgs~append(k)
  end
  do k over t~allIndexes
    if \base~hasIndex(k) then extra~append(k)
  end
  call check lang": every key of en" listOf(missing), missing~items = 0
  call check lang": no key en has not" listOf(extra), extra~items = 0
  call check lang": the same %n as en" listOf(badArgs), badArgs~items = 0
end
call check "the tables are big enough to be the whole designer", base~items > 300

-- 2. the page and the graph use only keys the base table has
used = .set~new
html = readFile(site"/designer.html")
do attr over .array~of('data-nls="', 'data-nls-title="', 'data-nls-placeholder="', 'data-nls-aria="', 'data-nls-rich="')
  call collect html, attr, '"', used
end
do f over .array~of("designer.js", "graph.js", "plugins.js")
  js = readFile(site"/"f)
  call collect js, "T('", "'", used
  do m over .array~of("graph.moved", "graph.inserted", "graph.insertedAction", "graph.changed", "graph.deleted", "graph.wrapped")
    if js~pos("'"m"'") > 0 then used~put(m)
  end
end
unknown = .array~new
do k over used
  if k~right(1) == "." then iterate                -- a prefix: graph.explain.<kind>
  if \base~hasIndex(k~upper) then unknown~append(k)
end
call check "every key the page uses is in the table" listOf(unknown), unknown~items = 0
call check "  (and the page uses many)", used~items > 140
-- each control kind and action of the catalogue has its text
d = .OodDesign~new("T")
cat = .OodCatalog~catalogText
noText = .array~new
do line over cat~makeArray("0a"x)
  f = oodFields(line)
  if f["*"] == "kind" then if \base~hasIndex(("kind."f["TYPE"])~upper) then noText~append("kind."f["TYPE"])
end
call check "every control kind has its label" listOf(noText), noText~items = 0
actions = .set~new
do ctl over .array~of("PUSHBUTTON", "LISTBOX", "CHECKBOX", "PROGRESSBAR", "LISTVIEW", "TAB", "TREEVIEW", "TRACKBAR", "DATETIME", "MENUITEM", "TIMER")
  n = d~addControl(ctl, 0, 0)
  do l over d~actionsFor(n)~makeArray("0a"x)
    parse var l label "09"x .
    actions~put(label)
  end
end
do l over d~actionsFor("form")~makeArray("0a"x)
  parse var l label "09"x .
  actions~put(label)
end
noText = .array~new
do a over actions
  if \base~hasIndex(("action."a)~upper) then noText~append(a)
end
call check "every action has its label ("actions~items")" listOf(noText), noText~items = 0

-- 3. the designer speaks the language chosen
call check "use de-DE: de", .OodUi~use("de-DE") == "de"
call check "a text in German", .OodUi~text("btn.close") == "Schließen"
call check "%1 in German", .OodUi~text("st.added", "btn1")~pos("btn1 hinzugefügt.") = 1
m = refusal("d~setProp('form', 'name', '1abc')")
call check "a refusal in German:" m, m == "Der Name 1abc muss mit einem Buchstaben oder _ beginnen"
m = refusal(".OodGraph~new('if a then b = 1')~insertCode(1, 'then', 1, 'nop')")
call check "a graph refusal in German:" m, m~pos("erst in do...end einschließen") > 0
call check "use fr (none): en", .OodUi~use("fr") == "en"
m = refusal("d~setProp('form', 'name', '1abc')")
call check "a refusal in English:" m, m == "Name 1abc must start with a letter or _"

say "t04_ui:" checks - fails "of" checks "checks passed"
return fails

-- a language's table: key (upper) -> text
tableOf: procedure
  use arg lang
  t = .directory~new
  do l over .OodUi~package~resources["STRINGS."lang~upper]
    if l~strip == "" | l~strip~left(2) == "--" then iterate
    parse var l key "=" text
    t[key~strip~upper] = text~strip("L")
  end
  return t

-- the %n a text has, in order: "%1 %2"
placeholders: procedure
  use arg text
  found = .array~new
  p = text~pos("%")
  do while p > 0
    n = text~substr(p + 1)~verify("0123456789") - 1
    if n < 0 then n = text~length - p
    if n > 0 then found~append(text~substr(p + 1, n))
    p = text~pos("%", p + 1)
  end
  return found~sort~makeString("L", " ")

-- every text between start and stop in text, into the set
collect: procedure
  use arg text, start, stop, set
  if set == .nil then return
  p = text~pos(start)
  do while p > 0
    q = text~pos(stop, p + length(start))
    if q > 0 then set~put(text~substr(p + length(start), q - p - length(start)))
    p = text~pos(start, p + 1)
  end
  return

readFile: procedure
  use arg file
  s = .stream~new(file)
  text = s~charIn(1, s~chars)
  s~close
  return text

listOf: procedure
  use arg list
  if list~items = 0 then return ""
  return "--" list~makeArray~makeString("L", " ")

refusal: procedure expose d
  use arg code
  signal on syntax name refused
  interpret code
  return "(not refused)"
refused:
  return condition("O")~at("ADDITIONAL")[1]

check: procedure expose fails checks
  use arg ckLabel, ckOk
  checks = checks + 1
  if ckOk then say "  ok  " ckLabel
  else do
    say "  FAIL" ckLabel
    fails = fails + 1
  end
  return

::requires "OodUi.cls"
::requires "OodDesigner.cls"
::requires "OodGraph.cls"
