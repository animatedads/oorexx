/* t18: ResizingAdmin's pagedTab.  A resizable dialog with a tab control whose two pages are
   ControlDialogs; the second page has its own sizing definition.  When the dialog grows, the
   tab control grows, and each page takes the tab's display area. */
dlg = .Main~new
dlg~create(30, 30, 220, 130, "Paged tab", "CENTER")
dlg~execute("SHOWTOP")
say "ended" dlg~log
return 0

::requires "ooDialog.cls"

::class Main subclass UserDialog inherit ResizingAdmin
::attribute pages
::attribute log
::method defineSizing
  self~pagedTab(100, .array~of(501, 502))
  self~controlSizing(100, .array~of("STATIONARY", "LEFT"), .array~of("STATIONARY", "TOP"), .array~of("STATIONARY", "RIGHT"), .array~of("STATIONARY", "BOTTOM"))
  self~controlSizing(1, .array~of("STATIONARY", "RIGHT"), .array~of("STATIONARY", "BOTTOM"), .array~of("MYLEFT", "LEFT"), .array~of("MYTOP", "TOP"))
  return 0
::method defineDialog
  self~createTab(100, 5, 5, 210, 100)
  self~createPushButton(1, 165, 110, 50, 14, "DEFAULT", "Close")
  self~connectTabEvent(100, "SELCHANGE", "onTab")
::method initDialog
  self~log = ""
  tab = self~newTab(100)
  tab~addSequence("One", "Two")
  area = tab~windowRect
  tab~calcDisplayRect(area)
  self~screen2client(area)
  self~pages = .array~of(.PageOne~new( , , self), .PageTwo~new( , , self))
  self~pages[1]~dlgID = 501
  self~pages[2]~dlgID = 502
  do page over self~pages
    page~create(0, 0, 100, 50)
    page~execute
    do while page~initializing
      call SysSleep 0.02
    end
    page~setWindowPos(tab~hwnd, area~left, area~top, area~right - area~left, area~bottom - area~top)
  end
  self~pages[2]~hide
  signal on syntax
  self~pagedTab(100, .array~of(503))
  return
syntax:
  self~log = "late:" condition("O")~message
::method onTab unguarded
  use arg id, hwnd, tab
  index = tab~selectedIndex + 1
  do i = 1 to self~pages~items
    if i == index then self~pages[i]~show
    else self~pages[i]~hide
  end
::method ok unguarded
  do page over self~pages
    page~endExecution(.true)
  end
  return self~ok:super

::class PageOne subclass UserControlDialog
::method defineDialog
  self~createEdit(11, 5, 5, 60, 12)

::class PageTwo subclass UserControlDialog inherit ResizingAdmin
::method defineSizing
  self~controlSizing(21, .array~of("STATIONARY", "LEFT"), .array~of("STATIONARY", "TOP"), .array~of("STATIONARY", "RIGHT"), .array~of("STATIONARY", "BOTTOM"))
  return 0
::method defineDialog
  self~createListBox(21, 5, 5, 90, 40)
