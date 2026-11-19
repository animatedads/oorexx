/* t23: the ToolBar control and TbButton.  The first part follows upstream toolBar.rex
   (three buttons, the third inserted second); upstream's own needs its compiled toolBar.dll. */
dlg = .Main~new
dlg~create(30, 30, 240, 120, "Tool bar", "CENTER")
dlg~execute("SHOWTOP")
say "log:" dlg~log
return 0

::requires "ooDialog.cls"

::class Main subclass UserDialog
::attribute log
::constant IDB_PRESS 301
::constant IDB_WHERE 302
::constant IDB_PUSH  303
::method defineDialog
  self~createToolBar(100, 0, 0, 0, 0)
  self~createStaticText(110, 5, 40, 230, 10, , "nothing yet")
  self~createPushButton(201, 5, 60, 60, 14, , "Report", onReport)
  self~createPushButton(1, 185, 100, 50, 14, "DEFAULT", "Close")
::method initDialog
  expose tb
  self~log = ""
  self~connectButtonEvent(self~IDB_PRESS, 'CLICKED', onPress)
  self~connectButtonEvent(self~IDB_WHERE, 'CLICKED', onWhere)
  self~connectButtonEvent(self~IDB_PUSH, 'CLICKED', onPush)
  self~connectButtonEvent(304, 'CLICKED', onBold)
  self~connectButtonEvent(305, 'CLICKED', onAlign)
  self~connectButtonEvent(306, 'CLICKED', onAlign)
  tb = self~newToolBar(100)
  tbb1 = .TbButton~new(self~IDB_PRESS, "Press Me Please", "BUTTON", "ENABLED")
  tbb2 = .TbButton~new(self~IDB_WHERE, "Where Am I?", "BUTTON", "ENABLED")
  tbb3 = .TbButton~new(self~IDB_PUSH, "Please Push Me", "BUTTON", "ENABLED", "data-push", 4)
  say "button" tbb3~cmdID tbb3~text tbb3~style tbb3~state tbb3~itemData tbb3~bitmapID
  say "add" tb~addButtons(.array~of(tbb1, tbb2)) tb~insertButton(tbb3, 2) tb~buttonCount
  tb~autoSize
  say "index" tb~commandToIndex(self~IDB_PUSH) tb~commandToIndex(999) tb~indexTocommand(3) tb~indexTocommand(9)
  first = tb~addString(.array~of("Bold", "Left", "Right"))
  say "strings" first tb~addString(.array~of("more"))
  tb~addButtons(.array~of(.TbButton~new(0, , "SEP"), .TbButton~new(304, 1, "CHECK", "ENABLED"), .TbButton~new(0, , "SEP"), -
                          .TbButton~new(305, 2, "CHECKGROUP", "ENABLED CHECKED"), .TbButton~new(306, 3, "CHECKGROUP", "ENABLED"), -
                          .TbButton~new(307, "Off", "BUTTON", "")))
  got = tb~getButton(2)
  say "getButton" got~cmdID got~text got~style got~state got~itemData got~bitmapID (tb~getButton(99) == .nil)
  say "text" tb~getButtonText(305) (tb~getButtonText(999) == .nil) tb~setButtonText("Pushed", self~IDB_PUSH) tb~getButtonText(self~IDB_PUSH) tb~setButtonText("x", 999)
  say "states" tb~isButtonEnabled(307) tb~enableButton(307) tb~isButtonEnabled(307) tb~isButtonChecked(304) tb~checkButton(304) tb~isButtonChecked(304) tb~checkButton(304, .false) tb~isButtonChecked(304) tb~isButtonHidden(304) tb~isButtonPressed(304) tb~isButtonIndeterminate(304) tb~isButtonHighlighted(304)
  say "images" tb~setBitmapSize(24, 24) tb~addBitmap(.nil, 3) tb~addBitmap(.nil, 2) tb~loadImages("STDSMALL") tb~setBitmapSize(16, 16) tb~changeBitmap(304, 2) tb~getButton(5)~bitmapID (tb~setImageList("il") == .nil) tb~getImageList tb~setExtendedStyle("mixedButtons") tb~getExtendedStyle tb~customize
::method onPress unguarded
  self~log = self~log "press"
  self~newStatic(110)~setText("pressed")
::method onPush unguarded
  self~log = self~log "push"
::method onWhere unguarded
  expose tb
  self~log = self~log "where"
  self~newStatic(110)~setText("There are" tb~buttonCount "buttons.")
::method onBold unguarded
  expose tb
  self~log = self~log "bold:"tb~isButtonChecked(304)
::method onAlign unguarded
  expose tb
  self~log = self~log "align:"tb~isButtonChecked(305)||tb~isButtonChecked(306)
::method onReport unguarded
  expose tb
  tb~enableButton(self~IDB_PRESS, .false)
