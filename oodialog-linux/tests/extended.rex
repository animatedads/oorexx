d = .Extended~new
call verify d~hasControl(10), 'hasControl'
call verify \d~hasControl(999), 'missing'
call verify d~getSize[1] = 120, 'size'
call verify d~getFocus == .nil, 'no initial focus'
call verify d~newEdit(10)~setFocus = 0, 'focus'
call verify d~newEdit(10)~hasFocus, 'hasFocus'
call verify d~newPushButton(20)~disable = 0, 'disable'
call verify d~newPushButton(20)~setFocus = -1, 'disabled focus'
p = d~getProgressBarControl(30)
call verify p~setRange(5,25) = 0, 'range'
call verify p~setPosition(100) = 0, 'progress clamp'
call verify p~getPosition = 25, 'max clamp'
call verify p~step(-4) = 0, 'step'
call verify p~getPosition = 21, 'stepped'
call verify p~setRange(30,10) = -1, 'bad range'
call verify d~execute = 0, 'execute'
call verify d~newPushButton(20)~click = 9, 'button callback'
call verify d~calls = 1, 'calls'
call verify d~execute = 0, 'second execute'
call verify d~calls = 1, 'initDialog invoked only once'
call verify d~ok = 0, 'ok'
call verify \d~isDialogActive, 'inactive after ok'
say 'PASS: focus, progress, lifecycle, callbacks'
exit 0
verify: procedure
use arg pass, description
if \pass then do
 say 'FAIL:' description
 exit 1
end
return
::class Extended subclass UserDialog
::method defineDialog
 expose calls
 calls = 0
 self~create(0,0,120,80,'Extended')
 self~createEdit(10,1,1,20,10,,'abc')
 self~createPushButton(20,1,1,20,10,,'Push')
 self~createProgressBar(30,1,1,20,10)
::method initDialog
 self~connectButtonEvent(20,'CLICKED','pressed')
::method pressed
 expose calls
 calls = calls + 1
 return 9
::method calls
 expose calls
 return calls
::requires 'ooDialog.cls'