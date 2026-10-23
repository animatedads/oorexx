d = .Demo2~new
if d~getControlText(10) <> 'Start' then call fail 'text'
if d~newEdit(10)~appendText('!') <> 0 then call fail 'append'
if d~getControlText(10) <> 'Start!' then call fail 'append result'
b = d~getListBoxControl(20)
if b~add('alpha') <> 1 then call fail 'add 1'
if b~add('beta') <> 2 then call fail 'add 2'
if b~items <> 2 then call fail 'count'
if b~select(2) <> 0 then call fail 'select'
if b~selectedItem <> 'beta' then call fail 'selected'
if b~deleteAll <> 0 then call fail 'deleteAll'
if b~items <> 0 then call fail 'empty'
if d~getControlHandle(10) <> .nil then call fail 'handle'
if d~execute <> 0 then call fail 'execute'
if d~newPushButton(30)~click <> 77 then call fail 'callback'
if d~count <> 1 then call fail 'callback count'
say 'PASS: controls, list model, event translation, negative handle'
exit 0
fail: procedure
parse arg what
say 'FAIL:' what
exit 1
::class Demo2 subclass UserDialog
::method defineDialog
 expose count
 count = 0
 self~create(0,0,100,100,'Model')
 self~createEdit(10,1,1,10,10,,'Start')
 self~createListBox(20,1,1,10,10)
 self~createPushButton(30,1,1,10,10,,'Go')
::method initDialog
 self~connectControlEvent(30,'CLICKED','pressed')
::method pressed
 expose count
 count = count + 1
 return 77
::method count
 expose count
 return count
::requires 'ooDialog.cls'