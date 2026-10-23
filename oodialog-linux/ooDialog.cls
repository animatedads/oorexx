/* ooDialog Linux compatibility experiment dev3.
 * This is a headless semantic test double, NOT a GUI backend or an
 * 80-percent compatible implementation. Unsupported methods fail visibly.
 */
::class 'PlainBaseDialog' public
::method init
  expose controls callbacks title width height running dialogResult focused initialized
  controls = .directory~new
  callbacks = .directory~new
  title = ''
  width = 0
  height = 0
  running = .false
  dialogResult = 0
  focused = .nil
  initialized = .false
::method create
  expose title width height
  use arg x,y,w,h,caption
  if arg(3,'E') then width = w
  if arg(4,'E') then height = h
  if arg(5,'E') then title = caption
  return 0
::method defineDialog
  return 0
::method initDialog
  return 0
::method execute
  expose running dialogResult initialized
  running = .true
  dialogResult = 0
  if \initialized then do
    self~initDialog
    initialized = .true
  end
  return dialogResult
::method endDialog
  expose running dialogResult
  use arg value
  if arg(1,'E') then dialogResult = value
  running = .false
  return 0
::method ok
  return self~endDialog(1)
::method cancel
  return self~endDialog(2)
::method isDialogActive
  expose running
  return running
::method setTitle
  expose title
  use strict arg newTitle
  title = newTitle
  return 0
::method getTitle
  expose title
  return title
::method getSize
  expose width height
  return .array~of(width,height)
::method setFocus
  expose focused controls
  use strict arg id
  c = controls~at(id)
  if c == .nil then return -1
  if \c~isEnabled | \c~isVisible then return -1
  focused = id
  return 0
::method getFocus
  expose focused
  return focused
::method addControl
  expose controls
  use arg kind,id,x,y,w,h,style,caption
  if \arg(2,'E') then return -1
  select
    when kind~upper = 'LISTBOX' then ctl = .ListBox~new(self,id,kind)
    when kind~upper = 'COMBOBOX' then ctl = .ComboBox~new(self,id,kind)
    when kind~upper = 'PROGRESSBAR' then ctl = .ProgressBar~new(self,id,kind)
    when kind~upper = 'GROUPBOX' then ctl = .GroupBox~new(self,id,kind)
    when kind~upper = 'STATIC' then ctl = .Static~new(self,id,kind)
    when kind~upper = 'EDIT' then ctl = .Edit~new(self,id,kind)
    when kind~upper = 'PUSHBUTTON' then ctl = .PushButton~new(self,id,kind)
    when kind~upper = 'CHECKBOX' then ctl = .CheckBox~new(self,id,kind)
    when kind~upper = 'RADIOBUTTON' then ctl = .RadioButton~new(self,id,kind)
    otherwise ctl = .DialogControl~new(self,id,kind)
  end
  if arg(8,'E') then ctl~setText(caption)
  controls~put(ctl, id)
  return 0
/* Accept a decoded JSON resource document as ooRexx Directory/Array objects.
 * Parsing JSON text belongs to the resource adapter; this entry point
 * deliberately never executes resource-provided Rexx or event handlers.
 * Provisional interchange contract, not upstream ooDialog parity. */
::method loadResourceModel
  expose controls title width height
  use strict arg model
  if \(model~isInstanceOf(.Directory)) then return -1
  dlg = model~at('dialog')
  if dlg == .nil then return -1
  if \(dlg~isInstanceOf(.Directory)) then return -1
  entries = dlg~at('controls')
  if \(entries~isInstanceOf(.Array)) then return -1
  newTitle = dlg~at('title')
  newWidth = dlg~at('width')
  newHeight = dlg~at('height')
  seen = .directory~new
  do i = 1 to entries~items
    entry = entries[i]
    if \(entry~isInstanceOf(.Directory)) then return -1
    idValue = entry~at('id')
    typeValue = entry~at('type')
    if idValue == .nil | typeValue == .nil then return -1
    if \(idValue~datatype('W')) then return -1
    if idValue < 0 then return -1
    if seen~hasIndex(idValue) | controls~hasIndex(idValue) then return -1
    seen~put(1,idValue)
    k = typeValue~upper
    if k \= 'PUSHBUTTON' & k \= 'EDIT' & k \= 'CHECKBOX' & k \= 'RADIOBUTTON' & k \= 'LISTBOX' & k \= 'COMBOBOX' & k \= 'PROGRESSBAR' & k \= 'GROUPBOX' & k \= 'STATIC' then return -1
  end
  if newTitle \== .nil then title = newTitle
  if newWidth \== .nil then width = newWidth
  if newHeight \== .nil then height = newHeight
  do i = 1 to entries~items
    entry = entries[i]
    caption = entry~at('text')
    if caption == .nil then caption = ''
    self~addControl(entry~at('type'),entry~at('id'),entry~at('x'),entry~at('y'),entry~at('width'),entry~at('height'),entry~at('style'),caption)
  end
  return 0
