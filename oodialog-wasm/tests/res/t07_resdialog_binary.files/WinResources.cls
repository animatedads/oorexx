/* oorexx_win_resources v0.1 -- read binary Windows resources in ooRexx.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14.
 *
 * Reads compiled resource files (.res, as written by rc.exe, windres and
 * llvm-rc) and the .rsrc section of PE images (.dll, .exe), and decodes
 * DIALOG/DIALOGEX and MENU/MENUEX templates.  Pure ooRexx, one file, no
 * native code, so it runs unchanged on ooRexx/WASM.
 *
 * WinResourceProvider answers the ooDialog/WASM reader contract
 * (animatedads/oorexx, oodialog-wasm/src/oodWeb.cls, comment above
 * resourceProvider):
 *     .oodn~resourceProvider = .WinResourceProvider~new
 *
 * Text: resources hold UTF-16LE; this reader returns UTF-8.
 * All integers in the formats are little-endian.
 */
::options digits 12        -- 32-bit fields need 10 digits; the default 9 is not enough

/*==========================================================================*/
/* Little-endian fields and UTF-16 text over a byte string (1-based pos).    */
/*==========================================================================*/
::class WinResBytes public
::method u8 class
  use strict arg b, p
  return b~substr(p, 1)~c2d
::method u16 class
  use strict arg b, p
  return b~substr(p, 2)~reverse~c2d
::method i16 class
  use strict arg b, p
  v = b~substr(p, 2)~reverse~c2d
  if v > 32767 then v = v - 65536
  return v
::method u32 class
  use strict arg b, p
  return b~substr(p, 4)~reverse~c2d
::method i32 class
  use strict arg b, p
  v = b~substr(p, 4)~reverse~c2d
  if v > 2147483647 then v = v - 4294967296
  return v

/* Position p (1-based, relative to a DWORD-aligned base at position base)
 * rounded up to the next DWORD boundary. */
::method align4 class
  use strict arg p, base = 1
  off = p - base
  return base + ((off + 3) % 4) * 4

/* NUL-terminated UTF-16LE at p -> (text in UTF-8, position after the NUL) */
::method utf16z class
  use strict arg b, p
  limit = b~length
  out = .mutableBuffer~new
  do while p + 1 <= limit
    u = b~substr(p, 2)~reverse~c2d
    p += 2
    if u == 0 then return .array~of(out~string, p)
    if u >= 55296 & u <= 56319 & p + 1 <= limit then do        -- high surrogate
      lo = b~substr(p, 2)~reverse~c2d
      if lo >= 56320 & lo <= 57343 then do
        p += 2
        u = 65536 + (u - 55296) * 1024 + (lo - 56320)
      end
    end
    out~append(self~utf8(u))
  end
  raise syntax 98.900 array("WinResources: unterminated UTF-16 string")

/* Counted UTF-16LE (n code units) at p -> UTF-8 */
::method utf16n class
  use strict arg b, p, n
  out = .mutableBuffer~new
  i = 0
  do while i < n
    u = b~substr(p + 2 * i, 2)~reverse~c2d
    i += 1
    if u >= 55296 & u <= 56319 & i < n then do
      lo = b~substr(p + 2 * i, 2)~reverse~c2d
      if lo >= 56320 & lo <= 57343 then do
        i += 1
        u = 65536 + (u - 55296) * 1024 + (lo - 56320)
      end
    end
    out~append(self~utf8(u))
  end
  return out~string

