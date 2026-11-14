/* t05: up-down with its buddy, track bar, date-time picker, a font and a colour. */
dlg = .Misc~new
dlg~create(30, 30, 200, 110, "More controls", "CENTER")
dlg~execute("SHOWTOP")
say "log:" dlg~log
return 0

::requires "ooDialog.cls"

::class Misc subclass UserDialog
::attribute log
::method defineDialog
  self~log = ""
  self~createEdit(101, 10, 10, 50, 12, "NUMBER", "amount")
  self~createUpDown(102, 0, 0, 10, 12, "AUTOBUDDY SETBUDDYINT RIGHT ARROWKEYS")
  self~createTrackBar(103, 70, 8, 120, 16, "HORIZONTAL")
  self~createDateTimePicker(104, 10, 34, 80, 12, "SHORT")
  self~createStaticText(105, 10, 56, 180, 14, , "Styled text")
  self~createPushButton(IDOK, 140, 88, 50, 14, "DEFAULT", "Close")
  self~connectUpDownEvent(102, "DELTAPOS", onDelta)
  self~connectDateTimePickerEvent(104, "DATETIMECHANGE", onDate)

::method initDialog
  ud = self~newUpDown(102)
  ud~setRange(1, 5)
  ud~setPosition(3)
  tb = self~newTrackBar(103)
  tb~initRange(0, 50)
  tb~pos = 20
  dtp = self~newDateTimePicker(104)
  dtp~setDateTime(.DateTime~fromIsoDate("2026-11-14T12:00:00.000000"))
  font = self~createFontEx("Georgia", 12, .directory~new~~setEntry("WEIGHT", 700))
  label = self~newStatic(105)
  label~setFont(font)
  self~setControlColor(105, 14, 4)
  r = ud~getRange
  self~log = "range" r~min r~max "pos" ud~getPosition "buddy" self~newEdit(101)~getText "track" tb~pos tb~range "date" dtp~getDateTime~isoDate~left(10)

::method onDelta unguarded
  use arg pos, delta, id, hwnd, ud
  self~log = self~log "delta" pos delta
::method onDate unguarded
  use arg dt, valid, id, hwnd, code, dtp
  self~log = self~log "newdate" dt~isoDate~left(10)
