/* Contacts.rex -- an ooDialog program made with the ooDialog Designer 0.13.0
   Design: the ::RESOURCE oodDesign at the end.  The designer writes this
   whole file; what you type is the body of each event method.
   ooDialog Designer -- architecture: Tom Dyer; code: Claude (Opus 5.5). */
dlg = .Contacts~new
if dlg~initCode \= 0 then return dlg~initCode
return dlg~execute("SHOWTOP")

::requires "ooDialog.cls"

::class Contacts subclass UserDialog


::method init
  forward class (super) continue
  self~create(0, 0, 220, 146, "Contacts", "CENTER")
  self~txtNotes_data = "Notes go here."

::method defineDialog
  self~createTab(100, 8, 6, 204, 14, "")
  self~createListView(101, 8, 24, 204, 90, "REPORT SHOWSELALWAYS")
  self~createEdit(102, 8, 24, 204, 90, "MULTILINE", "txtNotes_data")
  self~createStaticText(103, 8, 122, 140, 10, "", "")
  self~createPushButton(IDCANCEL, 156, 120, 56, 14, "", "Close")
  self~connectListViewEvent(101, "SELECTCHANGED", "on_lvPeople_selectchanged")
  self~connectTabEvent(100, "SELCHANGE", "tabMain_pageChanged")

::method initDialog unguarded
  self~tabMain~addSequence("People", "Notes")
  self~tabMain_show(1)
  self~lvPeople~addExtendedStyle("FULLROWSELECT GRIDLINES")
  self~lvPeople~insertColumn(0, "Name", 80)
  self~lvPeople~insertColumn(1, "Role", 84)
  self~lvPeople~insertColumn(2, "Since", 30)
  self~lvPeople~addRow( , , "Mike Cowlishaw", "Created Rexx", "1979")
  self~lvPeople~addRow( , , "Rick McGuire", "ooRexx interpreter", "1988")
  self~lvPeople~addRow( , , "Mark Miesfeld", "ooDialog", "2006")
  self~lvPeople~addRow( , , "Josep Maria Blasco", "ooRexx/WASM", "2026")
  menu = .UserMenuBar~new(9000, , , .false)
  menu~addPopup(9001, "&People", "")
  menu~addItem(105, "&Add a Rexx person", "", "on_mnuAdd_clicked")
  menu~addSeparator(106, "")
  menu~addItem(107, "E&xit", "END", "on_mnuExit_clicked")
  menu~addPopup(9002, "&View", "END")
  menu~addItem(108, "&Grid lines", "CHECKED END", "on_mnuGrid_clicked")
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

::method on_tabMain_selchange unguarded
  self~lblInfo~setText("Page:" self~tabMain~selected)

::method on_lvPeople_selectchanged unguarded
  use arg id, item, state, list
  if state == "SELECTED" then self~lblInfo~setText(list~itemText(item) "--" list~itemText(item, 1))

::method on_mnuAdd_clicked unguarded
  self~lvPeople~addRow( , , "Rony Flatscher", "BSF4ooRexx", 2000)
  self~lblInfo~setText(self~lvPeople~items "people")

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

::resource oodDesign
designer version=0.13.0
form name=Contacts title=Contacts w=220 h=146 style=CENTER
control type=TAB name=tabMain id=100 x=8 y=6 w=204 h=14 tabs=People|Notes opts=""
control type=LISTVIEW name=lvPeople id=101 x=8 y=24 w=204 h=90 columns=Name:80|Role:84|Since:30 rows="Mike Cowlishaw;Created Rexx;1979|Rick McGuire;ooRexx interpreter;1988|Mark Miesfeld;ooDialog;2006|Josep Maria Blasco;ooRexx/WASM;2026" exstyles="FULLROWSELECT GRIDLINES" opts="REPORT SHOWSELALWAYS" page=tabMain:1
control type=EDIT name=txtNotes id=102 x=8 y=24 w=204 h=90 text="Notes go here." opts=MULTILINE page=tabMain:2
control type=STATIC name=lblInfo id=103 x=8 y=122 w=140 h=10 text="" opts=""
control type=PUSHBUTTON name=btnClose id=104 x=156 y=120 w=56 h=14 text=Close role=CANCEL opts=""
control type=MENUITEM name=mnuAdd id=105 x=0 y=0 w=0 h=0 popup=&People text="&Add a Rexx person" checked=0 grayed=0
control type=MENUITEM name=mnuSep id=106 x=0 y=0 w=0 h=0 popup=&People text=- checked=0 grayed=0
control type=MENUITEM name=mnuExit id=107 x=0 y=0 w=0 h=0 popup=&People text=E&xit checked=0 grayed=0
control type=MENUITEM name=mnuGrid id=108 x=0 y=0 w=0 h=0 popup=&View text="&Grid lines" checked=1 grayed=0
event control=tabMain event=SELCHANGE thread=ui
event control=lvPeople event=SELECTCHANGED thread=ui
event control=mnuAdd event=CLICKED thread=ui
event control=mnuExit event=CLICKED thread=ui
event control=mnuGrid event=CLICKED thread=ui
::END
