/* languages.rex -- the Contacts example in English and German: its texts in
   ::RESOURCE strings.en and strings.de, an event string with %1.  Shared by
   tools/build.rex (site/examples/ContactsDE.rex) and tests/wincheck.rex.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx languages.rex [out.rex]                                       */
parse arg outFile
d = .contactsDeDesign~build
if outFile \= "" then do
  st = .stream~new(outFile~strip)
  st~open("write replace")
  st~charOut(d~generate)
  st~close
  say "languages: wrote" outFile~strip
end
return d

::requires "OodDesigner.cls"
::requires "views.rex"

::class contactsDeDesign public
::method build class
  d = .viewsDesign~build
  d~setProp("form", "name", "ContactsDE")
  d~setLanguages("en de")
  d~setString("de", "form.title", "Kontakte")
  d~setString("de", "tabMain.tabs", "Personen|Notizen")
  d~setString("de", "lvPeople.columns", "Name:80|Rolle:84|Seit:30")
  d~setString("de", "btnClose.text", "Schließen")
  d~setString("de", "mnuAdd.popup", "&Personen")
  d~setString("de", "mnuAdd.text", "Rexx-Person &hinzufügen")
  d~setString("de", "mnuExit.text", "&Beenden")
  d~setString("de", "mnuGrid.popup", "&Ansicht")
  d~setString("de", "mnuGrid.text", "&Gitterlinien")
  d~addString("msg.count", "%1 people")
  d~setString("de", "msg.count", "%1 Personen")
  d~setEventCode("mnuAdd", "CLICKED", -
    'self~lvPeople~addRow( , , "Rony Flatscher", "BSF4ooRexx", 2000)' || "0a"x || -
    'self~lblInfo~setText(self~nls("msg.count", self~lvPeople~items))')
  return d
