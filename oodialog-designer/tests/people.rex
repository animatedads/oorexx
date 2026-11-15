/* people.rex -- the "People" example: a dialog bound to one object over five
   tables (oorexx_mapped_objects).  The Person of data/People.cls comes from
   ent.per, its phone from ent.per_ext, its addresses from ent.addr through
   ent.per_addr, its employer from ent.com.  OK saves it all in one
   transaction; a refusal is shown and the dialog stays open.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx people.rex [out.rex]                                         */
parse arg outFile
d = .peopleDesign~build
if outFile \= "" then do
  st = .stream~new(outFile~strip)
  st~open("write replace")
  st~charOut(d~generate)
  st~close
  say "people: wrote" outFile~strip
end
return d

::requires "OodDesigner.cls"

::class peopleDesign public
::method build class
  d = .OodDesign~new("People")
  d~setProp("form", "title", "A person")
  d~setProp("form", "w", 230)
  d~setProp("form", "h", 158)
  d~setProp("form", "object", "Person")
  d~setProp("form", "objectfile", "People.cls")
  d~setProp("form", "objectkey", "1")
  d~setProp("form", "databases", "ent=ent")
  call label d, "lblName", 8, 10, "Name"
  call field d, "txtName", 60, 8, "name"
  call label d, "lblPhone", 8, 26, "Phone"
  call field d, "txtPhone", 60, 24, "phone"
  call label d, "lblEmployer", 8, 42, "Employer"
  n = d~addControl("STATIC", 60, 42)
  d~setProp(n, "name", "lblCompany")
  d~setGeometry("lblCompany", 60, 42, 120, 10)
  d~setProp("lblCompany", "text", "")
  d~setProp("lblCompany", "bind", "employer.name")
  n = d~addControl("CHECKBOX", 60, 56)
  d~setProp(n, "name", "chkActive")
  d~setProp("chkActive", "text", "Active")
  d~setProp("chkActive", "bind", "active")
  n = d~addControl("LISTVIEW", 8, 72)
  d~setProp(n, "name", "lvAddresses")
  d~setGeometry("lvAddresses", 8, 72, 214, 56)
  d~setProp("lvAddresses", "columns", "Street:120|Town:80")
  d~setProp("lvAddresses", "exstyles", "FULLROWSELECT GRIDLINES")
  d~setProp("lvAddresses", "bind", "addresses:street,town")
  n = d~addControl("PUSHBUTTON", 112, 136)
  d~setProp(n, "name", "btnOk")
  d~setGeometry("btnOk", 112, 136, 52, 14)
  d~setProp("btnOk", "text", "Save")
  d~setProp("btnOk", "role", "OK")
  n = d~addControl("PUSHBUTTON", 170, 136)
  d~setProp(n, "name", "btnCancel")
  d~setGeometry("btnCancel", 170, 136, 52, 14)
  d~setProp("btnCancel", "text", "Cancel")
  d~setProp("btnCancel", "role", "CANCEL")
  d~setEventCode("form", "SAVED", "say ""saved:"" self~object~name ""("" || self~object~phone || "")""")
  return d

::routine label
  use arg d, name, x, y, text
  n = d~addControl("STATIC", x, y)
  d~setProp(n, "name", name)
  d~setGeometry(name, x, y, 48, 10)
  d~setProp(name, "text", text)
  return

::routine field
  use arg d, name, x, y, attr
  n = d~addControl("EDIT", x, y)
  d~setProp(n, "name", name)
  d~setGeometry(name, x, y, 120, 12)
  d~setProp(name, "text", "")
  d~setProp(name, "bind", attr)
  return
