/* Architecture: Tom Dyer. Code: ChatGPT (GPT-6).                      */
/* Real ooDialog HWND + WinUI 3 + ooRexx package integration exercise. */
/* CI presses the ordinary ooDialog IDOK button to exercise teardown.  */

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

say 'REXX_SMOKE_STAGE=EXECUTE_BEGIN'
result = dialog~execute('SHOWTOP')
say 'REXX_SMOKE_EXECUTE_RESULT='result
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
  expose fluent button toggle
  say 'REXX_SMOKE_STAGE=INIT_DIALOG'
  fluent = .OodFluentHost~attach(self, self~catalogue)
  fluent~move(16, 54, 390, 140)
  button = fluent~newButton(201, 'Native WinUI 3 Button', '800000001')
  toggle = fluent~newToggleSwitch(202, 'Native WinUI 3 Toggle', '800000002')
  button~setText('WinUI button through Rexx')
  toggle~setOn(.true)
  button~connectEvent('click', 'onFluentButton')
  toggle~connectEvent('toggled', 'onFluentToggle')
  say 'REXX_SMOKE_STAGE=CONTROLS_READY'

::method onFluentButton
  use strict arg resourceId, uid, value
  say 'REXX_SMOKE_EVENT=button' resourceId uid value

::method onFluentToggle
  use strict arg resourceId, uid, value
  say 'REXX_SMOKE_EVENT=toggle' resourceId uid value

::method ok
  expose fluent
  say 'REXX_SMOKE_STAGE=OO_DIALOG_OK'
  fluent~dispatchPending
  fluent~close
  say 'REXX_SMOKE_STAGE=FLUENT_CLOSED'
  return self~ok:super
