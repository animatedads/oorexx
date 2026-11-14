/* t04: a UserMenuBar built from the menu template methods, attached to a
   dialog; command events, check state, a disabled item, an inserted item. */
dlg = .MenuDlg~new
dlg~create(30, 30, 220, 90, "Menus", "CENTER")
dlg~execute("SHOWTOP")
say "log:" dlg~log
return 0

::requires "ooDialog.cls"

::class MenuDlg subclass UserDialog
::attribute log
::method defineDialog
  self~log = ""
  self~createStaticText(100, 10, 20, 200, 10, , "Use the menu.")
  self~createPushButton(IDOK, 160, 68, 50, 14, "DEFAULT", "Close")

::method initDialog
  expose menu
  menu = .UserMenuBar~new(500, , , .false)
  menu~addPopup(200, "&File")
  menu~addItem(201, "&Open..." || "09"~x2c || "Ctrl+O", , onOpen)
  menu~addItem(204, "&Print", "GRAYED", onPrint)
  menu~addSeparator(202)
  menu~addItem(203, "E&xit", "END", onExit)
  menu~addPopup(210, "&View", "END")
  menu~addItem(211, "&Toolbar", "CHECKED", onToggle)
  menu~addItem(212, "&Status bar", "END", onToggle)
  self~log = "complete" menu~complete "attached" menu~attachTo(self)
  menu~insertItem(212, 213, "&Ruler", , , .false, .true, onToggle)
  self~log = self~log "count" menu~getPopup(210)~getCount "text" menu~getText(203) "checked" menu~isChecked(211) "print enabled" menu~isEnabled(204)

::method onOpen unguarded
  self~newStatic(100)~setText("Open chosen")
  self~log = self~log "open"
::method onPrint unguarded
  self~log = self~log "print"
::method onToggle unguarded
  expose menu
  use arg info
  id = .DlgUtil~loWord(info)
  if menu~isChecked(id) then menu~unCheck(id)
  else menu~check(id)
  self~log = self~log "toggle" id menu~isChecked(id)
::method onExit unguarded
  self~log = self~log "exit"
  return self~ok
