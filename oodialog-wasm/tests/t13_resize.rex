/* t13: a dialog with a sizing border: connectResize keeps a control glued
   to the right and bottom edges; a track bar's DRAG and ENDTRACK events. */
dlg = .Sizer~new
dlg~create(30, 30, 160, 80, "Resize me", "CENTER THICKFRAME")
dlg~execute("SHOWTOP")
say "log:" dlg~log
return 0

::requires "ooDialog.cls"

::class Sizer subclass UserDialog
::attribute log
::method defineDialog
  self~log = ""
  self~createEdit(101, 6, 6, 148, 40, "MULTILINE")
  self~createTrackBar(102, 6, 52, 90, 14, "HORIZONTAL")
  self~createPushButton(IDOK, 104, 60, 50, 14, "DEFAULT", "Close")
  self~connectResize(onResize)
  self~connectSizeMoveEnded(onEnded)
  self~connectTrackBarEvent(102, "DRAG", onDrag)
  self~connectTrackBarEvent(102, "ENDTRACK", onEndTrack)
::method onResize unguarded
  use arg sizeType, sizeInfo
  width = .DlgUtil~loWord(sizeInfo)
  height = .DlgUtil~hiWord(sizeInfo)
  self~newEdit(101)~resizeTo(width - 24, height - 80)
  self~log = self~log "size" width height
::method onEnded unguarded
  self~log = self~log "ended"
::method onDrag unguarded
  use arg info, hwnd
  self~log = self~log "drag" .DlgUtil~hiWord(info) .DlgUtil~loWord(info)
::method onEndTrack unguarded
  use arg info, hwnd
  self~log = self~log "endtrack" .DlgUtil~hiWord(info)
