/* t33: CommonDialogCustomizations: the program's own controls in an Open dialog, their
   notices, and their values while the dialog is shown and after it */
.application~useGlobalConstDir("O")
.constDir[IDC_READONLY] = 501
.constDir[IDC_ENCODING] = 502
call SysMkDir "work"
do name over .array~of("a.rex", "b.cls", "c.txt")
  call charout "work/"name, "x"
  call stream "work/"name, "c", "close"
end
ofd = .MyOpen~new
ofd~setTitle("Custom open")
ofd~setFolder("work")
say "add" ofd~addCheckButton(IDC_READONLY, "Open read only", .true) ofd~addCheckButton(IDC_READONLY, "again") ofd~addCheckButton("NO_SUCH", "x")
say "group" ofd~startVisualGroup(510, "Encoding:") ofd~addComboBox(IDC_ENCODING) ofd~endVisualGroup
say "items" ofd~addControlItem(IDC_ENCODING, "UTF-8", 1) ofd~addControlItem(IDC_ENCODING, "Latin-1", 2) ofd~addControlItem(IDC_ENCODING, "Hidden", 3) ofd~addControlItem(IDC_READONLY, "no", 9)
say "item state" ofd~setControlItemState(IDC_ENCODING, 3, "INACTIVE") ofd~getControlItemState(IDC_ENCODING, 3) ofd~setSelectedControlItem(IDC_ENCODING, 1)
say "edit" ofd~addEditBox(520, "note") ofd~addText(521, "A text") ofd~addSeparator(522) ofd~addPushButton(523, "Fill") ofd~addPushButton(529, "Report")
say "radio" ofd~addRadioButtonList(524) ofd~addControlItem(524, "Whole file", 1) ofd~addControlItem(524, "First page", 2) ofd~setSelectedControlItem(524, 1)
say "menu" ofd~addMenu(525, "More") ofd~addControlItem(525, "Alpha", 11) ofd~addControlItem(525, "Beta", 12)
say "drop" ofd~enableOpenDropDown(526) ofd~addControlItem(526, "Open as copy", 21) ofd~addControlItem(526, "Open in new window", 22)
say "before" ofd~isChecked(IDC_READONLY) ofd~getEditBoxText(520) ofd~getSelectedControlItem(IDC_ENCODING) ofd~getControlState(520) ofd~getSelectedControlItem(525) ofd~removeAllControlItems(524) ofd~removeControlItem(524, 1) ofd~isChecked(777)
events = .Events~new
ofd~advise(events)
ret = ofd~show
say "show" ret filespec("NAME", ofd~getResult)
say "after" ofd~isChecked(IDC_READONLY) "[" || ofd~getEditBoxText(520) || "]" ofd~getSelectedControlItem(IDC_ENCODING) ofd~getSelectedControlItem(524) ofd~getSelectedControlItem(525) ofd~getSelectedControlItem(526)
say "log:" events~log
ofd~release
return 0

::requires "ooDialog.cls"

::class MyOpen subclass OpenFileDialog inherit CommonDialogCustomizations

::class Events subclass CommonDialogEvents
::attribute log
::method init
  self~log = ""
  forward class (super)
::method onCheckButtonToggled unguarded
  use arg cfd, hwnd, id, checked
  self~log = self~log "toggle:"id":"checked
  return self~S_OK
::method onButtonClicked unguarded
  use arg cfd, hwnd, id
  if id == 523 then do
    self~log = self~log "fill:"cfd~setEditBoxText(520, "filled")":"cfd~setControlLabel(521, "Changed text")":"cfd~setControlState(522, "INACTIVE")":"cfd~addCheckButton(590, "late")":"cfd~uncheck(IDC_READONLY)
    cfd~setControlItemText(IDC_ENCODING, 2, "ISO 8859-1")
  end
  else self~log = self~log "report:"cfd~isChecked(IDC_READONLY)":"cfd~getEditBoxText(520)":"cfd~getSelectedControlItem(IDC_ENCODING)":"cfd~getSelectedControlItem(524)
  return self~S_OK
::method onItemSelected unguarded
  use arg cfd, hwnd, itemID, ctlID
  self~log = self~log "item:"ctlID":"itemID
  return self~S_OK
::method onControlActivating unguarded
  use arg cfd, hwnd, id
  self~log = self~log "activating:"id
  return self~S_OK
