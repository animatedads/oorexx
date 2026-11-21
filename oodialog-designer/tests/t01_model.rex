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
call check "module_version", .OodDesign~module_version == "0.18.0" & d~module_version == "0.18.0"

-- CATCH and FINALLY: found in the code, guarded in the program, refused on an older ooRexx
k = .calcDesign~build
call check "no CATCH: no guard, may run", \k~usesCatch & k~generate~pos("oodProbe") = 0 & k~catchRefusal == ""
k~setEventCode("bEnter", "CLICKED", "catch = 1" || "0a"x || "finally: nop")
call check "  catch = 1 and a label are not CATCH clauses", \k~usesCatch
k~setEventCode("bEnter", "CLICKED", "do" || "0a"x || "  self~enter" || "0a"x || "catch co = syntax" || "0a"x || "  say co~message" || "0a"x || "end")
kp = k~generate
call check "a CATCH clause found", k~usesCatch
call check "  the program asks its ooRexx: a lone CATCH clause compiled", kp~pos("signal on syntax name oodKnowsCATCH") > 0 & -
  kp~pos('oodProbe = .Routine~new("oodProbe", "catch syntax")') > 0 & kp~pos("oodKnowsCATCH:") > 0
call check "  and refuses to start where it compiles (a command there)", -
  kp~pos('call errorDialog "This program uses CATCH, which this ooRexx does not know: it would run it as a command."') > 0
call check "  not by revision (a build from git answers r0)", kp~pos("RexxInfo~revision") = 0
call check "  the guard comes before the dialog is made", kp~pos("oodProbe") < kp~pos("dlg = .Calculator~new")
call check "  and the round trip keeps the code", .OodDesign~fromSource(kp)~generate == kp
if \.OodDesign~knowsClause("catch syntax") then
  call check "  refused to run on this ooRexx, which does not know CATCH (r" || .RexxInfo~revision || ")", k~catchRefusal~pos("CATCH") > 0
else
  call check "  allowed on this ooRexx, which knows CATCH (r" || .RexxInfo~revision || ")", k~catchRefusal == ""
call check "knowsClause: a plain command clause is not a keyword", \.OodDesign~knowsClause("'ls'")
k~setEventCode("bEnter", "CLICKED", "self~enter" || "0a"x || "  FINALLY")
call check "  FINALLY alone too, any case", k~catchWords == "FINALLY"
if \.OodDesign~knowsClause("finally") then
  call check "  FINALLY refused on this ooRexx, which does not know it", k~catchRefusal~pos("FINALLY") > 0
else
  call check "  FINALLY allowed on this ooRexx, which knows it", k~catchRefusal == ""
call check "  its guard asks for FINALLY", k~generate~pos('oodProbe = .Routine~new("oodProbe", "finally")') > 0
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

-- 10. v0.3: tree view, track bar, date picker
g = .gadgetsDesign~build
gsrc = g~generate
call check "gadgets round trip", .OodDesign~fromSource(gsrc)~generate == gsrc
call check "tree root expanded", gsrc~pos('self~tvRexx~add("ooRexx", , , "EXPANDED")') > 0
call check "tree depth as blank arguments", gsrc~pos('self~tvRexx~add( , , "RxSock")') > 0
call check "track bar range and position", gsrc~pos("self~trkLevel~initRange(0, 50)") > 0 & gsrc~pos("self~trkLevel~pos = 30") > 0
call check "date picker event connected", gsrc~pos('self~connectDateTimePickerEvent(103, "DATETIMECHANGE", "on_dtpWhen_datetimechange")') > 0
call refuses "a tree whose first node is a child", "g~setProp('tvRexx', 'nodes', '.orphan|top')"
call refuses "a tree node with no text", "g~setProp('tvRexx', 'nodes', 'top|..')"

-- 11. v0.4: libraries and the shared scope
s = .calcDesign~build
s~addRequire("lib/alchemy/LoggingCore.cls")
s~setShared("logging", '.LogService~new("calculator")')
s~setEventCode("bEnter", "CLICKED", 'expose sharedScope' || "0a"x || 'L = sharedScope["logging"]' || "0a"x || 'self~status~setText("Logging service:" L~serviceId)')
ssrc = s~generate
call check "library required after ooDialog.cls", ssrc~pos('::requires "ooDialog.cls"' || "0a"x || '::requires "lib/alchemy/LoggingCore.cls"') > 0
call check "sharedScope attribute", ssrc~pos("::attribute sharedScope") > 0
call check "shared entry made in init", ssrc~pos('self~sharedScope["logging"] = .LogService~new("calculator")') > 0
call check "shared scope round trip", .OodDesign~fromSource(ssrc)~generate == ssrc
call refuses "sharedScope as a control name", "d~setProp('lcd', 'name', 'sharedScope')"
call refuses "a shared entry with no value", "g~setShared('x', '')"

