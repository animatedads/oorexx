/* t24: a dialog is kept within reach.  Its place is far outside the window: it is moved in.
   Then the window gets smaller than the dialog: the dialog is scaled down to it. */
dlg = .Main~new
dlg~create(900, 700, 200, 120, "Far away")
dlg~execute("SHOWTOP")
say "ended"
return 0
::requires "ooDialog.cls"
::class Main subclass UserDialog
::method defineDialog
  self~createStaticText(10, 5, 5, 190, 10, , "This dialog was placed at 900, 700 dialog units.")
  self~createPushButton(1, 145, 100, 50, 14, "DEFAULT", "Close")
