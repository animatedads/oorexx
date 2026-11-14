/* t08: connectKeyPress and connectFKeyPress. */
dlg = .Keys~new
dlg~create(30, 30, 160, 60, "Keys", "CENTER")
dlg~execute("SHOWTOP")
say "log:" dlg~log
return 0

::requires "ooDialog.cls"

::class Keys subclass UserDialog
::attribute log
::method defineDialog
  self~log = ""
  self~createEdit(101, 10, 10, 140, 12)
  self~createPushButton(IDOK, 100, 38, 50, 14, "DEFAULT", "Close")
  self~connectFKeyPress(onFKey)
  self~connectKeyPress(onCtrlLetter, "65-90", "CONTROL")
  self~connectKeyPress(onPlain, "88", "NONE")
::method onFKey unguarded
  use arg key, shift, control, alt
  self~log = self~log "F" || (key - 111) shift
::method onCtrlLetter unguarded
  use arg key
  self~log = self~log "ctrl" key~d2c
::method onPlain unguarded
  use arg key
  self~log = self~log "plain" key~d2c