-- 12. v0.16 (ooDialog/WASM v0.21): up-down with its buddy, month calendar,
-- tool tips, track bar DRAG and ENDTRACK
g = .gadgetsDesign~build
e = g~addControl("EDIT", 10, 150)
u = g~addControl("UPDOWN", 92, 150)
call check "an up-down dropped after an entry field takes it as buddy", g~getProp(u, "buddy") == e
call check "  and SETBUDDYINT ARROWKEYS, not AUTOBUDDY", g~getProp(u, "opts") == "SETBUDDYINT ARROWKEYS"
g~setProp(u, "min", 1); g~setProp(u, "max", 9); g~setProp(u, "pos", 3)
g~setEventCode(u, "DELTAPOS", "say pos delta")
cal = g~addControl("MONTHCALENDAR", 110, 120)
g~setEventCode(cal, "SELECT", "say startDate~standardDate")
g~setEventCode("trkLevel", "DRAG", "say .DlgUtil~hiWord(info)")
g~setProp(e, "tip", "How many, 1 to 9")
g~setProp("trkLevel", "tip", 'Drag me, or use the "arrow" keys')
usrc = g~generate
call check "up-down made with createUpDown", usrc~pos("self~createUpDown(") > 0 & usrc~pos('"SETBUDDYINT ARROWKEYS")') > 0
call check "  its buddy set in initDialog", usrc~pos("self~"u"~setBuddy(self~"e")") > 0
call check "  its range and position", usrc~pos("self~"u"~setRange(1, 9)") > 0 & usrc~pos("self~"u"~setPosition(3)") > 0
call check "  its buddy's data starts at its position (execute sets it after initDialog)", usrc~pos("self~"e"_data = 3") > 0
call check "  DELTAPOS connected, with its arguments", usrc~pos('self~connectUpDownEvent(') > 0 & usrc~pos('"DELTAPOS", "on_'u'_deltapos")') > 0 & g~eventArgs(u, "DELTAPOS") == "pos, delta, id, hwnd, ud"
call check "month calendar made and SELECT connected", usrc~pos("self~createMonthCalendar(") > 0 & usrc~pos('"SELECT", "on_'cal'_select")') > 0 & g~eventArgs(cal, "SELECT") == "startDate, endDate, id, hwnd"
call check "track bar DRAG connected", usrc~pos('self~connectTrackBarEvent(') > 0 & usrc~pos('"DRAG", "on_trkLevel_drag")') > 0 & g~eventArgs("trkLevel", "DRAG") == "info, hwnd"
call check "one ToolTip, its id after the controls'", usrc~pos("tips = self~createToolTip(") > 0 & usrc~countStr("createToolTip(") = 1
call check "  a tool per tip, quotes doubled", usrc~pos('tips~addTool(self~'e', "How many, 1 to 9")') > 0 & usrc~pos('tips~addTool(self~trkLevel, "Drag me, or use the ""arrow"" keys")') > 0
call check "new kinds round trip", .OodDesign~fromSource(usrc)~generate == usrc
call refuses "a buddy that is not on the form", "g~setProp('"u"', 'buddy', 'nobody')"
call refuses "an up-down as its own buddy", "g~setProp('"u"', 'buddy', '"u"')"
call refuses "a tip of two lines", "g~setProp('trkLevel', 'tip', 'one' || '0a'x || 'two')"
g~setProp(e, "name", "txtHowMany")
call check "renaming the buddy follows it", g~getProp(u, "buddy") == "txtHowMany"
g~removeControl("txtHowMany")
call check "a buddy removed is a problem", g~problems~pos(u": its buddy txtHowMany is not on the form any more") > 0
g~setLanguages("en de")
nsrc = g~generate
call check "with languages, a tip is a text of the table", nsrc~pos('tips~addTool(self~trkLevel, self~nls("trkLevel.tip"))') > 0 & g~nlsKeys~hasItem("trkLevel.tip")
call check "  a control with no tip has no key", \g~nlsKeys~hasItem(cal".tip")

