/* t01_model.rex -- OodDesign without a browser: generate, read back, refuse.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
   usage: rexx t01_model.rex            (beside OodDesigner.cls)            */
fails = 0
checks = 0

d = .calcDesign~build
src = d~generate
call write "Calculator.rex", src

-- 1. a program is also its design: read it back and write it again
d2 = .OodDesign~fromSource(src)
src2 = d2~generate
call check "round trip gives the same program", src2 == src
call check "round trip keeps the event code", d2~getEventCode("bClear", "CLICKED") == d~getEventCode("bClear", "CLICKED")
call check "round trip keeps the methods", d2~getMethod("operate") == d~getMethod("operate")
call check "same design lines after the round trip", d2~resourceLines~items == d~resourceLines~items

-- 2. what is generated is plain ooDialog
call check "a UserDialog subclass", src~pos("::class Calculator subclass UserDialog") > 0
call check "controls made with createXxx", src~pos('self~createEdit(100, 8, 8, 116, 14, "READONLY RIGHT", "lcd_data")') > 0
call check "Cancel role becomes IDCANCEL", src~pos('self~createPushButton(IDCANCEL,') > 0
call check "events connected", src~pos('self~connectButtonEvent(101, "CLICKED", "on_b7_clicked")') > 0
call check "accessor per control", src~pos("::method lcd unguarded") > 0
call check "edit's first text is its data attribute", src~pos('self~lcd_data = "0"') > 0

-- 3. threads: a background event replies first and is unguarded
d~setEventThread("bEnter", "CLICKED", "background")
src3 = d~generate
call check "background event is unguarded", src3~pos("::method on_bEnter_clicked unguarded") > 0
guarded = 0
do l over src3~makeArray("0a"x)
  if l~left(9) == "::method " then do
    if l~caselessPos("unguarded") = 0 then do
      if l \== "::method init" & l \== "::method defineDialog" then guarded = guarded + 1
    end
  end
end
call check "every event, form and accessor method is unguarded (oodguide 4.3.2)", guarded = 0
call check "background event replies first", src3~pos("::method on_bEnter_clicked unguarded" || "0a"x || .OodDesign~replyLine) > 0
d3 = .OodDesign~fromSource(src3)
call check "background survives the round trip", d3~getEventThread("bEnter", "CLICKED") == "background"
call check "reply line is not user code", d3~getEventCode("bEnter", "CLICKED") == "self~enter"
d~setEventThread("bEnter", "CLICKED", "ui")

-- 4. a timer is a thread of its own
t = d~addControl("TIMER", 0, 0)
d~setProp(t, "interval", "0.5")
d~setEventCode(t, "TICK", 'self~status~setText(time())')
src4 = d~generate
call check "timer thread started in initDialog", src4~pos('self~start("timer_tmr1")') > 0
call check "timer sleeps its interval", src4~pos("call SysSleep 0.5") > 0
call check "tick is unguarded", src4~pos("::method on_tmr1_tick unguarded") > 0
call check "timer round trip", .OodDesign~fromSource(src4)~generate == src4
d~removeControl(t)
call check "removing a control removes its events", d~generate == src

-- 5. renaming carries the events and the self~name references
d~setProp("status", "name", "info")
src5 = d~generate
call check "rename rewrites self~status", src5~pos("self~status") == 0 & src5~pos("self~info~setText") > 0
call check "rename keeps events of other controls", d~getEventCode("form", "INIT") == 'self~info~setText("Ready")'
d~setProp("info", "name", "status")
call check "rename back restores the program", d~generate == src

-- 6. what is refused, and why
call refuses "a UserDialog method as a name", "d~setProp('lcd', 'name', 'execute')"
call refuses "a used name", "d~setProp('lcd', 'name', 'b7')"
call refuses "a name that is not a symbol", "d~setProp('lcd', 'name', '7up')"
call refuses "a style the control does not take", "d~setProp('lcd', 'opts', 'READONLY BOGUS')"
call refuses "an event the control does not have", "d~setEventCode('lcd', 'CLICKED', 'nop')"
call refuses "a code line starting ::", "d~setEventCode('b7', 'CLICKED', '::method x')"
call refuses "two OK buttons", "d~setProp('b7', 'role', 'OK'); d~setProp('b8', 'role', 'OK')"
call refuses "a background form event", "d~setEventThread('form', 'INIT', 'background')"
call refuses "an unknown control type", "d~addControl('HOLOGRAM', 0, 0)"
call refuses "a role for a button with event code", "d~setProp('bAdd', 'role', 'OK')"
call check "an OK or Cancel button has no events", d~eventNames("bClose") == ""

