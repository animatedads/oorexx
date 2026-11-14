/* views.rex -- the "Tabs, list view and menu" example: a tab strip whose
   pages hold controls (the program shows and hides them), a report list
   view, and a menu bar whose items are designer controls with events.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx views.rex [out.rex]                                          */
parse arg outFile
d = .viewsDesign~build
if outFile \= "" then do
  st = .stream~new(outFile~strip)
  st~open("write replace")
  st~charOut(d~generate)
  st~close
  say "views: wrote" outFile~strip
end
return d

::requires "OodDesigner.cls"

::class viewsDesign public
::method build class
  d = .OodDesign~new("Contacts")
  d~setProp("form", "title", "Contacts")
  d~setProp("form", "w", 220)
  d~setProp("form", "h", 146)

  n = d~addControl("TAB", 8, 6)
  d~setProp(n, "name", "tabMain")
  d~setGeometry("tabMain", 8, 6, 204, 14)
  d~setProp("tabMain", "tabs", "People|Notes")
  n = d~addControl("LISTVIEW", 8, 24)
  d~setProp(n, "name", "lvPeople")
  d~setGeometry("lvPeople", 8, 24, 204, 90)
  d~setProp("lvPeople", "columns", "Name:80|Role:84|Since:30")
  d~setProp("lvPeople", "rows", "Mike Cowlishaw;Created Rexx;1979|Rick McGuire;ooRexx interpreter;1988|Mark Miesfeld;ooDialog;2006|Josep Maria Blasco;ooRexx/WASM;2026")
  d~setProp("lvPeople", "exstyles", "FULLROWSELECT GRIDLINES")
  d~setProp("lvPeople", "page", "tabMain:1")
  n = d~addControl("EDIT", 8, 24)
  d~setProp(n, "name", "txtNotes")
  d~setGeometry("txtNotes", 8, 24, 204, 90)
  d~setProp("txtNotes", "opts", "MULTILINE")
  d~setProp("txtNotes", "text", "Notes go here.")
  d~setProp("txtNotes", "page", "tabMain:2")
  n = d~addControl("STATIC", 8, 120)
  d~setProp(n, "name", "lblInfo")
  d~setGeometry("lblInfo", 8, 122, 140, 10)
  d~setProp("lblInfo", "text", "")
  n = d~addControl("PUSHBUTTON", 156, 120)
  d~setProp(n, "name", "btnClose")
  d~setGeometry("btnClose", 156, 120, 56, 14)
  d~setProp("btnClose", "text", "Close")
  d~setProp("btnClose", "role", "CANCEL")

  -- the menu bar: items are controls; popup names the menu each is in
  n = d~addControl("MENUITEM", 0, 0)
  d~setProp(n, "name", "mnuAdd")
  d~setProp("mnuAdd", "popup", "&People")
  d~setProp("mnuAdd", "text", "&Add a Rexx person")
  n = d~addControl("MENUITEM", 0, 0)
  d~setProp(n, "name", "mnuSep")
  d~setProp("mnuSep", "text", "-")
  n = d~addControl("MENUITEM", 0, 0)
  d~setProp(n, "name", "mnuExit")
  d~setProp("mnuExit", "text", "E&xit")
  n = d~addControl("MENUITEM", 0, 0)
  d~setProp(n, "name", "mnuGrid")
  d~setProp("mnuGrid", "popup", "&View")
  d~setProp("mnuGrid", "text", "&Grid lines")
  d~setProp("mnuGrid", "checked", "1")

  d~setEventCode("lvPeople", "SELECTCHANGED", -
    'use arg id, item, state, list'                                    || "0a"x || -
    'if state == "SELECTED" then self~lblInfo~setText(list~itemText(item) "--" list~itemText(item, 1))')
  d~setEventCode("tabMain", "SELCHANGE", 'self~lblInfo~setText("Page:" self~tabMain~selected)')
  d~setEventCode("mnuAdd", "CLICKED", -
    'self~lvPeople~addRow( , , "Rony Flatscher", "BSF4ooRexx", 2000)'   || "0a"x || -
    'self~lblInfo~setText(self~lvPeople~items "people")')
  d~setEventCode("mnuGrid", "CLICKED", -
    'if self~menuBar~isChecked(self~mnuGrid) then do'                  || "0a"x || -
    '  self~menuBar~unCheck(self~mnuGrid)'                             || "0a"x || -
    '  self~lvPeople~removeExtendedStyle("GRIDLINES")'                 || "0a"x || -
    'end'                                                              || "0a"x || -
    'else do'                                                          || "0a"x || -
    '  self~menuBar~check(self~mnuGrid)'                               || "0a"x || -
    '  self~lvPeople~addExtendedStyle("GRIDLINES")'                    || "0a"x || -
    'end'                                                              || "0a"x || -
    'self~lblInfo~setText("Grid lines:" self~menuBar~isChecked(self~mnuGrid))')
  d~setEventCode("mnuExit", "CLICKED", 'self~cancel')
  return d
