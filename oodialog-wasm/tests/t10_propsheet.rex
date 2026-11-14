/* t10: a PropertySheetDialog with two UserPSPDialog pages: pages are made
   when first shown, killActive can refuse to leave, OK applies the pages
   that were shown, the data comes back in the pages' attributes. */
p1 = .NamePage~new( , , , "Name")
p2 = .OptionsPage~new( , , , "Options")
sheet = .Sheet~new(.array~of(p1, p2), "NOAPPLYNOW", "Settings")
ret = sheet~execute
say "execute" ret "result" sheet~getResult
say "name:" p1~name "| second page shown:" p2~wasActivated "| agree:" p2~agree
say "log:" sheet~log
return 0

::requires "ooDialog.cls"

::class Sheet subclass PropertySheetDialog
::attribute log
::method initDialog
  self~log = "pages" self~pages~items

::class NamePage subclass UserPSPDialog
::method defineDialog
  self~createStaticText(-1, 10, 12, 30, 10, , "&Name:")
  self~createEdit(101, 44, 10, 110, 12, , "name")
::method init
  forward class (super) continue
  self~cx = 170
  self~cy = 70
::method killActive
  use arg sheet
  if self~newEdit(101)~getText == "" then do
    sheet~log = sheet~log "refused"
    return .false
  end
  return .true
::method setActive
  use arg sheet
  sheet~log = sheet~log "active1"
  return 0

::class OptionsPage subclass UserPSPDialog
::method defineDialog
  self~createCheckBox(201, 10, 12, 100, 10, , "I &agree", "agree")
::method init
  forward class (super) continue
  self~cx = 170
  self~cy = 70
::method setActive
  use arg sheet
  sheet~log = sheet~log "active2"
  return 0
