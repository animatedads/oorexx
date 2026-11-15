/* ContactsDE.rex -- an ooDialog program made with the ooDialog Designer 0.7.0
   Design: the ::RESOURCE oodDesign at the end.  The designer writes this
   whole file; what you type is the body of each event method.
   ooDialog Designer -- architecture: Tom Dyer; code: Claude (Opus 5.5). */
parse arg lang                     -- the language: de, fr_CA, ...
.ContactsDE~nlsChosen = lang~strip
dlg = .ContactsDE~new
if dlg~initCode \= 0 then return dlg~initCode
return dlg~execute("SHOWTOP")

::requires "ooDialog.cls"

::class ContactsDE subclass UserDialog


::method init
  forward class (super) continue
  self~nlsUse(self~class~nlsChosen, "en")
  self~create(0, 0, 220, 146, self~nls("form.title"), "CENTER")
  self~txtNotes_data = "Notes go here."

::method defineDialog
  self~createTab(100, 8, 6, 204, 14, "")
  self~createListView(101, 8, 24, 204, 90, "REPORT SHOWSELALWAYS")
  self~createEdit(102, 8, 24, 204, 90, "MULTILINE", "txtNotes_data")
  self~createStaticText(103, 8, 122, 140, 10, "", self~nls("lblInfo.text"))
  self~createPushButton(IDCANCEL, 156, 120, 56, 14, "", self~nls("btnClose.text"))
  self~connectListViewEvent(101, "SELECTCHANGED", "on_lvPeople_selectchanged")
  self~connectTabEvent(100, "SELCHANGE", "tabMain_pageChanged")

::method initDialog unguarded
  do t over self~nls("tabMain.tabs")~makeArray("|")
    self~tabMain~addSequence(t)
  end
  self~tabMain_show(1)
  self~lvPeople~addExtendedStyle("FULLROWSELECT GRIDLINES")
  i = 0
  do col over self~nls("lvPeople.columns")~makeArray("|")
    parse var col title ":" width
    if width == "" then width = 50
    self~lvPeople~insertColumn(i, title, width)
    i = i + 1
  end
  self~lvPeople~addRow( , , "Mike Cowlishaw", "Created Rexx", "1979")
  self~lvPeople~addRow( , , "Rick McGuire", "ooRexx interpreter", "1988")
  self~lvPeople~addRow( , , "Mark Miesfeld", "ooDialog", "2006")
  self~lvPeople~addRow( , , "Josep Maria Blasco", "ooRexx/WASM", "2026")
  menu = .UserMenuBar~new(9000, , , .false)
  menu~addPopup(9001, self~nls("mnuAdd.popup"), "")
  menu~addItem(105, self~nls("mnuAdd.text"), "", "on_mnuAdd_clicked")
  menu~addSeparator(106, "")
  menu~addItem(107, self~nls("mnuExit.text"), "END", "on_mnuExit_clicked")
  menu~addPopup(9002, self~nls("mnuGrid.popup"), "END")
  menu~addItem(108, self~nls("mnuGrid.text"), "CHECKED END", "on_mnuGrid_clicked")
  menu~complete
  menu~attachTo(self)

::method tabMain unguarded
  return self~newTab(100)
::method lvPeople unguarded
  return self~newListView(101)
::method txtNotes unguarded
  return self~newEdit(102)
::method lblInfo unguarded
  return self~newStatic(103)
::method btnClose unguarded
  return self~newPushButton(IDCANCEL)
::method mnuAdd unguarded
  return 105
::method mnuSep unguarded
  return 106
::method mnuExit unguarded
  return 107
::method mnuGrid unguarded
  return 108

::method tabMain_pageChanged unguarded
  self~tabMain_show(self~tabMain~selectedIndex + 1)
  forward message ("on_tabMain_selchange")

::method tabMain_show unguarded
  use strict arg page
  if page = 1 then self~lvPeople~show
  else self~lvPeople~hide
  if page = 2 then self~txtNotes~show
  else self~txtNotes~hide

