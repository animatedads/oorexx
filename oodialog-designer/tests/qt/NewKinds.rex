/* NewKinds.rex -- an ooDialog program made with the ooDialog Designer 0.18.0
   Design: the ::RESOURCE oodDesign at the end.  The designer writes this
   whole file; what you type is the body of each event method.
   ooDialog Designer -- architecture: Tom Dyer; code: Claude (Opus 5.5). */
dlg = .NewKinds~new
if dlg~initCode \= 0 then return dlg~initCode
return dlg~execute("SHOWTOP")

::requires "ooDialog.cls"

::class NewKinds subclass UserDialog


::method init
  forward class (super) continue
  self~create(0, 0, 240, 170, "My Dialog", "CENTER")
  self~txtCount_data = 3

::method defineDialog
  self~createEdit(100, 10, 10, 80, 12, "", "txtCount_data")
  self~createUpDown(101, 92, 10, 10, 12, "SETBUDDYINT ARROWKEYS")
  self~createTrackBar(102, 120, 10, 100, 16, "HORIZONTAL AUTOTICKS")
  self~createMonthCalendar(103, 10, 34, 150, 110, "")
  self~createPushButton(IDOK, 180, 145, 50, 14, "DEFAULT", "OK")
  self~connectUpDownEvent(101, "DELTAPOS", "on_ud1_deltapos")
  self~connectTrackBarEvent(102, "DRAG", "on_trkLevel_drag")
  self~connectTrackBarEvent(102, "ENDTRACK", "on_trkLevel_endtrack")
  self~connectMonthCalendarEvent(103, "SELECT", "on_calDay_select")

::method initDialog unguarded
  self~ud1~setBuddy(self~txtCount)
  self~ud1~setRange(1, 9)
  self~ud1~setPosition(3)
  self~trkLevel~initRange(0, 100)
  self~trkLevel~pos = 0
  tips = self~createToolTip(105)
  tips~addTool(self~txtCount, "How many, 1 to 9")

::method txtCount unguarded
  return self~newEdit(100)
::method ud1 unguarded
  return self~newUpDown(101)
::method trkLevel unguarded
  return self~newTrackBar(102)
::method calDay unguarded
  return self~newMonthCalendar(103)
::method btn1 unguarded
  return self~newPushButton(IDOK)

::method on_ud1_deltapos unguarded
  use arg pos, delta
  say "deltapos" pos delta

::method on_trkLevel_drag unguarded
  use arg info
  say "drag" .DlgUtil~hiWord(info)

::method on_trkLevel_endtrack unguarded
  say "endtrack" self~trkLevel~pos

::method on_calDay_select unguarded
  use arg startDate
  say "select" startDate~day

::resource oodDesign
designer version=0.18.0
form name=NewKinds title="My Dialog" w=240 h=170 style=CENTER
control type=EDIT name=txtCount id=100 x=10 y=10 w=80 h=12 text="" opts="" tip="How many, 1 to 9" anchor="LEFT TOP"
control type=UPDOWN name=ud1 id=101 x=92 y=10 w=10 h=12 min=1 max=9 pos=3 buddy=txtCount opts="SETBUDDYINT ARROWKEYS" tip="" anchor="LEFT TOP"
control type=TRACKBAR name=trkLevel id=102 x=120 y=10 w=100 h=16 min=0 max=100 pos=0 opts="HORIZONTAL AUTOTICKS" tip="" anchor="LEFT TOP"
control type=MONTHCALENDAR name=calDay id=103 x=10 y=34 w=150 h=110 opts="" tip="" anchor="LEFT TOP"
control type=PUSHBUTTON name=btn1 id=104 x=180 y=145 w=50 h=14 text=OK role=OK opts="" tip="" anchor="LEFT TOP"
event control=ud1 event=DELTAPOS thread=ui
event control=trkLevel event=DRAG thread=ui
event control=trkLevel event=ENDTRACK thread=ui
event control=calDay event=SELECT thread=ui
::END
