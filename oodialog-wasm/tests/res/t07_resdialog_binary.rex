/* t07: t06 over a real binary.  The stand-in reader is replaced by oorexx_win_resources
   reading app.dll (built by llvm-rc + lld-link from app.rc).  Same steps, same expected output.
   Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14. */
.oodn~resourceProvider = .WinResourceProvider~new
dlg = .Res~new("app.dll", 100)
say "initCode" dlg~initCode
dlg~execute("SHOWTOP")
say "log:" dlg~log "name:" dlg~data11 "agree:" dlg~Iagree
return 0

::requires "ooDialog.cls"
::requires "WinResources.cls"

::class Res subclass ResDialog
::attribute log
::method initDialog
  self~log = "title" self~title
  self~setMenu(300)
  self~menuBar~connectCommandEvent(301, onHello)
::method onHello unguarded
  self~log = self~log "hello"