-- 13. v0.17: a resizable form (ResizingAdmin) and anchors
r = .OodDesign~new("Sizer")
r~setProp("form", "w", 200); r~setProp("form", "h", 120)
lb = r~addControl("LISTBOX", 6, 6)
ok = r~addControl("PUSHBUTTON", 140, 100)
mid = r~addControl("STATIC", 80, 50)
call check "a new control is anchored LEFT TOP", r~getProp(lb, "anchor") == "LEFT TOP"
plain = r~generate
call check "not resizable: no ResizingAdmin, no defineSizing", plain~pos("ResizingAdmin") = 0 & plain~pos("defineSizing") = 0
r~setProp("form", "resizable", 1)
r~setProp(lb, "anchor", "bottom right top left")
r~setProp(ok, "anchor", "RIGHT BOTTOM")
r~setProp(mid, "anchor", "")
call check "anchor is put in order, upper case", r~getProp(lb, "anchor") == "LEFT TOP RIGHT BOTTOM"
call check "no edge is CENTER", r~getProp(mid, "anchor") == "CENTER"
rs = r~generate
call check "resizable: inherits ResizingAdmin", rs~pos("::class Sizer subclass UserDialog inherit ResizingAdmin") > 0
call check "  THICKFRAME added to the style", rs~pos('"CENTER THICKFRAME")') > 0
call check "  default: stationary left and top, own width and height", rs~pos('self~defaultSizing(.array~of("STATIONARY", "LEFT"), .array~of("STATIONARY", "TOP"), .array~of("MYLEFT", "LEFT"), .array~of("MYTOP", "TOP"))') > 0
lbId = r~getProp(lb, "id")
call check "  all four: it stretches", rs~pos('self~controlSizing('lbId', .array~of("STATIONARY", "LEFT"), .array~of("STATIONARY", "TOP"), .array~of("STATIONARY", "RIGHT"), .array~of("STATIONARY", "BOTTOM"))') > 0
okId = r~getProp(ok, "id")
call check "  right and bottom: it moves, its size kept", rs~pos('self~controlSizing('okId', .array~of("STATIONARY", "RIGHT"), .array~of("STATIONARY", "BOTTOM"), .array~of("MYLEFT", "LEFT"), .array~of("MYTOP", "TOP"))') > 0
call check "  none: it keeps to the centre", rs~pos('.array~of("STATIONARY", "XCENTER"), .array~of("STATIONARY", "YCENTER"), .array~of("MYLEFT", "LEFT"), .array~of("MYTOP", "TOP"))   --' mid": CENTER") > 0
call check "  a control left at LEFT TOP gets no line of its own", rs~countStr("self~controlSizing(") = 3
call check "  defineSizing returns 0", rs~pos("::method defineSizing") > 0 & rs~substr(rs~pos("::method defineSizing"))~pos("  return 0") > 0
call check "resizable round trips", .OodDesign~fromSource(rs)~generate == rs
g = r                                 -- refuses exposes g
call refuses "an anchor that is not an edge", "g~setProp('"lb"', 'anchor', 'LEFT MIDDLE')"
call refuses "resizable is 0 or 1", "g~setProp('form', 'resizable', 2)"
-- a control on a tab page is pinned to the tab control, and the tab comes first
tb = r~addControl("TAB", 6, 60)
r~setProp(tb, "tabs", "One|Two")
onp = r~addControl("EDIT", 12, 80)
r~setProp(onp, "page", tb":1")
r~setProp(tb, "anchor", "LEFT TOP RIGHT BOTTOM")
ts = r~generate
tbId = r~getProp(tb, "id"); onId = r~getProp(onp, "id")
call check "on a tab page: pinned to the tab", ts~pos('self~controlSizing('onId', .array~of("STATIONARY", "LEFT",' tbId'), .array~of("STATIONARY", "TOP",' tbId'), .array~of("MYLEFT", "LEFT"), .array~of("MYTOP", "TOP"))') > 0
call check "  the tab control is given before the controls pinned to it", ts~pos("self~controlSizing("tbId",") < ts~pos("self~controlSizing("onId",")
call check "an older design (no anchor) is LEFT TOP", .OodDesign~fromSource(changestr("anchor=", ts, "anchorX="))~generate~pos("controlSizing("lbId",") = 0

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

refuses: procedure expose fails checks d v g
  use arg refLabel, refCode
  checks = checks + 1
  signal on syntax name refused
  interpret refCode
  say "  FAIL not refused:" refLabel
  fails = fails + 1
  return
refused:
  -- the designer's own refusal: Error 93.900 with its message, not any error
  if condition("O")~at("CODE") \== "93.900" | condition("O")~at("ADDITIONAL")~isA(.Array) = .false then do
    say "  FAIL refused, but not by the designer:" refLabel "--" condition("O")~at("MESSAGE")
    fails = fails + 1
    return
  end
  say "  ok   refuses" refLabel "--" condition("O")~at("ADDITIONAL")[1]~left(90)
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
::requires "gadgets.rex"
