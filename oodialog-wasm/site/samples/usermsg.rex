/* t30: user messages, the notifications every control has, the up-down reply, buttons
   from a stem, a status bar made after the dialog is shown, .Window, the public routines */
dlg = .UserMsg~new
dlg~execute("SHOWTOP")
return 0

::requires "ooDialog.cls"

::class UserMsg subclass UserDialog inherit CreateWindows
::method init
  forward class (super) continue
  self~create(30, 30, 240, 150, "User messages")
::method defineDialog
  self~createPushButton(40, 10, 10, 50, 14, , "Command")
  self~createPushButton(41, 65, 10, 50, 14, , "Send", onSend)
  self~createStaticText(42, 10, 30, 100, 10, "NOTIFY", "Click me")
  self~createEdit(43, 120, 10, 50, 12)
  self~createEdit(44, 120, 28, 40, 12)
  self~createUpDown(45, 160, 28, 12, 12, "SETBUDDYINT")
  self~createStaticText(46, 10, 45, 220, 10, , "")
  self~createListBox(47, 10, 60, 100, 40)
  b.0 = 2
  b.1.ID = 50; b.1.TEXT = "One"; b.1.METHOD = "onStem"
  b.2.ID = 51; b.2.TEXT = "Two"; b.2.METHOD = "onStem"; b.2.OPTS = "DEFAULT"
  say "stem" self~createPushButtonStem(120, 60, 40, 14, b., .true)
  self~createPushButton(IDCANCEL, 180, 110, 50, 14, , "Close")
  say "addUserMsg" self~addUserMsg(onCommand, "0x0111", , .DlgUtil~makeWParam(40, 0), "0xFFFFFFFF")
  say "addUserMsg" self~addUserMsg(onCustom, "0x0401", "0xFFFFFFFF", 7, "0xFFFFFFFF")
  say "notify" self~connectNotifyEvent(42, "CLICK", onStaticClick) self~connectNotifyEvent(43, "GOTFOCUS") self~connectNotifyEvent(43, "LOSTFOCUS") self~connectNotifyEvent(47, "RDBLCLK")
  self~connectUpDownEvent(45, "DELTAPOS", onDelta)
::method initDialog
  ud = self~newUpDown(45)
  ud~setBuddy(self~newEdit(44))
  ud~setRange(0, 100)
  ud~setPosition(1)
  sb = self~createStatusBarWindow(60)
  say "status bar" sb~class~id sb~setText("made later", 1) sb~getText(1)
  rb = self~createReBarWindow(62)
  say "more bars" rb~class~id .Image~fromIDs(.array~of(32512, 32513))~items self~initCreateWindows self~initWindowExtensions
  lb = self~newListBox(47)
  say "subclass" lb~addUserSubclass(onListMsg, "0x0402")
::method note
  use arg text
  say text
  self~newStatic(46)~setText(text)
::method onCommand unguarded
  use arg wParam, lParam
  self~note("command" .DlgUtil~loWord(wParam) .DlgUtil~hiWord(wParam) (lParam == self~newPushButton(40)~hwnd))
::method onCustom unguarded
  use arg wParam, lParam
  self~note("custom" wParam lParam)
  return 99
::method onListMsg unguarded
  use arg wParam, lParam
  say "list message" wParam lParam
  return 5
::method onSend unguarded
  say "sent" self~sendMessage("0x0401", 7, 12) self~sendMessage("0x0401", 8, 12)
  say "sent to list" self~newListBox(47)~sendMessage("0x0402", 3, 4)
  w = .Window~new(self~newEdit(43)~hwnd)
  w~setText("by window")
  say "window" w~getText self~newEdit(43)~getText .Window~new(self~hwnd)~getText
  say "findWindow" (findWindow("User messages") == self~hwnd) findWindow("No such dialog")
  say "toID" .Image~toID("IDI_HAND") .Image~toID("image_icon") .Image~toID("LR_SHARED") .Image~userIcon(self, 12)~isNull
  self~note("send done")
::method onStaticClick unguarded
  use arg id, hwnd
  self~note("static click" id (hwnd == self~newStatic(42)~hwnd))
::method onGotFocus unguarded
  use arg id
  say "got focus" id
::method onLostFocus unguarded
  use arg id
  self~note("lost focus" id)
::method onStem unguarded
  use arg wParam
  self~note("stem button" .DlgUtil~loWord(wParam))
::method onDelta unguarded
  use arg pos, delta
  say "delta" pos delta
  if pos + delta == 2 then return .UpDown~deltaPosReply(.true, .false, 9)     -- 1 -> 10
  if delta < 0 then return .UpDown~deltaPosReply(.true, .true)               -- no going down
  return .UpDown~deltaPosReply
