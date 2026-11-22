/* t32: a tab owner dialog: two managed tabs whose pages are control dialogs, made when
   first chosen; the owner's notices; getTabPage; Ok ends every page */
.application~useGlobalConstDir("O")
.constDir[IDC_TAB1] = 200
.constDir[IDC_TAB2] = 201
info = .ControlDlgInfo~new( , .true, "Alpha", .Size~new(120, 60))
pages = .array~new
pages[1] = .Page~new( , , info)
info~title = "Beta"
pages[2] = .Page~new( , , info)
info~title = "Gamma"
pages[3] = .Page~new( , , info)
mt1 = .ManagedTab~new(IDC_TAB1, pages, "SELCHANGE")
info~title = "One"
p1 = .Page~new( , , info)
info~title = "Two"
p2 = .Page~new( , , info)
mt2 = .ManagedTab~new(IDC_TAB2, .array~of(p1, p2), , 2)
say "managed" pages[1]~isManaged pages[2]~pageTitle
dlg = .Owner~new( , , .TabOwnerDlgInfo~new(.array~of(mt1, mt2)))
say "execute" dlg~execute("SHOWTOP") "initCode" dlg~initCode
say "log:" dlg~log
say "values: [" || pages[1]~value || "] [" || pages[2]~value || "] [" || p1~value || "]"
return 0

::requires "ooDialog.cls"

::class Owner subclass UserDialog inherit TabOwnerDialog
::attribute log
::method init
  forward class (super) continue
  self~log = ""
  self~create(30, 30, 300, 130, "Tab owner")
::method defineDialog
  self~createTab(IDC_TAB1, 5, 5, 140, 90)
  self~createTab(IDC_TAB2, 155, 5, 140, 90)
  self~createPushButton(300, 5, 105, 50, 14, , "Next", onNext)
  self~createPushButton(301, 60, 105, 50, 14, , "Report", onReport)
  self~createPushButton(IDOK, 190, 105, 50, 14, "DEFAULT", "Ok")
  self~createPushButton(IDCANCEL, 245, 105, 50, 14, , "Cancel")
  self~createStaticText(302, 115, 107, 70, 10, , "")
::method tabOwnerSelChange unguarded
  use arg pageDlg, pageNumber
  self~log = self~log "sel:"pageDlg~pageTitle":"pageNumber
::method onNext unguarded
  tab = self~newTab(IDC_TAB1)
  tab~focus(tab~selectedIndex + 1)
::method onReport unguarded
  page = self~getTabPage(IDC_TAB1, 2)
  self~log = self~log "page2:"page~pageTitle":"page~wasActivated "page3:"self~getTabPage(IDC_TAB1, 3)~wasActivated
  self~newStatic(302)~setText("reported")

::class Page subclass UserControlDialog
::attribute value
::method init
  forward class (super) continue
  self~value = "never shown"
::method defineDialog
  self~createStaticText(-1, 5, 5, 100, 10, , "Page" self~pageTitle)
  self~createEdit(401, 5, 20, 80, 12)
::method tabPageSetActive unguarded
  use strict arg owner, tab
  return 0
::method tabPageKillActive unguarded
  use strict arg owner, tab
  return .true
::method endExecution unguarded
  use arg isOkay = .false
  if self~wasActivated then self~value = self~newEdit(401)~getText
  forward class (super)
