/* Minimal load and dispatch test. The Linux module is intentionally headless. */
d = .Demo~new
if d~getTitle <> 'Linux dialog' then raise syntax 40.1 array ('title')
if d~getControlText(100) <> 'Save' then raise syntax 40.1 array ('label')
if d~execute <> 0 then raise syntax 40.1 array ('execute')
if d~newPushButton(100)~click <> 42 then raise syntax 40.1 array ('callback')
if d~seen <> 1 then raise syntax 40.1 array ('dispatch')
say 'PASS: load, subclass, defineDialog, control lookup, text, callback'
::class Demo subclass UserDialog
::method defineDialog
  expose seen
  seen = 0
  self~create(0,0,180,80,'Linux dialog')
  self~createPushButton(100,5,5,60,20,, 'Save')
::method initDialog
  self~connectButtonEvent(100,'CLICKED','saveClicked')
::method saveClicked
  expose seen
  seen = seen + 1
  return 42
::method seen
  expose seen
  return seen
::requires 'ooDialog.cls'