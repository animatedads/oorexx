/* t10_binding.rex -- a dialog bound to a mapped object (oorexx_mapped_objects),
   without a browser: the form's binding and the controls' bind checked, the
   problems listed, the program written (open, fields, list, validate and its
   commit), the design read back from it, and an unbound design unchanged.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx t10_binding.rex        (REXX_PATH: src and tests) */
fails = 0
checks = 0
.OodUi~use("en")
d = .peopleDesign~build
src = d~generate
call check "the program opens a store, a session and the object", -
  src~pos('self~store~attach("ent", oodBeside("ent"))') > 0 & src~pos("self~session = self~store~session") > 0 & -
  src~pos("else self~object = self~session~find(.Person, key)") > 0
call check "  takes the key as its argument, the design's when none", src~pos("parse arg key") > 0 & src~pos('if key == "" then key = "1"') > 0
call check "  requires the object layer and the class file", src~pos('::requires "MappedObjects.cls"') > 0 & src~pos('::requires "People.cls"') > 0
call check "the fields' first values from the object", src~pos('self~txtName_data = oodValueOf(self~object, "name")') > 0
call check "a check box: a flag", src~pos('self~chkActive_data = (oodValueOf(self~object, "active") == 1)') > 0
call check "a text shows a path: employer.name", pathShown()
call check "a list view shows a many-part, one attribute a column", -
  src~pos('do part over oodPartsOf(self~object, "addresses")') > 0 & src~pos('addRow( , , oodValueOf(part, "street"), oodValueOf(part, "town"))') > 0
call check "validate: the fields into the object, then one commit", -
  src~pos("::method validate unguarded") > 0 & src~pos("self~object~name = oodFromText(self~txtName_data)") > 0 & src~pos("self~session~commit") > 0
call check "  a path is not written back", src~pos("self~object~employer.name") = 0
call check "  SAVED runs after the commit; a refusal is shown, the dialog stays", -
  src~pos("self~session~commit" || "0a"x || "  self~on_form_saved") > 0 & src~pos("call errorDialog msg") > 0 & src~pos("return .false") > 0
d2 = .OodDesign~fromSource(src)
call check "round trip: the program reads back to the same program", d2~generate == src
call check "  with its binding", d2~getProp("form", "object") == "Person" & d2~getProp("form", "databases") == "ent=ent" & d2~getProp("lvAddresses", "bind") == "addresses:street,town"
call check "the problems: none", d~problems == ""

-- v0.10: the reference picker, Add and Remove, the fields of the selected row
call check "a combo box offers a one-part's objects, the current one chosen", -
  src~pos('self~cboEmployer_choices = oodChoices(self~store, self~session, self~object, "employer", "name")') > 0 & -
  src~pos('self~cboEmployer_data = oodLabelOf(self~cboEmployer_choices, self~object~employer)') > 0 & -
  src~pos('do choice over self~cboEmployer_choices["LABELS"]') > 0
call check "  validate puts the chosen object back", src~pos("self~object~employer = oodChosen(self~cboEmployer_choices, self~cboEmployer_data)") > 0
call check "  the label routines: none first, labels made unique", -
  src~pos('r["LABELS"] = .array~of("")') > 0 & src~pos('label = (t "("n")")~strip') > 0 & src~pos("::routine oodChosen") > 0
call check "Add and Remove: their buttons call the list's methods", -
  src~pos('self~connectButtonEvent(112, "CLICKED", "btnAddAddress_bound")') > 0 & src~pos("::method btnAddAddress_bound unguarded" || "0a"x || "  self~lvAddresses_add") > 0 & -
  src~pos("::method btnRemoveAddress_bound unguarded" || "0a"x || "  self~lvAddresses_remove") > 0
call check "  Add: a new object of the part's class, its row, its fields", -
  src~pos('part = self~session~new(oodPartOf(self~store, self~object, "addresses")~targetClass)') > 0 & -
  src~pos("self~lvAddresses_load(parts~items - 1)") > 0 & src~pos("self~txtStreet~assignFocus") > 0
call check "  Remove: current cleared first, a new part dropped, its row deleted", -
  src~pos("self~lvAddresses_current = -1            -- first") < src~pos("parts~delete(i + 1)") & -
  src~pos('if self~session~stateOf(part) == "NEW" then self~session~delete(part)') > 0 & src~pos("self~lvAddresses~delete(i)") > 0
call check "row fields: empty at first, loaded and saved with the selection", -
  src~pos('self~txtStreet_data = ""') > 0 & src~pos('self~connectListViewEvent(107, "SELECTCHANGED", "lvAddresses_bound")') > 0 & -
  src~pos('self~txtStreet_data = oodValueOf(part, "street")') > 0 & src~pos("part~street = oodFromText(self~txtStreet_data)") > 0 & -
  src~pos('call oodRow self~lvAddresses, i, part, "street,town"') > 0
call check "  validate saves the selected row before the commit", -
  src~pos("self~lvAddresses_save") > 0 & src~pos("self~lvAddresses_save                 --") < src~pos("self~session~commit")
