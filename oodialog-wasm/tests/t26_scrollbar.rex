/* t26: the ScrollBar control, and the DateTimePicker's range. */
dlg = .Main~new
dlg~create(30, 30, 240, 110, "Scroll bar", "CENTER")
dlg~execute("SHOWTOP")
say "codes:" dlg~log
return 0

::requires "ooDialog.cls"

::class Main subclass UserDialog
::attribute log
::method defineDialog
  self~createScrollBar(100, 10, 10, 200, 12, "HORIZONTAL")
  self~createScrollBar(101, 220, 10, 12, 70, "VERTICAL")
  self~createStaticText(110, 10, 30, 200, 10, , "position 10")
  self~createDateTimePicker(120, 10, 50, 90, 14)
  self~createPushButton(1, 185, 90, 50, 14, "DEFAULT", "Close")
::method initDialog
  self~log = ""
  self~connectAllSBEvents(100, onScroll, 0, 50, 10)
  self~connectEachSBEvent(101, onUp, onDown, onDrop, 1, 9, 5, , , onTop, onBottom, onTrack)
  bar = self~newScrollBar(100)
  r = bar~getRange
  say "start" bar~getPos bar~position r~min r~max bar~range
  say "set" bar~setRange(0, 60) bar~setPos(20) bar~getPos bar~range bar~setPos(999) bar~getPos bar~setPos(10)
  say "vertical" self~newScrollBar(101)~getPos self~newScrollBar(101)~range
  dtp = self~newDateTimePicker(120)
  dtp~setDateTime(.DateTime~fromIsoDate("2026-11-20T10:00:00.000000"))
  range = .array~new
  say "dtp range" dtp~getRange(range) range[1] range[2]
  say "dtp set" dtp~setRange(.array~of(.DateTime~fromIsoDate("2026-11-01T00:00:00.000000"), .DateTime~fromIsoDate("2026-11-30T00:00:00.000000"))) dtp~getRange(range) range[1]~isoDate~left(10) range[2]~isoDate~left(10)
  only = .array~new
  only[2] = .DateTime~fromIsoDate("2026-12-31T00:00:00.000000")
  say "dtp max only" dtp~setRange(only) dtp~getRange(range) range[1]~isoDate~left(10) range[2]~isoDate~left(10)
  size = .Size~new
  say "dtp ideal" dtp~getIdealSize(size) (size~width > 40) (dtp~getMonthCal == .nil) dtp~setMonthCalStyle("WEEKNUMBERS") dtp~getMonthCalStyle dtp~getMonthCalColor("BACKGROUND") dtp~setMonthCalColor("BACKGROUND", 255) dtp~getMonthCalColor("BACKGROUND")
::method onScroll unguarded
  use arg wParam, lParam
  bar = self~newScrollBar(100)
  code = .DlgUtil~loWord(wParam)
  self~log = self~log code
  if code == 8 then return
  pos = bar~determinePosition(wParam, 1, 10)
  self~newStatic(110)~setText("position" pos (lParam == bar~hwnd))
::method onUp unguarded
  self~log = self~log "v-up"
::method onDown unguarded
  bar = self~newScrollBar(101)
  bar~setPos(bar~getPos + 1)
  self~log = self~log "v-down:"bar~getPos
::method onDrop unguarded
  use arg wParam
  self~log = self~log "v-drop:".DlgUtil~hiWord(wParam)
::method onTop unguarded
  self~log = self~log "v-top"
::method onBottom unguarded
  self~log = self~log "v-bottom"
::method onTrack unguarded
  expose tracked
  if tracked == 1 then return
  tracked = 1
  self~log = self~log "v-track"
