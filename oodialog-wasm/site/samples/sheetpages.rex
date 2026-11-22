/* t27: a PropertySheetDialog whose pages are added, inserted and removed while it is shown;
   its buttons pressed and renamed from the program; page IDs and indexes. */
p1 = .Page~new( , , , "First")
p2 = .Page~new( , , , "Second")
sheet = .Sheet~new(.array~of(p1, p2), , "Pages")
say "before" sheet~addPage(.Page~new( , , , "Third")) sheet~pages~items
ret = sheet~execute
say "execute" ret
say "log:" sheet~log
return 0

::requires "ooDialog.cls"

::class Sheet subclass PropertySheetDialog
::attribute log
::method initDialog
  self~log = ""
  self~setButtonText("OK", "Done")

::class Page subclass UserPSPDialog
::method defineDialog
  self~createStaticText(-1, 10, 10, 150, 10, , "Page" self~pageTitle)
  self~createPushButton(301, 10, 30, 50, 14, , "Insert", onInsert)
  self~createPushButton(302, 65, 30, 50, 14, , "Remove", onRemove)
  self~createPushButton(303, 120, 30, 50, 14, , "Report", onReport)
  self~createPushButton(304, 10, 50, 50, 14, , "Apply it", onApply)
::method init
  forward class (super) continue
  self~cx = 190
  self~cy = 80
::method setActive
  use arg sheet
  sheet~log = sheet~log "active:"self~pageTitle
  return 0
::method apply
  use arg isOk, index, current, sheet
  sheet~log = sheet~log "apply:"self~pageTitle":"isOk
  return 0
::method onInsert unguarded
  sheet = self~propSheet
  say "insert" sheet~insertPage(.Page~new( , , , "Inserted"), 1) sheet~pages~items sheet~insertPage(self, 1)
::method onRemove unguarded
  sheet = self~propSheet
  say "remove" sheet~removePage(1) sheet~pages~items sheet~removePage(99)
::method onReport unguarded
  sheet = self~propSheet
  id = sheet~indexToID(self~pageNumber)
  say "ids" self~pageNumber (id == self~hwnd) sheet~idToIndex(id) sheet~hwndToIndex(self~hwnd) sheet~idToIndex("0x0000000000000042") sheet~indexToID(99) (sheet~indexToHwnd(self~pageNumber) == self~hwnd)
  say "byID" sheet~setCurSelByID("0x0000000000000042") sheet~setCurSelByID(id)
::method onApply unguarded
  sheet = self~propSheet
  sheet~changed(self)
  say "apply" sheet~apply
  sheet~pressButton("OK")
