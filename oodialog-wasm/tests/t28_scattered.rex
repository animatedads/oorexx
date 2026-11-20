/* t28: natives scattered over the classes (v0.24.0) */
dlg = .Scattered~new
dlg~execute("SHOWTOP")
::requires "ooDialog.cls"
::class Scattered subclass UserDialog
::method init
  forward class (super) continue
  self~create(30, 30, 260, 190, "Scattered natives")
::method defineDialog
  self~createListBox(10, 5, 5, 70, 50, "NOTIFY")
  self~createListView(11, 80, 5, 170, 50, "REPORT")
  self~createTab(12, 5, 60, 150, 40)
  self~createTrackBar(13, 5, 105, 100, 16, "ENABLESELRANGE")
  self~createGroupBox(14, 160, 60, 90, 40, "", "Group")
  self~createTreeView(15, 110, 105, 70, 50, "LINES")
  self~createComboBox(16, 185, 105, 65, 60, "LIST")
  self~createPushButton(20, 5, 165, 50, 14, , "Run", onRun)
  self~createPushButton(IDCANCEL, 200, 165, 50, 14, , "Close")
  self~createStaticText(21, 60, 167, 130, 10, , "")
::method initDialog
  lb = self~newListBox(10)
  do i = 1 to 3
    lb~add("item" i)
  end
  lv = self~newListView(11)
  lv~insertColumnPx(0, "One", 80)
  lv~insertColumnPx(1, "Two", 60)
  lv~addRow( , , "a", "b")
  lv~addRow( , , "c", "d")
  tab = self~newTab(12)
  tab~addSequence("First", "Second", "Third")
  tv = self~newTreeView(15)
  self~root = tv~add("Root")
  tt = self~createToolTip(30)
  tt~addTool(self~newPushButton(20), "Runs the checks")
  self~tt = tt
::attribute root
::attribute tt
::method onRun unguarded
  lb = self~newListBox(10)
  info = .directory~new
  say "lb hit" lb~hitTestInfo(5, 5, info) info~inClientArea info~itemIndex
  say "lb far" lb~hitTestInfo(.Point~new(5, 6000), info) info~inClientArea info~itemIndex
  lv = self~newListView(11)
  p0 = lv~getItemPos(0)
  p1 = lv~getItemPos(1)
  say "lv pos" (p0~x >= 0) (p1~y > p0~y) lv~getItemPos(9)
  say "lv modify" lv~modifyColumnPx(1, "Deux", 90, "RIGHT") lv~columnWidthPx(1) lv~modifyColumnPx(7, "x")
  d = .directory~new
  ok = lv~getColumnInfo(1, d)
  say "lv column" ok d~text d~width d~fmt
  say "lv setItemPos" lv~setItemPos(0, 5, 5) lv~findNearestXY(1, 1)
  tab = self~newTab(12)
  r1 = .Rect~new
  r2 = .Rect~new
  say "tab rect" tab~getItemRect(0, r1) tab~getItemRect(1, r2) (r2~left > r1~left) (r1~bottom > r1~top) tab~getItemRect(9, r2)
  tb = self~newTrackBar(13)
  tb~initSelRange(20, 60)
  sel = tb~getSelRange
  say "trackbar sel" sel["START"] sel["END"]
  tb~clearSelRange
  sel = tb~getSelRange
  say "trackbar cleared" sel["START"] sel["END"]
  say "keys" .VK~key2name(13) .VK~key2name(112) .VK~key2name(65) "["||.VK~key2name(7)||"]" .Keyboard~getAsyncKeyState(.VK~SHIFT)
  gb = self~newGroupBox(14)
  gb~style = "RIGHT"
  h = self~childWindowFromPoint(.Point~new(20, 20))
  say "child" (h == lb~hwnd) (self~childWindowFromPoint(.Point~new(-50, -50)) == 0)
  tv = self~newTreeView(15)
  say "tv state" tv~getStateImage(self~root) tv~setStateImage(self~root, 2) tv~getStateImage(self~root) tv~getStateImage(12345)
  tt = self~tt
  m = .Rect~new(4, 2, 4, 2)
  tt~setMargin(m)
  g = tt~getMargin
  tt~setTipBkColor(.Image~colorRef(255, 255, 200))
  tt~setTipTextColor(.Image~colorRef(0, 0, 128))
  say "tt look" g~left g~top g~right g~bottom tt~getTipBkColor tt~getTipTextColor
  size = tt~getBubbleSize(self~newPushButton(20))
  r = .Rect~new(0, 0, 100, 20)
  ok = tt~adjustRect(r, .true)
  say "tt size" (size~width > 60) (size~height > 10) ok r~left r~top r~right r~bottom
  cb = self~newComboBox(16)
  ci = cb~getComboBoxInfo
  say "combo" ci~buttonState (ci~buttonRect~right > ci~buttonRect~left) (ci~textObj == cb)
  il = .ImageList~create(.Size~new(16, 16), "COLOR8", 2, 0)
  say "imagelist" (il~getIcon(0) == .nil)
  self~newStatic(21)~setText("done")
