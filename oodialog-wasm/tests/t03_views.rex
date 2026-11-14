/* t03: list-view (report), tree-view and tab in a UserDialog, with events. */
dlg = .Views~new
dlg~create(30, 30, 300, 190, "Views", "CENTER")
dlg~execute("SHOWTOP")
say "log:" dlg~log
return 0

::requires "ooDialog.cls"

::class Views subclass UserDialog
::attribute log
::method defineDialog
  self~log = ""
  self~createTab(100, 6, 6, 288, 20)
  self~createListView(101, 10, 30, 170, 110, "REPORT SHOWSELALWAYS")
  self~createTreeView(102, 186, 30, 104, 110, "LINES BUTTONS ATROOT")
  self~createStaticText(103, 10, 146, 280, 10, , "")
  self~createPushButton(IDOK, 240, 168, 50, 14, "DEFAULT", "Close")
  self~connectListViewEvent(101, "SELECTCHANGED", onRow)
  self~connectListViewEvent(101, "COLUMNCLICK", onColumn)
  self~connectListViewEvent(101, "CHECKBOXCHANGED", onCheck)
  self~connectTreeViewEvent(102, "SELCHANGED", onNode)
  self~connectTabEvent(100, "SELCHANGE", onTab)

::method initDialog
  tab = self~newTab(100)
  tab~addSequence("Rexx people", "Second", "Third")
  list = self~newListView(101)
  list~addExtendedStyle("FULLROWSELECT GRIDLINES CHECKBOXES")
  list~insertColumnPx(0, "Name", 110)
  list~insertColumnPx(1, "Role", 130)
  list~insertColumnPx(2, "Since", 60, "RIGHT")
  list~addRow( , , "Mike Cowlishaw", "Created Rexx", 1979)
  list~addRow( , , "Rick McGuire", "ooRexx interpreter", 1988)
  list~addRow( , , "Mark Miesfeld", "ooDialog", 2006)
  list~addRow( , , "Josep Maria Blasco", "ooRexx/WASM", 2026)
  list~setItemText(1, 1, "ooRexx kernel")
  tree = self~newTreeView(102)
  root = tree~add("ooRexx", , , "BOLD EXPANDED")
  tree~add( , "Interpreter")
  ext = tree~add( , "Extensions", , , "EXPANDED")
  tree~add( , , "ooDialog")
  tree~add( , , "RxSock")
  self~log = "rows" list~items "cols" list~getColumnCount "cell" list~itemText(1, 1) "nodes" tree~items "tabs" tab~items

::method onRow unguarded
  use arg id, item, state, list
  if state == "SELECTED" then do
    self~newStatic(103)~setText("Selected:" list~itemText(item) "(" || list~itemText(item, 1) || ")")
    self~log = self~log "sel" item
  end
::method onColumn unguarded
  use arg id, column, list
  self~log = self~log "col" column
::method onCheck unguarded
  use arg id, item, state, list
  self~log = self~log "chk" item state list~isChecked(item)
::method onNode unguarded
  use arg id, old, oldData, new, newData, action, tree
  self~log = self~log "node" tree~itemText(new) "parent" tree~itemText(tree~parent(new))
::method onTab unguarded
  use arg id, hwnd, tab
  self~log = self~log "tab" tab~selectedIndex tab~selected
