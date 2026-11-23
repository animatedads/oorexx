/* Hello.rex -- the kit's end-to-end check: a dialog with a text and two buttons.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-23. */
dlg = .Hello~new
return dlg~execute("SHOWTOP")

::requires "ooDialog.cls"

::class Hello subclass UserDialog
::method init
  forward class (super) continue
  self~create(30, 30, 160, 60, "ooDialog on Linux")
::method defineDialog
  self~createStaticText(100, 10, 10, 140, 10, , "Hello from the kit")
  self~createPushButton(IDOK, 40, 36, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 100, 36, 50, 14, , "Cancel")
::method ok
  say "OK pressed"
  return self~ok:super