/* V5 executable resource tree adapter.  Keeps ooDialog control wrappers
 * independent of RcNode, and exposes source node for renderer integration. */
::method loadRcTree
  expose controls title width height rcTree rcDialog
  use strict arg tree, dialogId
  if \(tree~isInstanceOf(.RcNode)) then return -1
  dlg = tree~find(dialogId)
  if dlg == .nil then return -1
  if \(dlg~nodeType~upper = 'DIALOG' | dlg~nodeType~upper = 'DIALOGEX') then return -1
  resource = dlg~properties
  if \(resource~isInstanceOf(.Directory)) then return -1
  planned = .array~new
  seen = .directory~new
  do node over dlg~children
    entry = node~properties
    if node~nodeType~upper \= 'CONTROL' then iterate
    if \(entry~isInstanceOf(.Directory)) then return -1
    kind = entry~at('controlType')
    if kind == .nil then return -1
    select
      when kind~upper = 'EDITTEXT' then mapped = 'EDIT'
      when kind~upper = 'PUSHBUTTON' then mapped = 'PUSHBUTTON'
      when kind~upper = 'DEFPUSHBUTTON' then mapped = 'PUSHBUTTON'
      when kind~upper = 'CHECKBOX' then mapped = 'CHECKBOX'
      when kind~upper = 'AUTOCHECKBOX' then mapped = 'CHECKBOX'
      when kind~upper = 'RADIOBUTTON' then mapped = 'RADIOBUTTON'
      when kind~upper = 'AUTORADIOBUTTON' then mapped = 'RADIOBUTTON'
      when kind~upper = 'LTEXT' | kind~upper = 'RTEXT' | kind~upper = 'CTEXT' then mapped = 'STATIC'
      when kind~upper = 'GROUPBOX' then mapped = 'GROUPBOX'
      when kind~upper = 'LISTBOX' then mapped = 'LISTBOX'
      when kind~upper = 'COMBOBOX' then mapped = 'COMBOBOX'
      otherwise return -1
    end
    id = entry~at('resolvedControlId')
    if id == .nil then do
      id = node~id
      if \id~datatype('W') then return -1
    end
    if \id~datatype('W') then return -1
    if seen~hasIndex(id) | controls~hasIndex(id) then return -1
    seen~put(1,id)
    args = entry~at('arguments')
    caption = ''
    if args \== .nil then do
      if args~items > 0 & mapped \= 'EDIT' then do
        candidate = args[1]
        if candidate~isInstanceOf(.String) then do
          if candidate~length >= 2 then do
            if candidate~left(1) = '"' & candidate~right(1) = '"' then caption = candidate~substr(2,candidate~length - 2)
          end
        end
      end
    end
    planned~append(.array~of(mapped,id,caption,node))
  end
  /* No mutation until every imported control passes validation. */
  do record over planned
    self~addControl(record[1],record[2],0,0,0,0,'',record[3])
    controls~at(record[2])~attachResourceNode(record[4])
  end
  rcTree = tree
  rcDialog = dlg
  do entry over dlg~children
    if entry~nodeType~upper = 'PROPERTY' then do
      prop = entry~properties
      if prop~at('name')~upper = 'CAPTION' then do
        value = prop~at('value')
        if value \== .nil then do
          if value~length >= 2 & value~left(1) = '"' & value~right(1) = '"' then title = value~substr(2,value~length - 2)
        end
      end
    end
  end
  return 0
::method resourceTree
  expose rcTree
  if \var('rcTree') then return .nil
  return rcTree