call check "  the first row is shown when the dialog opens", src~pos("self~lvAddresses_load(0)") > 0
call check "  a row field is not written to the object itself", src~pos("self~object~@") = 0 & src~pos("self~object~street") = 0
e = .peopleDesign~build
e~setEventCode("lvAddresses", "SELECTCHANGED", "say item")
e~setEventCode("btnAddAddress", "CLICKED", "say 'added'")
es = e~generate
call check "the user's own SELECTCHANGED and CLICKED: called from the bound methods, not connected twice", -
  es~pos('forward message ("on_lvAddresses_selectchanged")') > 0 & es~pos('forward message ("on_btnAddAddress_clicked")') > 0 & -
  es~pos('"on_lvAddresses_selectchanged")') = es~pos('forward message ("on_lvAddresses_selectchanged")') + 17 & -
  es~pos('connectButtonEvent(112, "CLICKED", "on_btnAddAddress_clicked")') = 0
call check "  and the round trip keeps them", .OodDesign~fromSource(es)~generate == es

-- what is refused
call refuses "a class name that is not a symbol", "d~setProp('form', 'object', 'Per son')"
call refuses "a database that is not name=folder", "d~setProp('form', 'databases', 'ent')"
call refuses "an entry field bound to a path", "d~setProp('txtName', 'bind', 'employer.name')"
call refuses "a list view bound without its attributes", "d~setProp('lvAddresses', 'bind', 'addresses')"
call refuses "an attribute that is not a name", "d~setProp('txtPhone', 'bind', 'phone number')"
call refuses "a push button's bind that is not add: or remove:", "d~setProp('btnOk', 'bind', 'name')"
call refuses "a combo box bound without its attribute", "d~setProp('cboEmployer', 'bind', 'employer')"
call refuses "a row field without its attribute", "d~setProp('txtStreet', 'bind', '@lvAddresses')"
call refuses "a check box bound to a row field", "d~setProp('chkActive', 'bind', '@lvAddresses.active')"
call refuses "bind on a control that has none", "d~setProp(d~addControl('LISTBOX', 1, 1), 'bind', 'name')"
d~setProp("btnAddAddress", "bind", "add:lvNowhere")
call check "a button naming no bound list: a problem", d~problems~pos("btnAddAddress: lvNowhere is not a bound list view") > 0
d~setProp("btnAddAddress", "bind", "add:lvAddresses")
d~setProp("lvAddresses", "opts", "REPORT")
call check "a managed list without SINGLESEL: a problem", d~problems~pos("give it SINGLESEL") > 0
d~setProp("lvAddresses", "opts", "REPORT SHOWSELALWAYS SINGLESEL")
d~setProp("txtStreet", "bind", "")
d~setProp("txtTown", "bind", "")
call check "Add with no row fields: a problem", d~problems~pos("has Add but no row fields") > 0
d~setProp("txtStreet", "bind", "@lvAddresses.street")
d~setProp("lvAddresses", "bind", "addresses:street,town,id")
call check "a list's attributes and columns differ: a problem", d~problems~pos("lvAddresses: its bound attributes and its columns differ") > 0
d~setProp("lvAddresses", "bind", "addresses:street,town")
d~setProp("form", "databases", "")
call check "an object with no databases: a problem", d~problems~pos("needs its databases") > 0
d~setProp("form", "object", "")
call check "bound controls with no object: a problem", d~problems~pos("names no object class") > 0
u = d~generate
call check "unbound: no store, no validate", u~pos("ObjectStore") = 0 & u~pos("::method validate") = 0 & u~pos("parse arg key") = 0

-- a design with no binding is written as before
c = .calcDesign~build
call check "an unbound design: no bind= in its design lines", c~generate~pos(" bind=") = 0 & c~generate~pos("binding ") = 0
call check "German refusals", germanRefusal()

say "t10_binding:" checks - fails "of" checks "checks passed"
return fails

pathShown: procedure
  p = .peopleDesign~build
  n = p~addControl("STATIC", 130, 56)
  p~setProp(n, "name", "lblCompany")
  p~setProp("lblCompany", "bind", "employer.name")
  return p~generate~pos('self~lblCompany~setText(oodValueOf(self~object, "employer.name"))') > 0

germanRefusal: procedure
  .OodUi~use("de")
  signal on syntax name got
  .peopleDesign~build~setProp("form", "object", "1x")
  return .false
got:
  .OodUi~use("en")
  return condition("O")~at("ADDITIONAL")[1]~pos("ist kein Klassenname") > 0

check: procedure expose fails checks
  use arg ckLabel, ckOk
  checks = checks + 1
  if ckOk then say "  ok  " ckLabel
  else do
    say "  FAIL" ckLabel
    fails = fails + 1
  end
  return

refuses: procedure expose fails checks d
  use arg rfLabel, rfCode
  checks = checks + 1
  signal on syntax name rfRefused
  interpret rfCode
  say "  FAIL not refused:" rfLabel
  fails = fails + 1
  return
rfRefused:
  co = condition("O")
  if co~at("CODE") \== "93.900" then do
    say "  FAIL refused, but not by the designer:" rfLabel "--" co~at("MESSAGE")
    fails = fails + 1
    return
  end
  say "  ok   refuses" rfLabel "--" co~at("ADDITIONAL")[1]
  return

::requires "OodDesigner.cls"
::requires "people.rex"
::requires "calculator.rex"
