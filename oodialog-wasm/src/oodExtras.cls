
-- ======== ooDialog/WASM additions (src/oodExtras.cls) ========
-- Architecture: Tom Dyer.  Code: Claude (Fable 5.2).
-- Classes of the port that need ooDialog's own classes; appended by oodgen.rex.

/* OodFileDialog: FileNameDialog() for ooRexx/WASM.  Windows shows its common
 * file dialog; here the dialog is an ooDialog UserDialog over the file system
 * of the "WASM machine" (what SysFileTree sees). */
::class 'OodFileDialog' subclass UserDialog public
::method module_version class
  return "0.7.0"
::method module_lastChanged class
  return "2026-11-21"
::method module_version
  return self~class~module_version
::method module_lastChanged
  return self~class~module_lastChanged

::attribute chosen unguarded       -- the answer: a path, several joined by the separator, or 0
-- Set by the shell dialog classes (OpenFileDialog, SaveFileDialog) before execute:
::attribute okLabel unguarded      -- text of the OK button, "" for the usual one
::attribute cancelLabel unguarded
::attribute nameLabel unguarded    -- text in front of the file name field
::attribute typeIndex unguarded    -- the file type selected first; after OK, the one in use
::attribute itemFilter unguarded   -- .nil, or an object whose includeItem(dialog, hwnd, path) answers 0 to list a file
::attribute filterOwner unguarded  -- the first argument for includeItem
::attribute extras unguarded       -- the state of the shell dialog object, .nil without one
::attribute custom unguarded       -- the program's own controls (CommonDialogCustomizations), in drawing order

