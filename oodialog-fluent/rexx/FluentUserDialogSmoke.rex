/* Architecture: Tom Dyer. Code: ChatGPT (GPT-6).                      */
/* Real ooDialog HWND + WinUI 3 + ooRexx package integration exercise. */
/* CI closes the asynchronous ooDialog through its own Rexx API.        */

parse arg catalogue
/* rexx.exe receives the command's quoted argument as Rexx text. */
catalogue = strip(catalogue, 'B', '"')
if catalogue == '' then do
  say 'REXX_SMOKE_ERROR=missing catalogue path'
  exit 2
end

dialog = .FluentSmokeDialog~new
dialog~catalogue = catalogue
if \ dialog~createCenter(300, 190, 'OodFluent ooDialog Runtime Smoke') then do
  say 'REXX_SMOKE_ERROR=ooDialog window creation failed'
  exit 3
end

say 'REXX_SMOKE_STAGE=EXECUTE_ASYNC_BEGIN'
dialog~executeAsync
call SysSleep 1
say 'REXX_SMOKE_STAGE=REQUEST_CLOSE'
dialog~ok
/* ooDialog's documented async join; do not exit while its GUI thread unwinds. */
result = dialog~endAsyncExecution
say 'REXX_SMOKE_END_ASYNC_RESULT='result
if result \= 1 then exit 4
say 'REXX_SMOKE_PASS=1'
exit 0

::requires 'ooDialog.cls'
::requires 'OodFluent.cls'

::class FluentSmokeDialog subclass UserDialog

::attribute catalogue

::method defineDialog
  self~createStaticText(101, 8, 8, 280, 16, , 'WinUI controls hosted in a real ooDialog dialog')
  self~createPushButton(1, 224, 162, 58, 15, 'DEFAULT', '&Close')

::method initDialog
  expose fluent button toggle check toggleButton slider auto radio repeat hyperlink appbar appbarToggle
  say 'REXX_SMOKE_STAGE=INIT_DIALOG'
  fluent = .OodFluentHost~attach(self, self~catalogue)
  fluent~move(16, 42, 390, 150)
  /* Automatic UID is intentionally allocated BEFORE low authored IDs. */
  auto = fluent~newButton(206, 'Auto identity collision probe')
  say 'REXX_SMOKE_AUTO_UID='auto~uid
  if left(auto~uid, 1) \== 'U' then raise user OodFluent additional ('automatic UID lacks opaque prefix')
  button = fluent~newButton(201, 'Native WinUI 3 Button', '800000001')
  toggle = fluent~newToggleSwitch(202, 'Native WinUI 3 Toggle', '800000002')
  check = fluent~newCheckBox(203, 'WinUI 3 CheckBox', '800000003')
  toggleButton = fluent~newToggleButton(204, 'WinUI 3 ToggleButton', '800000004')
  slider = fluent~newSlider(205, 'WinUI 3 Slider', '800000005')
  low = fluent~newButton(207, 'Low authored occurrence', '1')
  say 'REXX_SMOKE_LOW_AUTHORED_UID='low~uid
  radio = fluent~newRadioButton(208, 'Mode A', '800000006')
  repeat = fluent~newRepeatButton(209, 'Repeat', '800000007')
  hyperlink = fluent~newHyperlinkButton(210, 'ooRexx', '800000008')
  appbar = fluent~newAppBarButton(211, 'Save', '800000009')
  appbarToggle = fluent~newAppBarToggleButton(212, 'Favourite', '800000010')
  button~setText('WinUI button through Rexx')
  button~connectEvent('click', 'onFluentButton')
  toggle~connectEvent('toggled', 'onFluentToggle')
  check~connectEvent('checked', 'onFluentCheck')
  toggleButton~connectEvent('checked', 'onFluentToggleButton')
  slider~connectEvent('valueChanged', 'onFluentSlider')
  radio~connectEvent('checked', 'onFluentRadio')
  appbarToggle~connectEvent('checked', 'onFluentAppBarToggle')
  /* A property-driven native event tests the GUI queue -> Rexx boundary. */
  toggle~setOn(.true)
  check~setChecked(.true)
  toggleButton~setChecked(.true)
  slider~setValue(42.5)
  radio~setGroupName('Mode')
  radio~setChecked(.true)
  repeat~setDelay(500)
  repeat~setInterval(100)
  hyperlink~setNavigateUri('https://www.oorexx.org/')
  appbar~setLabel('Save changes')
  appbarToggle~setChecked(.true)
  say 'REXX_SMOKE_STAGE=CONTROLS_READY'

::method onFluentButton
  use strict arg resourceId, uid, value, revision
  say 'REXX_SMOKE_EVENT=button' resourceId uid value revision

::method onFluentToggle
  use strict arg resourceId, uid, value, revision
  say 'REXX_SMOKE_EVENT=toggle' resourceId uid value revision

::method onFluentCheck
  use strict arg resourceId, uid, value, revision
  say 'REXX_SMOKE_EVENT=check' resourceId uid value revision

::method onFluentToggleButton
  use strict arg resourceId, uid, value, revision
  say 'REXX_SMOKE_EVENT=toggleButton' resourceId uid value revision

::method onFluentSlider
  use strict arg resourceId, uid, value, revision
  say 'REXX_SMOKE_EVENT=slider' resourceId uid value revision

::method onFluentRadio
  use strict arg resourceId, uid, value, revision
  say 'REXX_SMOKE_EVENT=radio' resourceId uid value revision

::method onFluentAppBarToggle
  use strict arg resourceId, uid, value, revision
  say 'REXX_SMOKE_EVENT=appBarToggle' resourceId uid value revision

::method ok
  expose fluent
  say 'REXX_SMOKE_STAGE=OO_DIALOG_OK'
  count = fluent~dispatchPendingVersioned
  say 'REXX_SMOKE_EVENTS_DISPATCHED='count
  fluent~close
  say 'REXX_SMOKE_STAGE=FLUENT_CLOSED'
  return self~ok:super