::method emitResourceEvent
  use strict arg id, eventName
  control = self~control(id)
  if control == .nil then return .nil
  node = control~resourceNode
  if node == .nil then return .nil
  return node~emit(eventName)
::method control
  expose controls
  use strict arg id
  return controls~at(id)
::method hasControl
  use strict arg id
  return self~control(id) \== .nil
::method newPushButton
  use strict arg id
  return self~control(id)
::method newEdit
  use strict arg id
  return self~control(id)
::method newCheckBox
  use strict arg id
  return self~control(id)
::method newRadioButton
  use strict arg id
  return self~control(id)
::method newStatic
  use strict arg id
  return self~control(id)
::method setControlText
  use strict arg id, value
  ctl = self~control(id)
  if ctl == .nil then return -1
  return ctl~setText(value)
::method getControlText
  use strict arg id
  ctl = self~control(id)
  if ctl == .nil then return ''
  return ctl~getText
::method connectButtonEvent
  expose callbacks
  use arg id, event, methodName
  if \arg(3,'E') then methodName = 'on' || id
  callbacks~put(methodName, id || ':' || event~upper)
  return 0
::method dispatchButtonEvent
  expose callbacks
  use strict arg id, event
  target = callbacks~at(id || ':' || event~upper)
  if target == .nil then return -1
  return self~send(target)
::method connectControlEvent
  expose callbacks
  use strict arg id, event, methodName
  callbacks~put(methodName, id || ':' || event~upper)
  return 0
::method dispatchControlEvent
  expose callbacks
  use strict arg id, event
  target = callbacks~at(id || ':' || event~upper)
  if target == .nil then return -1
  return self~send(target)
::method getControlHandle
  use strict arg id
  return .nil /* no HWND on Linux: fail closed */
::method getEditControl
  use strict arg id
  return self~newEdit(id)
::method getButtonControl
  use strict arg id
  return self~newPushButton(id)
::method getCheckBoxControl
  use strict arg id
  return self~newCheckBox(id)
::method getRadioButtonControl
  use strict arg id
  return self~newRadioButton(id)
::method getListBoxControl
  use strict arg id
  return self~control(id)
::method getComboBoxControl
  use strict arg id
  return self~control(id)
::method getProgressBarControl
  use strict arg id
  return self~control(id)

::class 'BaseDialog' public subclass PlainBaseDialog
::class 'UserDialog' public subclass BaseDialog
::method init
  forward class (super) continue
  self~defineDialog
::method createPushButton
  forward message 'addControl' arguments ('PUSHBUTTON', arg(1), arg(2), arg(3), arg(4), arg(5), arg(6), arg(7))
::method createEdit
  forward message 'addControl' arguments ('EDIT', arg(1), arg(2), arg(3), arg(4), arg(5), arg(6), arg(7))
::method createCheckBox
  forward message 'addControl' arguments ('CHECKBOX', arg(1), arg(2), arg(3), arg(4), arg(5), arg(6), arg(7))
::method createRadioButton
  forward message 'addControl' arguments ('RADIOBUTTON', arg(1), arg(2), arg(3), arg(4), arg(5), arg(6), arg(7))
::method createListBox
  forward message 'addControl' arguments ('LISTBOX', arg(1), arg(2), arg(3), arg(4), arg(5), arg(6), arg(7))
::method createComboBox
  forward message 'addControl' arguments ('COMBOBOX', arg(1), arg(2), arg(3), arg(4), arg(5), arg(6), arg(7))
::method createProgressBar
  forward message 'addControl' arguments ('PROGRESSBAR', arg(1), arg(2), arg(3), arg(4), arg(5), arg(6), arg(7))
::method createGroupBox
  forward message 'addControl' arguments ('GROUPBOX', arg(1), arg(2), arg(3), arg(4), arg(5), arg(6), arg(7))
::method createStaticText
  forward message 'addControl' arguments ('STATIC', arg(1), arg(2), arg(3), arg(4), arg(5), arg(6), arg(7))

::class 'DialogControl' public
::method init
  expose owner id kind text enabled visible checked
  use strict arg owner,id,kind
  text = ''
  enabled = .true
  visible = .true
  checked = .false
::method id
  expose id
  return id
