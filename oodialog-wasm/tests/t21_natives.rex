/* t21: natives ported in v0.21.0 that have no upstream example of their own: windows by
   handle, a control's key presses, item data of a combo box and a tree-view, lines of an
   edit, DlgUtil's arithmetic, SM, SPI and OS. */
dlg = .Main~new
dlg~create(30, 30, 240, 150, "Natives", "CENTER")
dlg~execute("SHOWTOP")
say "keys:" dlg~log
return 0

::requires "ooDialog.cls"

::class Main subclass UserDialog
::attribute log
::method defineDialog
  self~createEdit(10, 5, 5, 110, 40, "MULTILINE WANTRETURN")
  self~createEdit(11, 5, 50, 110, 12)
  self~createComboBox(12, 125, 5, 100, 60, "LIST")
  self~createTreeView(13, 125, 25, 100, 60)
  self~createStaticText(14, 5, 70, 110, 10, , "label")
  self~createPushButton(1, 185, 130, 50, 14, "DEFAULT", "Close")
::method initDialog
  self~log = ""
  edit = self~newEdit(10)
  one = self~newEdit(11)
  say "DlgUtil" .DlgUtil~shiftLeft(1, 4) .DlgUtil~shiftRight(256, 4) .DlgUtil~sShiftLeft(-1, 2) .DlgUtil~sShiftRight(-16, 2) .DlgUtil~signed32(4294967295) .DlgUtil~unsigned32(-1) -
      .DlgUtil~sloWord(65535) .DlgUtil~shiWord("0xFFFE0001") .DlgUtil~signed("0xFFFFFFFFFFFFFFFF") .DlgUtil~unsigned(-2)
  say "SM" (.SM~cxScreen > 300) (.SM~cyScreen > 200) .SM~cxIcon .SM~cySmIcon .SM~cMouseButtons .SM~cxVScroll
  .SPI~wheelScrollLines = 5
  .SPI~mouseHoverTime = 250
  say "SPI" .SPI~wheelScrollLines .SPI~mouseHoverTime .SPI~dragWidth .SPI~menuFade .SPI~nonClientMetrics~scrollWidth
  say "OS" .OS~is64bit .OS~is32on64bit .OS~isAtLeastVista .OS~isAtLeastWindows7
  area = .DlgUtil~screenArea
  say "screenArea" (area~right == .SM~cxScreen) (area~bottom == .SM~cyScreen)

  say "getWindowText" self~getWindowText(self~hwnd) "/" self~getWindowText(self~getControlHandle(14)) "/" (self~getWindowText("0x0000000000000007") == "")
  say "setWindowText" self~setWindowText(self~getControlHandle(14), "changed") self~newStatic(14)~getText self~setWindowText("0x0000000000000007", "x")
  say "hideWindow" self~hideWindow(self~getControlHandle(14)) self~newStatic(14)~isVisible self~showWindow(self~getControlHandle(14)) self~newStatic(14)~isVisible

  edit~setText("one" || .endOfLine || "three" || .endOfLine || "five5")
  say "lines" self~sendMessageToControl(10, "0x00BA", 0, 0) self~sendMessageToWindow(edit~hwnd, "0x00BA", 0, 0)
  say "edit" edit~lineFromIndex(1) edit~lineFromIndex(5) edit~lineFromIndex(11) "index" edit~lineIndex(1) edit~lineIndex(2) edit~lineIndex(3) edit~lineIndex(9) "length" edit~lineLength(1) edit~lineLength(2) edit~lineLength(3)
  one~setCue("type here")
  say "cue" one~getCue

  combo = self~newComboBox(12)
  combo~add("b"); combo~add("a"); combo~add("c")
  say "cb data" (combo~setItemData(2, "data-a") == .nil) combo~getItemData(2) (combo~getItemData(1) == .nil) (combo~getItemData(9) == .nil)
  combo~insert(1, "first")
  say "cb data moved" combo~getItemData(3) (combo~getItemData(2) == .nil) "removed" combo~removeItemData(3) (combo~getItemData(3) == .nil)

  tree = self~newTreeView(13)
  root = tree~add("root")
  tree~setItemData(root, "data-root")
  say "tv data" tree~getItemData(root) tree~removeItemData(root) (tree~getItemData(root) == .nil) (tree~getItemHeight > 8)

  size = .Size~new
  say "textSize" edit~textSize("some text", size) (size~width > 20) (size~height > 8)
  r = self~newPushButton(1)~getTextMargin
  say "margin" r~isA(.Rect) self~newPushButton(1)~setTextMargin(.Rect~new(3, 2, 3, 2)) self~newPushButton(1)~getTextMargin~left

  one~connectKeyPress(onOneKey, "65, 66", "NONE")
  edit~connectFKeyPress(onEditF)
  say "connections" one~hasKeyPressConnection one~hasKeyPressConnection("onOneKey") one~hasKeyPressConnection("other") edit~hasKeyPressConnection self~newComboBox(12)~hasKeyPressConnection
  self~connectKeyPress(onAnyKey, "67", "NONE")
::method onOneKey unguarded
  use arg key, shift, control, alt, info, ctrl
  self~log = self~log "one:"key":"ctrl~id
::method onEditF unguarded
  use arg key, shift, control, alt, info, ctrl
  self~log = self~log "f:"key":"ctrl~id
::method onAnyKey unguarded
  use arg key
  self~log = self~log "any:"key
::method ok unguarded
  one = self~newEdit(11)
  say "disconnect" one~disconnectKeyPress one~hasKeyPressConnection
  pos = self~newPushButton(1)~windowRect
  at = .DlgUtil~windowFromPoint(.Point~new(pos~left + 5, pos~top + 5))
  say "windowFromPoint" (at == self~getControlHandle(1)) (.DlgUtil~windowFromPoint(.Point~new(1, 1)) == 0)
  return self~ok:super
