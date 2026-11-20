/* t29: a property sheet shown with popupAsChild: the dialog that opened it goes on working */
dlg = .Owner~new
dlg~execute("SHOWTOP")
say "owner ended, sheet said:" dlg~said
return 0

::requires "ooDialog.cls"

::class Owner subclass UserDialog
::attribute said
::method init
  forward class (super) continue
  self~said = ""
  self~create(30, 30, 180, 70, "Owner")
::method defineDialog
  self~createPushButton(101, 10, 10, 60, 14, , "Open sheet", onOpen)
  self~createPushButton(102, 80, 10, 60, 14, , "Count", onCount)
  self~createStaticText(103, 10, 30, 150, 10, , "count 0")
  self~createPushButton(IDCANCEL, 10, 48, 60, 14, , "Leave")
::method onOpen unguarded
  expose sheet
  p1 = .Page~new( , , , "Alpha")
  p2 = .Page~new( , , , "Beta")
  sheet = .Sheet~new(.array~of(p1, p2), , "Popped")
  sheet~owner = self
  say "popup" sheet~popupAsChild(self)
::method onCount unguarded
  expose count
  if \var("COUNT") then count = 0
  count += 1
  self~newStatic(103)~setText("count" count)

::class Sheet subclass PropertySheetDialog
::attribute owner
::method leaving unguarded
  self~owner~said = "closed"

::class Page subclass UserPSPDialog
::method defineDialog
  self~createStaticText(-1, 10, 10, 150, 10, , "Page" self~pageTitle)
::method init
  forward class (super) continue
  self~cx = 170
  self~cy = 50