::attribute nlsChosen class      -- the program's argument: rexx ContactsDE.rex de
-- Language support (OodNls.cls of the ooDialog Designer): texts are in
-- ::RESOURCE strings.<language> at the end (key = text).  self~nls(key, a1, a2, ...)
-- gives a key's text with %1, %2, ... replaced by a1, a2, ...; a key a language
-- lacks takes "en"'s.
::attribute nlsLanguage get

::method nlsUse unguarded
  expose nlsTable nlsLanguage
  use strict arg lang = "", base = "en", tables = (.resources)
  if lang == .nil then lang = ""
  if lang == "" then do var over .array~of("LC_ALL", "LC_MESSAGES", "LANG")
    lang = value(var, , "ENVIRONMENT")
    if lang \== "", lang~upper \== "C", lang~upper \== "POSIX" then leave
    lang = ""
  end
  parse var lang lang "." .                    -- de_DE.UTF-8: de_DE
  lang = lang~changeStr("-", "_")               -- de-AT: de_AT
  if tables["STRINGS."lang~upper] == .nil then lang = lang~left(2)
  if tables["STRINGS."lang~upper] == .nil then lang = base
  nlsLanguage = lang
  nlsTable = .directory~new
  parse source os .
  order = .array~of(base)
  if lang \== base then order~append(lang)
  do table over order
    lines = tables["STRINGS."table~upper]
    if lines == .nil then iterate
    do line over lines
      parse var line key "=" text
      key = key~strip
      if key == "" | key~left(2) == "--" then iterate
      text = text~strip("L")
      if text == "", table \== base then iterate   -- untranslated: the base's
      -- ooDialog on Windows takes ANSI text: the file is UTF-8
      if os~caselessPos("Windows") = 1 then text = nlsAnsi(text)
      nlsTable[key~upper] = text
    end
  end
  return lang

-- A key's text; %1, %2, ... take the arguments after the key.

::method nls unguarded
  expose nlsTable
  use strict arg key, ...
  text = nlsTable[key~upper]
  if text == .nil then return "<"key">"     -- a missing key shows itself
  if arg() = 1 then return text
  -- one pass: %n becomes argument n+1; what goes in is not looked at again
  out = ""
  i = 1
  do forever
    p = text~pos("%", i)
    if p = 0 then leave
    n = text~substr(p + 1)~verify("0123456789") - 1
    if n < 0 then n = text~length - p
    k = text~substr(p + 1, n)
    if n > 0, k > 0, k < arg() then do
      out = out || text~substr(i, p - i) || arg(k + 1)
      i = p + 1 + n
    end
    else do
      out = out || text~substr(i, p - i + 1)
      i = p + 1
    end
  end
  return out || text~substr(i)

-- Every key's text, key TAB text, keys as the table has them (upper case):
-- for a page that shows the texts.  (Not copied into programs.)  It is here
-- because only OodNls's own methods see its object variables.

::method on_tabMain_selchange unguarded
  self~lblInfo~setText("Page:" self~tabMain~selected)

::method on_lvPeople_selectchanged unguarded
  use arg id, item, state, list
  if state == "SELECTED" then self~lblInfo~setText(list~itemText(item) "--" list~itemText(item, 1))

::method on_mnuAdd_clicked unguarded
  self~lvPeople~addRow( , , "Rony Flatscher", "BSF4ooRexx", 2000)
  self~lblInfo~setText(self~nls("msg.count", self~lvPeople~items))

::method on_mnuExit_clicked unguarded
  self~cancel

::method on_mnuGrid_clicked unguarded
  if self~menuBar~isChecked(self~mnuGrid) then do
    self~menuBar~unCheck(self~mnuGrid)
    self~lvPeople~removeExtendedStyle("GRIDLINES")
  end
  else do
    self~menuBar~check(self~mnuGrid)
    self~lvPeople~addExtendedStyle("GRIDLINES")
  end
  self~lblInfo~setText("Grid lines:" self~menuBar~isChecked(self~mnuGrid))