-- 7. code insertion: a control dropped on the code pane
acts = d~actionsFor("lcd")
call check "actions name the control", acts~pos("self~lcd~setText(") > 0
call check "list actions for a list only", acts~pos("~add(") == 0

-- 8. versions
call check "module_version", .OodDesign~module_version == "0.2.0" & d~module_version == "0.2.0"
call check "module_lastChanged", .OodCatalog~module_lastChanged \== ""

-- 9. v0.2: tab pages, list view, menu bar
v = .viewsDesign~build
vsrc = v~generate
call write "Contacts.rex", vsrc
call check "views round trip", .OodDesign~fromSource(vsrc)~generate == vsrc
call check "tab page handler connected", vsrc~pos('self~connectTabEvent(100, "SELCHANGE", "tabMain_pageChanged")') > 0
call check "page handler passes on to the user's SELCHANGE", vsrc~pos('forward message ("on_tabMain_selchange")') > 0
call check "first page shown at start", vsrc~pos("self~tabMain_show(1)") > 0
call check "list view columns in dialog units", vsrc~pos('self~lvPeople~insertColumn(1, "Role", 84)') > 0
call check "list view rows", vsrc~pos('self~lvPeople~addRow( , , "Mike Cowlishaw", "Created Rexx", "1979")') > 0
call check "menu popups and END", vsrc~pos('menu~addPopup(9002, "&View", "END")') > 0
call check "menu item with its event", vsrc~pos('menu~addItem(108, "&Grid lines", "CHECKED END", "on_mnuGrid_clicked")') > 0
call check "separator", vsrc~pos('menu~addSeparator(106, "")') > 0
call check "menu item accessor is its id", vsrc~pos("::method mnuGrid unguarded" || "0a"x || "  return 108") > 0
call check "event arguments known", v~eventArgs("lvPeople", "SELECTCHANGED") == "id, item, state, list"
call refuses "a page of a missing tab", "v~setProp('lblInfo', 'page', 'nope:1')"
call refuses "a page past the last tab", "v~setProp('lblInfo', 'page', 'tabMain:3')"
call refuses "a page for the tab itself", "v~setProp('tabMain', 'page', 'tabMain:1')"
call refuses "an unknown extended style", "v~setProp('lvPeople', 'exstyles', 'GRIDLINES SPARKLES')"
call refuses "a column width that is not a number", "v~setProp('lvPeople', 'columns', 'Name:wide')"
v~setProp("tabMain", "name", "tabs1")
call check "renaming a tab moves its pages", v~getProp("txtNotes", "page") == "tabs1:2"
v~removeControl("tabs1")
call check "removing a tab leaves its controls on no page", v~getProp("txtNotes", "page") == ""

say "t01_model:" checks - fails "of" checks "checks passed"
if fails > 0 then return 1
return 0

check: procedure expose fails checks
  use arg chkLabel, chkOk
  checks = checks + 1
  if chkOk then say "  ok  " chkLabel
  else do
    say "  FAIL" chkLabel
    fails = fails + 1
  end
  return

refuses: procedure expose fails checks d v
  use arg refLabel, refCode
  checks = checks + 1
  signal on syntax name refused
  interpret refCode
  say "  FAIL not refused:" refLabel
  fails = fails + 1
  return
refused:
  say "  ok   refuses" refLabel "--" condition("O")~at("MESSAGE")
  return

write: procedure
  use arg wrName, wrText
  st = .stream~new(wrName)
  st~open("write replace")
  st~charOut(wrText)
  st~close
  return

::requires "OodDesigner.cls"
::requires "calculator.rex"
::requires "views.rex"
