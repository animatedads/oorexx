/* t11: two UserControlDialogs as the pages of a tab control the program
   manages itself: each runs on its own thread, is placed by setWindowPos,
   and gives its data back when the owner ends it. */
dlg = .Owner~new
dlg~create(30, 30, 220, 130, "Control dialogs", "CENTER")
dlg~execute("SHOWTOP")
say "log:" dlg~log
say "city:" dlg~pages[1]~city "| express:" dlg~pages[2]~express
return 0

::requires "ooDialog.cls"

::class Owner subclass UserDialog
::attribute log
::attribute pages
::method defineDialog
  self~log = ""
  self~createTab(100, 6, 6, 208, 96)
  self~createPushButton(IDOK, 164, 110, 50, 14, "DEFAULT", "OK")
  self~connectTabEvent(100, "SELCHANGE", onTab)
::method initDialog
  tab = self~newTab(100)
  tab~addSequence("Address", "Delivery")
  area = .Rect~new
  tab~calcDisplayRect(area)
  self~pages = .array~of(.AddressPage~new, .DeliveryPage~new)
  do page over self~pages
    page~ownerDialog = self
    page~create(0, 0, 190, 70)
    page~execute
    do while page~initializing
      call SysSleep 0.02
    end
    page~setWindowPos(tab~hwnd, area~left, area~top, area~right - area~left, area~bottom - area~top, "NOSIZE")
  end
  self~pages[2]~hide
  self~log = "started" self~pages[1]~wasActivated self~pages[2]~wasActivated
::method onTab unguarded
  use arg id, hwnd, tab
  index = tab~selectedIndex + 1
  do i = 1 to self~pages~items
    if i == index then self~pages[i]~show
    else self~pages[i]~hide
  end
  self~log = self~log "tab" index
::method ok unguarded
  do page over self~pages
    page~endExecution(.true)
  end
  return self~ok:super

::class AddressPage subclass UserControlDialog
::method defineDialog
  self~createStaticText(-1, 6, 8, 30, 10, , "&City:")
  self~createEdit(11, 40, 6, 120, 12, , "city")
  self~createPushButton(12, 40, 26, 60, 14, , "&Glasgow", onGlasgow)
::method onGlasgow unguarded
  self~newEdit(11)~setText("Glasgow")
  self~ownerDialog~log = self~ownerDialog~log "button"

::class DeliveryPage subclass UserControlDialog
::method defineDialog
  self~createCheckBox(21, 6, 8, 100, 10, , "&Express", "express")
