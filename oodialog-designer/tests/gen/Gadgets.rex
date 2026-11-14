/* Gadgets.rex -- an ooDialog program made with the ooDialog Designer 0.3.0
   Design: the ::RESOURCE oodDesign at the end.  The designer writes this
   whole file; what you type is the body of each event method.
   ooDialog Designer -- architecture: Tom Dyer; code: Claude (Opus 5.5). */
dlg = .Gadgets~new
if dlg~initCode \= 0 then return dlg~initCode
return dlg~execute("SHOWTOP")

::requires "ooDialog.cls"

::class Gadgets subclass UserDialog


::method init
  forward class (super) continue
  self~create(0, 0, 220, 120, "Tree view, track bar, date picker", "CENTER")

::method defineDialog
  self~createTreeView(100, 8, 8, 96, 86, "LINES BUTTONS ATROOT SHOWSELALWAYS")
  self~createTrackBar(101, 112, 8, 100, 16, "HORIZONTAL AUTOTICKS")
  self~createPushButton(102, 112, 28, 100, 14, "", "&Read the level")
  self~createDateTimePicker(103, 112, 50, 100, 12, "SHORT")
  self~createStaticText(104, 112, 70, 100, 24, "", "")
  self~createPushButton(IDCANCEL, 156, 100, 56, 14, "", "Close")
  self~connectTreeViewEvent(100, "SELCHANGED", "on_tvRexx_selchanged")
  self~connectButtonEvent(102, "CLICKED", "on_btnRead_clicked")
  self~connectDateTimePickerEvent(103, "DATETIMECHANGE", "on_dtpWhen_datetimechange")

::method initDialog unguarded
  self~tvRexx~add("ooRexx", , , "EXPANDED")
  self~tvRexx~add( , "Interpreter")
  self~tvRexx~add( , "Extensions", , , "EXPANDED")
  self~tvRexx~add( , , "ooDialog")
  self~tvRexx~add( , , "RxSock")
  self~tvRexx~add( , , "BSF4ooRexx")
  self~tvRexx~add("Classic Rexx", , , "EXPANDED")
  self~tvRexx~add( , "Regina")
  self~trkLevel~initRange(0, 50)
  self~trkLevel~pos = 30

::method tvRexx unguarded
  return self~newTreeView(100)
::method trkLevel unguarded
  return self~newTrackBar(101)
::method btnRead unguarded
  return self~newPushButton(102)
::method dtpWhen unguarded
  return self~newDateTimePicker(103)
::method lblOut unguarded
  return self~newStatic(104)
::method btnClose unguarded
  return self~newPushButton(IDCANCEL)

::method on_tvRexx_selchanged unguarded
  use arg id, old, oldData, new, newData, action, tree
  self~lblOut~setText("Node:" tree~itemText(new))

::method on_btnRead_clicked unguarded
  self~lblOut~setText("Level:" self~trkLevel~pos)

::method on_dtpWhen_datetimechange unguarded
  use arg dt
  self~lblOut~setText("Date:" dt~isoDate~left(10))

::resource oodDesign
designer version=0.3.0
form name=Gadgets title="Tree view, track bar, date picker" w=220 h=120 style=CENTER
control type=TREEVIEW name=tvRexx id=100 x=8 y=8 w=96 h=86 nodes="ooRexx|.Interpreter|.Extensions|..ooDialog|..RxSock|..BSF4ooRexx|Classic Rexx|.Regina" opts="LINES BUTTONS ATROOT SHOWSELALWAYS"
control type=TRACKBAR name=trkLevel id=101 x=112 y=8 w=100 h=16 min=0 max=50 pos=30 opts="HORIZONTAL AUTOTICKS"
control type=PUSHBUTTON name=btnRead id=102 x=112 y=28 w=100 h=14 text="&Read the level" role="" opts=""
control type=DATETIME name=dtpWhen id=103 x=112 y=50 w=100 h=12 opts=SHORT
control type=STATIC name=lblOut id=104 x=112 y=70 w=100 h=24 text="" opts=""
control type=PUSHBUTTON name=btnClose id=105 x=156 y=100 w=56 h=14 text=Close role=CANCEL opts=""
event control=tvRexx event=SELCHANGED thread=ui
event control=btnRead event=CLICKED thread=ui
event control=dtpWhen event=DATETIMECHANGE thread=ui
::END