::method utf8 class
  use strict arg u
  if u < 128 then return d2c(u)
  if u < 2048 then return d2c(192 + u % 64) || d2c(128 + u // 64)
  if u < 65536 then return d2c(224 + u % 4096) || d2c(128 + (u % 64) // 64) || d2c(128 + u // 64)
  return d2c(240 + u % 262144) || d2c(128 + (u % 4096) // 64) || d2c(128 + (u % 64) // 64) || d2c(128 + u // 64)

/* sz_Or_Ord at p -> (value, "none" | "ordinal" | "string", next position) */
::method szOrOrd class
  use strict arg b, p
  first = self~u16(b, p)
  if first == 0 then return .array~of("", "none", p + 2)
  if first == 65535 then return .array~of(self~u16(b, p + 2), "ordinal", p + 4)
  r = self~utf16z(b, p)
  return .array~of(r[1], "string", r[2])


/*==========================================================================*/
/* One resource: type, name, language and its bytes.                       */
/*==========================================================================*/
::class WinResourceEntry public
::attribute type get        -- number (RT_xxx) or upper-case string
::attribute name get        -- number or upper-case string
::attribute language get    -- LANGID, number
::attribute data get        -- the resource bytes
::attribute codePage get    -- PE only; 0 for .res
::method init
  expose type name language data codePage
  use strict arg type, name, language, data, codePage = 0
::method typeName
  expose type
  if \type~datatype("W") then return type
  names = "CURSOR BITMAP ICON MENU DIALOG STRING FONTDIR FONT ACCELERATOR RCDATA" -
          "MESSAGETABLE GROUP_CURSOR 13 GROUP_ICON 15 VERSION DLGINCLUDE 18 PLUGPLAY" -
          "VXD ANICURSOR ANIICON HTML MANIFEST"
  if type >= 1 & type <= words(names) then do
    w = word(names, type)
    if \w~datatype("W") then return "RT_"w
  end
  return type
::method string
  expose name language data
  return self~typeName name "lang="language~d2x(4) "bytes="data~length


/*==========================================================================*/
/* The resources of one .res file or PE image.                              */
/*==========================================================================*/
::class WinResourceSet public
::constant RT_MENU 4
::constant RT_DIALOG 5
::attribute entries get
::attribute source get       -- "res" or "pe"
::attribute path get

::method fromFile class
  use strict arg path
  s = .stream~new(path)
  if s~open("read") \= "READY:" then
    raise syntax 98.900 array("WinResources: cannot open" path)
  size = s~chars
  b = s~charIn(1, size)
  s~close
  set = self~fromBytes(b)
  set~setPath(path)
  return set

::method fromBytes class
  use strict arg b
  if b~left(2) == "MZ" then return self~new(.PeResourceReader~read(b), "pe")
  return self~new(.ResFileReader~read(b), "res")

::method init
  expose entries source path
  use strict arg entries, source
  path = ""

::method setPath
  expose path
  use strict arg path

/* The entry of a type and name (number, or a string compared without case).
 * Language: the one asked for, else neutral (0), else en-US (0x409), else
 * the first in the file. */
::method find
  expose entries
  use strict arg type, name, language = .nil
  key = self~nameKey(name)
  found = .array~new
  do e over entries
    if e~type \== type then iterate
    if self~nameKey(e~name) \== key then iterate
    found~append(e)
  end
  if found~items == 0 then return .nil
  wanted = .array~of(0, 1033)
  if language \== .nil then wanted = .array~of(language, 0, 1033)
  do lang over wanted
    do e over found
      if e~language = lang then return e
    end
  end
  return found[1]

::method nameKey private
  use strict arg name
  if name~datatype("W") then return "#"name + 0
  return "$"name~upper

::method dialog
  use strict arg name, language = .nil
  e = self~find(self~RT_DIALOG, name, language)
  if e == .nil then return .nil
  return .WinDialogTemplate~parse(e~data)

::method menu
  use strict arg name, language = .nil
  e = self~find(self~RT_MENU, name, language)
  if e == .nil then return .nil
  return .WinMenuTemplate~parse(e~data)


/*==========================================================================*/
/* .res: a sequence of RESOURCEHEADER + data records, each DWORD-aligned.   */
/*==========================================================================*/
::class ResFileReader public
::method read class
  use strict arg b
  entries = .array~new
  limit = b~length
  p = 1
  do while p + 31 <= limit
    dataSize = .WinResBytes~u32(b, p)
    headerSize = .WinResBytes~u32(b, p + 4)
    if headerSize < 32 | p + headerSize - 1 > limit | p + headerSize + dataSize - 1 > limit then
      raise syntax 98.900 array("WinResources: .res record at byte" p - 1 "has a bad size")
    t = .WinResBytes~szOrOrd(b, p + 8)
    n = .WinResBytes~szOrOrd(b, t[3])
    q = .WinResBytes~align4(n[3])
    language = .WinResBytes~u16(b, q + 6)
    isSentinel = (dataSize == 0 & t[2] == "ordinal" & t[1] == 0)
    if \isSentinel then do
      type = t[1]; if t[2] == "string" then type = type~upper
      name = n[1]; if n[2] == "string" then name = name~upper
      entries~append(.WinResourceEntry~new(type, name, language, b~substr(p + headerSize, dataSize)))
    end
    p = .WinResBytes~align4(p + headerSize + dataSize)
  end
  return entries


/*==========================================================================*/
/* PE image: the Type -> Name -> Language tree of the .rsrc data directory. */
/*==========================================================================*/
::class PeResourceReader public
::method read class
  use strict arg b
  rb = .WinResBytes
  if b~left(2) \== "MZ" then raise syntax 98.900 array("WinResources: not a PE image (no MZ)")
  e = rb~u32(b, 61) + 1                                   -- e_lfanew
  if b~substr(e, 4) \== "PE" || "0000"x then raise syntax 98.900 array("WinResources: not a PE image (no PE signature)")
  coff = e + 4
  sections = rb~u16(b, coff + 2)
  optSize = rb~u16(b, coff + 16)
  opt = coff + 20
  magic = rb~u16(b, opt)
  select
    when magic == 267 then dd = opt + 96                  -- PE32
    when magic == 523 then dd = opt + 112                 -- PE32+
    otherwise raise syntax 98.900 array("WinResources: unknown optional header magic" magic~d2x)
  end
  rva = rb~u32(b, dd + 16)                                 -- data directory 2: resources
  if rva == 0 then return .array~new
  table = .array~new
  s = opt + optSize
  do i = 1 to sections
    table~append(.array~of(rb~u32(b, s + 12), max(rb~u32(b, s + 8), rb~u32(b, s + 16)), rb~u32(b, s + 20)))
    s += 40
  end
  base = self~rvaToPos(table, rva)
  if base == 0 then raise syntax 98.900 array("WinResources: resource directory outside every section")
  entries = .array~new
  do t over self~directory(b, base, 0)
    if \t[3] then iterate
    do n over self~directory(b, base, t[2])
      if \n[3] then iterate
      do l over self~directory(b, base, n[2])
        if l[3] then iterate
        de = base + l[2]
        dataRva = rb~u32(b, de)
        size = rb~u32(b, de + 4)
        pos = self~rvaToPos(table, dataRva)
        if pos == 0 | pos + size - 1 > b~length then
          raise syntax 98.900 array("WinResources: resource data outside the image")
        entries~append(.WinResourceEntry~new(t[1], n[1], l[1], b~substr(pos, size), rb~u32(b, de + 8)))
      end
    end
  end
  return entries

/* RVA -> 1-based position in the file, or 0 */
::method rvaToPos class
  use strict arg table, rva
  do s over table
    if rva >= s[1] & rva < s[1] + s[2] then return s[3] + (rva - s[1]) + 1
  end
  return 0

/* One IMAGE_RESOURCE_DIRECTORY at offset off -> array of
 * (id or upper-case name, offset, isSubdirectory) */
::method directory class
  use strict arg b, base, off
  rb = .WinResBytes
  p = base + off
  count = rb~u16(b, p + 12) + rb~u16(b, p + 14)
  if count > 65535 then raise syntax 98.900 array("WinResources: bad resource directory")
  out = .array~new
  q = p + 16
  do count
    nameField = rb~u32(b, q)
    offField = rb~u32(b, q + 4)
    if nameField >= 2147483648 then do
      s = base + nameField - 2147483648
      name = rb~utf16n(b, s + 2, rb~u16(b, s))~upper
    end
    else name = nameField
    isDir = (offField >= 2147483648)
    if isDir then offField -= 2147483648
    out~append(.array~of(name, offField, isDir))
    q += 8
  end
  return out


/*==========================================================================*/
/* DIALOG and DIALOGEX templates.                                           */
/*==========================================================================*/
::class WinDialogTemplate public
::attribute extended get     -- .true for DIALOGEX
::attribute style get
::attribute exStyle get
::attribute x get
::attribute y get
::attribute cx get
::attribute cy get
::attribute menu get
::attribute windowClass get
::attribute title get
::attribute fontName get
::attribute fontSize get
::attribute fontWeight get
::attribute fontItalic get
::attribute items get        -- array of WinDialogItem

::method parse class
  use strict arg b
  t = self~new
  t~decode(b)
  return t

::method decode
  expose extended style exStyle x y cx cy menu windowClass title fontName fontSize fontWeight fontItalic items
  use strict arg b
  rb = .WinResBytes
  extended = (rb~u16(b, 1) == 1 & rb~u16(b, 3) == 65535)
  if extended then do
    exStyle = rb~u32(b, 9); style = rb~u32(b, 13); count = rb~u16(b, 17); p = 19
  end
  else do
    style = rb~u32(b, 1); exStyle = rb~u32(b, 5); count = rb~u16(b, 9); p = 11
  end
  x = rb~i16(b, p); y = rb~i16(b, p + 2); cx = rb~i16(b, p + 4); cy = rb~i16(b, p + 6)
  p += 8
  r = rb~szOrOrd(b, p); menu = r[1]; p = r[3]
  r = rb~szOrOrd(b, p); windowClass = r[1]; p = r[3]
  r = rb~utf16z(b, p); title = r[1]; p = r[2]
  fontName = ""; fontSize = 0; fontWeight = 0; fontItalic = .false
  if bits(style, 64) \= 0 then do                         -- DS_SETFONT (also DS_SHELLFONT)
    fontSize = rb~u16(b, p); p += 2
    if extended then do
      fontWeight = rb~u16(b, p); fontItalic = (rb~u8(b, p + 2) \= 0); p += 4
    end
    if fontSize \= 32767 then do
      r = rb~utf16z(b, p); fontName = r[1]; p = r[2]
    end
  end
  items = .array~new
  do count
    p = rb~align4(p)
    item = .WinDialogItem~new
    p = item~decode(b, p, extended)
    items~append(item)
  end
  return self

/* The style keywords of UserDialog~create */
::method opts
  expose style
  words = ""
  if bits(style, 2048)       \= 0 then words = words "CENTER"
  if bits(style, 524288)      = 0 then words = words "NOMENU"
  if bits(style, 268435456)  \= 0 then words = words "VISIBLE"
  if bits(style, 2)          \= 0 then words = words "SYSTEMMODAL"
  if bits(style, 131072)     \= 0 then words = words "MINIMIZEBOX"
  if bits(style, 65536)      \= 0 then words = words "MAXIMIZEBOX"
  if bits(style, 262144)     \= 0 then words = words "THICKFRAME"
  if bits(style, 2097152)    \= 0 then words = words "VSCROLL"
  if bits(style, 1048576)    \= 0 then words = words "HSCROLL"
  return words~strip

/* The ooDialog/WASM resourceProvider contract (see oodWeb.cls). */
::method asContract
  expose x y cx cy title fontName fontSize items style exStyle menu windowClass
  t = .directory~new
  t~x = x; t~y = y; t~cx = cx; t~cy = cy
  t~title = title
  t~opts = self~opts
  if fontName \== "" then do
    t~fontName = fontName
    t~fontSize = fontSize
  end
  t~controls = .array~new
  t~unsupported = .array~new            -- beyond the contract: what was left out, and why
  do item over items
    c = item~asContract
    if c~kind == "" then t~unsupported~append(c)
    else t~controls~append(c)
  end
  t~style = style~d2x(8)                -- beyond the contract: provenance
  t~exStyle = exStyle~d2x(8)
  t~menu = menu
  return t


::class WinDialogItem public
::attribute style get
::attribute exStyle get
::attribute x get
::attribute y get
::attribute cx get
::attribute cy get
::attribute id get
::attribute windowClass get      -- ordinal (128..133) or name
::attribute text get
::attribute textIsOrdinal get    -- e.g. the icon of an SS_ICON static
::attribute creationData get

::method decode
  expose style exStyle x y cx cy id windowClass text textIsOrdinal creationData
  use strict arg b, p, extended
  rb = .WinResBytes
  if extended then do
    exStyle = rb~u32(b, p + 4); style = rb~u32(b, p + 8); p += 12
  end
  else do
    style = rb~u32(b, p); exStyle = rb~u32(b, p + 4); p += 8
  end
  x = rb~i16(b, p); y = rb~i16(b, p + 2); cx = rb~i16(b, p + 4); cy = rb~i16(b, p + 6)
  p += 8
  if extended then do
    id = rb~i32(b, p); p += 4
  end
  else do
    id = rb~u16(b, p); p += 2
    if id == 65535 then id = -1
  end
  r = rb~szOrOrd(b, p); windowClass = r[1]; p = r[3]
  if r[2] == "string" then windowClass = windowClass~upper
  r = rb~szOrOrd(b, p); text = r[1]; textIsOrdinal = (r[2] == "ordinal"); p = r[3]
  extra = rb~u16(b, p); p += 2
  creationData = b~substr(p, extra)
  return p + extra

/* Window class -> contract kind; "" when the contract has no such kind. */
::method kind
  expose windowClass style
  cls = windowClass
  select
    when cls == 128 | cls == "BUTTON" then do
      bs = bits(style, 15)
      select
        when bs == 2 | bs == 3 | bs == 5 | bs == 6 then return "CHECK"
        when bs == 4 | bs == 9 then return "RADIO"
        when bs == 7 then return "GROUP"
        otherwise return "BUTTON"
      end
    end
    when cls == 129 | cls == "EDIT" then return "EDIT"
    when cls == 130 | cls == "STATIC" then do
      ss = bits(style, 31)
      if (ss >= 4 & ss <= 9) | (ss >= 16 & ss <= 18) then return "FRAME"
      return "STATIC"
    end
    when cls == 131 | cls == "LISTBOX" then return "LIST"
    when cls == 133 | cls == "COMBOBOX" then return "COMBO"
    when cls == "MSCTLS_PROGRESS32" then return "PROGRESS"
    when cls == "SYSLISTVIEW32" then return "LISTVIEW"
    when cls == "SYSTREEVIEW32" then return "TREEVIEW"
    when cls == "SYSTABCONTROL32" then return "TAB"
    when cls == "MSCTLS_UPDOWN32" then return "UPDOWN"
    when cls == "MSCTLS_TRACKBAR32" then return "TRACKBAR"
    when cls == "SYSDATETIMEPICK32" then return "DATETIMEPICKER"
    otherwise return ""
  end

/* The style keywords the createXxx methods of DynamicDialog take. */
::method opts
  expose style
  kind = self~kind
  w = ""
  s = style
  -- window styles common to every control
  if bits(s, 268435456) = 0 then w = w "HIDDEN"                  -- no WS_VISIBLE
  if bits(s, 134217728) \= 0 then w = w "DISABLED"
  if bits(s, 131072) \= 0 then w = w "GROUP"
  tabbable = "BUTTON CHECK RADIO EDIT LIST COMBO LISTVIEW TREEVIEW TAB TRACKBAR DATETIMEPICKER"
  if wordpos(kind, tabbable) > 0 & bits(s, 65536) = 0 then w = w "NOTAB"
  if bits(s, 2097152) \= 0 then w = w "VSCROLL"
  if bits(s, 1048576) \= 0 then w = w "HSCROLL"
  border = (bits(s, 8388608) \= 0)
  select
    when kind == "BUTTON" | kind == "CHECK" | kind == "RADIO" | kind == "GROUP" then do
      bs = bits(s, 15)
      if bs == 1 | bs == 13 | bs == 15 then w = w "DEFAULT"
      if bs == 5 | bs == 6 then w = w "3STATE"
      if bs == 11 then w = w "OWNER"
      if bits(s, 32) \= 0 then w = w "LTEXT"                    -- BS_LEFTTEXT
      if bits(s, 8192) \= 0 then w = w "MULTILINE"
      if bits(s, 16384) \= 0 then w = w "NOTIFY"
      if bits(s, 4096) \= 0 then w = w "PUSHLIKE"
    end
    when kind == "STATIC" then do
      ss = bits(s, 31)
      if ss == 1 then w = w "CENTER"
      if ss == 2 then w = w "RIGHT"
      if ss == 3 then w = w "ICON"
      if ss == 14 then w = w "BITMAP"
      if bits(s, 256) \= 0 then w = w "NOTIFY"
      if bits(s, 4096) \= 0 then w = w "SUNKEN"
      if border then w = w "BORDER"
    end
    when kind == "FRAME" then do
      ss = bits(s, 31)
      if ss >= 4 & ss <= 6 then w = w "RECT"
      if ss == 5 | ss == 8 then w = w "GRAY"
      if ss == 6 | ss == 9 then w = w "WHITE"
      if ss >= 16 then w = w "ETCHED"
    end
    when kind == "EDIT" then do
      if bits(s, 1) \= 0 then w = w "CENTER"
      if bits(s, 2) \= 0 then w = w "RIGHT"
      if bits(s, 4) \= 0 then do
        w = w "MULTILINE"
        if bits(s, 4096) \= 0 then w = w "WANTRETURN"
        else w = w "NOWANTRETURN"
      end
      if bits(s, 8) \= 0 then w = w "UPPER"
      if bits(s, 16) \= 0 then w = w "LOWER"
      if bits(s, 32) \= 0 then w = w "PASSWORD"
      if bits(s, 64) \= 0 then w = w "AUTOSCROLLV"
      if bits(s, 128) \= 0 then w = w "AUTOSCROLLH"
      if bits(s, 256) \= 0 then w = w "KEEPSELECTION"
      if bits(s, 2048) \= 0 then w = w "READONLY"
      if bits(s, 8192) \= 0 then w = w "NUMBER"
      if \border then w = w "NOBORDER"
    end
    when kind == "LIST" then do
      if bits(s, 1) \= 0 then w = w "NOTIFY"
      if bits(s, 2) \= 0 then w = w "SORT"
      if bits(s, 8) \= 0 then w = w "MULTI"
      if bits(s, 2048) \= 0 then w = w "EXTSEL MULTI"
      if bits(s, 128) \= 0 then w = w "USETAB"
      if bits(s, 256) \= 0 then w = w "PARTIAL"
      if bits(s, 512) \= 0 then w = w "COLUMNS"
      if bits(s, 1024) \= 0 then w = w "KEYINPUT"
      if bits(s, 4096) \= 0 then w = w "SBALWAYS"
      if bits(s, 16384) \= 0 then w = w "NOSEL"
    end
    when kind == "COMBO" then do
      cbs = bits(s, 3)
      if cbs == 1 then w = w "SIMPLE"
      if cbs == 3 then w = w "LIST"
      if bits(s, 256) \= 0 then w = w "SORT"
      if bits(s, 1024) \= 0 then w = w "PARTIAL"
      if bits(s, 8192) \= 0 then w = w "UPPER"
      if bits(s, 16384) \= 0 then w = w "LOWER"
    end
    when kind == "PROGRESS" then do
      if bits(s, 4) \= 0 then w = w "VERTICAL"
      if bits(s, 1) \= 0 then w = w "SMOOTH"
    end
    when kind == "LISTVIEW" then do
      view = bits(s, 3)
      w = w word("ICON REPORT SMALLICON LIST", view + 1)
      if bits(s, 4) \= 0 then w = w "SINGLESEL"
      if bits(s, 8) \= 0 then w = w "SHOWSELALWAYS"
      if bits(s, 16) \= 0 then w = w "ASCENDING"
      if bits(s, 32) \= 0 then w = w "DESCENDING"
      if bits(s, 512) \= 0 then w = w "EDIT"
      if bits(s, 16384) \= 0 then w = w "NOHEADER"
    end
    when kind == "TREEVIEW" then do
      if bits(s, 1) \= 0 then w = w "BUTTONS"
      if bits(s, 2) \= 0 then w = w "LINES"
      if bits(s, 4) \= 0 then w = w "ATROOT"
      if bits(s, 8) \= 0 then w = w "EDIT"
      if bits(s, 32) \= 0 then w = w "SHOWSELALWAYS"
    end
    when kind == "TAB" then do
      if bits(s, 256) \= 0 then w = w "BUTTONS"
      if bits(s, 512) \= 0 then w = w "MULTILINE"
      if bits(s, 1024) \= 0 then w = w "FIXED"
    end
    when kind == "UPDOWN" then do
      if bits(s, 1) \= 0 then w = w "WRAP"
      if bits(s, 2) \= 0 then w = w "SETBUDDYINT"
      if bits(s, 4) \= 0 then w = w "RIGHT"
      if bits(s, 8) \= 0 then w = w "LEFT"
      if bits(s, 16) \= 0 then w = w "AUTOBUDDY"
      if bits(s, 32) \= 0 then w = w "ARROWKEYS"
      if bits(s, 64) \= 0 then w = w "HORIZONTAL"
      if bits(s, 128) \= 0 then w = w "NOTHOUSANDS"
    end
    when kind == "TRACKBAR" then do
      if bits(s, 1) \= 0 then w = w "AUTOTICKS"
      if bits(s, 2) \= 0 then w = w "VERTICAL"
      if bits(s, 4) \= 0 then w = w "TOP"
      if bits(s, 8) \= 0 then w = w "BOTH"
      if bits(s, 16) \= 0 then w = w "NOTICKS"
    end
    when kind == "DATETIMEPICKER" then do
      if bits(s, 9) == 9 then w = w "TIME"
      else if bits(s, 1) \= 0 then w = w "UPDOWN"
      if bits(s, 2) \= 0 then w = w "SHOWNONE"
      if bits(s, 12) == 4 then w = w "LONG"
      if bits(s, 12) == 12 then w = w "CENTURY"
      if bits(s, 32) \= 0 then w = w "RIGHT"
    end
    otherwise nop
  end
  return w~strip

::method asContract
  expose id x y cx cy text textIsOrdinal style exStyle windowClass
  c = .directory~new
  c~kind = self~kind
  c~id = id
  c~x = x; c~y = y; c~cx = cx; c~cy = cy
  if textIsOrdinal then c~text = ""
  else c~text = text
  c~opts = self~opts
  c~style = style~d2x(8)                -- beyond the contract: provenance
  c~exStyle = exStyle~d2x(8)
  c~windowClass = windowClass           -- not ~class: that is Object's own method
  if textIsOrdinal then c~resource = text
  return c


/*==========================================================================*/
/* MENU and MENUEX templates, flattened depth first.                        */
/*==========================================================================*/
::class WinMenuTemplate public
::attribute extended get
::attribute records get      -- array of directories: depth id text flags popup

::method parse class
  use strict arg b
  t = self~new
  t~decode(b)
  return t

::method decode
  expose extended records
  use strict arg b
  rb = .WinResBytes
  records = .array~new
  version = rb~u16(b, 1)
  extended = (version == 1)
  if extended then do
    p = 5 + rb~u16(b, 3)
    self~itemsEx(b, p, 0)
  end
  else do
    p = 5 + rb~u16(b, 3)
    self~items(b, p, 0)
  end
  return self

::method add private
  expose records
  use strict arg depth, id, text, flags, popup
  r = .directory~new
  r~depth = depth
  r~id = id
  r~text = text
  r~flags = flags~strip
  r~popup = popup
  records~append(r)

/* MENU: WORD flags, [WORD id unless MF_POPUP], text; MF_END closes a level */
::method items private
  use strict arg b, p, depth
  rb = .WinResBytes
  if depth > 32 then raise syntax 98.900 array("WinResources: menu nested too deeply")
  do forever
    if p + 1 > b~length then raise syntax 98.900 array("WinResources: menu template ends early")
    f = rb~u16(b, p); p += 2
    popup = (bits(f, 16) \= 0)
    id = 0
    if \popup then do
      id = rb~u16(b, p); p += 2
    end
    r = rb~utf16z(b, p); text = r[1]; p = r[2]
    flags = self~menuFlags(f, 0)
    if \popup & id == 0 & text == "" then flags = "SEPARATOR" flags
    self~add(depth, id, text, flags, popup)
    if popup then p = self~items(b, p, depth + 1)
    if bits(f, 128) \= 0 then return p
  end

/* MENUEX: DWORD type, DWORD state, DWORD id, WORD resInfo, text, align,
 * [DWORD helpId and the children when resInfo has 0x01]; 0x80 ends a level */
::method itemsEx private
  use strict arg b, p, depth
  rb = .WinResBytes
  if depth > 32 then raise syntax 98.900 array("WinResources: menu nested too deeply")
  do forever
    if p + 13 > b~length then raise syntax 98.900 array("WinResources: menu template ends early")
    type = rb~u32(b, p); state = rb~u32(b, p + 4); id = rb~i32(b, p + 8); info = rb~u16(b, p + 12)
    r = rb~utf16z(b, p + 14); text = r[1]
    p = rb~align4(r[2])
    popup = (bits(info, 1) \= 0)
    self~add(depth, id, text, self~menuFlags(type, state, .true), popup)
    if popup then p = self~itemsEx(b, p + 4, depth + 1)
    if bits(info, 128) \= 0 then return p
  end

/* MF_ / MFT_ / MFS_ bits -> the flag words of ooDialog menus */
::method menuFlags private
  use strict arg f, state, ex = .false
  w = ""
  if ex then do
    if bits(f, 2048) \= 0 then w = w "SEPARATOR"
    if bits(f, 512) \= 0 then w = w "RADIO"
    if bits(state, 3) \= 0 then w = w "GRAYED"
    if bits(state, 8) \= 0 then w = w "CHECKED"
    if bits(state, 4096) \= 0 then w = w "DEFAULT"
    if bits(state, 128) \= 0 then w = w "HILITE"
  end
  else do
    if bits(f, 2048) \= 0 then w = w "SEPARATOR"
    if bits(f, 1) \= 0 then w = w "GRAYED"
    if bits(f, 2) \= 0 then w = w "DISABLED"
    if bits(f, 8) \= 0 then w = w "CHECKED"
  end
  if bits(f, 32) \= 0 then w = w "MENUBARBREAK"
  if bits(f, 64) \= 0 then w = w "MENUBREAK"
  if bits(f, 256) \= 0 then w = w "OWNERDRAW"
  if bits(f, 16384) \= 0 then w = w "HELP"
  return w~strip

/* The ooDialog/WASM resourceProvider contract: depth id text flags */
::method asContract
  expose records
  out = .array~new
  do r over records
    c = .directory~new
    c~depth = r~depth; c~id = r~id; c~text = r~text; c~flags = r~flags
    out~append(c)
  end
  return out


/*==========================================================================*/
/* The reader ooDialog/WASM plugs in:  .oodn~resourceProvider = this        */
/*==========================================================================*/
::class WinResourceProvider public
::attribute language            -- preferred LANGID, or .nil
::attribute opened get          -- path -> WinResourceSet

::method init
  expose opened language
  use strict arg language = .nil
  opened = .table~new

/* library: a path in this file system (a .dll, .exe or .res); id: numeric */
::method dialogTemplate
  use strict arg library, id
  t = self~resources(library)~dialog(id, self~language)
  if t == .nil then return .nil
  return t~asContract

::method menuTemplate
  use strict arg library, id
  m = self~resources(library)~menu(id, self~language)
  if m == .nil then return .nil
  return m~asContract

::method resources
  expose opened
  use strict arg library
  set = opened[library]
  if set == .nil then do
    set = .WinResourceSet~fromFile(library)
    opened[library] = set
  end
  return set

::method forget
  expose opened
  opened = .table~new
  return self

/* Numeric AND of two unsigned 32-bit values (String~bitAnd works on characters). */
::routine bits public
  use strict arg v, m
  return c2d(bitand(d2c(v, 4), d2c(m, 4)))