::method init
  expose dir fileName filters saving multi sepChar defExt caption folders
  use arg preselected = "", fileFilter = "", saving = .false, caption = "", defExt = "", multi = .false, sepChar = " ", folders = .false, extras = .nil
  self~init:super
  self~chosen = 0
  self~okLabel = ""
  self~cancelLabel = ""
  self~nameLabel = ""
  self~typeIndex = 1
  self~itemFilter = .nil
  self~filterOwner = .nil
  self~extras = extras
  self~custom = .array~new
  if extras \== .nil then if extras["CUSTOM"] \== .nil then do
    do entry over extras["CUSTOM"]       -- a prominent control is drawn first
      if entry~prominent then self~custom~append(entry)
    end
    do entry over extras["CUSTOM"]
      if \entry~prominent then self~custom~append(entry)
    end
  end
  if extras \== .nil then do           -- defineDialog runs inside create, below: these must be set first
    self~okLabel = extras~okLabel
    self~cancelLabel = extras~cancelLabel
    self~nameLabel = extras~nameLabel
    self~typeIndex = extras~typeIndex
    self~itemFilter = extras~filter
    self~filterOwner = extras~owner
  end
  dir = directory()
  fileName = ""
  if preselected \== "" then do
    given = preselected~changeStr("\", "/")
    if SysIsFileDirectory(given) then dir = given
    else do
      where = filespec("LOCATION", given)~strip("T", "/")
      if where \== "" then if SysIsFileDirectory(where) then dir = where
      fileName = filespec("NAME", given)
    end
  end
  if dir~left(1) \== "/" then dir = directory()"/"dir          -- always a full path, without a trailing separator
  if dir~length > 1 then dir = dir~strip("T", "/")
  -- the filter: "Text (*.txt)" 00x "*.txt" 00x "All (*.*)" 00x "*.*" 00x
  filters = .array~new
  parts = fileFilter~makeArray(x2c("00"))
  do i = 1 to parts~items by 2
    if parts[i] == "" then iterate
    pattern = "*"
    if parts~hasIndex(i + 1) then pattern = parts[i + 1]
    filters~append(.array~of(parts[i], pattern))
  end
  if filters~items == 0 then do
    filters~append(.array~of("Text Files (*.txt)", "*.txt"))
    filters~append(.array~of("All Files (*.*)", "*.*"))
  end
  if caption == "" then do
    if saving then caption = "Save As"
    else caption = "Open"
    if folders then caption = "Browse For Folder"
  end
  self~create(30, 30, 260, 176 + self~customHeight, caption, "CENTER")

::method defineDialog
  expose saving multi folders
  self~autoDetect = .false
  self~createStaticText(-1, 8, 9, 34, 10, , "Look &in:")
  self~createEdit(10, 44, 7, 208, 12, "READONLY")
  listStyle = "VSCROLL HSCROLL NOTIFY"
  if multi then listStyle = listStyle "MULTI"
  self~createListBox(20, 8, 24, 244, 100, listStyle)
  nameText = "File &name:"
  if self~nameLabel \== "" then nameText = self~nameLabel
  self~createStaticText(-1, 8, 132, 44, 10, , nameText)
  self~createEdit(21, 54, 130, 142, 12, "AUTOSCROLLH")
  self~createStaticText(-1, 8, 150, 44, 10, , "Files of &type:")
  self~createComboBox(22, 54, 148, 142, 60, "LIST")
  okText = "&Open"
  if saving then okText = "&Save"
  if folders then okText = "OK"
  if self~okLabel \== "" then okText = self~okLabel
  cancelText = "Cancel"
  if self~cancelLabel \== "" then cancelText = self~cancelLabel
  okWidth = 50
  do entry over self~custom
    if entry~kind == "OPENDROP" then do    -- the button's own list: a small button beside it
      okWidth = 38
      self~createPushButton(999, 241, 129, 11, 14, , "v")
      self~connectButtonEvent(999, "CLICKED", onOpenDrop)
    end
  end
  self~createPushButton(IDOK, 202, 129, okWidth, 14, "DEFAULT", okText)
  self~defineCustom(168)
  self~createPushButton(IDCANCEL, 202, 147, 50, 14, , cancelText)
  self~connectListBoxEvent(20, "DBLCLK", onPick)
  self~connectListBoxEvent(20, "SELCHANGE", onSelect)
  self~connectComboBoxEvent(22, "SELCHANGE", onType)

::method initDialog
  expose filters fileName
  types = self~newComboBox(22)
  do f over filters
    types~add(f[1])
  end
  first = self~typeIndex
  if \datatype(first, "W") then first = 1
  if first < 1 | first > filters~items then first = 1
  types~selectIndex(first)
  self~newEdit(21)~setText(fileName)
  self~refresh
  do entry over self~custom
    self~customApply(entry)
  end
  if self~extras \== .nil then self~extras["LIVE"] = self

::method leaving unguarded         -- the dialog ends: what the user did in the program's controls is kept
  if self~extras \== .nil then if self~extras["LIVE"] \== .nil then do
    self~customSync
    self~extras["LIVE"] = .nil
  end

/*---- the program's own controls (CommonDialogCustomizations) -------------------------------*/
/* Each entry takes one row below the file type; a radio button list one row for each item;
   a group and the Open button's list none.  A control of a group stands right of the
   group's label.  The control of entry k has the dialog ID 1000 + 20 * k, and item j of a
   radio button list that ID + j. */
::method customRows unguarded      -- the rows of one entry
  use arg entry
  if entry~kind == "GROUP" | entry~kind == "OPENDROP" then return 0
  if entry~kind == "RADIO" then return max(1, entry~list~items)
  return 1
::method customHeight unguarded    -- the height all entries take, in dialog units
  rows = 0
  do entry over self~custom
    rows = rows + self~customRows(entry)
  end
  if rows == 0 then return 0
  return rows * 16 + 4
::method customIndex unguarded     -- the place of the entry with an ID of the program; 0
  use arg id
  do k = 1 to self~custom~items
    if self~custom[k]~id == id then return k
  end
  return 0
::method defineCustom unguarded
  use arg y
  labelled = .set~new
  do k = 1 to self~custom~items
    entry = self~custom[k]
    rows = self~customRows(entry)
    if rows == 0 then iterate
    id = 1000 + 20 * k
    x = 8
    width = 244
    if entry~group \== .nil then do
      x = 60
      width = 192
      if \labelled~hasIndex(entry~group) then do
        labelled~put(entry~group)
        g = self~customIndex(entry~group)
        if g > 0 then self~createStaticText(1000 + 20 * g, 8, y + 2, 50, 10, , self~custom[g]~text)
      end
    end
    select
      when entry~kind == "CHECK" then do
        self~createCheckBox(id, x, y, width, 12, , entry~text)
        self~connectButtonEvent(id, "CLICKED", onCustomButton)
      end
      when entry~kind == "BUTTON" | entry~kind == "MENU" then do
        self~createPushButton(id, x, y, 90, 14, , entry~text)
        self~connectButtonEvent(id, "CLICKED", onCustomButton)
      end
      when entry~kind == "EDIT" then self~createEdit(id, x, y, min(width, 142), 12, "AUTOSCROLLH")
      when entry~kind == "TEXT" then self~createStaticText(id, x, y + 2, width, 10, , entry~text)
      when entry~kind == "SEP" then self~createBlackRect(id, x, y + 6, width, 1)
      when entry~kind == "COMBO" then do
        self~createComboBox(id, x, y, min(width, 142), 60, "LIST")
        self~connectComboBoxEvent(id, "SELCHANGE", onCustomCombo)
      end
      when entry~kind == "RADIO" then do j = 1 to entry~list~items
        style = ""
        if j == 1 then style = "GROUP"
        self~createRadioButton(id + j, x, y + (j - 1) * 16, width, 12, style, entry~list[j]~text)
        self~connectButtonEvent(id + j, "CLICKED", onCustomButton)
      end
      otherwise nop
    end
    y = y + rows * 16
  end

::method customShow unguarded      -- a state keyword on one control
  use arg ctl, state
  if ctl == 0 | ctl == .nil then return
  if state~pos("VISIBLE") > 0 then ctl~show
  else ctl~hide
  if state~pos("ENABLED") > 0 then ctl~enable
  else ctl~disable

::method customApply unguarded     -- an entry's values to its control(s)
  use arg entry
  k = self~customIndex(entry~id)
  if k == 0 then return
  id = 1000 + 20 * k
  select
    when entry~kind == "GROUP" then do
      label = self~newStatic(id)
      if label \== 0 then label~setText(entry~text)
    end
    when entry~kind == "CHECK" then do
      box = self~newCheckBox(id)
      box~setText(entry~text)
      if entry~checked then box~check
      else box~uncheck
      self~customShow(box, entry~state)
    end
    when entry~kind == "BUTTON" | entry~kind == "MENU" then do
      button = self~newPushButton(id)
      button~setText(entry~text)
      self~customShow(button, entry~state)
    end
    when entry~kind == "EDIT" then do
      edit = self~newEdit(id)
      edit~setText(entry~text)
      self~customShow(edit, entry~state)
    end
    when entry~kind == "TEXT" then do
      text = self~newStatic(id)
      text~setText(entry~text)
      self~customShow(text, entry~state)
    end
    when entry~kind == "SEP" then self~customShow(self~newStatic(id), entry~state)
    when entry~kind == "COMBO" then do
      combo = self~newComboBox(id)
      combo~deleteAll
      chosen = 0
      shown = 0
      do item over entry~list
        if item~state~pos("VISIBLE") == 0 then iterate
        combo~add(item~text)
        shown = shown + 1
        if item~id == entry~selected then chosen = shown
      end
      if chosen > 0 then combo~selectIndex(chosen)
      self~customShow(combo, entry~state)
    end
    when entry~kind == "RADIO" then do j = 1 to entry~list~items
      radio = self~newRadioButton(id + j)
      if radio == 0 then iterate
      radio~setText(entry~list[j]~text)
      if entry~list[j]~id == entry~selected then radio~check
      else radio~uncheck
      state = entry~list[j]~state
      if entry~state~pos("VISIBLE") == 0 then state = "INACTIVE"
      else if entry~state~pos("ENABLED") == 0 then state = "VISIBLE"
      self~customShow(radio, state)
    end
    when entry~kind == "OPENDROP" then self~customShow(self~newPushButton(999), entry~state)
    otherwise nop
  end

::method customSync unguarded      -- what the user did, into the entries
  do k = 1 to self~custom~items
    entry = self~custom[k]
    id = 1000 + 20 * k
    select
      when entry~kind == "CHECK" then entry~checked = self~newCheckBox(id)~checked
      when entry~kind == "EDIT" then entry~text = self~newEdit(id)~getText
      when entry~kind == "COMBO" then entry~selected = self~customComboItem(entry, self~newComboBox(id)~selectedIndex)
      when entry~kind == "RADIO" then do j = 1 to entry~list~items
        radio = self~newRadioButton(id + j)
        if radio \== 0 then if radio~checked then entry~selected = entry~list[j]~id
      end
      otherwise nop
    end
  end

::method customComboItem unguarded -- the ID of the item at a place of a combo box, which lists the visible items; 0
  use arg entry, index
  shown = 0
  do item over entry~list
    if item~state~pos("VISIBLE") == 0 then iterate
    shown = shown + 1
    if shown == index then return item~id
  end
  return 0

::method customNotify unguarded    -- a notice to the program's CommonDialogEvents object, if it has one
  use arg method, id, extra
  if self~extras == .nil then return 0
  handler = self~extras~handler
  if handler == .nil then return 0
  args = .array~of(self~extras~owner, self~hwnd, id)
  if arg(3, "E") then args~append(extra)
  return handler~sendWith(method, args)

::method customMenu unguarded      -- the items of a menu entry as a pop-up menu under a button: the ID chosen, 0
  use arg entry, buttonID
  self~customNotify("onControlActivating", entry~id)
  menu = .PopupMenu~new(998)
  count = 0
  do item over entry~list
    if item~state~pos("VISIBLE") == 0 then iterate
    count = count + 1
    menu~insertItem(count, item~id, item~text, , , .true)
    if item~state~pos("ENABLED") == 0 then menu~disable(item~id)
  end
  if count == 0 then return 0
  r = self~newPushButton(buttonID)~windowRect
  chosen = menu~track(.Point~new(r~left, r~bottom), self)
  if chosen == 0 then return 0
  entry~selected = chosen
  self~customNotify("onItemSelected", chosen, entry~id)
  return chosen

::method onCustomButton unguarded
  use arg wParam
  cid = .DlgUtil~loWord(wParam)
  k = (cid - 1000) % 20
  j = (cid - 1000) // 20
  if k < 1 | k > self~custom~items then return 0
  entry = self~custom[k]
  select
    when entry~kind == "CHECK" then do
      entry~checked = self~newCheckBox(cid)~checked
      self~customNotify("onCheckButtonToggled", entry~id, entry~checked)
    end
    when entry~kind == "BUTTON" then self~customNotify("onButtonClicked", entry~id)
    when entry~kind == "MENU" then self~customMenu(entry, cid)
    when entry~kind == "RADIO" then do
      if j < 1 | j > entry~list~items then return 0
      entry~selected = entry~list[j]~id
      self~customNotify("onItemSelected", entry~selected, entry~id)
    end
    otherwise nop
  end
  return 0

::method onCustomCombo unguarded
  use arg wParam
  cid = .DlgUtil~loWord(wParam)
  k = (cid - 1000) % 20
  if k < 1 | k > self~custom~items then return 0
  entry = self~custom[k]
  entry~selected = self~customComboItem(entry, self~newComboBox(cid)~selectedIndex)
  if entry~selected \== 0 then self~customNotify("onItemSelected", entry~selected, entry~id)
  return 0

::method onOpenDrop unguarded      -- the Open button's own list: choosing an item is Open with that item
  do entry over self~custom
    if entry~kind \== "OPENDROP" then iterate
    if self~customMenu(entry, 999) \== 0 then return self~ok
  end
  return 0

::method refresh unguarded         -- the directory's sub-directories, then its files that match the type
  expose dir filters folders
  self~newEdit(10)~setText(dir)
  list = self~newListBox(20)
  list~deleteAll
  if dir \== "/" then list~add("[..]")
  base = dir
  if base~right(1) \== "/" then base = base"/"
  call SysFileTree base"*", "dirs.", "DO"
  names = .array~new
  do i = 1 to dirs.0
    names~append(filespec("NAME", dirs.i))
  end
  do name over names~sortWith(.CaselessComparator~new)
    list~add("["name"]")
  end
  if folders then return               -- a folder dialog lists no files
  index = self~newComboBox(22)~selectedIndex
  if index < 1 then index = 1
  patterns = filters[index][2]~makeArray(";")
  call SysFileTree base"*", "files.", "FO"
  names = .array~new
  do i = 1 to files.0
    name = filespec("NAME", files.i)
    if self~itemFilter \== .nil then if self~itemFilter~includeItem(self~filterOwner, self~hwnd, files.i) \== 0 then iterate
    do pattern over patterns
      if self~matches(name, pattern~strip) then do
        names~append(name)
        leave
      end
    end
  end
  do name over names~sortWith(.CaselessComparator~new)
    list~add(name)
  end

::method matches unguarded         -- a name against a pattern with * and ?, without regard to case
  use arg name, pattern
  if pattern == "*.*" | pattern == "*" then return .true
  return self~matchAt(name~upper, 1, pattern~upper, 1)
::method matchAt unguarded
  use arg name, n, pattern, p
  do while p <= pattern~length
    ch = pattern~subChar(p)
    if ch == "*" then do
      if p == pattern~length then return .true
      do k = n to name~length + 1
        if self~matchAt(name, k, pattern, p + 1) then return .true
      end
      return .false
    end
    if n > name~length then return .false
    if ch \== "?" then if ch \== name~subChar(n) then return .false
    n = n + 1
    p = p + 1
  end
  return n > name~length

::method full unguarded            -- a name of the list or the edit as a path
  expose dir
  use arg name
  name = name~changeStr("\", "/")
  if name~left(1) == "/" then return name
  if dir~right(1) == "/" then return dir || name
  return dir"/"name

::method enter unguarded           -- go into a directory; .true if it was one
  expose dir
  use arg entry
  if entry == "[..]" then do
    p = dir~lastPos("/")
    if p <= 1 then dir = "/"
    else dir = dir~left(p - 1)
    self~refresh
    return .true
  end
  if entry~left(1) == "[" then entry = entry~substr(2, entry~length - 2)
  target = self~full(entry)
  if \SysIsFileDirectory(target) then return .false
  dir = target
  self~refresh
  return .true

::method onSelect unguarded
  expose multi
  list = self~newListBox(20)
  entry = list~selected
  if entry == "" then return
  if entry~left(1) == "[" then return
  if multi then do
    names = ""
    do index over list~selectedIndexes
      name = list~getText(index)
      if name~left(1) \== "[" then names = names '"'name'"'
    end
    self~newEdit(21)~setText(names~strip)
  end
  else self~newEdit(21)~setText(entry)

::method onPick unguarded
  entry = self~newListBox(20)~selected
  if entry == "" then return
  if entry~left(1) == "[" then self~enter(entry)
  else return self~ok

::method onType unguarded
  self~refresh

::method validate unguarded        -- OK: enter a directory, or accept the file name(s)
  expose saving multi sepChar defExt dir folders
  text = self~newEdit(21)~getText~strip
  index = self~newComboBox(22)~selectedIndex
  if index >= 1 then self~typeIndex = index
  if folders then do                   -- the answer is the directory shown, or the one named
    if text \== "" then if \self~enter(text) then return .false
    self~chosen = dir
    return .true
  end
  if text == "" then return .false
  if multi then if text~pos('"') > 0 then do
    names = .array~new
    rest = text
    do while rest~pos('"') > 0
      parse var rest '"' name '"' rest
      if name \== "" then names~append(name)
    end
    if names~items > 1 then do
      self~chosen = dir || sepChar || names~makeString("L", sepChar)
      return .true
    end
    text = names[1]
  end
  if text~pos("*") > 0 | text~pos("?") > 0 then return .false
  if self~enter(text) then do
    self~newEdit(21)~setText("")
    return .false
  end
  path = self~full(text)
  if saving then do
    if defExt \== "" then if filespec("EXTENSION", path) == "" then path = path"."defExt~strip("L", ".")
    if SysIsFile(path) then do
      answer = messageDialog(path "already exists." || "0a"~x2c || "Do you want to replace it?", self~hwnd, "Confirm Save As", "YESNO", "WARNING")
      if answer \== 6 then return .false
    end
  end
  else if \SysIsFile(path) then do
    call messageDialog path || "0a"~x2c || "File not found." || "0a"~x2c || "Check the file name and try again.", self~hwnd, self~title, "OK", "WARNING"
    return .false
  end
  self~chosen = path
  return .true
