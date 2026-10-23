d = .ImportedDialog~new
model = .directory~new
dialog = .directory~new
model~put(dialog, 'dialog')
dialog~put('Imported test dialog','title')
dialog~put(280,'width')
dialog~put(120,'height')
controls = .array~new
dialog~put(controls,'controls')
controls~append(makeControl(101,'PUSHBUTTON','Save'))
controls~append(makeControl(102,'EDIT','initial'))
call verify d~loadResourceModel(model) = 0, 'import'
call verify d~getTitle = 'Imported test dialog', 'title'
call verify d~getSize[1] = 280, 'width'
call verify d~getButtonControl(101)~getText = 'Save', 'caption'
call verify d~getEditControl(102)~getText = 'initial', 'edit'
call verify d~connectButtonEvent(101,'CLICKED','saved') = 0, 'connect'
call verify d~getButtonControl(101)~click = 7, 'callback'
bad = .directory~new
baddialog = .directory~new
bad~put(baddialog,'dialog')
arr = .array~new
arr~append(makeControl(101,'PUSHBUTTON','Collision'))
baddialog~put(arr,'controls')
call verify d~loadResourceModel(bad) = -1, 'reject conflicting id'
call verify d~getButtonControl(101)~getText = 'Save', 'preserve on rejection'
say 'PASS: decoded JSON resource model boundary, callbacks, collision rejection'
exit 0
makeControl: procedure
 use arg id,kind,caption
 ctl = .directory~new
 ctl~put(id,'id')
 ctl~put(kind,'type')
 ctl~put(caption,'text')
 ctl~put(0,'x')
 ctl~put(0,'y')
 ctl~put(50,'width')
 ctl~put(15,'height')
 return ctl
verify: procedure
 use arg pass,msg
 if \pass then do
   say 'FAIL:' msg
   exit 1
 end
 return
::class ImportedDialog subclass UserDialog
::method saved
 return 7
::requires 'ooDialog.cls'