/* t22: the StatusBar control, the old addXxx names of the create methods, the dialog's
   background colour, the list-view's colours and column order. */
dlg = .Main~new
dlg~create(30, 30, 240, 150, "Status bar", "CENTER")
dlg~execute("SHOWTOP")
return 0

::requires "ooDialog.cls"

::class Main subclass UserDialog
::method defineDialog
  self~createStatusBar(50, 0, 0, 0, 0)
  self~addButton(201, 5, 5, 60, 14, "Parts", onParts)
  self~addButton(202, 70, 5, 60, 14, "Simple", onSimple, "GROUP")
  self~addCheckBox(203, , 5, 25, 60, 12, "A check box")
  self~addRadioButton(204, , 70, 25, 60, 12, "A radio")
  self~addEntryLine(205, , 5, 42, 60, 12)
  self~addGroupBox(140, 2, 90, 40, "Old names", , 206)
  self~addListBox(207, , 5, 60, 60, 40)
  self~addListControl(208, , 70, 60, 160, 40, "REPORT")
  self~createPushButton(1, 185, 115, 50, 14, "DEFAULT", "Close")
::method initDialog
  bar = self~newStatusBar(50)
  say "start" bar~getParts bar~isSimple bar~setText("Ready", 1) bar~getText(1) bar~getTextLength(1)
  say "background" self~backgroundColor(.Image~colorRef(200, 220, 240)) self~backgroundSysColor(99)
  list = self~newListView(208)
  list~insertColumn(0, "One", 40); list~insertColumn(1, "Two", 40)
  list~bkColor = .Image~colorRef(255, 255, 200)
  list~textColor = .Image~colorRef(128, 0, 0)
  say "lv" list~bkColor list~textColor list~textBkColor list~getColumnOrder~toString("L", " ") list~setColumnOrder(.array~of(0, 1)) list~setColumnOrder(.array~of(1, 0)) (list~stringWidthPx("some text") > 20)
::method onParts unguarded
  bar = self~newStatusBar(50)
  edges = .array~new
  say "setParts" bar~setParts(.array~of(80, 160, -1)) bar~getParts(edges) edges~toString("L", " ")
  say "texts" bar~setText("left", 1) bar~setText("middle", 2) bar~setText("right", 3) bar~setText("none", 4) bar~getText(2) (bar~getText(4) == "")
  r = bar~getRect(2)
  say "rect" r~left r~right (bar~getRect(9) == .nil) bar~setTipText("a tip", 2) bar~getTipText(2)
  old = bar~setBkColor(.Image~colorRef(255, 255, 0))
  say "bk" old bar~setBkColor(old)
::method onSimple unguarded
  bar = self~newStatusBar(50)
  bar~simple(.true)
  say "simple" bar~isSimple bar~setText("one text", 256) bar~getText(256)