::routine nlsAnsi
  use strict arg s
  if s~verify(xrange("00"x, "7F"x)) = 0 then return s
  special = "E282AC 80 E2809A 82 C692 83 E2809E 84 E280A6 85 E280A0 86 E280A1 87"
  special = special "CB86 88 E280B0 89 C5A0 8A E280B9 8B C592 8C C5BD 8E E28098 91 E28099 92"
  special = special "E2809C 93 E2809D 94 E280A2 95 E28093 96 E28094 97 CB9C 98 E284A2 99"
  special = special "C5A1 9A E280BA 9B C593 9C C5BE 9E C5B8 9F"
  out = ""
  i = 1
  do while i <= s~length
    c = s~subchar(i)
    b = c~c2d
    select
      when b < 128 then do
        out = out || c
        i = i + 1
      end
      when b = 194 | b = 195 then do   -- C2 xx, C3 xx: U+0080 to U+00FF
        out = out || d2c(s~subchar(i + 1)~c2d + 64 * (b - 194))
        i = i + 2
      end
      otherwise do
        n = 2
        if b >= 224 then n = 3
        if b >= 240 then n = 4
        k = wordpos(s~substr(i, n)~c2x, special)
        if k > 0 then out = out || special~word(k + 1)~x2c
        else out = out || "?"
        i = i + n
      end
    end
  end
  return out

::resource strings.en
form.title = Contacts
tabMain.tabs = People|Notes
lvPeople.columns = Name:80|Role:84|Since:30
lblInfo.text =
btnClose.text = Close
mnuAdd.popup = &People
mnuAdd.text = &Add a Rexx person
mnuExit.text = E&xit
mnuGrid.popup = &View
mnuGrid.text = &Grid lines
msg.count = %1 people
::END
::resource strings.de
form.title = Kontakte
tabMain.tabs = Personen|Notizen
lvPeople.columns = Name:80|Rolle:84|Seit:30
btnClose.text = Schließen
mnuAdd.popup = &Personen
mnuAdd.text = Rexx-Person &hinzufügen
mnuExit.text = &Beenden
mnuGrid.popup = &Ansicht
mnuGrid.text = &Gitterlinien
msg.count = %1 Personen
::END
::resource oodDesign
designer version=0.7.0
form name=ContactsDE title=Contacts w=220 h=146 style=CENTER
languages list="en de"
control type=TAB name=tabMain id=100 x=8 y=6 w=204 h=14 tabs=People|Notes opts=""
control type=LISTVIEW name=lvPeople id=101 x=8 y=24 w=204 h=90 columns=Name:80|Role:84|Since:30 rows="Mike Cowlishaw;Created Rexx;1979|Rick McGuire;ooRexx interpreter;1988|Mark Miesfeld;ooDialog;2006|Josep Maria Blasco;ooRexx/WASM;2026" exstyles="FULLROWSELECT GRIDLINES" opts="REPORT SHOWSELALWAYS" page=tabMain:1
control type=EDIT name=txtNotes id=102 x=8 y=24 w=204 h=90 text="Notes go here." opts=MULTILINE page=tabMain:2
control type=STATIC name=lblInfo id=103 x=8 y=122 w=140 h=10 text="" opts=""
control type=PUSHBUTTON name=btnClose id=104 x=156 y=120 w=56 h=14 text=Close role=CANCEL opts=""
control type=MENUITEM name=mnuAdd id=105 x=0 y=0 w=0 h=0 popup=&People text="&Add a Rexx person" checked=0 grayed=0
control type=MENUITEM name=mnuSep id=106 x=0 y=0 w=0 h=0 popup=&People text=- checked=0 grayed=0
control type=MENUITEM name=mnuExit id=107 x=0 y=0 w=0 h=0 popup=&People text=E&xit checked=0 grayed=0
control type=MENUITEM name=mnuGrid id=108 x=0 y=0 w=0 h=0 popup=&View text="&Grid lines" checked=1 grayed=0
string key=msg.count
event control=tabMain event=SELCHANGE thread=ui
event control=lvPeople event=SELECTCHANGED thread=ui
event control=mnuAdd event=CLICKED thread=ui
event control=mnuExit event=CLICKED thread=ui
event control=mnuGrid event=CLICKED thread=ui
::END