::method attachResourceNode
  expose resourceNodeValue
  use strict arg node
  resourceNodeValue = node
  return 0
::method resourceNode
  expose resourceNodeValue
  if \var('resourceNodeValue') then return .nil
  return resourceNodeValue
::method getText
  expose text
  return text
::method setText
  expose text
  use strict arg value
  text = value
  return 0
::method enable
  expose enabled
  enabled = .true
  return 0
::method disable
  expose enabled
  enabled = .false
  return 0
::method isEnabled
  expose enabled
  return enabled
::method show
  expose visible
  visible = .true
  return 0
::method hide
  expose visible
  visible = .false
  return 0
::method isVisible
  expose visible
  return visible
::method getID
  expose id
  return id
::method setFocus
  expose owner id
  return owner~setFocus(id)
::method hasFocus
  expose owner id
  return owner~getFocus == id
::method check
  expose checked
  use arg value
  if arg(1,'E') then checked = value
  else checked = .true
  return 0
::method uncheck
  expose checked
  checked = .false
  return 0
::method isChecked
  expose checked
  return checked
::method click
  expose owner id
  return owner~dispatchButtonEvent(id,'CLICKED')

/* These models are in-memory test doubles, not proven Windows API equivalents. */
::class 'PushButton' public subclass DialogControl
::class 'CheckBox' public subclass DialogControl
::class 'RadioButton' public subclass DialogControl
::class 'Edit' public subclass DialogControl
::method getLineCount
  t = self~getText
  if t == '' then return 1
  n = 1
  do i = 1 to t~length
    if t~substr(i,1) == '0a'x then n = n + 1
  end
  return n
::method selectAll
  return 0
::method clear
  return self~setText('')
::method appendText
  use strict arg value
  return self~setText(self~getText || value)

::class 'ListBox' public subclass DialogControl
::method init
  expose items selected
  forward class (super) continue
  items = .array~new
  selected = 0
::method add
  expose items
  use strict arg value
  items~append(value)
  return items~items /* prototype indexes are 1-based */
::method insert
  expose items
  use strict arg value, position
  if position < 1 | position > items~items + 1 then return -1
  items~insert(value,position)
  return position
::method items
  expose items
  return items~items
::method getItem
  expose items
  use strict arg position
  if position < 1 | position > items~items then return .nil
  return items[position]
::method delete
  expose items selected
  use strict arg position
  if position < 1 | position > items~items then return -1
  items~delete(position)
  if selected = position then selected = 0
  return 0
::method deleteAll
  expose items selected
  items = .array~new
  selected = 0
  return 0
::method select
  expose selected items
  use strict arg position
  if position < 1 | position > items~items then return -1
  selected = position
  return 0
::method selectedIndex
  expose selected
  return selected
::method selectedItem
  expose selected items
  if selected = 0 then return .nil
  return items[selected]
::class 'ComboBox' public subclass ListBox
::method removeAll
  return self~deleteAll

/* Additional headless control families. These do not imply Windows parity. */
::class 'GroupBox' public subclass DialogControl
::class 'Static' public subclass DialogControl
::class 'ProgressBar' public subclass DialogControl
::method init
  expose minimum maximum position
  forward class (super) continue
  minimum = 0
  maximum = 100
  position = 0
::method setRange
  expose minimum maximum position
  use strict arg low, high
  if low > high then return -1
  minimum = low
  maximum = high
  if position < minimum then position = minimum
  if position > maximum then position = maximum
  return 0
::method setPosition
  expose minimum maximum position
  use strict arg n
  if n < minimum then n = minimum
  if n > maximum then n = maximum
  position = n
  return 0
::method getPosition
  expose position
  return position
::method step
  expose position
  use arg delta
  if \arg(1,'E') then delta = 1
  return self~setPosition(position + delta)


::class 'RcDialog' public subclass UserDialog
::class 'ResDialog' public subclass BaseDialog

/* Explicit bridge: adapter passes ooDialog's original event identifier. */
::class 'OoDialogRcHandler' public
::method init
  expose dialog id eventName
  use strict arg dialog,id,eventName
::method handle
  expose dialog id eventName
  use strict arg event
  return dialog~dispatchControlEvent(id,eventName)

::requires 'RcExecutableTree.cls'