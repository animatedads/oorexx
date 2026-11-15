/* t14: an owned dialog (ownerDialog) ends when its owner ends, as Windows
   destroys an owned window with its owner.  The owned dialog refuses ok and
   cancel, so the owner is its only way out (as in upstream's useTools.rex). */
main = .Main~new
main~create(30, 30, 140, 60, "Owner", "CENTER")
pal = .Palette~new
pal~create(10, 10, 80, 40, "Palette")
pal~ownerDialog = main
main~executeAsync("SHOWTOP")
pal~popup("SHOWTOP")
main~endAsyncExecution
call SysSleep 0.5
say "log: owner ended; palette left" pal~left "windows" pal~seen
return 0

::requires "ooDialog.cls"

::class Main subclass UserDialog
::method defineDialog
  self~createPushButton(IDOK, 80, 40, 50, 14, "DEFAULT", "Close")

::class Palette subclass UserDialog
::attribute left unguarded
::attribute seen unguarded
::method init
  forward class (super) continue
  self~left = 0
::method defineDialog
  self~createPushButton(201, 6, 6, 60, 14, , "Tool")
::method initDialog unguarded     -- .oodn~windows: the dialogs on the page (the seam for a system-classes file)
  self~seen = ""
  do w over .oodn~windows
    self~seen = self~seen w~title
  end
  self~seen = self~seen~strip
::method ok unguarded
::method cancel unguarded
::method leaving unguarded
  self~left = 1
