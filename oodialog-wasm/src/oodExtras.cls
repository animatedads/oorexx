
-- ======== ooDialog/WASM additions (src/oodExtras.cls) ========
-- Architecture: Tom Dyer.  Code: Claude (Fable 5.2).
-- Classes of the port that need ooDialog's own classes; appended by oodgen.rex.

/* OodFileDialog: FileNameDialog() for ooRexx/WASM.  Windows shows its common
 * file dialog; here the dialog is an ooDialog UserDialog over the file system
 * of the "WASM machine" (what SysFileTree sees). */
::class 'OodFileDialog' subclass UserDialog public
::method module_version class
  return "0.6.0"
::method module_lastChanged class
  return "2026-11-14"
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
  self~create(30, 30, 260, 176, caption, "CENTER")

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
  self~createPushButton(IDOK, 202, 129, 50, 14, "DEFAULT", okText)
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
