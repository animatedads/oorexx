/* people.rex -- the "People" example: a dialog bound to one object over five
   tables (oorexx_mapped_objects).  The Person of data/People.cls comes from
   ent.per, its phone from ent.per_ext, its addresses from ent.addr through
   ent.per_addr, its employer from ent.com.  The employer is chosen in a
   combo box; addresses are added and removed, and the selected one edited
   in the fields under the list.  OK saves it all in one
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
  d~setProp("form", "h", 182)
  d~setProp("form", "object", "Person")
  d~setProp("form", "objectfile", "People.cls")
  d~setProp("form", "objectkey", "1")
  d~setProp("form", "databases", "ent=ent")
  call label d, "lblName", 8, 10, "Name"
  call field d, "txtName", 60, 8, "name"
  call label d, "lblPhone", 8, 26, "Phone"
  call field d, "txtPhone", 60, 24, "phone"
  call label d, "lblEmployer", 8, 42, "Employer"
  n = d~addControl("COMBOBOX", 60, 40)
  d~setProp(n, "name", "cboEmployer")
  d~setGeometry("cboEmployer", 60, 40, 120, 60)
  d~setProp("cboEmployer", "bind", "employer:name")
  n = d~addControl("CHECKBOX", 60, 56)
  d~setProp(n, "name", "chkActive")
  d~setProp("chkActive", "text", "Active")
  d~setProp("chkActive", "bind", "active")
  n = d~addControl("LISTVIEW", 8, 72)
  d~setProp(n, "name", "lvAddresses")
  d~setGeometry("lvAddresses", 8, 72, 214, 48)
  d~setProp("lvAddresses", "columns", "Street:120|Town:80")
  d~setProp("lvAddresses", "opts", "REPORT SHOWSELALWAYS SINGLESEL")
  d~setProp("lvAddresses", "exstyles", "FULLROWSELECT GRIDLINES")
  d~setProp("lvAddresses", "bind", "addresses:street,town")
  call label d, "lblStreet", 8, 126, "Street"
  call field d, "txtStreet", 60, 124, "@lvAddresses.street"
  d~setGeometry("txtStreet", 60, 124, 104, 12)
  call label d, "lblTown", 8, 142, "Town"
  call field d, "txtTown", 60, 140, "@lvAddresses.town"
  d~setGeometry("txtTown", 60, 140, 104, 12)
  call button d, "btnAddAddress", 170, 124, "Add", "add:lvAddresses"
  call button d, "btnRemoveAddress", 170, 140, "Remove", "remove:lvAddresses"
  n = d~addControl("PUSHBUTTON", 112, 160)
  d~setProp(n, "name", "btnOk")
  d~setGeometry("btnOk", 112, 160, 52, 14)
  d~setProp("btnOk", "text", "Save")
  d~setProp("btnOk", "role", "OK")
  n = d~addControl("PUSHBUTTON", 170, 160)
  d~setProp(n, "name", "btnCancel")
  d~setGeometry("btnCancel", 170, 160, 52, 14)
  d~setProp("btnCancel", "text", "Cancel")
  d~setProp("btnCancel", "role", "CANCEL")
  d~setEventCode("form", "SAVED", "say ""saved:"" self~object~name ""("" || self~object~phone || "")""" || "0a"x || -
    "say ""employer:"" oodValueOf(self~object, ""employer.name"")" || "0a"x || -
    "do a over self~object~addresses" || "0a"x || "  say ""address:"" a~street ""/"" a~town" || "0a"x || "end")
  return d

::routine label
  use arg d, name, x, y, text
  n = d~addControl("STATIC", x, y)
  d~setProp(n, "name", name)
  d~setGeometry(name, x, y, 48, 10)
  d~setProp(name, "text", text)
  return

::routine button
  use arg d, name, x, y, text, bind
  n = d~addControl("PUSHBUTTON", x, y)
  d~setProp(n, "name", name)
  d~setGeometry(name, x, y, 52, 12)
  d~setProp(name, "text", text)
  d~setProp(name, "bind", bind)
  return

::routine field
  use arg d, name, x, y, attr
  n = d~addControl("EDIT", x, y)
  d~setProp(n, "name", name)
  d~setGeometry(name, x, y, 120, 12)
  d~setProp(name, "text", "")
  d~setProp(name, "bind", attr)
  return
