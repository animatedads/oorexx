/* t25: the ReBar control and ReBarBandInfo.  Two bands hold a tool bar and a combo box; a
   third band starts a second row and holds an edit. */
dlg = .Main~new
dlg~create(30, 30, 260, 130, "Re-bar", "CENTER")
dlg~execute("SHOWTOP")
say "log:" dlg~log
return 0

::requires "ooDialog.cls"

::class Main subclass UserDialog
::attribute log
::method defineDialog
  self~createReBar(100, 0, 0, 0, 0)
  self~createToolBar(110, 0, 0, 0, 0)
  self~createComboBox(120, 0, 0, 80, 60, "LIST")
  self~createEdit(130, 0, 0, 80, 12)
  self~createStaticText(140, 5, 80, 250, 10, , "nothing yet")
  self~createPushButton(201, 5, 110, 60, 14, , "Change", onChange)
  self~createPushButton(1, 205, 110, 50, 14, "DEFAULT", "Close")
::method initDialog
  expose rb
  self~log = ""
  self~connectButtonEvent(301, 'CLICKED', onNew)
  tb = self~newToolBar(110)
  tb~addButtons(.array~of(.TbButton~new(301, "New", "BUTTON", "ENABLED"), .TbButton~new(302, "Open", "BUTTON", "ENABLED")))
  combo = self~newComboBox(120)
  combo~add("one"); combo~add("two"); combo~selectIndex(1)
  rb = self~newReBar(100)
  band1 = .ReBarBandInfo~new(tb, "Tools", "CHILDEDGE", "data-1", 501)
  say "band" band1~text band1~style band1~id band1~itemData (band1~child == tb) band1~mask
  say "insert" rb~insertBand(band1) rb~insertBand(.ReBarBandInfo~new(combo, "Pick", "NOGRIPPER", , 502, 140)) rb~getBandCount
  third = .ReBarBandInfo~new(self~newEdit(130), "Address", "BREAK", , 503)
  third~cyMinChild = 20
  third~imageIndex = 2
  say "third" rb~insertBand(third) rb~getBandCount rb~getRowCount (rb~getBarHeight > 40)
  got = rb~getBandInfo(2)
  say "getBandInfo" got~text got~style got~id got~cx (got~child == combo) (rb~getBandInfo(9) == .nil) rb~getBandInfo(3)~cyMinChild rb~getBandInfo(3)~imageIndex rb~getBandInfo(1)~itemData
  say "index" rb~idToIndex(503) rb~idToIndex(999)
  r1 = rb~getRect(1); r2 = rb~getRect(2); r3 = rb~getRect(3)
  say "rects" (r1~left == 0) (r2~left == r1~right) (r2~right - r2~left) (r3~top >= r1~bottom) (rb~getRect(9) == .nil) (rb~getRowHeight(1) > 20)
  info = .directory~new
  say "hit" rb~hitTestInfo(.Point~new(r2~left + 10, r2~top + 5), info) info~component rb~hitTestInfo(5, 500)
  old = rb~setBkColor(.Image~colorRef(220, 230, 250))
  say "colours" old rb~getBkColor rb~setTextColor(.Image~colorRef(0, 0, 128)) rb~getTextColor
  say "kept" rb~setExtendedStyle("DBLCLKTOGGLE", "DBLCLKTOGGLE") rb~getExtendedStyle (rb~setBarInfo("images") == .nil) rb~getBarInfo rb~getBandBorders(1)~isA(.Rect)
::method onNew unguarded
  self~log = self~log "new"
  self~newStatic(140)~setText("New pressed in the re-bar")
::method onChange unguarded
  expose rb
  say "move" rb~moveBand(1, 2) rb~getBandInfo(1)~text rb~getBandInfo(2)~text
  change = .ReBarBandInfo~new
  change~text = "Choose"
  say "setBandInfo" rb~setBandInfo(change, 1) rb~getBandInfo(1)~text rb~getBandInfo(1)~id rb~setBandWidth(1, 180) rb~getBandInfo(1)~cx
  say "show" rb~showBand(3) (rb~getRect(3) == .nil) rb~getRowCount rb~showBand(3, .true) rb~getRowCount
  say "delete" rb~deleteBand(3) rb~getBandCount rb~deleteBand(3) self~newEdit(130)~isVisible
