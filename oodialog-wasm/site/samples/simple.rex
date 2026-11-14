/* t01: a UserDialog with a static text, an edit connected to a data
   attribute, OK and Cancel.  The upstream class code runs unchanged. */
dlg = .Simple~new
if dlg~initCode \= 0 then do
  say "init failed" dlg~initCode
  return 1
end
dlg~create(30, 30, 200, 90, "Simple Dialog", "CENTER")
dlg~name = "Tom"
rc = dlg~execute("SHOWTOP")
say "execute returned" rc
say "name is" dlg~name
say "greeted" dlg~greeted "time(s)"
return 0

::requires "ooDialog.cls"

::class Simple subclass UserDialog
::attribute greeted
::method defineDialog
  self~greeted = 0
  self~createStaticText(-1, 10, 12, 40, 10, , "&Name:")
  self~createEdit(101, 52, 10, 130, 12, , "name")
  self~createStaticText(102, 10, 32, 180, 10, , "")
  self~createPushButton(103, 10, 66, 50, 14, , "&Greet", onGreet)
  self~createPushButton(IDOK, 84, 66, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 140, 66, 50, 14, , "Cancel")
::method onGreet
  self~greeted = self~greeted + 1
  edit = self~newEdit(101)
  self~newStatic(102)~setText("Hello," edit~getText || "!")
