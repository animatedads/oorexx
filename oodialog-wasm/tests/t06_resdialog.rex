/* t06: the seam for binary Windows resources.  A stand-in provider answers
   what a real .dll/.res reader will; ResDialog and BinaryMenuBar run over it. */
.oodn~resourceProvider = .FakeResources~new
dlg = .Res~new("app.dll", 100)
say "initCode" dlg~initCode
dlg~execute("SHOWTOP")
say "log:" dlg~log "name:" dlg~data11 "agree:" dlg~Iagree
return 0

::requires "ooDialog.cls"

::class Res subclass ResDialog
::attribute log
::method initDialog
  self~log = "title" self~title
  self~setMenu(300)
  self~menuBar~connectCommandEvent(301, onHello)
::method onHello unguarded
  self~log = self~log "hello"

::class FakeResources
::method control
  use arg kind, id, x, y, cx, cy, text, opts
  c = .directory~new
  c~kind = kind; c~id = id; c~x = x; c~y = y; c~cx = cx; c~cy = cy; c~text = text; c~opts = opts
  return c
::method dialogTemplate
  use arg library, id
  if id \== 100 then return .nil
  t = .directory~new
  t~x = 20; t~y = 20; t~cx = 180; t~cy = 80
  t~title = "From" library
  t~opts = "CENTER"
  t~fontName = "MS Shell Dlg"; t~fontSize = 8
  t~controls = .array~of(self~control("STATIC", -1, 10, 12, 30, 10, "&Name", ""), -
                         self~control("EDIT", 11, 44, 10, 120, 12, "", ""), -
                         self~control("CHECK", 12, 10, 30, 100, 10, "I &agree", ""), -
                         self~control("BUTTON", 1, 120, 58, 50, 14, "OK", "DEFAULT"))
  return t
::method menuTemplate
  use arg library, id
  if id \== 300 then return .nil
  return .array~of(self~item(0, 310, "&Demo", ""), self~item(1, 301, "&Hello", ""), self~item(1, 302, "&Other", "GRAYED"))
::method item
  use arg depth, id, text, flags
  r = .directory~new
  r~depth = depth; r~id = id; r~text = text; r~flags = flags
  return r
