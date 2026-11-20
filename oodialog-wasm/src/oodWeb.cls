/* oodWeb.cls -- the native layer of ooDialog for ooRexx/WASM.
 *
 * Architecture: Tom Dyer.  Code: Claude (Fable 5.2).
 *
 * ooDialog.cls (generated from upstream by oodgen.rex) sends every call that
 * the Windows DLL used to answer to .oodn, with the name of the DLL function
 * as the message: .oodn~wb_getText(self, "GETTEXT", args).  The methods of
 * .OodNative below are those functions, written in Rexx over the page-side
 * runtime (oodialog-web.js, embedded at the end of this file), which they
 * reach through Josep Maria Blasco's js.cls.
 *
 * A function that is not here yet raises SYNTAX 98.900 naming itself, so
 * what is missing is always visible; .oodn~implemented lists what is here.
 */
.local~oodn = .OodNative~new
.local~constDirUsage = "use never"
.local~systemErrorCode = 0

::requires "js.cls"
::requires "ooShapes.cls"

/*============================================================================*/
/* State of a dialog (what CPlainBaseDialog is to the DLL).                    */
/*============================================================================*/
::class OodDlg
::method module_version class
  return "0.24.0"
::method module_lastChanged class
  return "2026-11-20"
::attribute key unguarded
::attribute rexxSelf unguarded
::attribute library unguarded
::attribute resourceID unguarded
::attribute dlgID unguarded
::attribute autoDetect unguarded
::attribute fontName unguarded
::attribute fontSize unguarded
::attribute sizeX unguarded
::attribute sizeY unguarded
::attribute factorX unguarded
::attribute factorY unguarded
::attribute pixelCX unguarded
::attribute pixelCY unguarded
::attribute initCode unguarded
::attribute live unguarded            -- the dialog exists in the page
::attribute templateActive unguarded  -- create() has run, controls may be added
::attribute spec unguarded            -- x y cx cy title opts of create()
::attribute template unguarded        -- the controls, in creation order
::attribute dataTable unguarded       -- (id kind) of the controls connected to data attributes
::attribute cmdTable unguarded        -- WM_COMMAND connections: (id code method)
::attribute controls unguarded        -- control objects handed out, by "id class"
::attribute kinds unguarded           -- kind of control, by id
::attribute notifyTable unguarded     -- WM_NOTIFY connections: (id event method keyword)
::attribute store unguarded           -- user data of items, by "id item"
::attribute menu unguarded            -- the menu bar's OodMenu, if one is attached
::attribute pageInfo unguarded        -- a property sheet page's state, else .nil
::attribute sheet unguarded           -- a property sheet's state, else .nil
::attribute embed unguarded           -- (parent key, x, y in pixels) of a dialog shown inside another, else .nil
::attribute wmTable unguarded          -- dialog message connections: (event method)
::attribute ctlInfo unguarded         -- a ControlDialog's state, else .nil
::attribute keyTable unguarded        -- key press connections: (method, set of key codes, filter)
::attribute deferred unguarded        -- operations asked for before the dialog exists: (id name a b c)
::attribute contextMethod unguarded   -- the method of the context menu event
::attribute parentDlg unguarded
::attribute ownerDialog unguarded
::method init
  expose key rexxSelf library resourceID dlgID autoDetect fontName fontSize sizeX sizeY factorX factorY -
         pixelCX pixelCY initCode live templateActive spec template dataTable cmdTable controls kinds -
         parentDlg ownerDialog notifyTable store menu contextMethod deferred keyTable pageInfo sheet embed ctlInfo wmTable
  use arg key, rexxSelf, library, resourceID
  dlgID = -1
  autoDetect = .true
  fontName = "MS Shell Dlg"
  fontSize = 8
  sizeX = 0; sizeY = 0; factorX = 1; factorY = 1; pixelCX = 0; pixelCY = 0
  initCode = 0
  live = .false
  templateActive = .false
  spec = .nil
  template = .array~new
  dataTable = .array~new
  cmdTable = .array~new
  controls = .directory~new
  kinds = .directory~new
  notifyTable = .array~new
  store = .directory~new
  deferred = .array~new
  keyTable = .array~new
  ctlInfo = .nil
  wmTable = .array~new
  pageInfo = .nil
  sheet = .nil
  embed = .nil
  menu = .nil
  contextMethod = ""
  parentDlg = .nil
  ownerDialog = .nil
::method hwnd unguarded
  expose key
  return "0x"d2x(key * 65536)~right(16, "0")

/* State of a menu object: a menu bar, a popup menu, or a popup of a template. */
::class OodMenu
::method module_version class
  return "0.24.0"
::method module_lastChanged class
  return "2026-11-20"
::attribute rexxSelf unguarded
::attribute isBar unguarded
::attribute wID unguarded
::attribute items unguarded           -- directories: id text flags popup
::attribute stack unguarded           -- template levels still open: (menu, closes its parent too)
::attribute pending unguarded         -- (id method) to connect when a dialog is known
::attribute dlg unguarded             -- the dialog attached or assigned to
::attribute owner unguarded           -- the menu this popup is in
::attribute autoConnect unguarded
::attribute autoMethod unguarded
::method init
  expose rexxSelf isBar wID items stack pending dlg owner autoConnect autoMethod
  use arg rexxSelf, isBar
  wID = -1
  items = .array~new
  stack = .queue~new
  stack~push(.array~of(self, .false))
  pending = .array~new
  dlg = .nil
  owner = .nil
  autoConnect = .false
  autoMethod = ""

/* State of a control object. */
::class OodCtl
::method module_version class
  return "0.24.0"
::method module_lastChanged class
  return "2026-11-20"
::attribute dlg unguarded             -- its dialog's OodDlg
::attribute id unguarded
::attribute kind unguarded
::method init
  expose dlg id kind
  use arg dlg, id, kind
::method hwnd unguarded
  expose dlg id
  return "0x"d2x(dlg~key * 65536 + id)~right(16, "0")

/*============================================================================*/
/* The native layer.                                                           */
/*============================================================================*/
::class OodNative public
::method module_version class
  return "0.24.0"
::method module_lastChanged class
  return "2026-11-20"
::method module_version unguarded
  return self~class~module_version
::method module_lastChanged unguarded
  return self~class~module_lastChanged

::method init
  expose dialogs nextKey pkg msgResults nextToken appAutoDetect defFontName defFontSize
  self~resourceProvider = .nil
  dialogs = .directory~new
  nextKey = 0
  nextToken = 0
  msgResults = .directory~new
  pkg = .nil
  appAutoDetect = .true
  defFontName = "MS Shell Dlg"
  defFontSize = 8

/* The names of the DLL functions answered here. */
::method implemented unguarded
  names = .array~new
  sup = self~class~methods(.nil)
  do while sup~available
    if sup~index~pos("_") > 0 then names~append(sup~index)
    sup~next
  end
  return names~sort

::method unknown unguarded
  use arg name, args
  if name~right(9) == "_INIT_CLS" then return 0        -- class set-up the DLL needed, nothing here
  if name~left(3) == "SM_" then return self~systemMetric(name)
  if name == "OS_ISVERSION" then return args[2]~pos("ATLEAST") > 0   -- newer than every Windows it asks about
  if name~left(5) == "OS_IS" then return .false                      -- not a 64-bit Windows
  what = name
  if args~items >= 2 then what = name "(method" args[2]")"
  raise syntax 98.900 array("ooDialog/WASM: native function" what "is not implemented yet")

/* .SM: system metrics.  The page's sizes where they exist, Windows' usual values otherwise. */
::method systemMetric unguarded
  use arg name
  parse var name "SM_" metric "_CLS"
  if metric == "CXSCREEN" | metric == "CYSCREEN" then do
    parse value self~web~screen with w h
    if metric == "CXSCREEN" then return w
    return h
  end
  usual = "CXFIXEDFRAME 3 CYFIXEDFRAME 3 CXSIZE 36 CYSIZE 22 CYCAPTION 23 CXVSCROLL 17 CYHSCROLL 17 CXICON 32 CYICON 32" -
          "CXSMICON 16 CYSMICON 16 CXCURSOR 32 CYCURSOR 32 CXDRAG 4 CYDRAG 4 CYMENU 20 CMOUSEBUTTONS 3"
  p = usual~wordPos(metric)
  if p > 0 then return usual~word(p + 1)
  return 0

/*---- the page ----------------------------------------------------------------*/
/* deliver(path, title, mime): hand a file of the program's file system to the user.  The page
   shows it with Print, Open, Save and Close.  Answers the number of bytes; -1 if the file
   cannot be read.  (The standby printer: see oodPrint.cls.) */
::method deliver unguarded
  use strict arg path, title = "", mime = ""
  file = .stream~new(path)
  if file~query("EXISTS") == "" then return -1
  if file~open("READ SHARED") \== "READY:" then return -1
  bytes = file~charIn(1, file~chars)
  file~close
  name = filespec("NAME", path~changeStr("\", "/"))
  if mime == "" then do
    ext = name~substr(name~lastPos(".") + 1)~upper
    types = .directory~new
    types~pdf = "application/pdf"
    types~txt = "text/plain"
    types~csv = "text/csv"
    types~html = "text/html"
    types~png = "image/png"
    types~jpg = "image/jpeg"
    mime = types[ext]
    if mime == .nil then mime = "application/octet-stream"
  end
  if title == "" then title = name
  return self~web~deliver(name, mime, bytes~c2x, title)
::method web                       -- the page's __ood, loading the runtime the first time
  expose web
  if var("WEB") then return web
  page = .js~page
  if page["__ood"] == .js~undefined then do
    source = .resources~oodjs~makeString("L", "0a"x)
    page~js.invokeStrict("eval", source)
  end
  web = page["__ood"]
  web~setHandler(.js~handler(self, "PAGEEVENT"))
  return web

::method newKey
  expose nextKey
  nextKey = nextKey + 1
  return nextKey

::method register
  expose dialogs
  use arg d
  dialogs[d~key] = d
::method deregister
  expose dialogs
  use arg d
  dialogs~remove(d~key)
::method dialogOf unguarded
  expose dialogs
  use arg key
  return dialogs[key]

/* The state of a dialog or control object. */
::method peer unguarded
  use arg obj
  return obj~oodPeer

/* (key, id) of a window object: id 0 is the dialog itself. */
::method target unguarded
  use arg obj
  p = obj~oodPeer
  if p~isA(.OodDlg) then return .array~of(p, 0)
  return .array~of(p~dlg, p~id)

::method op unguarded              -- an operation on a window object, in the page
  use arg obj, name, a = "", b = "", c = ""
  t = self~target(obj)
  if \t[1]~live then return ""
  return self~web~op(t[1]~key, t[2], name, a, b, c)

::method ctlOp unguarded           -- the same, by dialog state and control ID
  use arg d, id, name, a = "", b = "", c = ""
  if \d~live then return ""
  return self~web~op(d~key, id, name, a, b, c)

::method winMsg unguarded          -- a Win32 message to a control
  use arg d, id, msg, wParam = 0, lParam = 0
  if \d~live then return 0
  return self~web~msg(d~key, id, self~number(msg), self~number(wParam), self~number(lParam))

::method number unguarded          -- 0x00F5, a handle, or a number, as a number
  use arg v
  numeric digits 40                  -- (a handle or a 64-bit value has more than nine digits)
  if v~isA(.String) then do
    if v~left(2)~upper == "0X" then return x2d(v~substr(3))
    if v~datatype("N") then return v
    if v == .true then return 1
  end
  return 0

/*---- events from the page ----------------------------------------------------*/
::method pageEvent unguarded
  expose msgResults
  use arg key, kind, id, code, extra
  select
    when kind == "MSGBOX" then msgResults[id] = code
    when kind == "CMD" then self~command(key, id, code)
    when kind == "NOTIFY" then self~notify(key, id, code, extra)
    when kind == "CTX" then self~contextMenu(key, id, code, extra)
    when kind == "KEY" then self~keyPress(key, id, code, extra)
    when kind == "WM" then self~wmEvent(key, code, extra)
    when kind == "MOUSE" then self~mouseEvent(key, id, code, extra)
    when kind == "GC" then self~grandChildEvent(key, id, code)
    when kind == "TT" then self~ttEvent(key, id, code, extra)
    when kind == "CD" then self~cdEvent(key, id, extra)
    when kind == "SB" then self~sbEvent(key, id, code, extra)
    otherwise nop
  end

/* The dialog's own messages: connectResize, connectMove, connectSizeMoveEnded.
 * The others (connectActivate, connectHelp, connectPosChanged, connectResizing) are accepted
 * and not produced. */
::method en_connectWmEvent unguarded
  use arg self_, msg, a
  d = self_~oodPeer
  event = ""
  if msg == "CONNECTRESIZE" then event = "RESIZE"
  if msg == "CONNECTMOVE" then event = "MOVE"
  if msg == "CONNECTSIZEMOVEENDED" then event = "SIZEMOVEENDED"
  if event == "" then do
    say "ooDialog/WASM:" msg~substr(8) "is connected but is not produced yet"
    return .true
  end
  d~wmTable~append(.array~of(event, a[1]~upper))
  d~cmdTable~append(.array~of(0, event, ""))
  if d~live then self~web~sub(d~key, 0, event)
  return .true
::method wmEvent unguarded         -- the arguments are wParam and lParam, as for WM_SIZE and WM_MOVE
  use arg key, event, extra
  d = self~dialogOf(key)
  if d == .nil then return
  sep = self~sep
  parse var extra first (sep) second
  do entry over d~wmTable
    if entry[1] \== event then iterate
    if event == "SIZEMOVEENDED" | event == "RASIZEENDED" then args = .array~new
    else args = .array~of(0, second * 65536 + first)
    self~invoke(d~rexxSelf, entry[2], args)
  end

/* Track bar events: DRAG while the thumb moves, ENDTRACK when it is let go. */
::method en_connectTrackBarEvent unguarded
  use arg self_, msg, a
  return self~connectNotify(self_, a, "DRAG TRACK ENDTRACK TRACK POSITION TRACK")

/* Key presses: connectKeyPress(method, keys, filter), connectFKeyPress(method). */
::method keySet unguarded          -- "ALL", "FKEYS", "65-90", "13, 27" ... as a set of virtual key codes
  use arg keys
  codes = .set~new
  do token over keys~translate(" ", ",")~upper~makeArray(" ")
    low = 0
    high = -1
    select
      when token == "ALL" then do
        low = 1; high = 255
      end
      when token == "FKEYS" then do
        low = 112; high = 135
      end
      when token == "ALPHA" then do
        low = 65; high = 90
      end
      when token == "NUMERIC" then do
        low = 48; high = 57
      end
      when token == "ALPHANUMERIC" then do
        low = 48; high = 90
      end
      when token~pos("-") > 1 then parse var token low "-" high
      when token~datatype("W") then do
        low = token; high = token
      end
      otherwise nop
    end
    if low~datatype("W") then if high~datatype("W") then do code = low to high
      codes~put(code)
    end
  end
  return codes
::method connectKeys unguarded
  use arg dlg, method, keys, filter
  d = dlg~oodPeer
  d~keyTable~append(.array~of(method~upper, self~keySet(keys), filter~upper))
  d~cmdTable~append(.array~of(0, "KEY", ""))
  if d~live then self~web~sub(d~key, 0, "KEY")
  return 0
::method en_connectKeyPress unguarded
  use arg self_, msg, a
  return self~connectKeys(self_, a[1], a[2], self~opt(a, 3))
::method en_connectFKeyPress unguarded
  use arg self_, msg, a
  return self~connectKeys(self_, a[1], "FKEYS", "")
::method en_disconnectKeyPress unguarded
  use arg self_, msg, a
  d = self_~oodPeer
  keep = .array~new
  do entry over d~keyTable
    if a~hasIndex(1) then if entry[1] \== a[1]~upper then keep~append(entry)
  end
  d~keyTable = keep
  return 0
::method en_hasKeyPressConnection unguarded
  use arg self_, msg, a
  do entry over self_~oodPeer~keyTable
    if \a~hasIndex(1) then return .true
    if entry[1] == a[1]~upper then return .true
  end
  return .false
::method keyPress unguarded        -- the method gets (key code, shift, control, alt, info); a control's method also the control
  use arg key, code, mods, focusId = 0
  d = self~dialogOf(key)
  if d == .nil then return
  shift = (mods~pos("S") > 0)
  control = (mods~pos("C") > 0)
  alt = (mods~pos("A") > 0)
  do entry over d~keyTable
    if \entry[2]~hasIndex(code) then iterate
    filter = entry[3]
    if filter~wordPos("NONE") > 0 then if shift | control | alt then iterate
    if filter~wordPos("SHIFT") > 0 then if \shift then iterate
    if filter~wordPos("CONTROL") > 0 then if \control then iterate
    if filter~wordPos("ALT") > 0 then if \alt then iterate
    if entry~items > 3 then do      -- connected by a control: only while it has the focus
      if entry[4] \== focusId then iterate
      self~invoke(d~rexxSelf, entry[1], .array~of(code, shift, control, alt, mods, self~controlObject(d, entry[4])))
    end
    else self~invoke(d~rexxSelf, entry[1], .array~of(code, shift, control, alt, mods))
  end
::method controlObject unguarded   -- the control object the program has for an ID; .nil if it has none
  use arg d, id
  do name over d~controls~allIndexes
    if name~word(1) == id then return d~controls[name]
  end
  return .nil
/* connectKeyPress and its family for a control: as the dialog's, but the method runs only
   while that control has the focus, and gets the control as its sixth argument. */
::method dlgctrl_connectKeyPress unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  self~connectKeys(p~dlg~rexxSelf, a[1], a[2], self~opt(a, 3))
  p~dlg~keyTable[p~dlg~keyTable~items]~append(p~id)
  return 0
::method dlgctrl_connectFKeyPress unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  self~connectKeys(p~dlg~rexxSelf, a[1], "FKEYS", "")
  p~dlg~keyTable[p~dlg~keyTable~items]~append(p~id)
  return 0
::method dlgctrl_disconnectKeyPress unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  keep = .array~new
  do entry over p~dlg~keyTable
    mine = (entry~items > 3)
    if mine then mine = (entry[4] == p~id)
    if mine then if a~hasIndex(1) then mine = (entry[1] == a[1]~upper)
    if \mine then keep~append(entry)
  end
  p~dlg~keyTable = keep
  return 0
::method dlgctrl_hasKeyPressConnection unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  do entry over p~dlg~keyTable
    if entry~items < 4 then iterate
    if entry[4] \== p~id then iterate
    if \a~hasIndex(1) then return .true
    if entry[1] == a[1]~upper then return .true
  end
  return .false

/* WM_CONTEXTMENU: the method gets the window's handle and the position. */
::method contextMenu unguarded
  use arg key, id, x, y
  d = self~dialogOf(key)
  if d == .nil then return
  if d~contextMethod == "" then return
  self~invoke(d~rexxSelf, d~contextMethod, .array~of("0x"d2x(key * 65536 + id)~right(16, "0"), x, y))

/* WM_COMMAND: the connected method, or OK / Cancel / Help for IDs 1, 2, 9. */
::method command unguarded
  use arg key, id, code
  d = self~dialogOf(key)
  if d == .nil then return
  dlg = d~rexxSelf
  if d~sheet \== .nil then if code == 0 then if self~sheetButton(d, id) then return
  method = ""
  do entry over d~cmdTable
    if entry[1] \== id then iterate
    if entry[3] == "" then iterate
    if entry[2] \== "*" then if entry[2] \== code then iterate
    method = entry[3]
    leave
  end
  if method == "" then do
    if code \== 0 then return
    select
      when id == 1 then method = "OK"
      when id == 2 then method = "CANCEL"
      when id == 9 then method = "HELP"
      otherwise return
    end
  end
  wParam = code * 65536 + id
  lParam = "0x"d2x(key * 65536 + id)~right(16, "0")
  self~invoke(dlg, method, .array~of(wParam, lParam))

/* Send an event method whose answer is wanted; .nil if it gives none or fails. */
::method invokeResult unguarded
  use arg dlg, method, args
  signal on syntax
  answer = dlg~sendWith(method, args)
  if var("ANSWER") then return answer
  return .nil
syntax:
  say "ooDialog/WASM: error in event method" method":" condition("O")~message
  return .nil

/* Send an event method.  An error in it is reported and the dialog goes on. */
::method invoke unguarded
  expose handlerDepth
  use arg dlg, method, args
  if \var("HANDLERDEPTH") then handlerDepth = 0
  handlerDepth = handlerDepth + 1  -- (msSleep asks: is an event method running?)
  signal on syntax                 -- (a class may answer events in UNKNOWN, as the DLL allowed)
  dlg~sendWith(method, args)
  handlerDepth = handlerDepth - 1
  return
syntax:
  handlerDepth = handlerDepth - 1
  co = condition("O")
  say "ooDialog: error in event method" method": rc" rc "line" sigl condition("C") condition("D")
  if co \== .nil then do
    say "  " co~message
    if co~traceback \== .nil then do line over co~traceback
      say line
    end
  end
  return

/* The seam for a system-classes file (WindowsManager, WindowObject, MenuObject of
   winsystm.cls, done for this machine): the dialogs now on the page, as their own
   ooDialog objects, oldest first.  Everything else such a file needs is ooDialog's
   public API on those objects (title, hwnd, moveTo, resizeTo, show, menuBar ...). */
::method windows unguarded
  expose dialogs
  found = .array~new
  keys = dialogs~allIndexes~sort
  do key over keys
    d = dialogs[key]
    if d~live then if d~embed == .nil then found~append(d~rexxSelf)
  end
  return found

/* winTimer("START", ms) answers a timer; winTimer("WAIT", timer) returns at its next
   tick; winTimer("STOP", timer).  The wait takes the page's events, as msSleep does. */
::method winTimer_rtn unguarded
  expose timers
  use arg , , a
  numeric digits 20
  if \var("TIMERS") then timers = .directory~new
  mode = self~opt(a, 1)~upper
  select
    when mode~abbrev("STA") then do
      ms = 0
      if a~hasIndex(2) then if a[2]~datatype("N") then ms = a[2]
      id = timers~items + 1
      do while timers~hasIndex(id)
        id = id + 1
      end
      timers[id] = .array~of(ms, time("F") + ms * 1000)
      return id
    end
    when mode~abbrev("STO") then do
      if a~hasIndex(2) then timers~remove(a[2])
      return 0
    end
    when mode~abbrev("W") then do
      if \a~hasIndex(2) then return 1
      t = timers[a[2]]
      if t == .nil then return 1
      left = (t[2] - time("F")) / 1000
      if left > 0 then self~msSleep_rtn(.nil, "", .array~of(left))
      t[2] = max(t[2] + t[1] * 1000, time("F"))
      return 0
    end
    otherwise return 1
  end

::method onPumpThread unguarded    -- is the caller below pumpUntilFinished on the call stack?
  do frame over .context~stackFrames
    if frame~name == "PUMPUNTILFINISHED" then return .true
  end
  return .false

::method handlerOutlivedDialogs unguarded
  expose handlerDepth dialogs
  if \var("HANDLERDEPTH") then return .false
  if handlerDepth < 1 then return .false
  do d over dialogs~allItems       -- a dialog marked finished is only waiting for this method to return
    if d~live then if d~rexxSelf~finished \== .true then return .false
  end
  return .true

/* Take the page's events on this thread until the dialog is finished. */
::method pumpUntilFinished unguarded
  use arg dlg
  do while \dlg~finished
    event = .js~nextEvent(0.2)
    if event \== .nil then event~dispatch
  end

/*---- symbolic IDs ------------------------------------------------------------*/
::method putDefaultSymbols unguarded
  use arg dir
  dir["IDOK"] = 1
  dir["IDCANCEL"] = 2
  dir["IDHELP"] = 9
  dir["IDC_STATIC"] = -1
  dir["IDI_DLG_OODIALOG"] = 11
  dir["IDI_DLG_APPICON"] = 12
  dir["IDI_DLG_APPICON2"] = 13
  dir["IDI_DLG_OOREXX"] = 14
  dir["IDI_DLG_DEFAULT"] = 12

::method resolveId unguarded       -- a number, or a symbol of the constDir; -1 if unknown
  use arg obj, rxID
  if rxID~isA(.String) then do
    if rxID~datatype("W") then return rxID
    name = rxID~strip~upper
    if name == "" then return -1
    usage = .constDirUsage
    own = .nil
    if obj \== .nil then if obj~hasMethod("CONSTDIR") then own = obj~constDir
    global = .constDir
    if usage == "use only" | usage == "use first" then do
      if global \== .nil then if global~hasIndex(name) then return global[name]
    end
    if usage \== "use only" then do
      if own \== .nil then if own~hasIndex(name) then return own[name]
    end
    if usage == "use last" then do
      if global \== .nil then if global~hasIndex(name) then return global[name]
    end
  end
  return -1

::method global_resolveSymbolicId unguarded   -- resolveSymbolicId(symbol): by the global .constDir
  use arg self_, msg, a
  return self~resolveId(.nil, a[1])
::method rsrcUtils_resolveResourceID unguarded
  use arg self_, msg, a
  return self~resolveId(self_, a[1])
::method rsrcUtils_checkID unguarded
  use arg self_, msg, a
  id = self~resolveId(self_, a[1])
  if id == -1 then self~messageDialog_rtn(.nil, "", .array~of("Resource ID" a[1] "could not be resolved", 0, "ooDialog Error", "OK", "ERROR"))
  return id
::method rsrcUtils_idError unguarded
  use arg self_, msg, a
  return -1
::method rsrcUtils_resolveIconID_pvt unguarded
  use arg self_, msg, a
  if a[1]~datatype("W") then return a[1]
  id = self~resolveId(self_, a[1])
  if id == -1 then return 0
  return id

/*---- ApplicationManager and DlgUtil ------------------------------------------*/
::method dlgutil_init_cls          -- the DLL makes .application here
  expose pkg
  use arg self_, msg, a
  pkg = self_~package
  app = pkg~findClass("ApplicationManager")~new(0)
  .local~application = app
  return 0

::method classOf unguarded         -- a class of ooDialog.cls by name
  expose pkg
  use arg name
  return pkg~findClass(name)

::method app_init
  use arg self_, msg, a
  dir = .directory~new
  .local~constDir = dir
  self_~constDir = dir
  self~putDefaultSymbols(dir)
  .local~constDirUsage = "use never"
  return
::method app_initAutoDetection unguarded
  expose appAutoDetect
  use arg self_, msg, a
  a[1]~autoDetect = appAutoDetect
  return 0
::method app_autoDetection
  expose appAutoDetect
  use arg self_, msg, a
  if a~hasIndex(1) then appAutoDetect = (a[1] == .true)
  else appAutoDetect = .true
  return 0
::method setUsage
  use arg mode
  first = mode~strip~left(1)~upper
  select
    when first == "O" then .local~constDirUsage = "use only"
    when first == "F" then .local~constDirUsage = "use first"
    when first == "L" then .local~constDirUsage = "use last"
    when first == "N" then .local~constDirUsage = "use never"
    otherwise return .false
  end
  return .true
::method addSymbols                -- a header file, or a collection of symbols
  use arg app, src
  if src~isA(.String) then return app~parseIncludeFile(src)
  if src~hasMethod("SUPPLIER") then do
    sup = src~supplier
    do while sup~available
      .constDir[sup~index~upper] = sup~item
      sup~next
    end
    return .true
  end
  return .false
::method app_useGlobalConstDir
  use arg self_, msg, a
  if \self~setUsage(a[1]) then return .false
  if a~hasIndex(2) then return self~addSymbols(self_, a[2])
  return .true
::method app_addToConstDir
  use arg self_, msg, a
  return self~addSymbols(self_, a[1])
::method app_setDefaults
  expose appAutoDetect defFontName defFontSize
  use arg self_, msg, a
  if a~hasIndex(1) then if \self~setUsage(a[1]) then return .false
  if a~hasIndex(2) then if \self~addSymbols(self_, a[2]) then return .false
  if a~hasIndex(3) then appAutoDetect = (a[3] == .true)
  if a~hasIndex(4) then defFontName = a[4]
  if a~hasIndex(5) then defFontSize = a[5]
  return .true
::method app_defaultFont
  expose defFontName defFontSize
  use arg self_, msg, a
  if a~hasIndex(1) then defFontName = a[1]
  if a~hasIndex(2) then defFontSize = a[2]
  return .true
::method app_defaultIcon unguarded
  return .true
::method app_requiredOS unguarded
  return .true
/* .application~srcDir: the directory of the program that was started, not of this
   file (PARSE SOURCE here names oodWeb.cls; in the browser both sit in one directory,
   on another system they do not).  The program is the bottom of the call stack. */
::method app_srcDir_atr unguarded
  expose appSrcDir
  if var("APPSRCDIR") then return appSrcDir
  frames = .context~stackFrames
  bottom = frames[frames~items]
  program = ""
  signal on syntax name noPackage
  program = bottom~executable~package~name
noPackage:
  if program == "" then do
    parse source . . program
    return filespec("LOCATION", program)
  end
  appSrcDir = filespec("LOCATION", program)
  return appSrcDir

::method dlgutil_loWord_cls unguarded
  use arg self_, msg, a
  return self~number(a[1]) // 65536
::method dlgutil_hiWord_cls unguarded
  use arg self_, msg, a
  return (self~number(a[1]) % 65536) // 65536
::method dlgutil_makeLPARAM_cls unguarded
  use arg self_, msg, a
  return ((a[2] + 65536) // 65536) * 65536 + ((a[1] + 65536) // 65536)
::method dlgutil_makeWPARAM_cls unguarded
  use arg self_, msg, a
  return ((a[2] + 65536) // 65536) * 65536 + ((a[1] + 65536) // 65536)
::method dlgutil_and_cls unguarded
  use arg self_, msg, a
  numeric digits 20
  x = self~number(a[1])~d2c(8)
  y = self~number(a[2])~d2c(8)
  return bitand(x, y)~c2d
::method dlgutil_or_cls unguarded
  use arg self_, msg, a
  numeric digits 20
  acc = "00000000 00000000"x
  do v over a
    acc = bitor(acc, self~number(v)~d2c(8))
  end
  return acc~c2d
::method dlgutil_version_cls unguarded
  use arg self_, msg, a
  return "ooDialog 4.2.5 for ooRexx/WASM" self~module_version "(upstream r13513; native layer oodWeb.cls)"
::method dlgutil_comctl32Version_cls unguarded
  return "6.10"
::method dlgutil_screenSize_cls unguarded
  use arg self_, msg, a
  parse value self~web~screen with w h
  return .array~of(w % 2, h % 2, w, h)
::method dlgutil_getSystemMetrics_cls unguarded
  use arg self_, msg, a
  parse value self~web~screen with w h
  if a[1] == 0 then return w
  if a[1] == 1 then return h
  return 0

/* DlgUtil's arithmetic (oodUtilities.cpp). */
::method dlgutil_shiftLeft_cls unguarded       -- unsigned, 64 bits
  use arg self_, msg, a
  numeric digits 40
  amount = 1
  if a~hasIndex(2) then amount = a[2]
  return (self~number(a[1]) * 2 ** amount) // 18446744073709551616
::method dlgutil_shiftRight_cls unguarded
  use arg self_, msg, a
  numeric digits 40
  amount = 1
  if a~hasIndex(2) then amount = a[2]
  return self~number(a[1]) % 2 ** amount
::method dlgutil_sShiftLeft_cls unguarded      -- signed, 64 bits
  use arg self_, msg, a
  numeric digits 40
  amount = 1
  if a~hasIndex(2) then amount = a[2]
  n = (self~number(a[1]) * 2 ** amount) // 18446744073709551616
  if n < 0 then n = n + 18446744073709551616
  if n >= 9223372036854775808 then n = n - 18446744073709551616
  return n
::method dlgutil_sShiftRight_cls unguarded     -- the sign stays
  use arg self_, msg, a
  numeric digits 40
  amount = 1
  if a~hasIndex(2) then amount = a[2]
  n = self~number(a[1])
  if n >= 0 then return n % 2 ** amount
  return -((-n + 2 ** amount - 1) % 2 ** amount)
::method dlgutil_signed32_cls unguarded
  use arg self_, msg, a
  numeric digits 20
  n = self~number(a[1]) // 4294967296
  if n >= 2147483648 then return n - 4294967296
  return n
::method dlgutil_unsigned32_cls unguarded
  use arg self_, msg, a
  numeric digits 20
  n = self~number(a[1])
  if n < 0 then return n + 4294967296
  return n
::method dlgutil_signed_cls unguarded          -- (a pointer-sized number: 64 bits)
  use arg self_, msg, a
  numeric digits 40
  n = self~number(a[1])
  if n >= 9223372036854775808 then return n - 18446744073709551616
  return n
::method dlgutil_unsigned_cls unguarded
  use arg self_, msg, a
  numeric digits 40
  n = self~number(a[1])
  if n < 0 then return n + 18446744073709551616
  return n
::method dlgutil_sloWord_cls unguarded         -- the low word, signed
  use arg self_, msg, a
  numeric digits 40
  n = self~number(a[1])
  if n < 0 then n = n + 18446744073709551616
  n = n // 65536
  if n >= 32768 then return n - 65536
  return n
::method dlgutil_shiWord_cls unguarded         -- the high word of the low 32 bits, signed
  use arg self_, msg, a
  numeric digits 40
  n = self~number(a[1])
  if n < 0 then n = n + 18446744073709551616
  n = (n % 65536) // 65536
  if n >= 32768 then return n - 65536
  return n
::method dlgutil_handleToPointer_cls unguarded
  use arg self_, msg, a
  return a[1]
::method dlgutil_threadID_cls unguarded
  return 1
::method dlgutil_errMsg_cls unguarded          -- (Windows' text for a system error code: there is no Windows)
  use arg self_, msg, a
  return "No description available"
::method dlgutil_screenArea_cls unguarded      -- the work area as a Rect
  use arg self_
  parse value self~web~screen with w h
  return self~classOf("Rect")~new(0, 0, w, h)
::method dlgutil_windowFromPoint_cls unguarded -- the handle of the window at a point of the screen; 0 if none
  use arg self_, msg, a
  parse value self~web~windowAt(a[1]~x, a[1]~y) with key id
  if key == "" then return 0
  return "0x"d2x(key * 65536 + id)~right(16, "0")
::method dlgutil_halt_cls unguarded
  return 0
::method dlgutil_terminate_cls unguarded
  return 0

/* SM: system metrics as class attributes (oodUtilities.cpp).  The values are those of a
   Windows desktop at 96 DPI with its usual settings, except the screen, which is the page. */
::method sm_cxScreen_cls unguarded
  parse value self~web~screen with w .
  return w
::method sm_cyScreen_cls unguarded
  parse value self~web~screen with . h
  return h
::method sm_cMouseButtons_cls unguarded
  return 3
::method sm_cxCursor_cls unguarded
  return 32
::method sm_cyCursor_cls unguarded
  return 32
::method sm_cxDrag_cls unguarded
  return 4
::method sm_cyDrag_cls unguarded
  return 4
::method sm_cxFixedFrame_cls unguarded
  return 3
::method sm_cyFixedFrame_cls unguarded
  return 3
::method sm_cxIcon_cls unguarded
  return 32
::method sm_cyIcon_cls unguarded
  return 32
::method sm_cxSmIcon_cls unguarded
  return 16
::method sm_cySmIcon_cls unguarded
  return 16
::method sm_cxSize_cls unguarded
  return 36
::method sm_cySize_cls unguarded
  return 22
::method sm_cxVScroll_cls unguarded
  return 17
::method sm_cyHScroll_cls unguarded
  return 17
::method sm_cyCaption_cls unguarded
  return 23
::method sm_cyMenu_cls unguarded
  return 20
::method sm_menuDropAlignment_cls unguarded
  return 0
/* SPI: system parameters.  A page cannot change the system: a value that is set is kept for
   this run and answered back, and nothing else changes. */
::method spiValues unguarded
  expose spiTable
  if \var("spiTable") then do
    spiTable = .directory~new
    spiTable~dragWidth = 4
    spiTable~dragHeight = 4
    spiTable~menuAnimation = .false
    spiTable~menuFade = .false
    spiTable~mouseHoverWidth = 4
    spiTable~mouseHoverHeight = 4
    spiTable~mouseHoverTime = 400
    spiTable~wheelScrollLines = 3
    spiTable~updateFlag = 0
  end
  return spiTable
::method spi_init_cls unguarded
  return 0
::method spi_getDragWidth_cls unguarded
  return self~spiValues~dragWidth
::method spi_setDragWidth_cls unguarded
  use arg self_, msg, a
  self~spiValues~dragWidth = a[1]
::method spi_getDragHeight_cls unguarded
  return self~spiValues~dragHeight
::method spi_setDragHeight_cls unguarded
  use arg self_, msg, a
  self~spiValues~dragHeight = a[1]
::method spi_getMenuAnimation_cls unguarded
  return self~spiValues~menuAnimation
::method spi_setMenuAnimation_cls unguarded
  use arg self_, msg, a
  self~spiValues~menuAnimation = (a[1] == .true)
::method spi_getMenuFade_cls unguarded
  return self~spiValues~menuFade
::method spi_setMenuFade_cls unguarded
  use arg self_, msg, a
  self~spiValues~menuFade = (a[1] == .true)
::method spi_getMouseHoverWidth_cls unguarded  -- (one native for the attribute and its setter)
  use arg self_, msg, a
  if msg~right(1) == "=" then self~spiValues~mouseHoverWidth = a[1]
  else return self~spiValues~mouseHoverWidth
::method spi_getMouseHoverHeight_cls unguarded
  use arg self_, msg, a
  if msg~right(1) == "=" then self~spiValues~mouseHoverHeight = a[1]
  else return self~spiValues~mouseHoverHeight
::method spi_getMouseHoverTime_cls unguarded
  use arg self_, msg, a
  if msg~right(1) == "=" then self~spiValues~mouseHoverTime = a[1]
  else return self~spiValues~mouseHoverTime
::method spi_getWheelScrollLines_cls unguarded
  return self~spiValues~wheelScrollLines
::method spi_setWheelScrollLines_cls unguarded
  use arg self_, msg, a
  self~spiValues~wheelScrollLines = a[1]
::method spi_getUpdateFlag_cls unguarded
  return self~spiValues~updateFlag
::method spi_setUpdateFlag_cls unguarded
  use arg self_, msg, a
  self~spiValues~updateFlag = a[1]
::method spi_setWorkArea_cls unguarded
  return 0
::method spi_getNonClientMetrics_cls unguarded -- a directory of the sizes and fonts of a window's frame
  use arg self_
  d = .directory~new
  d~borderWidth = 1
  d~scrollWidth = 17
  d~scrollHeight = 17
  d~captionWidth = 36
  d~captionHeight = 22
  d~smCaptionWidth = 22
  d~smCaptionHeight = 22
  d~menuWidth = 19
  d~menuHeight = 19
  d~paddedBorderWidth = 4
  return d
::method spi_setNonClientMetrics_cls unguarded
  return 0
/* OS: which Windows this is.  It is none: the answers are those of a current 64-bit Windows,
   which is what a program that asks wants to hear before it uses a newer control. */
::method os_isVersion unguarded
  use arg self_, msg
  if msg~left(9) == "ISATLEAST" then return .true
  return (msg == "ISWINDOWS10" | msg == "ISW10")
::method os_is64bit unguarded
  return .true
::method os_is32on64bit unguarded
  return .false
::method os_settingChanged unguarded
  return 0
::method os_shellChangeNotify unguarded
  return 0

/* Windows by handle (ooDialog.cpp): a handle of this port is dialog key * 65536 + control ID. */
::method windowOfHandle unguarded  -- an array (dialog peer, id); .nil if the handle is not a live window
  use arg handle
  n = self~number(handle)
  if \n~datatype("W") | n < 65536 then return .nil
  d = self~dialogOf(n % 65536)
  if d == .nil then return .nil
  if \d~live then return .nil
  return .array~of(d, n // 65536)
::method pbdlg_getWindowText unguarded
  use arg self_, msg, a
  w = self~windowOfHandle(a[1])
  if w == .nil then return ""
  return self~ctlOp(w[1], w[2], "getText")
::method pbdlg_setWindowText unguarded -- 0 on success, 1 if there is no such window
  use arg self_, msg, a
  w = self~windowOfHandle(a[1])
  if w == .nil then return 1
  if self~ctlOp(w[1], w[2], "setText", a[2]) == 1 then return 0
  return 1
::method pbdlg_showWindow unguarded    -- showWindow, hideWindow and their Fast forms
  use arg self_, msg, a
  w = self~windowOfHandle(a[1])
  if w == .nil then return 1
  if msg~left(4) == "HIDE" then self~ctlOp(w[1], w[2], "hide")
  else self~ctlOp(w[1], w[2], "show")
  return 0
::method pbdlg_sendMessageToControl unguarded  -- sendMessageToControl(id, msg, wParam, lParam)
  use arg self_, msg, a
  d = self_~oodPeer
  id = self~resolveId(self_, a[1])
  if id < 1 then return -1
  return self~winMsg(d, id, a[2], a[3], a[4])
::method pbdlg_sendMessageToWindow unguarded   -- sendMessageToWindow(hwnd, msg, wParam, lParam)
  use arg self_, msg, a
  w = self~windowOfHandle(a[1])
  if w == .nil then return -1
  return self~winMsg(w[1], w[2], a[2], a[3], a[4])
::method pbdlg_putControl unguarded    -- (keeps a control object alive: the port keeps them all)
  return 0
::method dlgctrl_putInBag unguarded
  return 0
::method pbdlg_dumpMessageTable unguarded
  return 0
::method dlgctrl_setWindowTheme unguarded
  return 0
::method dlgctrl_textSize unguarded    -- textSize(text, size): the Size object takes the text's size in pixels, in the control's font
  use arg self_, msg, a
  p = self_~oodPeer
  parse value self~ctlOp(p~dlg, p~id, "textSize", a[1]) with w h .
  if w == "" then return .false
  a[2]~width = w
  a[2]~height = h
  return .true
::method dlgctrl_redrawRect unguarded  -- (the browser redraws by itself)
  return 0
::method dlgctrl_clearRect unguarded
  return 0

/* ReBar and ReBarBandInfo (oodReBar.cpp).  A band holds another control of the same dialog.
   A ReBarBandInfo's peer is a directory.  Bands are numbered from 1 in Rexx.  The page keeps
   id, text, style, child, width and colours of each band; the rest of what a ReBarBandInfo
   says (the other sizes, image index, item data, chevron) is kept here, by the band's id, and
   answered back, and changes nothing that is drawn. */
::method rbbi_init_cls unguarded
  return 0
::method rbbi_unInit unguarded
  return 0
::method rbbi_init unguarded       -- ReBarBandInfo~new(child, text, style, itemData, id, cx, mask)
  use arg self_, msg, a
  info = .directory~new
  if a~hasIndex(1) then info~child = a[1]
  if a~hasIndex(2) then info~text = a[2]
  if a~hasIndex(3) then info~style = a[3]~upper
  if a~hasIndex(4) then info~itemData = a[4]
  if a~hasIndex(5) then info~id = self~resolveId(.nil, a[5])
  if a~hasIndex(6) then info~cx = a[6]
  if a~hasIndex(7) then info~mask = a[7]~upper
  self_~oodPeer = info
  return 0
::method rbbi_child unguarded
  use arg self_
  return self_~oodPeer~child
::method rbbi_setChild unguarded
  use arg self_, msg, a
  self_~oodPeer~child = a[1]
::method rbbi_id unguarded
  use arg self_
  return self~lviGet(self_, "ID", 0)
::method rbbi_setId unguarded
  use arg self_, msg, a
  self_~oodPeer~id = self~resolveId(.nil, a[1])
::method rbbi_style unguarded
  use arg self_
  return self~lviGet(self_, "STYLE", "")
::method rbbi_setStyle unguarded
  use arg self_, msg, a
  self_~oodPeer~style = a[1]~upper
::method rbbi_mask unguarded       -- the mask given, or the one that follows from what is set
  use arg self_
  info = self_~oodPeer
  if info~hasIndex("MASK") then return info~mask
  names = "CHILD CHILD TEXT TEXT STYLE STYLE ITEMDATA LPARAM ID ID CX SIZE CLRBACK COLORS CLRFORE COLORS BITMAPBACK BACKGROUND IMAGEINDEX IMAGE CXMINCHILD CHILDSIZE CYMINCHILD CHILDSIZE CXIDEAL IDEALSIZE CXHEADER HEADERSIZE CHEVRONLOCATION CHEVRONLOCATION CHEVRONSTATE CHEVRONSTATE"
  mask = ""
  do i = 1 to names~words by 2
    if info~hasIndex(names~word(i)) then if mask~wordPos(names~word(i + 1)) == 0 then mask = mask names~word(i + 1)
  end
  return mask~strip
::method rbbi_setMask unguarded
  use arg self_, msg, a
  self_~oodPeer~mask = a[1]~upper
::method rbbi_bitmapBack unguarded
  use arg self_
  return self~lviGet(self_, "BITMAPBACK", .nil)
::method rbbi_setBitmapBack unguarded
  use arg self_, msg, a
  self_~oodPeer["BITMAPBACK"] = a[1]
::method rbbi_chevronLocation unguarded
  use arg self_
  return self~lviGet(self_, "CHEVRONLOCATION", .nil)
::method rbbi_setChevronLocation unguarded
  use arg self_, msg, a
  self_~oodPeer["CHEVRONLOCATION"] = a[1]
::method rbbi_chevronState unguarded
  use arg self_
  return self~lviGet(self_, "CHEVRONSTATE", "")
::method rbbi_setChevronState unguarded
  use arg self_, msg, a
  self_~oodPeer["CHEVRONSTATE"] = a[1]
::method rbbi_clrBack unguarded
  use arg self_
  return self~lviGet(self_, "CLRBACK", 4278190080)
::method rbbi_setClrBack unguarded
  use arg self_, msg, a
  self_~oodPeer["CLRBACK"] = a[1]
::method rbbi_clrFore unguarded
  use arg self_
  return self~lviGet(self_, "CLRFORE", 4278190080)
::method rbbi_setClrFore unguarded
  use arg self_, msg, a
  self_~oodPeer["CLRFORE"] = a[1]
::method rbbi_cx unguarded
  use arg self_
  return self~lviGet(self_, "CX", 0)
::method rbbi_setCx unguarded
  use arg self_, msg, a
  self_~oodPeer["CX"] = a[1]
::method rbbi_cxHeader unguarded
  use arg self_
  return self~lviGet(self_, "CXHEADER", 0)
::method rbbi_setCxHeader unguarded
  use arg self_, msg, a
  self_~oodPeer["CXHEADER"] = a[1]
::method rbbi_cxIdeal unguarded
  use arg self_
  return self~lviGet(self_, "CXIDEAL", 0)
::method rbbi_setCxIdeal unguarded
  use arg self_, msg, a
  self_~oodPeer["CXIDEAL"] = a[1]
::method rbbi_cxMinChild unguarded
  use arg self_
  return self~lviGet(self_, "CXMINCHILD", 0)
::method rbbi_setCxMinChild unguarded
  use arg self_, msg, a
  self_~oodPeer["CXMINCHILD"] = a[1]
::method rbbi_cyChild unguarded
  use arg self_
  return self~lviGet(self_, "CYCHILD", 0)
::method rbbi_setCyChild unguarded
  use arg self_, msg, a
  self_~oodPeer["CYCHILD"] = a[1]
::method rbbi_cyIntegral unguarded
  use arg self_
  return self~lviGet(self_, "CYINTEGRAL", 0)
::method rbbi_setCyIntegral unguarded
  use arg self_, msg, a
  self_~oodPeer["CYINTEGRAL"] = a[1]
::method rbbi_cyMaxChild unguarded
  use arg self_
  return self~lviGet(self_, "CYMAXCHILD", 0)
::method rbbi_setCyMaxChild unguarded
  use arg self_, msg, a
  self_~oodPeer["CYMAXCHILD"] = a[1]
::method rbbi_cyMinChild unguarded
  use arg self_
  return self~lviGet(self_, "CYMINCHILD", 0)
::method rbbi_setCyMinChild unguarded
  use arg self_, msg, a
  self_~oodPeer["CYMINCHILD"] = a[1]
::method rbbi_imageIndex unguarded
  use arg self_
  return self~lviGet(self_, "IMAGEINDEX", -1)
::method rbbi_setImageIndex unguarded
  use arg self_, msg, a
  self_~oodPeer["IMAGEINDEX"] = a[1]
::method rbbi_itemData unguarded
  use arg self_
  return self~lviGet(self_, "ITEMDATA", .nil)
::method rbbi_setItemData unguarded
  use arg self_, msg, a
  self_~oodPeer["ITEMDATA"] = a[1]
::method rbbi_text unguarded
  use arg self_
  return self~lviGet(self_, "TEXT", "")
::method rbbi_setText unguarded
  use arg self_, msg, a
  self_~oodPeer["TEXT"] = a[1]
::method rbJson unguarded          -- what a ReBarBandInfo says to the page, as JSON; only what the info has
  use arg info
  json = ""
  if info~hasIndex("ID") then json = json',"id":'info~id
  if info~hasIndex("TEXT") then json = json',"text":'self~ttJson(info~text)
  if info~hasIndex("STYLE") then json = json',"style":'self~ttJson(info~style)
  if info~hasIndex("CX") then json = json',"cx":'info~cx
  if info~hasIndex("CHILD") then do
    child = 0
    if info~child \== .nil then child = info~child~oodPeer~id
    json = json',"child":'child
  end
  if info~hasIndex("CLRBACK") then if info~clrBack \== 4278190080 then json = json',"bg":"'self~colorOf(info~clrBack)'"'
  if info~hasIndex("CLRFORE") then if info~clrFore \== 4278190080 then json = json',"fg":"'self~colorOf(info~clrFore)'"'
  return "{"json~substr(2)"}"
::method rbKeep unguarded          -- what the page does not keep of a band, by the band's id
  use arg self_, info
  if \info~hasIndex("ID") then return
  p = self_~oodPeer
  kept = p~dlg~store[p~id "rbband" info~id]
  if kept == .nil then kept = .directory~new
  do name over info~allIndexes
    kept[name] = info[name]
  end
  kept~remove("MASK")
  p~dlg~store[p~id "rbband" info~id] = kept
::method rbInfoArg unguarded
  use arg a
  if \a~hasIndex(1) then raise syntax 93.903 array(1)
  if \a[1]~isA(self~classOf("ReBarBandInfo")) then raise syntax 93.948 array(1, "ReBarBandInfo")
  return a[1]~oodPeer
::method rebar_insertBand unguarded    -- insertBand(bandInfo, index): omitted index: the band is the last
  use arg self_, msg, a
  info = self~rbInfoArg(a)
  at = -1
  if a~hasIndex(2) then at = a[2] - 1
  if \info~hasIndex("ID") then do      -- a band is known by its id: one without gets the next free one
    p = self_~oodPeer
    next = p~dlg~store[p~id "rbnext"]
    if next == .nil then next = 60000
    p~dlg~store[p~id "rbnext"] = next + 1
    info~id = next
  end
  self~rbKeep(self_, info)
  return self~op(self_, "rb.insert", at, self~rbJson(info)) == 1
::method rebar_setBandInfo unguarded   -- setBandInfo(bandInfo, index)
  use arg self_, msg, a
  info = self~rbInfoArg(a)
  described = self~op(self_, "rb.get", a[2] - 1)
  if described == "" then return .false
  if \info~hasIndex("ID") then do
    parse var described '"id":' id ','
    info~id = id
    self~rbKeep(self_, info)
    info~remove("ID")
  end
  else self~rbKeep(self_, info)
  return self~op(self_, "rb.set", a[2] - 1, self~rbJson(info)) == 1
::method rebar_getBandInfo unguarded   -- getBandInfo(index, mask): a ReBarBandInfo; .nil if there is no such band
  use arg self_, msg, a
  described = self~op(self_, "rb.get", a[1] - 1)
  if described == "" then return .nil
  p = self_~oodPeer
  parse var described '"id":' id ',"text":"' text '","style":"' style '","child":' child ',"cx":' cx ','
  band = self~classOf("ReBarBandInfo")~new
  info = band~oodPeer
  kept = p~dlg~store[p~id "rbband" id]
  if kept \== .nil then do name over kept~allIndexes
    info[name] = kept[name]
  end
  info~id = id
  info~text = text~changeStr('\"', '"')~changeStr("\\", "\")
  info~style = style
  info~cx = cx
  if child > 0 then info~child = self~controlObject(p~dlg, child)
  return band
::method rebar_deleteBand unguarded
  use arg self_, msg, a
  return self~op(self_, "rb.del", a[1] - 1) == 1
::method rebar_getBandCount unguarded
  use arg self_
  return self~op(self_, "rb.count")
::method rebar_idToIndex unguarded     -- 0 if no band has that id
  use arg self_, msg, a
  return self~op(self_, "rb.indexOf", a[1]) + 1
::method rebar_moveBand unguarded
  use arg self_, msg, a
  return self~op(self_, "rb.move", a[1] - 1, a[2] - 1) == 1
::method rebar_showBand unguarded      -- showBand(index, show): omitted: the band is hidden
  use arg self_, msg, a
  show = .false
  if a~hasIndex(2) then show = (a[2] == .true)
  return self~op(self_, "rb.show", a[1] - 1, show) == 1
::method rebar_setBandWidth unguarded
  use arg self_, msg, a
  return self~op(self_, "rb.set", a[1] - 1, '{"cx":'a[2]'}') == 1
::method rebar_maximizeBand unguarded  -- the band takes what is left of its row
  use arg self_, msg, a
  self~op(self_, "rb.set", a[1] - 1, '{"cx":0}')
  return 0
::method rebar_minimizeBand unguarded  -- (a band is as narrow as its control: nothing to do)
  return 0
::method rebar_getRect unguarded       -- the band's rectangle in the bar; .nil if there is no such band or it is hidden
  use arg self_, msg, a
  parse value self~op(self_, "rb.rect", a[1] - 1) with left top right bottom
  if left == "" then return .nil
  return self~classOf("Rect")~new(left, top, right, bottom)
::method rebar_getBarHeight unguarded
  use arg self_
  return self~op(self_, "rb.height")
::method rebar_getRowCount unguarded
  use arg self_
  return self~op(self_, "rb.rows")
::method rebar_getRowHeight unguarded  -- the height of the row the band is in
  use arg self_, msg, a
  parse value self~op(self_, "rb.rect", a[1] - 1) with . top . bottom
  if top == "" then return 0
  return bottom - top
::method rebar_hitTestInfo unguarded   -- hitTestInfo(point | x, y, directory): the band's index, 0 if none; the directory takes component
  use arg self_, msg, a
  if a[1]~isA(.String) then do
    x = a[1]
    y = a[2]
    info = a[3]
  end
  else do
    x = a[1]~x
    y = a[1]~y
    info = a[2]
  end
  parse value self~op(self_, "rb.hit", x, y) with index component
  if info \== .nil then do
    info~component = component~strip
    info~band = index + 1
  end
  return index + 1
::method rbColor unguarded
  use arg self_, which, a, set
  p = self_~oodPeer
  old = p~dlg~store[p~id which]
  if old == .nil then old = 4278190080      -- CLR_DEFAULT
  if set then do
    color = 4278190080
    if a~hasIndex(1) then color = a[1]
    p~dlg~store[p~id which] = color
    css = ""
    if color \== 4278190080 then css = self~colorOf(color)
    if which == "rbbk" then self~op(self_, "rb.colors", css, "")
    else self~op(self_, "rb.colors", "", css)
  end
  return old
::method rebar_getBkColor unguarded
  use arg self_, msg, a
  return self~rbColor(self_, "rbbk", a, .false)
::method rebar_setBkColor unguarded    -- answers the colour before
  use arg self_, msg, a
  return self~rbColor(self_, "rbbk", a, .true)
::method rebar_getTextColor unguarded
  use arg self_, msg, a
  return self~rbColor(self_, "rbtext", a, .false)
::method rebar_setTextColor unguarded
  use arg self_, msg, a
  return self~rbColor(self_, "rbtext", a, .true)
::method rebar_getBandBorders unguarded
  return self~classOf("Rect")~new(4, 2, 4, 2)
::method rebar_getBandMargins unguarded
  return self~classOf("Rect")~new(0, 0, 0, 0)
::method rbKept unguarded          -- get or set something that is only kept; answers what was there
  use arg self_, name, value, set
  p = self_~oodPeer
  old = p~dlg~store[p~id name]
  if set then p~dlg~store[p~id name] = value
  return old
::method rebar_getBarInfo unguarded    -- the bar's image list; .nil if none
  use arg self_
  return self~rbKept(self_, "rbimages", .nil, .false)
::method rebar_setBarInfo unguarded
  use arg self_, msg, a
  return self~rbKept(self_, "rbimages", a[1], .true)
::method rebar_getColorScheme unguarded
  use arg self_
  scheme = self~rbKept(self_, "rbscheme", .nil, .false)
  if scheme \== .nil then return scheme
  scheme = .directory~new
  scheme~clrBtnHighlight = 4278190080
  scheme~clrBtnShadow = 4278190080
  return scheme
::method rebar_setColorScheme unguarded    -- setColorScheme(directory) or setColorScheme(highlight, shadow)
  use arg self_, msg, a
  if a[1]~isA(.Directory) then scheme = a[1]
  else do
    scheme = .directory~new
    scheme~clrBtnHighlight = a[1]
    scheme~clrBtnShadow = 4278190080
    if a~hasIndex(2) then scheme~clrBtnShadow = a[2]
  end
  self~rbKept(self_, "rbscheme", scheme, .true)
  return 0
::method rebar_getExtendedStyle unguarded
  use arg self_
  style = self~rbKept(self_, "rbex", "", .false)
  if style == .nil then return ""
  return style
::method rebar_setExtendedStyle unguarded  -- setExtendedStyle(mask, style): answers the style before
  use arg self_, msg, a
  old = self~rebar_getExtendedStyle(self_)
  self~rbKept(self_, "rbex", self~opt(a, 2)~upper, .true)
  return old
::method rebar_getPalette unguarded
  return 0
::method rebar_setPalette unguarded
  return 0
::method rebar_setParent unguarded     -- (a control stays with its dialog) answers the dialog
  use arg self_
  return self_~oodPeer~dlg~rexxSelf
::method rebar_setWindowTheme unguarded
  return 0
::method rebar_pushChevron unguarded
  return 0
::method rebar_sizeToRect unguarded    -- (the bar is as wide as the dialog)
  return .true

/* ToolBar and TbButton (oodToolBar.cpp).  A TbButton's peer is a directory.  Buttons are
   numbered from 1 in Rexx.  The page keeps command ID, text, style and state of each button;
   item data and what was said about images are kept here, by command ID.  Images are not
   drawn: a button shows its text. */
::method tbb_init_cls unguarded
  return 0
::method tbb_init unguarded        -- TbButton~new(cmdID, text, style, state, itemData, bitmapID)
  use arg self_, msg, a
  info = .directory~new
  info~cmdID = 0
  if a~hasIndex(1) then info~cmdID = self~resolveId(.nil, a[1])
  info~text = ""
  if a~hasIndex(2) then info~text = a[2]
  info~style = self~opt(a, 3)~upper
  if info~style == "" then info~style = "BUTTON"
  info~state = self~opt(a, 4)~upper
  info~itemData = .nil
  if a~hasIndex(5) then info~itemData = a[5]
  info~bitmapID = -2                -- (I_IMAGENONE)
  if a~hasIndex(6) then info~bitmapID = a[6]
  self_~oodPeer = info
  return 0
::method tbb_cmdID unguarded
  use arg self_
  return self_~oodPeer~cmdID
::method tbb_setCmdID unguarded
  use arg self_, msg, a
  self_~oodPeer~cmdID = self~resolveId(.nil, a[1])
::method tbb_text unguarded
  use arg self_
  return self_~oodPeer~text
::method tbb_setText unguarded
  use arg self_, msg, a
  self_~oodPeer~text = a[1]
::method tbb_style unguarded
  use arg self_
  return self_~oodPeer~style
::method tbb_setStyle unguarded
  use arg self_, msg, a
  self_~oodPeer~style = a[1]~upper
::method tbb_state unguarded
  use arg self_
  return self_~oodPeer~state
::method tbb_setState unguarded
  use arg self_, msg, a
  self_~oodPeer~state = a[1]~upper
::method tbb_itemData unguarded
  use arg self_
  return self_~oodPeer~itemData
::method tbb_setItemData unguarded
  use arg self_, msg, a
  self_~oodPeer~itemData = a[1]
::method tbb_bitmapID unguarded
  use arg self_
  return self_~oodPeer~bitmapID
::method tbb_setBitmapID unguarded
  use arg self_, msg, a
  self_~oodPeer~bitmapID = a[1]
::method tbb_assignBitmapID unguarded  -- assignBitmapID(bitmapID, imageListID, offset): offset is added
  use arg self_, msg, a
  id = a[1]
  if a~hasIndex(3) then id = id + a[3]
  self_~oodPeer~bitmapID = id
  return 0
::method tbPut unguarded           -- one TbButton into the tool bar at a 0-based index (-1: the end)
  use arg self_, button, at
  if \button~isA(self~classOf("TbButton")) then raise syntax 93.948 array(1, "TbButton")
  info = button~oodPeer
  p = self_~oodPeer
  text = info~text
  if text~datatype("W") then do       -- a number is an index into the strings given with addString
    pool = p~dlg~store[p~id "tbstrings"]
    if pool \== .nil then if text >= 1 & text <= pool~items then text = pool[text]
  end
  if text == .nil then text = ""
  self~op(self_, "tb.insert", at, info~cmdID || self~sep || text || self~sep || info~style || self~sep || info~state || self~sep || info~bitmapID)
  if info~itemData \== .nil then self~setItemDataOf(p~dlg, p~id, "tb" info~cmdID, info~itemData)
  return .true
::method tb_addButtons unguarded   -- addButtons(array of TbButton): at the end
  use arg self_, msg, a
  if \a[1]~isA(.Array) then raise syntax 93.948 array(1, "Array")
  do i = 1 to a[1]~size
    if \a[1]~hasIndex(i) then raise syntax 93.900 array("The buttons array can not be sparse; index" i "is missing")
    self~tbPut(self_, a[1][i], -1)
  end
  return .true
::method tb_insertButton unguarded -- insertButton(tbButton, index): the button goes before the button at that index
  use arg self_, msg, a
  if a[2] < 1 then raise syntax 93.907 array(2, 1, 4294967295, a[2])
  return self~tbPut(self_, a[1], a[2] - 1)
::method tb_buttonCount unguarded
  use arg self_
  return self~op(self_, "tb.count")
::method tb_commandToIndex unguarded   -- 0 if there is no such command ID
  use arg self_, msg, a
  return self~op(self_, "tb.indexOf", self~resolveId(self_~oodPeer~dlg~rexxSelf, a[1])) + 1
::method tb_indexTocommand unguarded
  use arg self_, msg, a
  parse value self~op(self_, "tb.get", a[1] - 1) with cmd (self~sep) .
  if cmd == "" then return 0
  return cmd
::method tbButtonOf unguarded      -- a TbButton from what the page answers
  use arg self_, described
  if described == "" then return .nil
  parse var described cmd (self~sep) text (self~sep) style (self~sep) state (self~sep) image
  p = self_~oodPeer
  return self~classOf("TbButton")~new(cmd, text, style, state, self~itemData(p~dlg, p~id, "tb" cmd), image)
::method tb_getButton unguarded    -- getButton(index): a TbButton; .nil if there is no such button
  use arg self_, msg, a
  return self~tbButtonOf(self_, self~op(self_, "tb.get", a[1] - 1))
::method tb_getButtonText unguarded    -- by command ID; .nil if there is no such button
  use arg self_, msg, a
  described = self~op(self_, "tb.byCmd", self~resolveId(self_~oodPeer~dlg~rexxSelf, a[1]))
  if described == "" then return .nil
  parse var described . (self~sep) text (self~sep) .
  return text
::method tb_getButtonTextEx unguarded
  forward message "tb_getButtonText"
::method tb_setButtonText unguarded    -- setButtonText(text, cmdID)
  use arg self_, msg, a
  return self~op(self_, "tb.setText", self~resolveId(self_~oodPeer~dlg~rexxSelf, a[2]), a[1]) == 1
::method tbState unguarded
  use arg self_, a, word, on
  return self~op(self_, "tb.setState", self~resolveId(self_~oodPeer~dlg~rexxSelf, a[1]), word, on) == 1
::method tb_checkButton unguarded  -- checkButton(cmdID, check)
  use arg self_, msg, a
  on = .true
  if a~hasIndex(2) then on = (a[2] == .true)
  return self~tbState(self_, a, "CHECKED", on)
::method tb_enableButton unguarded
  use arg self_, msg, a
  on = .true
  if a~hasIndex(2) then on = (a[2] == .true)
  return self~tbState(self_, a, "ENABLED", on)
::method tbHas unguarded
  use arg self_, a, word
  return self~op(self_, "tb.has", self~resolveId(self_~oodPeer~dlg~rexxSelf, a[1]), word) == 1
::method tb_isButtonChecked unguarded
  use arg self_, msg, a
  return self~tbHas(self_, a, "CHECKED")
::method tb_isButtonEnabled unguarded
  use arg self_, msg, a
  return self~tbHas(self_, a, "ENABLED")
::method tb_isButtonHidden unguarded
  use arg self_, msg, a
  return self~tbHas(self_, a, "HIDDEN")
::method tb_isButtonHighlighted unguarded
  use arg self_, msg, a
  return self~tbHas(self_, a, "MARKED")
::method tb_isButtonIndeterminate unguarded
  use arg self_, msg, a
  return self~tbHas(self_, a, "INDETERMINATE")
::method tb_isButtonPressed unguarded
  use arg self_, msg, a
  return self~tbHas(self_, a, "PRESSED")
::method tb_autoSize unguarded     -- (the bar sizes itself to its buttons)
  return 0
::method tb_addString unguarded    -- addString(array of strings): the index (from 1) of the first one added; 0 on failure
  use arg self_, msg, a
  p = self_~oodPeer
  if \a[1]~isA(.Array) then return 0     -- (a ResourceImage's string table: no binary resources here)
  pool = p~dlg~store[p~id "tbstrings"]
  if pool == .nil then do
    pool = .array~new
    p~dlg~store[p~id "tbstrings"] = pool
  end
  first = pool~items + 1
  do text over a[1]
    pool~append(text)
  end
  return first
::method tb_changeBitmap unguarded -- changeBitmap(cmdID, bitmapID, imageListID, offset)
  use arg self_, msg, a
  id = a[2]
  if a~hasIndex(4) then id = id + a[4]
  return self~op(self_, "tb.setImage", self~resolveId(self_~oodPeer~dlg~rexxSelf, a[1]), id) == 1
::method tbImages unguarded        -- what the program said about the tool bar's images
  use arg self_
  p = self_~oodPeer
  images = p~dlg~store[p~id "tbimages"]
  if images == .nil then do
    images = .directory~new
    images~count = 0
    images~size = .nil
    p~dlg~store[p~id "tbimages"] = images
  end
  return images
::method tb_addBitmap unguarded    -- addBitmap(source, count, id): the index of the first new image
  use arg self_, msg, a
  images = self~tbImages(self_)
  first = images~count
  count = 1
  if a~hasIndex(2) then count = a[2]
  images~count = first + count
  return first
::method tb_loadImages unguarded   -- (the system's button images: STDSMALL has 15, VIEWSMALL 12, HISTSMALL 5)
  use arg self_, msg, a
  images = self~tbImages(self_)
  first = images~count
  word = a[1]~upper
  count = 15
  if word~left(4) == "VIEW" then count = 12
  if word~left(4) == "HIST" then count = 5
  images~count = first + count
  return first
::method tb_setBitmapSize unguarded
  use arg self_, msg, a
  images = self~tbImages(self_)
  if images~count > 0 then return .false     -- (only before any bitmap is added)
  if a[1]~isA(.String) then images~size = self~classOf("Size")~new(a[1], a[2])
  else images~size = a[1]
  return .true
::method tbList unguarded          -- get or set one of the tool bar's image lists; answers the list before
  use arg self_, which, a, set
  images = self~tbImages(self_)
  old = images[which]
  if set then images[which] = a[1]
  return old
::method tb_getImageList unguarded
  use arg self_, msg, a
  return self~tbList(self_, "NORMAL", a, .false)
::method tb_setImageList unguarded
  use arg self_, msg, a
  return self~tbList(self_, "NORMAL", a, .true)
::method tb_getDisabledImageList unguarded
  use arg self_, msg, a
  return self~tbList(self_, "DISABLED", a, .false)
::method tb_setDisabledImageList unguarded
  use arg self_, msg, a
  return self~tbList(self_, "DISABLED", a, .true)
::method tb_getHotImageList unguarded
  use arg self_, msg, a
  return self~tbList(self_, "HOT", a, .false)
::method tb_setHotImageList unguarded
  use arg self_, msg, a
  return self~tbList(self_, "HOT", a, .true)
::method tb_getPressedImageList unguarded
  use arg self_, msg, a
  return self~tbList(self_, "PRESSED", a, .false)
::method tb_setPressedImageList unguarded
  use arg self_, msg, a
  return self~tbList(self_, "PRESSED", a, .true)
::method tb_getExtendedStyle unguarded
  use arg self_
  style = self~tbImages(self_)~exStyle
  if style == .nil then return ""
  return style
::method tb_setExtendedStyle unguarded -- answers the style before
  use arg self_, msg, a
  old = self~tb_getExtendedStyle(self_)
  self~tbImages(self_)~exStyle = a[1]~upper
  return old
::method tb_customize unguarded    -- (Windows' Customize Toolbar dialog: there is none)
  return 0

/* StatusBar (oodStatusBar.cpp).  Parts are numbered from 1 in Rexx. */
::method stb_setParts unguarded    -- setParts(array of right edges in pixels; -1: to the end)
  use arg self_, msg, a
  if \a[1]~isA(.Array) then raise syntax 93.948 array(1, "Array")
  edges = ""
  do i = 1 to a[1]~size
    if \a[1]~hasIndex(i) then raise syntax 93.900 array("The edges array can not be sparse; index" i "is missing")
    if \a[1][i]~datatype("W") then raise syntax 93.900 array("The edges array must hold whole numbers; found" a[1][i])
    edges = edges a[1][i]
  end
  return self~op(self_, "sb.setParts", edges~strip) == 1
::method stb_getParts unguarded    -- getParts(array): the number of parts; the array takes their right edges
  use arg self_, msg, a
  edges = self~op(self_, "sb.parts")~makeArray(" ")
  if a~hasIndex(1) then do i = 1 to edges~items
    a[1][i] = edges[i]
  end
  return edges~items
::method stb_setText unguarded     -- setText(text, index, type)
  use arg self_, msg, a
  return self~op(self_, "sb.setText", a[2] - 1, a[1]) == 1
::method stb_getText unguarded     -- getText(index, directory): the directory, if given, takes the draw type
  use arg self_, msg, a
  if self~op(self_, "sb.has", a[1] - 1) \== 1 then return ""
  if a~hasIndex(2) then a[2]~drawType = "LOWERBORDERS"
  return self~op(self_, "sb.text", a[1] - 1)
::method stb_getTextLength unguarded
  use arg self_, msg, a
  if self~op(self_, "sb.has", a[1] - 1) \== 1 then return 0
  if a~hasIndex(2) then a[2]~drawType = "LOWERBORDERS"
  return self~op(self_, "sb.text", a[1] - 1)~length
::method stb_setTipText unguarded  -- setTipText(text, index)
  use arg self_, msg, a
  return self~op(self_, "sb.setTip", a[2] - 1, a[1]) == 1
::method stb_getTipText unguarded
  use arg self_, msg, a
  return self~op(self_, "sb.tip", a[1] - 1)
::method stb_simple unguarded      -- simple(.true | .false): one text instead of the parts
  use arg self_, msg, a
  on = .true
  if a~hasIndex(1) then on = (a[1] == .true)
  self~op(self_, "sb.simple", on)
  return 0
::method stb_isSimple unguarded
  use arg self_
  return self~op(self_, "sb.isSimple") == 1
::method stb_getRect unguarded     -- the part's rectangle in the bar; .nil if there is no such part
  use arg self_, msg, a
  parse value self~op(self_, "sb.rect", a[1] - 1) with left top right bottom
  if left == "" then return .nil
  return self~classOf("Rect")~new(left, top, right, bottom)
::method stb_getBorders unguarded  -- horizontal border, vertical border, gap between parts
  return .array~of(0, 1, 1)
::method stb_setMinHeight unguarded
  use arg self_, msg, a
  self~op(self_, "sb.minHeight", a[1])
  return 0
::method stb_setBkColor unguarded  -- answers the colour before (CLR_DEFAULT the first time)
  use arg self_, msg, a
  p = self_~oodPeer
  old = p~dlg~store[p~id "bk"]
  if old == .nil then old = 4278190080
  p~dlg~store[p~id "bk"] = a[1]
  if a[1] == 4278190080 then self~op(self_, "sb.bk", "")
  else self~op(self_, "sb.bk", self~colorOf(a[1]))
  return old
::method stb_setIcon unguarded     -- (icons in a status bar are not drawn; the icon is kept and answered)
  use arg self_, msg, a
  p = self_~oodPeer
  p~dlg~store[p~id "icon" a[2]] = a[1]
  return .true
::method stb_getIcon unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  return p~dlg~store[p~id "icon" a[1]]

/* The old names of DynamicDialog's create methods (oodUser.cpp): the same arguments in the
   old order.  Each row: the new method, then for each old argument its new position. */
::method dyndlgOldName unguarded
  use arg self_, a, method, positions
  args = .array~new
  do i = 1 to positions~words
    if a~hasIndex(i) then args[positions~word(i)] = a[i]
  end
  return self_~sendWith(method, args)
::method dyndlg_addButton unguarded          -- addButton(id, x, y, cx, cy, text, msgToRaise, opts, loadOptions)
  use arg self_, msg, a
  return self~dyndlgOldName(self_, a, "createPushButton", "1 2 3 4 5 7 8 6 9")
::method dyndlg_addRadioButton unguarded     -- addRadioButton / addCheckBox(id, attributeName, x, y, cx, cy, text, opts, loadOptions)
  use arg self_, msg, a
  method = "createCheckBox"
  if msg == "ADDRADIOBUTTON" then method = "createRadioButton"
  return self~dyndlgOldName(self_, a, method, "1 8 2 3 4 5 7 6 9")
::method dyndlg_addGroupBox unguarded        -- addGroupBox(x, y, cx, cy, text, opts, id)
  use arg self_, msg, a
  return self~dyndlgOldName(self_, a, "createGroupBox", "2 3 4 5 7 6 1")
::method dyndlg_addEntryLine unguarded       -- addEntryLine / addPasswordLine(id, attributeName, x, y, cx, cy, opts)
  use arg self_, msg, a
  method = "createEdit"
  if msg == "ADDPASSWORDLINE" then method = "createPasswordEdit"
  return self~dyndlgOldName(self_, a, method, "1 7 2 3 4 5 6")
::method dyndlg_addMethod unguarded          -- addListBox, addComboBox, addTreeControl, addListControl, addSliderControl, addTabControl
  use arg self_, msg, a
  names = "ADDLISTBOX createListBox ADDCOMBOBOX createComboBox ADDTREECONTROL createTreeView ADDLISTCONTROL createListView ADDSLIDERCONTROL createTrackBar ADDTABCONTROL createTab"
  at = names~wordPos(msg)
  if at == 0 then raise syntax 93.900 array('the method "'msg'" has no create method')
  return self~dyndlgOldName(self_, a, names~word(at + 1), "1 7 2 3 4 5 6")
::method dyndlg_init_cls unguarded
  return 0

/* The dialog's background, tab stops; the list-view's colours, styles and columns. */
::method sysColorOf unguarded      -- a COLOR_ index of Windows as a CSS colour
  use arg index
  colors = "#c8c8c8 #000000 #99b4d1 #bfcddb #f0f0f0 #ffffff #646464 #000000 #000000 #000000 #b4b4b4 #f4f7fc #ababab #0078d7 #ffffff #f0f0f0 #a0a0a0 #6d6d6d #000000 #000000 #ffffff #696969 #e3e3e3 #000000 #ffffe1 #f0f0f0 #0066cc #b9d1ea #d7e4f2 #0078d7 #f0f0f0"
  if \index~datatype("W") then return ""
  if index < 0 | index >= colors~words then return ""
  return colors~word(index + 1)
::method pbdlg_backgroundColor unguarded   -- backgroundColor(colour, isColorRef) / backgroundSysColor(index)
  use arg self_, msg, a
  if msg == "BACKGROUNDSYSCOLOR" then css = self~sysColorOf(a[1])
  else css = self~colorOf(a[1])
  if css == "" then return .false
  self~ctlOpWhenLive(self_~oodPeer, 0, "color", css, "")
  return .true
::method pbdlg_tiledBackgroundBitmap unguarded
  use arg self_, msg, a
  key = self~imageKey(a[1])
  if key == "" then return 1
  self~ctlOpWhenLive(self_~oodPeer, 0, "backdrop", key, "TILE")
  return 0
::method pbdlg_setTabGroup unguarded   -- setTabStop(id, add) / setGroup(id, add): groups are not kept
  use arg self_, msg, a
  id = self~resolveId(self_, a[1])
  if id < 1 then return -1
  add = .true
  if a~hasIndex(2) then add = (a[2] == .true)
  if msg == "SETTABSTOP" then self~ctlOp(self_~oodPeer, id, "tabStop", add)
  return 0
::method lv_setColor unguarded     -- bkColor=, textColor=, textBkColor=
  use arg self_, msg, a
  p = self_~oodPeer
  p~dlg~store[p~id msg~strip("T", "=")] = a[1]
  background = p~dlg~store[p~id "BKCOLOR"]
  if background == .nil then background = p~dlg~store[p~id "TEXTBKCOLOR"]
  foreground = p~dlg~store[p~id "TEXTCOLOR"]
  css = ""
  if background \== .nil then css = self~colorOf(background)
  fg = ""
  if foreground \== .nil then fg = self~colorOf(foreground)
  self~op(self_, "color", css, fg)
  return 0
::method lv_getColor unguarded     -- bkColor, textColor, textBkColor: -1 if none was set
  use arg self_, msg
  p = self_~oodPeer
  color = p~dlg~store[p~id msg]
  if color == .nil then return -1
  return color
::method lv_stringWidthPx unguarded
  use arg self_, msg, a
  parse value self~op(self_, "textSize", a[1]) with w .
  if \w~datatype("N") then return 0
  return w
::method lv_getColumnOrder unguarded   -- the columns from left to right: they are never moved
  use arg self_
  order = .array~new
  do c = 0 to self~op(self_, "lv.colCount") - 1
    order~append(c)
  end
  return order
::method lv_setColumnOrder unguarded   -- (columns cannot be moved: true only for the order they have)
  use arg self_, msg, a
  count = self~op(self_, "lv.colCount")
  if a[1]~items \== count then return .false
  do c = 1 to count
    if a[1][c] \== c - 1 then return .false
  end
  return .true
::method lv_addRemoveStyle unguarded   -- addStyle / removeStyle: a view keyword changes the view
  use arg self_, msg, a
  if msg == "ADDSTYLE" then self~lvViewStyle(self_, a[1])
  return 0
::method lv_replaceStyle unguarded     -- replaceStyle(remove, add)
  use arg self_, msg, a
  self~lvViewStyle(self_, a[2])
  return 0
::method lvViewStyle unguarded
  use arg self_, style
  do word over style~upper~makeArray(" ")
    if "ICON SMALLICON LIST REPORT"~wordPos(word) > 0 then self~op(self_, "lv.view", word)
  end

/* Item data of a combo box and a tree-view; lines of an edit; margins of a button. */
::method cb_setItemData unguarded  -- setItemData(index, data): index from 1; answers the data that was there
  use arg self_, msg, a
  p = self_~oodPeer
  uid = self~op(self_, "optUid", a[1] - 1)
  if uid == 0 then return .nil
  old = self~itemData(p~dlg, p~id, uid)
  data = .nil
  if a~hasIndex(2) then data = a[2]
  self~setItemDataOf(p~dlg, p~id, uid, data)
  return old
::method cb_getItemData unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  uid = self~op(self_, "optUid", a[1] - 1)
  if uid == 0 then return .nil
  return self~itemData(p~dlg, p~id, uid)
::method cb_removeItemData unguarded
  use arg self_, msg, a
  return self~cb_setItemData(self_, msg, .array~of(a[1]))
::method cb_getCue unguarded
  use arg self_
  return self~op(self_, "getCue")
::method e_getCue unguarded
  use arg self_
  return self~op(self_, "getCue")
/* sortChildrenCB(parent, method, param): the direct children of the item are put in the order
   a method of the dialog gives.  The method gets the item data of two children and param,
   and answers a negative number, 0 or a positive number. */
::method tv_sortChildrenCB unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  parent = self~tvItem(a, 1)
  dlg = p~dlg~rexxSelf
  if \dlg~hasMethod(a[2]) then raise syntax 93.900 array('sortChildrenCB: the dialog has no method "'a[2]'"')
  param = .nil
  if a~hasIndex(3) then param = a[3]
  keys = .array~new
  do h over self~op(self_, "tv.kids", parent)~makeArray(" ")
    keys~append(.array~of(self~itemData(p~dlg, p~id, h), h))
  end
  if keys~items < 2 then return .true
  order = ""
  do pair over keys~stableSortWith(.OodCallOrder~new(dlg, a[2], param))
    order = order pair[2]
  end
  return self~op(self_, "tv.order", parent, order~strip) == 1
::method tv_removeItemData unguarded   -- answers the data that was there
  use arg self_, msg, a
  p = self_~oodPeer
  item = self~tvItem(a, 1)
  old = self~itemData(p~dlg, p~id, item)
  self~setItemDataOf(p~dlg, p~id, item, .nil)
  return old
::method tv_getItemHeight unguarded
  use arg self_
  return self~op(self_, "rowHeight")
::method e_lineFromIndex unguarded -- the line (from 1) that holds a character index (from 1); omitted: the caret's line
  use arg self_, msg, a
  at = -1
  if a~hasIndex(1) then at = a[1] - 1
  return self~op(self_, "lineOf", at) + 1
::method e_lineIndex unguarded     -- the character index (from 1) of the start of a line (from 1); 0 if there is no such line
  use arg self_, msg, a
  line = -1
  if a~hasIndex(1) then line = a[1] - 1
  return self~op(self_, "lineStart", line) + 1
::method e_lineLength unguarded
  use arg self_, msg, a
  line = -1
  if a~hasIndex(1) then line = a[1] - 1
  return self~op(self_, "lineLen", line)
::method e_setTabStops unguarded   -- one tab stop, in dialog units, repeats: about four dialog units to a character
  use arg self_, msg, a
  if a[1]~items < 1 then return .false
  self~op(self_, "tabSize", max(1, a[1][1] % 4))
  return .true
::method e_getRect unguarded       -- the formatting rectangle: the client area less the padding
  use arg self_
  parse value self~op(self_, "pad", "") with left top right bottom
  size = self_~getRealSize
  return self~classOf("Rect")~new(left, top, size~width - right, size~height - bottom)
::method e_setRect unguarded
  use arg self_, msg, a
  size = self_~getRealSize
  r = a[1]
  self~op(self_, "pad", max(0, r~top) max(0, size~width - r~right) max(0, size~height - r~bottom) max(0, r~left))
  return 0
::method e_showBallon unguarded    -- (a balloon tip of an edit is not shown)
  return .false
::method e_hideBallon unguarded
  return .false
::method bc_getTextMargin unguarded
  use arg self_
  parse value self~op(self_, "pad", "") with left top right bottom
  return self~classOf("Rect")~new(left, top, right, bottom)
::method bc_setTextMargin unguarded
  use arg self_, msg, a
  r = a[1]
  self~op(self_, "pad", r~top r~right r~bottom r~left)
  return .true

/*---- PlainBaseDialog ---------------------------------------------------------*/
/* The fifth argument of a dialog's init (checkDlgType of ooDialog.cpp).  For a ControlDialog
   it is the owner dialog.  A ControlDlgInfo or TabOwnerDlgInfo is not ported: it is kept. */
::method dialogOwnerData
  use arg dlg, ownerData
  if ownerData == .nil then return
  if dlg~isA(self~classOf("ControlDialog")) then do
    if ownerData~isA(self~classOf("PlainBaseDialog")) then dlg~oodPeer~ownerDialog = ownerData
    else if ownerData~isA(self~classOf("ControlDlgInfo")) then dlg~oodPeer~store["ownerData"] = ownerData
    else raise syntax 93.900 array("argument 5 must be a PlainBaseDialog or a ControlDialogInfo object; found" ownerData)
  end
  else dlg~oodPeer~store["ownerData"] = ownerData
::method dialogInit                -- from PlainBaseDialog~init (patches.txt)
  expose defFontName defFontSize
  use arg dlg, library, resource
  d = .OodDlg~new(self~newKey, dlg, library, resource)
  d~fontName = defFontName
  d~fontSize = defFontSize
  dlg~oodPeer = d
  return d

::method pbdlg_setDefaultFont_cls
  expose defFontName defFontSize
  use arg self_, msg, a
  defFontName = a[1]
  if a~hasIndex(2) then defFontSize = a[2]
  return 0
::method pbdlg_getFontName_cls unguarded
  expose defFontName
  return defFontName
::method pbdlg_getFontSize_cls unguarded
  expose defFontSize
  return defFontSize

::method pbdlg_getAutoDetect unguarded
  use arg self_
  return self_~oodPeer~autoDetect
::method pbdlg_setAutoDetect unguarded
  use arg self_, msg, a
  self_~oodPeer~autoDetect = (a[1] == .true)
  return
::method pbdlg_getDlgHandle unguarded
  use arg self_
  d = self_~oodPeer
  if \d~live then return 0
  return d~hwnd
::method pbdlg_getDlgID unguarded
  use arg self_
  return self_~oodPeer~dlgID
::method pbdlg_setDlgID unguarded
  use arg self_, msg, a
  self_~oodPeer~dlgID = a[1]
  return
::method pbdlg_getFontNameSize unguarded
  use arg self_, msg
  if msg == "FONTNAME" then return self_~oodPeer~fontName
  return self_~oodPeer~fontSize
::method pbdlg_setFontName_pvt unguarded
  use arg self_, msg, a
  self_~oodPeer~fontName = a[1]
  return
::method pbdlg_setFontSize_pvt unguarded
  use arg self_, msg, a
  self_~oodPeer~fontSize = a[1]
  return
::method pbdlg_setDlgFont unguarded
  use arg self_, msg, a
  self_~oodPeer~fontName = a[1]
  if a~hasIndex(2) then self_~oodPeer~fontSize = a[2]
  return
::method pbdlg_getLibrary unguarded
  use arg self_
  return self_~oodPeer~library
::method pbdlg_getResourceID unguarded
  use arg self_
  return self_~oodPeer~resourceID
::method pbdlg_getParentDlg_pvt unguarded
  use arg self_
  return self_~oodPeer~parentDlg
::method pbdlg_setParentDlg_pvt unguarded
  use arg self_, msg, a
  self_~oodPeer~parentDlg = a[1]
  return
::method pbdlg_getOwnerDialog unguarded
  use arg self_
  return self_~oodPeer~ownerDialog
::method pbdlg_setOwnerDialog unguarded
  use arg self_, msg, a
  self_~oodPeer~ownerDialog = a[1]
  return
::method pbdlg_isDialogActive unguarded
  use arg self_
  return self_~oodPeer~live
::method pbdlg_get unguarded
  use arg self_
  return self_~dlgHandle
::method pbdlg_unInit unguarded
  return

::method pbdlg_show unguarded      -- show(options), restore()
  use arg self_, msg, a
  d = self_~oodPeer
  if \d~live then return .false
  options = "NORMAL"
  if a~hasIndex(1) then options = a[1]
  self~web~show(d~key, options~upper)
  if options~upper~pos("HIDE") == 0 then self~gdiPaintAll(d)      -- Windows paints the owner-drawn controls now
  return .true
::method pbdlg_toTheTop unguarded
  use arg self_
  self~op(self_, "top")
  return 0
::method pbdlg_doMinMax unguarded
  use arg self_, msg
  if msg == "ISMAXIMIZED" | msg == "ISMINIMIZED" then return .false
  return 0
::method pbdlg_center unguarded
  return 0

::method pbdlg_stopIt unguarded              -- leaving(), the page's dialog goes away, finalStopIt()
  use arg self_, msg, a
  d = self_~oodPeer
  code = -1
  if d~live then do
    if self_~finished then self_~leaving
    self~finishChildren(d)
    self~web~destroy(d~key)
    d~live = .false
    self~deregister(d)
    self~finishOwned(self_)
    code = 0
  end
  if a~hasIndex(1) then self_~finalStopIt(a[1])
  else self_~finalStopIt
  return code

::method pbdlg_getControlText unguarded
  use arg self_, msg, a
  return self~ctlOp(self_~oodPeer, self~resolveId(self_, a[1]), "getText")
::method pbdlg_setControlText unguarded
  use arg self_, msg, a
  if self~ctlOp(self_~oodPeer, self~resolveId(self_, a[1]), "setText", a[2]) == 1 then return 0
  return 1
::method pbdlg_getControlHandle unguarded
  use arg self_, msg, a
  d = self_~oodPeer
  id = self~resolveId(self_, a[1])
  if self~ctlOp(d, id, "exists") \== 1 then return 0
  return "0x"d2x(d~key * 65536 + id)~right(16, "0")
::method pbdlg_getControlID unguarded
  use arg self_, msg, a
  return self~number(a[1]) // 65536
::method pbdlg_enableDisableControl unguarded
  use arg self_, msg, a
  self~ctlOp(self_~oodPeer, self~resolveId(self_, a[1]), "enable", (msg == "ENABLECONTROL"))
  return 0
::method pbdlg_showControl unguarded
  use arg self_, msg, a
  opName = "show"
  if msg~left(4) == "HIDE" then opName = "hide"
  self~ctlOp(self_~oodPeer, self~resolveId(self_, a[1]), opName)
  return 0
::method pbdlg_focusControl unguarded
  use arg self_, msg, a
  self~ctlOp(self_~oodPeer, self~resolveId(self_, a[1]), "focus")
  return 0
::method pbdlg_setFocus unguarded
  use arg self_, msg, a
  d = self_~oodPeer
  previous = self~pbdlg_getFocus(self_)
  self~ctlOp(d, self~number(a[1]) // 65536, "focus")
  return previous
::method pbdlg_getFocus unguarded
  use arg self_
  d = self_~oodPeer
  id = self~ctlOp(d, 0, "focusId")
  if id == "" | id == 0 then return 0
  return "0x"d2x(d~key * 65536 + id)~right(16, "0")
::method pbdlg_tabTo unguarded
  use arg self_, msg
  self~ctlOp(self_~oodPeer, 0, "tab", (msg == "TABTONEXT"))
  return 0

/* A control object: newEdit(id), newPushButton(id) ... */
::method pbdlg_newControl unguarded
  use arg self_, msg, a
  d = self_~oodPeer
  if \d~live then return .nil
  id = self~resolveId(self_, a[1])
  if id < 1 then return .nil
  if self~ctlOp(d, id, "exists") \== 1 then return .nil
  name = msg~substr(4)
  if name == "PUSHBUTTON" then name = "BUTTON"
  if name == "CONTROL" then return .nil
  cacheKey = id name
  cached = d~controls[cacheKey]
  if cached \== .nil then return cached
  cls = self~classOf(name)
  if cls == .nil then return .nil
  ctl = cls~new(self_, id, .OodCtl~new(d, id, d~kinds[id]))
  d~controls[cacheKey] = ctl
  return ctl
::method pbdlg_getNewControl unguarded  -- newControl(id): the object of whatever control has that ID
  use arg self_, msg, a
  d = self_~oodPeer
  if \d~live then return .nil
  id = self~resolveId(self_, a[1])
  if id < 1 then return .nil
  kind = d~kinds[id]
  if kind == .nil then return .nil
  kinds = "BUTTON CHECK RADIO GROUP STATIC FRAME IMAGE EDIT LIST COMBO PROGRESS LISTVIEW TREEVIEW TAB UPDOWN TRACKBAR DATETIMEPICKER MONTHCALENDAR"
  names = "PUSHBUTTON CHECKBOX RADIOBUTTON GROUPBOX STATIC STATIC STATIC EDIT LISTBOX COMBOBOX PROGRESSBAR LISTVIEW TREEVIEW TAB UPDOWN TRACKBAR DATETIMEPICKER MONTHCALENDAR"
  at = kinds~wordPos(kind~word(1)~upper)
  if at == 0 then return .nil
  return self~pbdlg_newControl(self_, "NEW"names~word(at), a)
::method pbdlg_newControlEx unguarded   -- newUpDown, newReBar, newStatusBar, newToolBar ...
  forward message "pbdlg_newControl"
::method dlgctrl_unInit unguarded
  return

/*---- dialog data: controls <-> data attributes --------------------------------*/
::method pbdlg_connect_ControName unguarded
  use arg self_, msg, a
  kind = self~dataKind(msg~substr(8))
  if kind == "" then return -1
  if a~hasIndex(2) then id = self_~addAttribute(a[1], a[2])
  else id = self_~addAttribute(a[1])
  if id == -1 then return -1
  self_~oodPeer~dataTable~append(.array~of(id, kind))
  return 0

::method dataKind unguarded        -- the kind of control of a connectXxx / getXxxData name
  use arg name
  select
    when name~abbrev("EDIT") then return "EDIT"
    when name~abbrev("CHECKBOX") then return "CHECK"
    when name~abbrev("RADIOBUTTON") then return "RADIO"
    when name~abbrev("LISTBOX") then return "LIST"
    when name~abbrev("COMBOBOX") then return "COMBO"
    otherwise return ""
  end

::method connectCreated unguarded  -- connectCreatedControl() of oodUser.cpp
  use arg dlg, rxID, id, attributeName, kind
  if attributeName == "" then attributeName = "DATA"id
  dlg~addAttribute(rxID, attributeName)
  dlg~oodPeer~dataTable~append(.array~of(id, kind))
  return 0

::method getData unguarded         -- the data of one control
  use arg d, id, kind
  select
    when kind == "CHECK" | kind == "RADIO" then return self~winMsg(d, id, 240)
    when kind == "UPDOWN" then return self~winMsg(d, id, 1138)
    when kind == "TRACKBAR" then return self~winMsg(d, id, 1024)
    when kind == "TAB" then do
      current = self~winMsg(d, id, 4875)
      if current < 0 then return ""
      return self~ctlOp(d, id, "tab.text", current)
    end
    when kind == "LISTVIEW" then return self~ctlOp(d, id, "lv.next", -1, "SELECTED")
    when kind == "TREEVIEW" then return self~ctlOp(d, id, "tv.text", self~ctlOp(d, id, "tv.special", "SELECTED"))
    when kind == "DATETIMEPICKER" | kind == "MONTHCALENDAR" | kind == "SCROLLBAR" | kind == "PROGRESS" then return ""
    when kind == "LIST" then do
      if self~kindOpts(d, id)~pos("MULTI") > 0 then return self~ctlOp(d, id, "selItems")
      return self~ctlOp(d, id, "getText")
    end
    otherwise return self~ctlOp(d, id, "getText")
  end

::method setData unguarded
  use arg d, id, kind, data
  select
    when kind == "CHECK" | kind == "RADIO" then do
      if data~datatype("W") then self~winMsg(d, id, 241, data)
      else self~winMsg(d, id, 241, 0)
    end
    when kind == "LIST" then do
      if self~kindOpts(d, id)~pos("MULTI") > 0 then do
        self~winMsg(d, id, 389, 0, -1)
        do n over data~makeArray(" ")
          if n~datatype("W") then if n > 0 then self~winMsg(d, id, 389, 1, n - 1)
        end
      end
      else if data \== "" then self~ctlOp(d, id, "selectText", data)
    end
    when kind == "COMBO" then do
      if data \== "" then self~ctlOp(d, id, "selectText", data)
    end
    when kind == "UPDOWN" then do
      if data~datatype("W") then self~winMsg(d, id, 1137, 0, data)
    end
    when kind == "TRACKBAR" then do
      if data~datatype("W") then self~winMsg(d, id, 1029, 1, data)
    end
    when kind == "TAB" then do
      if data \== "" then self~ctlOp(d, id, "tab.selectText", data)
    end
    when kind == "EDIT" | kind == "STATIC" then self~ctlOp(d, id, "setText", data)
    when kind == "LISTVIEW" | kind == "TREEVIEW" | kind == "DATETIMEPICKER" | kind == "MONTHCALENDAR" | kind == "SCROLLBAR" | kind == "PROGRESS" then nop
    otherwise self~ctlOp(d, id, "setText", data)
  end
  return 0

::method kindOpts unguarded        -- the creation options of a control
  use arg d, id
  do c over d~template
    if c["id"] == id then return c["opts"]
  end
  return ""

::method kindOf unguarded
  use arg d, id
  do entry over d~dataTable
    if entry[1] == id then return entry[2]
  end
  k = d~kinds[id]
  if k == .nil then return "EDIT"
  if k == "BUTTON" | k == "STATIC" | k == "GROUP" then return "EDIT"
  return k

::method pbdlg_putDlgDataInStem_pvt unguarded
  use arg self_, msg, a
  d = self_~oodPeer
  stem = a[1]
  do entry over d~dataTable
    stem[entry[1]] = self~getData(d, entry[1], entry[2])
  end
  return 0
::method pbdlg_setDlgDataFromStem_pvt unguarded
  use arg self_, msg, a
  d = self_~oodPeer
  stem = a[1]
  do entry over d~dataTable
    id = entry[1]
    if \stem~hasIndex(id) then iterate
    self~setData(d, id, entry[2], stem[id])
  end
  return 0
::method pbdlg_getControlData unguarded
  use arg self_, msg, a
  d = self_~oodPeer
  id = self~resolveId(self_, a[1])
  kind = self~dataKind(msg~substr(4))
  if kind == "" then kind = self~kindOf(d, id)
  return self~getData(d, id, kind)
::method pbdlg_setControlData unguarded
  use arg self_, msg, a
  d = self_~oodPeer
  id = self~resolveId(self_, a[1])
  kind = self~dataKind(msg~substr(4))
  if kind == "" then kind = self~kindOf(d, id)
  return self~setData(d, id, kind, a[2])
::method dlgctrl_data unguarded
  use arg self_
  p = self_~oodPeer
  return self~getData(p~dlg, p~id, self~kindOf(p~dlg, p~id))
::method dlgctrl_dataEquals unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  self~setData(p~dlg, p~id, self~kindOf(p~dlg, p~id), a[1])
  return

/*---- DynamicDialog: the dialog template ---------------------------------------*/
::method dyndlg_dynamicInit unguarded
  return 0
::method dyndlg_getBasePtr unguarded
  use arg self_
  if self_~oodPeer~templateActive then return 1
  return 0
::method dyndlg_getActivePtr unguarded
  use arg self_
  if self_~oodPeer~templateActive then return 1
  return 0
::method dyndlg_getDialogItemCount unguarded
  use arg self_
  return self_~oodPeer~template~items
::method dyndlg_setBasePtr unguarded
  return
::method dyndlg_setActivePtr unguarded
  return
::method dyndlg_setDialogItemCount unguarded
  return

::method dyndlg_create unguarded
  use arg self_, msg, a
  d = self_~oodPeer
  spec = .StringTable~new
  spec["key"] = d~key
  spec["x"] = a[1]; spec["y"] = a[2]; spec["cx"] = a[3]; spec["cy"] = a[4]
  spec["title"] = ""
  if a~hasIndex(5) then spec["title"] = a[5]
  spec["opts"] = ""
  if a~hasIndex(6) then spec["opts"] = a[6]~upper
  if a~hasIndex(8) then if a[8] \== "" then d~fontName = a[8]
  if a~hasIndex(9) then if a[9]~datatype("W") then if a[9] > 0 then d~fontSize = a[9]
  d~spec = spec
  d~sizeX = a[3]
  d~sizeY = a[4]
  d~templateActive = .true
  self_~defineDialog
  return .true

::method dyndlg_startParentDialog unguarded
  use arg self_, msg, a
  d = self_~oodPeer
  if \d~templateActive then return .false
  spec = d~spec
  spec["fontName"] = d~fontName
  spec["fontSize"] = d~fontSize
  if a~hasIndex(2) then if a[2] == .true then spec["modeless"] = 1
  if d~embed \== .nil then do
    spec["parent"] = d~embed[1]
    spec["px"] = d~embed[2]
    spec["py"] = d~embed[3]
  end
  answer = self~web~create(spec, d~template)
  parse var answer fx fy pw ph
  d~factorX = fx
  d~factorY = fy
  d~pixelCX = pw
  d~pixelCY = ph
  d~live = .true
  if d~store["RA"] \== .nil then self~ctlOp(d, 0, "ra.init", self~raSpec(d))
  d~templateActive = .false
  self~register(d)
  do entry over d~cmdTable
    self~web~sub(d~key, entry[1], entry[2])
  end
  if d~menu \== .nil then self~menuSync(d~menu)
  do entry over d~deferred
    self~web~op(d~key, entry[1], entry[2], entry[3], entry[4], entry[5])
  end
  d~deferred~empty
  return .true

::method dyndlg_stop unguarded
  use arg self_
  d = self_~oodPeer
  if d~live then do
    self~web~destroy(d~key)
    d~live = .false
    self~deregister(d)
  end
  return

/* One control more in the template (or in the live dialog). */
::method addItem unguarded
  use arg dlg, kind, rxID, x, y, cx, cy, opts, text
  d = dlg~oodPeer
  if \d~templateActive then if \d~live then return -2
  id = -1
  if rxID \== .nil then id = self~resolveId(dlg, rxID)
  c = .StringTable~new
  c["kind"] = kind; c["id"] = id
  c["x"] = x; c["y"] = y; c["cx"] = cx; c["cy"] = cy
  c["opts"] = opts~upper
  c["text"] = text
  d~template~append(c)
  if id > 0 then d~kinds[id] = kind
  if d~live then self~web~addControl(d~key, c)
  return id

::method opt unguarded             -- an optional string argument
  use arg a, i
  if a~hasIndex(i) then return a[i]
  return ""

::method textExtent unguarded      -- the size in dialog units a text needs, in the dialog's font
  use arg d, text
  parse value self~web~measure(text, d~fontName, d~fontSize) with width height .
  return .array~of(width, height)

::method factors unguarded         -- pixels per dialog unit of a dialog, before or after it exists
  use arg d
  if d~live then return .array~of(d~factorX, d~factorY)
  parse value self~web~measure("x", d~fontName, d~fontSize) with . . . . fx fy
  return .array~of(fx, fy)

::method convertUnits unguarded    -- a Point, Size or Rect converted in place
  use arg obj, fx, fy, toPixels
  select
    when obj~hasMethod("RIGHT") then names = .array~of("LEFT", fx, "TOP", fy, "RIGHT", fx, "BOTTOM", fy)
    when obj~hasMethod("WIDTH") then names = .array~of("WIDTH", fx, "HEIGHT", fy)
    otherwise names = .array~of("X", fx, "Y", fy)
  end
  do i = 1 to names~items by 2
    value = obj~send(names[i])
    if toPixels then value = (value * names[i + 1])~format(, 0)
    else value = (value / names[i + 1])~format(, 0)
    obj~send(names[i]"=", value)
  end
  return .true

::method pbdlg_pixel2dlgUnit unguarded
  use arg self_, msg, a
  f = self~factors(self_~oodPeer)
  return self~convertUnits(a[1], f[1], f[2], .false)
::method pbdlg_dlgUnit2pixel unguarded
  use arg self_, msg, a
  f = self~factors(self_~oodPeer)
  return self~convertUnits(a[1], f[1], f[2], .true)

::method pbdlg_getTextSizeDu unguarded
  use arg self_, msg, a
  extent = self~textExtent(self_~oodPeer, a[1])
  return .Size~new(extent[1], extent[2])
::method pbdlg_getTextSizeDlg unguarded
  use arg self_, msg, a
  d = self~dlgOf(self_)
  fontName = d~fontName
  fontSize = d~fontSize
  if a~hasIndex(2) then fontName = a[2]
  if a~hasIndex(3) then fontSize = a[3]
  parse value self~web~measure(a[1], fontName, fontSize) with width height .
  return .Size~new(width, height)
::method dlgctrl_getTextSizeDlg unguarded
  forward message "pbdlg_getTextSizeDlg"
::method pbdlg_getTextSizeTitleBar unguarded
  use arg self_, msg, a
  d = self_~oodPeer
  parse value self~web~measure(a[1], d~fontName, d~fontSize) with . . width height .
  return .Size~new(width, height)
::method wb_getTextSizePx unguarded
  use arg self_, msg, a
  d = self~dlgOf(self_)
  parse value self~web~measure(a[1], d~fontName, d~fontSize) with . . width height .
  return .Size~new(width, height)
::method wb_getTextSizeScreen unguarded
  forward message "wb_getTextSizePx"

::method dyndlg_createPushButton unguarded
  use arg self_, msg, a
  opts = self~opt(a, 6)
  text = self~opt(a, 7)
  id = self~addItem(self_, "BUTTON", a[1], a[2], a[3], a[4], a[5], opts, text)
  if id < 1 then return id
  if id < 3 | id == 9 then return 0
  method = self~opt(a, 8)~space(0)
  loadOptions = self~opt(a, 9)~upper
  if loadOptions~pos("CONNECTBUTTONS") > 0 then method = self~methodName(text)
  if method \== "" then self~addCommand(self_, id, 0, method)
  return 0

::method methodName unguarded      -- a button's label as a method name
  use arg text
  return text~changeStr("&", "")~space(0)~translate("", ".:?!")~space(0)

::method dyndlg_createRadioButton unguarded   -- also createCheckBox
  use arg self_, msg, a
  opts = self~opt(a, 6)
  text = self~opt(a, 7)
  kind = "RADIO"
  if msg == "CREATECHECKBOX" then kind = "CHECK"
  cx = 0
  cy = 10
  if a~hasIndex(4) then cx = a[4]
  else cx = self~textExtent(self_~oodPeer, text)[1] + 12
  if a~hasIndex(5) then cy = a[5]
  id = self~addItem(self_, kind, a[1], a[2], a[3], cx, cy, opts, text)
  if id < 1 then return id
  if self_~autoDetect then do
    attribute = self~opt(a, 8)
    if attribute == "" then attribute = text
    self~connectCreated(self_, a[1], id, attribute, kind)
  end
  loadOptions = self~opt(a, 9)~upper
  if kind == "RADIO" then if loadOptions~pos("CONNECTRADIOS") > 0 then self~addCommand(self_, id, 0, "ID"self~methodName(text))
  if kind == "CHECK" then if loadOptions~pos("CONNECTCHECKS") > 0 then self~addCommand(self_, id, 0, "ID"self~methodName(text))
  return 0

::method dyndlg_createGroupBox unguarded
  use arg self_, msg, a
  rxID = -1
  if a~hasIndex(1) then rxID = a[1]
  id = self~addItem(self_, "GROUP", rxID, a[2], a[3], a[4], a[5], self~opt(a, 6), self~opt(a, 7))
  if id < -1 then return id
  return 0

::method dyndlg_createStaticText unguarded
  use arg self_, msg, a
  rxID = -1
  if a~hasIndex(1) then rxID = a[1]
  text = self~opt(a, 7)
  extent = self~textExtent(self_~oodPeer, text)
  cx = extent[1]
  cy = extent[2]
  if a~hasIndex(4) then cx = a[4]
  if a~hasIndex(5) then cy = a[5]
  id = self~addItem(self_, "STATIC", rxID, a[2], a[3], cx, cy, self~opt(a, 6), text)
  if id < -1 then return id
  return 0

::method dyndlg_createStatic unguarded
  use arg self_, msg, a
  rxID = -1
  if a~hasIndex(1) then rxID = a[1]
  opts = self~opt(a, 6)~upper
  kind = "STATIC"
  if opts~pos("RECT") > 0 | opts~pos("FRAME") > 0 | opts~pos("ETCHED") > 0 then kind = "FRAME"
  id = self~addItem(self_, kind, rxID, a[2], a[3], a[4], a[5], opts, self~opt(a, 7))
  if id < -1 then return id
  return 0

::method dyndlg_createStaticFrame unguarded   -- createBlackRect, createGrayFrame, createEtchedHorizontal ...
  use arg self_, msg, a
  rxID = -1
  if a~hasIndex(1) then rxID = a[1]
  id = self~addItem(self_, "FRAME", rxID, a[2], a[3], a[4], a[5], self~opt(a, 6) msg~substr(7), "")
  if id < -1 then return id
  return 0

::method dyndlg_createEdit unguarded
  use arg self_, msg, a
  cy = 12
  if a~hasIndex(5) then cy = a[5]
  opts = self~opt(a, 6)
  if msg == "CREATEPASSWORDEDIT" then opts = opts "PASSWORD"
  id = self~addItem(self_, "EDIT", a[1], a[2], a[3], a[4], cy, opts, "")
  if id < 1 then return id
  if self_~autoDetect then self~connectCreated(self_, a[1], id, self~opt(a, 7), "EDIT")
  return 0

::method dyndlg_createListBox unguarded
  use arg self_, msg, a
  id = self~addItem(self_, "LIST", a[1], a[2], a[3], a[4], a[5], self~opt(a, 6), "")
  if id < 1 then return id
  if self_~autoDetect then self~connectCreated(self_, a[1], id, self~opt(a, 7), "LIST")
  return 0

::method dyndlg_createComboBox unguarded
  use arg self_, msg, a
  id = self~addItem(self_, "COMBO", a[1], a[2], a[3], a[4], a[5], self~opt(a, 6), "")
  if id < 1 then return id
  if self_~autoDetect then self~connectCreated(self_, a[1], id, self~opt(a, 7), "COMBO")
  return 0

::method dyndlg_createProgressBar unguarded
  use arg self_, msg, a
  id = self~addItem(self_, "PROGRESS", a[1], a[2], a[3], a[4], a[5], self~opt(a, 6), "")
  if id < 1 then return id
  return 0

::method dyndlg_addIconResource unguarded     -- icons are not shown yet
  return 0

::method dyndlg_createNamedControl unguarded  -- createListView, createTreeView, createTab, createUpDown, createTrackBar ...
  use arg self_, msg, a
  kind = msg~substr(7)
  id = self~addItem(self_, kind, a[1], a[2], a[3], a[4], a[5], self~opt(a, 6), "")
  if id < 1 then return id
  if "STATUSBAR TOOLBAR REBAR"~wordPos(kind) > 0 then return 0     -- (these have no data)
  if self_~autoDetect then self~connectCreated(self_, a[1], id, self~opt(a, 7), kind)
  return 0

/*---- ResDialog and BinaryMenuBar: binary Windows resources -----------------------------*/
/* This layer does not read .dll or .res files.  A resource reader is plugged in:
 *     .oodn~resourceProvider = anObject
 * and must answer two messages.
 *   dialogTemplate(library, id)  ->  .nil, or a directory with
 *       x y cx cy (dialog units), title, opts (the style keywords of UserDialog~create),
 *       fontName, fontSize, and controls: an array, in creation order, of directories
 *       kind id x y cx cy text opts
 *       kind is one of BUTTON CHECK RADIO GROUP STATIC FRAME EDIT LIST COMBO PROGRESS
 *       LISTVIEW TREEVIEW TAB UPDOWN TRACKBAR DATETIMEPICKER; opts are the style
 *       keywords the createXxx methods of DynamicDialog take.
 *   menuTemplate(library, id)    ->  .nil, or an array of directories, depth first:
 *       depth (0 is the bar) id text flags (CHECKED GRAYED SEPARATOR RADIO ...)
 * library is the name given to ResDialog~new, as a path of this file system; id is numeric. */
::attribute resourceProvider unguarded

::method needProvider unguarded
  use arg what
  if self~resourceProvider \== .nil then return self~resourceProvider
  raise syntax 98.900 array("ooDialog/WASM:" what "needs a reader of binary Windows resources; set .oodn~resourceProvider (see oodWeb.cls)")

::method resTemplate unguarded     -- the dialog's template from the resource reader; .false if there is none
  use arg self_, library, rxID
  d = self_~oodPeer
  provider = self~needProvider("a dialog from a resource file")
  id = self~resolveId(self_, rxID)
  t = provider~dialogTemplate(self~path(library), id)
  if t == .nil then return .false
  spec = .StringTable~new
  spec["key"] = d~key
  spec["x"] = t~x; spec["y"] = t~y; spec["cx"] = t~cx; spec["cy"] = t~cy
  spec["title"] = t~title
  spec["opts"] = t~opts~upper
  if t~hasIndex("FONTNAME") then d~fontName = t~fontName
  if t~hasIndex("FONTSIZE") then d~fontSize = t~fontSize
  d~spec = spec
  d~sizeX = t~cx
  d~sizeY = t~cy
  d~templateActive = .true
  do c over t~controls
    cid = self~addItem(self_, c~kind, c~id, c~x, c~y, c~cx, c~cy, c~opts, c~text)
    if cid > 0 then if "EDIT CHECK RADIO LIST COMBO"~wordPos(c~kind) > 0 then d~dataTable~append(.array~of(cid, c~kind))
  end
  return .true
::method resdlg_startDialog_pvt unguarded
  use arg self_, msg, a
  if \self~resTemplate(self_, a[1], a[2]) then return .false
  return self~dyndlg_startParentDialog(self_, msg, .array~of(a[3], a[4]))
::method resdlg_getDataTableIDs_pvt unguarded
  use arg self_
  ids = .array~new
  do entry over self_~oodPeer~dataTable
    ids~append(entry[1])
  end
  return ids

/*---- ControlDialog: a dialog shown inside its owner dialog ---------------------------------------*/
::method ctlInfoOf unguarded
  use arg dlg
  d = dlg~oodPeer
  if d~ctlInfo == .nil then do
    info = .directory~new
    info~extraOptions = ""
    info~initializing = .true
    info~pageTitle = ""
    info~wasActivated = .false
    d~ctlInfo = info
  end
  return d~ctlInfo
::method cd_init unguarded
  return 0
::method cd_init_cls unguarded
  return 0
/* customDrawControl(id, "ListView" | "TreeView", method, flags): the method (onCustomDraw if
   omitted) is asked how to draw each row in view (lvSimpleCustomDraw of oodListView.cpp).
   It gets one LvCustomDrawSimple or TvCustomDrawSimple, sets clrText, clrTextBk, font and
   reply on it, and answers .true to have them used.  A reply with CDRF_NOTIFYSUBITEMDRAW from
   a list-view's row asks the method again for each of its columns. */
::method cd_customDrawControl unguarded
  use arg self_, msg, a
  d = self_~oodPeer
  id = self~resolveId(self_, a[1])
  if id < 1 then return .false
  name = self~opt(a, 2)~upper
  if name \== "LISTVIEW" & name \== "TREEVIEW" then raise syntax 93.900 array('customDrawControl: custom draw is not implemented for "'a[2]'"; ListView and TreeView are')
  method = "onCustomDraw"
  if a~hasIndex(3) then if a[3] \== "" then method = a[3]
  d~store["CD" id] = .array~of(name, method)
  self~ctlOpWhenLive(d, id, "cd.on")
  return .true
::method cdCss unguarded           -- a colour of a custom draw answer: '' if none was set
  use arg color
  if color == .nil then return '""'
  if color == 4278190080 | color == 4294967295 then return '""'      -- CLR_DEFAULT, CLR_NONE
  return '"'self~colorOf(color)'"'
::method cdFont unguarded
  use arg font
  if font == .nil then return '""'
  return self~ttJson(self~gdiFontCss(font))
::method cdAskOne unguarded        -- one question to the program; the paint as JSON fields, or "" if it answered no
  use arg dlg, method, cls, info
  answer = self~invokeResult(dlg, method, .array~of(self~classOf(cls)~new(info)))
  if answer \== .true then return ""
  return self~cdCss(info~clrText)","self~cdCss(info~clrTextBk)","self~cdFont(info~font)
::method cdEvent unguarded         -- the page drew rows: ask the program about each
  use arg key, id, rows
  d = self~dialogOf(key)
  if d == .nil then return
  entry = d~store["CD" id]
  if entry == .nil then return
  dlg = d~rexxSelf
  json = ""
  if entry[1] == "LISTVIEW" then do
    parse var rows first last .
    columns = self~ctlOp(d, id, "lv.colCount")
    do i = first to last
      if \d~live then return
      uid = self~ctlOp(d, id, "lv.uid", i)
      if uid == 0 then leave
      info = .directory~new
      info~drawStage = 65537         -- CDDS_ITEMPREPAINT
      info~item = i
      info~subItem = 0
      info~id = id
      info~itemData = self~itemData(d, id, uid)
      info~reply = 0
      paint = self~cdAskOne(dlg, entry[2], "LvCustomDrawSimple", info)
      if paint == "" then iterate
      cells = "[-1,"paint"]"
      if info~reply~datatype("W") then if info~reply // 64 >= 32 then do c = 0 to columns - 1    -- CDRF_NOTIFYSUBITEMDRAW
        sub = .directory~new
        sub~drawStage = 196609       -- CDDS_SUBITEMPREPAINT
        sub~item = i
        sub~subItem = c
        sub~id = id
        sub~itemData = info~itemData
        sub~reply = 0
        subPaint = self~cdAskOne(dlg, entry[2], "LvCustomDrawSimple", sub)
        if subPaint \== "" then cells = cells",["c","subPaint"]"
      end
      if json \== "" then json = json","
      json = json"["uid",["cells"]]"
    end
  end
  else do item over rows~makeArray(" ")
    if \d~live then return
    parse var item h ":" level
    info = .directory~new
    info~drawStage = 65537
    info~item = self~tvHandle(h)
    info~level = level
    info~id = id
    info~itemData = self~itemData(d, id, h)
    info~reply = 0
    paint = self~cdAskOne(dlg, entry[2], "TvCustomDrawSimple", info)
    if paint == "" then iterate
    if json \== "" then json = json","
    json = json"["h","paint"]"
  end
  self~ctlOp(d, id, "cd.paint", "["json"]")         -- (always: the page waits for the answer before it asks again)
::method lvcds_init_cls unguarded
  return 0
::method lvcds_init unguarded      -- (made by cdEvent with the directory that is its state)
  use arg self_, msg, a
  if \a~hasIndex(1) then raise syntax 93.900 array("The LvCustomDrawSimple class can not be instantiated from Rexx code")
  if \a[1]~isA(.Directory) then raise syntax 93.900 array("The LvCustomDrawSimple class can not be instantiated from Rexx code")
  self_~oodPeer = a[1]
  return 0
::method lvcds_getDrawStage unguarded
  use arg self_
  return self_~oodPeer~drawStage
::method lvcds_getID unguarded
  use arg self_
  return self_~oodPeer~id
::method lvcds_getItem unguarded
  use arg self_
  return self_~oodPeer~item
::method lvcds_getItemData unguarded
  use arg self_
  return self_~oodPeer~itemData
::method lvcds_getSubItem unguarded
  use arg self_
  return self_~oodPeer~subItem
::method lvcds_setClrText unguarded
  use arg self_, msg, a
  self_~oodPeer~clrText = a[1]
::method lvcds_setClrTextBk unguarded
  use arg self_, msg, a
  self_~oodPeer~clrTextBk = a[1]
::method lvcds_setFont unguarded
  use arg self_, msg, a
  self_~oodPeer~font = a[1]
::method lvcds_setReply unguarded
  use arg self_, msg, a
  self_~oodPeer~reply = a[1]
::method tvcds_init_cls unguarded
  return 0
::method tvcds_init unguarded
  use arg self_, msg, a
  if \a~hasIndex(1) then raise syntax 93.900 array("The TvCustomDrawSimple class can not be instantiated from Rexx code")
  if \a[1]~isA(.Directory) then raise syntax 93.900 array("The TvCustomDrawSimple class can not be instantiated from Rexx code")
  self_~oodPeer = a[1]
  return 0
::method tvcds_getDrawStage unguarded
  use arg self_
  return self_~oodPeer~drawStage
::method tvcds_getID unguarded
  use arg self_
  return self_~oodPeer~id
::method tvcds_getItem unguarded
  use arg self_
  return self_~oodPeer~item
::method tvcds_getItemData unguarded
  use arg self_
  return self_~oodPeer~itemData
::method tvcds_getLevel unguarded
  use arg self_
  return self_~oodPeer~level
::method tvcds_setClrText unguarded
  use arg self_, msg, a
  self_~oodPeer~clrText = a[1]
::method tvcds_setClrTextBk unguarded
  use arg self_, msg, a
  self_~oodPeer~clrTextBk = a[1]
::method tvcds_setFont unguarded
  use arg self_, msg, a
  self_~oodPeer~font = a[1]
::method tvcds_setReply unguarded
  use arg self_, msg, a
  self_~oodPeer~reply = a[1]
::method cd_controlDlgInit unguarded
  return 0
::method cd_get_extraOptions unguarded
  use arg self_
  return self~ctlInfoOf(self_)~extraOptions
::method cd_set_extraOptions unguarded
  use arg self_, msg, a
  self~ctlInfoOf(self_)~extraOptions = a[1]
  return
::method cd_get_initializing unguarded
  use arg self_
  return self~ctlInfoOf(self_)~initializing
::method cd_set_initializing unguarded
  use arg self_, msg, a
  self~ctlInfoOf(self_)~initializing = (a[1] == .true)
  return
::method cd_get_isManaged unguarded
  return .false
::method cd_get_pageTitle unguarded
  use arg self_
  return self~ctlInfoOf(self_)~pageTitle
::method cd_set_pageTitle unguarded
  use arg self_, msg, a
  self~ctlInfoOf(self_)~pageTitle = a[1]
  return
::method cd_get_wasActivated unguarded
  use arg self_
  return self~ctlInfoOf(self_)~wasActivated

::method startInOwner unguarded    -- make the dialog inside its owner, at its template's position
  use arg self_
  d = self_~oodPeer
  owner = d~ownerDialog
  if owner == .nil then return 0
  od = owner~oodPeer
  if \od~live then return 0
  if \d~templateActive then return 0
  left = (d~spec["x"] * od~factorX)~format(, 0)
  top = (d~spec["y"] * od~factorY)~format(, 0)
  d~embed = .array~of(od~key, left, top)
  if \self~dyndlg_startParentDialog(self_, "", .array~new) then return 0
  self~ctlInfoOf(self_)~wasActivated = .true
  self~raPage(self_)
  self~web~show(d~key, "NORMAL")
  return d~hwnd
::method dyndlg_startChildDialog unguarded
  use arg self_
  return self~startInOwner(self_)
::method resCtrlDlg_startDialog_pvt unguarded
  use arg self_, msg, a
  if \self~resTemplate(self_, a[1], a[2]) then return .false
  return self~startInOwner(self_) \== 0

/* Windows destroys an owned window with its owner.  The owned dialog's own
   thread is waiting in waitForDialog: mark it finished and it runs its own stopIt. */
::method finishOwned unguarded
  expose dialogs
  use arg owner
  do owned over dialogs~allItems
    if owned~ownerDialog \== owner then iterate
    if \owned~live then iterate
    if owned~embed \== .nil then iterate
    owned~rexxSelf~finished = .true
  end

::method finishChildren unguarded  -- the dialogs shown inside a dialog end with it
  expose dialogs
  use arg d
  do child over dialogs~allItems
    if child~embed == .nil then iterate
    if child~embed[1] \== d~key then iterate
    child~live = .false
    self~deregister(child)
    child~rexxSelf~finished = .true
  end

/* setWindowPos(hwndBehind, rect | point, size | x, y, cx, cy, opts): pixels in the parent's client area. */
::method wb_setWindowPos unguarded
  use arg self_, msg, a
  if self_~oodPeer~isA(.OodCtl) then if self_~oodPeer~kind == "TOOLTIP" then do    -- a tip is placed in screen pixels
    if a[2]~isA(.String) then self~ctlOp(self_~oodPeer~dlg, self_~oodPeer~id, "tip.pos", a[2], a[3])
    else self~ctlOp(self_~oodPeer~dlg, self_~oodPeer~id, "tip.pos", a[2]~x, a[2]~y)
    return .true
  end
  opts = ""
  nums = .array~new
  do i = 2 to a~size
    if \a~hasIndex(i) then iterate
    v = a[i]
    select
      when v~isA(.String) then do
        if v~datatype("N") then nums~append(v)
        else opts = v~upper
      end
      when v~hasMethod("WIDTH") then do
        nums~append(v~width)
        nums~append(v~height)
      end
      when v~hasMethod("RIGHT") then do
        nums~append(v~left); nums~append(v~top)
        nums~append(v~right); nums~append(v~bottom)      -- (a point / size rectangle: right and bottom are the width and height)
      end
      otherwise do
        nums~append(v~x)
        nums~append(v~y)
      end
    end
  end
  if nums~items >= 2 then if opts~pos("NOMOVE") == 0 then self~op(self_, "move", nums[1], nums[2])
  if nums~items >= 4 then if opts~pos("NOSIZE") == 0 then self~op(self_, "size", nums[3], nums[4])
  if opts~pos("SHOWWINDOW") > 0 then self~op(self_, "show")
  if opts~pos("HIDEWINDOW") > 0 then self~op(self_, "hide")
  return .true
::method wb_moveSizeWindow unguarded
  forward message "wb_setWindowPos"

/*---- property sheets -------------------------------------------------------------------------*/
/* A property sheet is drawn by this layer as an ordinary dialog: a tab control (ID 12320),
 * the pages as dialogs embedded in it, and OK / Cancel / Apply (12321) / Help buttons.
 * A page's dialog is made the first time the page is shown, as Windows does. */
::method pageInit unguarded        -- from the pages' init methods (patches.txt)
  use arg page, kind, pageOpts, connectOpts, expected
  info = .directory~new
  info~kind = kind
  info~opts = pageOpts~upper
  info~connectOpts = connectOpts
  info~expected = expected
  info~title = ""
  info~cx = 0
  info~cy = 0
  info~sheet = .nil
  info~number = -1
  info~activated = .false
  page~oodPeer~pageInfo = info
  return 0
::method pageInfoOf unguarded
  use arg page
  return page~oodPeer~pageInfo
::method psp_init_propertySheetPage unguarded
  return .true
::method psp_getcx unguarded       -- cx, cy
  use arg self_, msg
  if msg == "CX" then return self~pageInfoOf(self_)~cx
  return self~pageInfoOf(self_)~cy
::method psp_setcx unguarded
  use arg self_, msg, a
  if msg == "CX=" then self~pageInfoOf(self_)~cx = a[1]
  else self~pageInfoOf(self_)~cy = a[1]
  return
::method psp_setSize unguarded
  use arg self_, msg, a
  info = self~pageInfoOf(self_)
  first = a[1]
  if first~isA(.String) then do
    info~cx = first
    info~cy = a[2]
  end
  else do
    info~cx = first~width
    info~cy = first~height
  end
  return 0
::method psp_getPageTitle unguarded
  use arg self_, msg
  if msg == "PAGETITLE" then return self~pageInfoOf(self_)~title
  return ""
::method psp_setPageTitle unguarded
  use arg self_, msg, a
  if msg == "PAGETITLE=" then self~pageInfoOf(self_)~title = a[1]
  return
::method psp_pageID_atr unguarded
  use arg self_
  return self_~oodPeer~hwnd
::method psp_pageNumber_atr unguarded
  use arg self_
  return self~pageInfoOf(self_)~number + 1
::method psp_propSheet_atr unguarded
  use arg self_
  return self~pageInfoOf(self_)~sheet
::method psp_wasActivated_atr unguarded
  use arg self_
  return self~pageInfoOf(self_)~activated
::method psp_getWantNotification unguarded
  return .false
::method psp_setWantNotification unguarded
  return
::method psp_setResources_atr unguarded
  return
::method psp_setTabIcon_atr unguarded
  return

::method psp_initTemplate unguarded            -- the page's controls: from its .rc file, or from defineDialog
  use arg self_
  d = self_~oodPeer
  info = d~pageInfo
  if info~kind == "RC" then do
    if self_~loadFrame(info~expected) \== 0 then return 1
    return self_~loadItems(info~connectOpts)
  end
  if info~kind == "RES" then do
    if \self~resTemplate(self_, self_~library, self_~resourceID) then return 1
    info~cx = d~sizeX
    info~cy = d~sizeY
    if info~title == "" then info~title = d~spec["title"]
    return 0
  end
  self~pageTemplate(self_, info~cx, info~cy)
  self_~defineDialog
  return 0
::method pageTemplate unguarded
  use arg page, cx, cy
  d = page~oodPeer
  spec = .StringTable~new
  spec["key"] = d~key
  spec["x"] = 0; spec["y"] = 0; spec["cx"] = cx; spec["cy"] = cy
  spec["title"] = d~pageInfo~title
  spec["opts"] = ""
  d~spec = spec
  d~sizeX = cx
  d~sizeY = cy
  d~templateActive = .true
  return 0
::method rcpspdlg_startTemplate unguarded      -- (cx, cy, title, fontName, fontSize, expected), from loadFrame
  use arg self_, msg, a
  d = self_~oodPeer
  info = d~pageInfo
  info~cx = a[1]
  info~cy = a[2]
  if info~title == "" then info~title = a[3]
  if a[4] \== "" then d~fontName = a[4]
  if a[5]~datatype("W") then if a[5] > 0 then d~fontSize = a[5]
  return self~pageTemplate(self_, a[1], a[2])

::method sheetInit unguarded       -- from PropertySheetDialog~init (patches.txt)
  use arg sheet, pages, opts
  info = .directory~new
  info~pages = pages
  info~opts = opts~upper
  info~outcome = "NOTFINISHED"
  info~current = 0
  sheet~oodPeer~sheet = info
  do i = 1 to pages~items
    pageInfo = self~pageInfoOf(pages[i])
    pageInfo~sheet = sheet
    pageInfo~number = i - 1
  end
  return 0

::method psdlg_execute unguarded
  use arg self_, msg, a
  d = self_~oodPeer
  info = d~sheet
  pages = info~pages
  width = 100
  height = 60
  do page over pages                 -- every page's template, to know the sheet's size
    page~initTemplate
    pageInfo = self~pageInfoOf(page)
    width = max(width, pageInfo~cx)
    height = max(height, pageInfo~cy)
  end
  first = pages[1]~oodPeer
  d~fontName = first~fontName
  d~fontSize = first~fontSize
  spec = .StringTable~new
  spec["key"] = d~key
  spec["x"] = 0; spec["y"] = 0; spec["cx"] = width + 14; spec["cy"] = height + 48
  spec["title"] = self_~caption
  spec["opts"] = "CENTER"
  if info["MODELESS"] == .true then spec["modeless"] = 1     -- shown by popup or popupAsChild
  d~spec = spec
  d~sizeX = width + 14
  d~sizeY = height + 48
  d~templateActive = .true
  self~addItem(self_, "TAB", 12320, 4, 4, width + 6, height + 20, "", "")
  -- A wizard has no tabs: Back, Next and Finish walk through the pages
  -- (ID_WIZBACK 12323, ID_WIZNEXT 12324, ID_WIZFINISH 12325 of prsht.h).
  info~wizard = self~isWizard(info~opts)
  if info~wizard then buttons = .array~of(.array~of(12323, "< &Back", "DISABLED"), .array~of(12324, "&Next >", "DEFAULT"), .array~of(12325, "Finish", ""), .array~of(2, "Cancel", ""))
  else buttons = .array~of(.array~of(1, "OK", "DEFAULT"), .array~of(2, "Cancel", ""))
  if \info~wizard then if info~opts~wordPos("NOAPPLYNOW") == 0 then buttons~append(.array~of(12321, "&Apply", "DISABLED"))
  if info~opts~wordPos("HASHELP") > 0 then buttons~append(.array~of(9, "Help", ""))
  x = width + 10 - buttons~items * 54
  do b over buttons
    self~addItem(self_, "BUTTON", b[1], x, height + 29, 50, 14, b[3], b[2])
    x = x + 54
  end
  d~notifyTable~append(.array~of(12320, "SELCHANGE", "@SHEETTAB", "SELCHANGE"))
  d~cmdTable~append(.array~of(12320, "SELCHANGE", ""))
  if \self~dyndlg_startParentDialog(self_, msg, .array~new) then return -1
  if info~wizard then self~ctlOp(d, 12325, "hide")
  else do page over pages
    self~ctlOp(d, 12320, "tab.ins", -1, self~pageInfoOf(page)~title)
  end
  start = self_~startPage
  if \start~datatype("W") then start = 1
  if start < 1 | start > pages~items then start = 1
  self~sheetActivate(self_, start, .false)
  self_~initDialog
  self~web~show(d~key, "NORMAL")
  self~pumpUntilFinished(self_)
  do page over pages
    pd = page~oodPeer
    if pd~pageInfo~activated then do
      if pd~live then do
        self~web~destroy(pd~key)
        pd~live = .false
        self~deregister(pd)
      end
    end
  end
  self_~stopIt
  if info~outcome == "CLOSEDOK" then return 1
  return 2

/* Show page number index; make its dialog the first time. */
::method sheetActivate unguarded
  use arg sheet, index, leaveCurrent
  d = sheet~oodPeer
  info = d~sheet
  pages = info~pages
  if index < 1 | index > pages~items then return .false
  if info~current == index then return .true
  if leaveCurrent then if info~current > 0 then do
    if pages[info~current]~killActive(sheet) \== .true then do
      self~winMsg(d, 12320, 4876, info~current - 1)      -- the tab goes back to the page that refused
      return .false
    end
  end
  page = pages[index]
  pd = page~oodPeer
  pageInfo = pd~pageInfo
  if \pageInfo~activated then do
    parse value self~ctlOp(d, 12320, "tab.rect") with left top .
    pd~embed = .array~of(d~key, left + 4, top + 4)
    if \self~dyndlg_startParentDialog(page, "", .array~new) then return .false
    pageInfo~activated = .true
    page~pageCreate(sheet)
    page~execute
  end
  if info~current > 0 then self~web~show(pages[info~current]~oodPeer~key, "HIDE")
  info~current = index
  self~winMsg(d, 12320, 4876, index - 1)
  self~web~show(pd~key, "NORMAL")
  page~setActive(sheet)
  return .true

::method sheetTab unguarded        -- the user chose a tab
  use arg sheet
  d = sheet~oodPeer
  self~sheetActivate(sheet, self~winMsg(d, 12320, 4875) + 1, .true)

/* OK, Cancel, Apply, Help of a sheet.  .true: the command was the sheet's own. */
::method sheetButton unguarded
  use arg d, id
  info = d~sheet
  sheet = d~rexxSelf
  pages = info~pages
  select
    when id == 1 | id == 12321 then do
      isOk = (id == 1)
      if info~current > 0 then if pages[info~current]~killActive(sheet) \== .true then return .true
      do i = 1 to pages~items
        page = pages[i]
        if \self~pageInfoOf(page)~activated then iterate
        if page~apply(isOk, i, info~current, sheet) \== 0 then do
          self~sheetActivate(sheet, i, .false)
          return .true
        end
      end
      if \isOk then do
        self~ctlOp(d, 12321, "enable", 0)
        return .true
      end
      info~outcome = "CLOSEDOK"
      sheet~initCode = 1
      sheet~finished = .true
    end
    when id == 2 then do
      do page over pages
        if \self~pageInfoOf(page)~activated then iterate
        if page~queryCancel(sheet) \== .true then return .true
      end
      do page over pages
        if self~pageInfoOf(page)~activated then page~reset(.true, sheet)
      end
      info~outcome = "CLOSEDCANCEL"
      sheet~initCode = 2
      sheet~finished = .true
    end
    when id == 9 then do
      if info~current > 0 then pages[info~current]~help(sheet)
    end
    when id == 12323 | id == 12324 then do     -- Back, Next: 0 the neighbour page, -1 stay, else the page to show
      if info~current < 1 then return .true
      page = pages[info~current]
      if id == 12323 then answer = page~wizBack(sheet)
      else answer = page~wizNext(sheet)
      if answer == -1 then return .true
      target = info~current + 1
      if id == 12323 then target = info~current - 1
      if answer \== 0 then do
        wanted = self~sheetPageIndex(sheet, answer)
        if wanted > 0 then target = wanted
      end
      self~sheetActivate(sheet, target, .true)
    end
    when id == 12325 then do                   -- Finish: anything but 0 keeps the wizard open
      if info~current > 0 then do
        if pages[info~current]~killActive(sheet) \== .true then return .true
        if pages[info~current]~wizFinish(sheet) \== 0 then return .true
      end
      info~outcome = "CLOSEDOK"
      sheet~initCode = 1
      sheet~finished = .true
    end
    otherwise return .false
  end
  return .true

::method isWizard unguarded
  use arg opts
  do word over .array~of("WIZARD", "WIZARD97", "WIZARDLITE", "AEROWIZARD")
    if opts~caselessWordPos(word) > 0 then return .true
  end
  return .false
::method sheetPageIndex unguarded  -- a page object, a page number or a page id as a page number; 0 if it is none
  use arg sheet, which
  pages = sheet~oodPeer~sheet~pages
  do i = 1 to pages~items
    if pages[i] == which then return i
  end
  if which~isA(.string) then do
    if which~datatype("W") then if which >= 1 & which <= pages~items then return which
    do i = 1 to pages~items
      if pages[i]~pageID == which then return i
    end
  end
  return 0
/* setWizButtons(opts): BACK enables Back; NEXT shows Next; FINISH shows Finish in
   its place; DISABLEDFINISH shows Finish disabled. */
::method psdlg_setWizButtons unguarded
  use arg self_, msg, a
  d = self_~oodPeer
  if \d~live then return 0
  if \d~sheet~wizard then return 0
  opts = self~opt(a, 1)~upper
  self~ctlOp(d, 12323, "enable", (opts~wordPos("BACK") > 0))
  finish = (opts~wordPos("FINISH") > 0 | opts~wordPos("DISABLEDFINISH") > 0)
  if finish then do
    self~ctlOp(d, 12324, "hide")
    self~ctlOp(d, 12325, "show")
    self~ctlOp(d, 12325, "enable", (opts~wordPos("DISABLEDFINISH") == 0))
  end
  else do
    self~ctlOp(d, 12325, "hide")
    self~ctlOp(d, 12324, "show")
    self~ctlOp(d, 12324, "enable", (opts~wordPos("NEXT") > 0))
  end
  return 0
::method psdlg_querySiblings unguarded   -- querySiblings(arg1, arg2): each page made so far is asked, until one answers other than 0
  use arg self_, msg, a
  do page over self_~oodPeer~sheet~pages
    if \self~pageInfoOf(page)~activated then iterate
    answer = page~queryFromSibling(a[1], a[2], self_)
    if answer \== 0 then return answer
  end
  return 0
::method psdlg_setNextText unguarded
  use arg self_, msg, a
  if self_~oodPeer~live then self~ctlOp(self_~oodPeer, 12324, "setText", a[1])
  return 0
::method psdlg_setFinishText unguarded
  use arg self_, msg, a
  d = self_~oodPeer
  if \d~live then return 0
  self~ctlOp(d, 12325, "setText", a[1])
  self~ctlOp(d, 12324, "hide")
  self~ctlOp(d, 12325, "show")
  return 0
::method psdlg_getResult unguarded
  use arg self_
  return self_~oodPeer~sheet~outcome
::method psdlg_setCurSel unguarded -- setCurSel(index, hPage)
  use arg self_, msg, a
  if \self_~oodPeer~live then return .false
  if \a~hasIndex(1) then return .false
  return self~sheetActivate(self_, a[1], .true)
::method psdlg_getPage unguarded
  use arg self_, msg, a
  page = self_~oodPeer~sheet~pages[a[1]]
  if page == .nil then return .nil
  return page
::method psdlg_pageToIndex unguarded
  use arg self_, msg, a
  return self~pageInfoOf(a[1])~number + 1
::method psdlg_getTabControl unguarded
  use arg self_
  return self_~newTab(12320)
::method psdlg_changed unguarded
  use arg self_
  self~ctlOp(self_~oodPeer, 12321, "enable", 1)
  return 0
::method psdlg_unchanged unguarded
  use arg self_
  return 0
::method psdlg_setTitle unguarded
  use arg self_, msg, a
  self~ctlOp(self_~oodPeer, 0, "setText", a[1])
  return 0
::method psdlg_cancelToClose unguarded
  use arg self_
  self~ctlOp(self_~oodPeer, 1, "setText", "Close")
  self~ctlOp(self_~oodPeer, 2, "enable", 0)
  return 0
::method psdlg_getCurrentPageHwnd unguarded
  use arg self_
  info = self_~oodPeer~sheet
  if info~current == 0 then return 0
  return info~pages[info~current]~oodPeer~hwnd

/*---- EventNotification ---------------------------------------------------------*/
::method en_init_eventNotification unguarded
  return .true

::method addCommand unguarded      -- addCommandMessage() of the DLL
  use arg dlg, id, code, method
  d = dlg~oodPeer
  d~cmdTable~append(.array~of(id, code, method~upper))
  if d~live then self~web~sub(d~key, id, code)
  return .true

::method connectByKeyword unguarded
  use arg self_, a, words, prefix
  id = self~resolveId(self_, a[1])
  if id == -1 then return -1
  event = a[2]~strip~upper
  code = ""
  do i = 1 to words~words by 2
    if words~word(i) == event then do
      code = words~word(i + 1)
      leave
    end
  end
  if code == "" then return -1
  method = self~opt(a, 3)
  if method == "" then method = "on" || event
  if prefix == "BN" then if code == 0 then if id < 3 | id == 9 then return 0
  self~addCommand(self_, id, code, method)
  return 0

::method en_connectButtonEvent unguarded
  use arg self_, msg, a
  return self~connectByKeyword(self_, a, "CLICKED 0 PAINT 1 HILITE 2 UNHILITE 3 DISABLE 4 DBLCLK 5 GOTFOCUS 6 LOSTFOCUS 7", "BN")
::method en_connectEditEvent unguarded
  use arg self_, msg, a
  return self~connectByKeyword(self_, a, "GOTFOCUS 256 LOSTFOCUS 512 CHANGE 768 UPDATE 1024 ERRSPACE 1280 MAXTEXT 1281 HSCROLL 1537 VSCROLL 1538", "EN")
::method en_connectListBoxEvent unguarded
  use arg self_, msg, a
  return self~connectByKeyword(self_, a, "SELCHANGE 1 DBLCLK 2 SELCANCEL 3 GOTFOCUS 4 LOSTFOCUS 5 ERRSPACE -2", "LBN")
::method en_connectComboBoxEvent unguarded
  use arg self_, msg, a
  return self~connectByKeyword(self_, a, "SELCHANGE 1 DBLCLK 2 GOTFOCUS 3 LOSTFOCUS 4 CHANGE 5 UPDATE 6 DROPDOWN 7 CLOSEUP 8 SELENDOK 9 SELENDCANCEL 10 ERRSPACE -1", "CBN")
::method en_connectStaticEvent unguarded
  use arg self_, msg, a
  return self~connectByKeyword(self_, a, "CLICK 0 DBLCLK 1 ENABLE 2 DISABLE 3", "STN")
::method en_connectCommandEvents unguarded
  use arg self_, msg, a
  id = self~resolveId(self_, a[1])
  if id == -1 then return -1
  self~addCommand(self_, id, "*", a[2])
  return 0

::method dlgctrl_connectEvent unguarded      -- control~connectEvent(event, methodName): as the dialog's connectXxxEvent
  use arg self_, msg, a
  p = self_~oodPeer
  dlg = p~dlg~rexxSelf
  args = .array~of(p~id, a[1])
  if a~hasIndex(2) then args[3] = a[2]
  kind = p~dlg~kinds[p~id]
  select
    when kind == "BUTTON" | kind == "CHECK" | kind == "RADIO" then return self~en_connectButtonEvent(dlg, msg, args)
    when kind == "EDIT" then return self~en_connectEditEvent(dlg, msg, args)
    when kind == "LIST" then return self~en_connectListBoxEvent(dlg, msg, args)
    when kind == "COMBO" then return self~en_connectComboBoxEvent(dlg, msg, args)
    when kind == "STATIC" then return self~en_connectStaticEvent(dlg, msg, args)
    when kind == "LISTVIEW" then return self~en_connectListViewEvent(dlg, msg, args)
    when kind == "TREEVIEW" then return self~en_connectTreeViewEvent(dlg, msg, args)
    when kind == "TAB" then return self~en_connectTabEvent(dlg, msg, args)
    when kind == "UPDOWN" then return self~en_connectUpDownEvent(dlg, msg, args)
    when kind == "DATETIMEPICKER" then return self~en_connectDateTimePickerEvent(dlg, msg, args)
    when kind == "MONTHCALENDAR" then return self~en_connectMonthCalendarEvent(dlg, msg, args)
    otherwise do
      say "ooDialog/WASM: connectEvent" a[1] "for control" p~id "is connected but is not produced yet"
      return 0
    end
  end

/*---- WM_NOTIFY events: list-view, tree-view, tab ---------------------------------*/
::method sep unguarded             -- the separator of the values in one answer of the page
  return x2c("1F")

::method addNotify unguarded       -- a connection of a notification: (id, page event, method, keyword)
  use arg dlg, id, event, method, keyword
  d = dlg~oodPeer
  d~notifyTable~append(.array~of(id, event, method~upper, keyword))
  d~cmdTable~append(.array~of(id, event, ""))      -- so the page is told when the dialog starts
  if d~live then self~web~sub(d~key, id, event)
  return 0

::method connectNotify unguarded
  use arg self_, a, map
  id = self~resolveId(self_, a[1])
  if id == -1 then return -1
  keyword = a[2]~strip~upper
  p = map~wordPos(keyword)
  if p == 0 then do                  -- the connection is accepted; the page never produces this event
    say "ooDialog/WASM: the event" keyword "of control" id "is connected but is not produced yet"
    return 0
  end
  method = self~opt(a, 3)
  if method == "" then method = "on" || keyword
  do event over map~word(p + 1)~makeArray("+")
    self~addNotify(self_, id, event, method, keyword)
  end
  return 0

::method en_connectListViewEvent unguarded
  use arg self_, msg, a
  map = "CLICK CLICK DBLCLK DBLCLK COLUMNCLICK COLUMNCLICK ACTIVATE ACTIVATE KEYDOWN KEYDOWN" -
        "SELECTCHANGED SEL CHANGED SEL FOCUSCHANGED FOC SELECTFOCUSCHANGED SEL+FOC CHECKBOXCHANGED CHECK"
  return self~connectNotify(self_, a, map)
::method en_connectTreeViewEvent unguarded
  use arg self_, msg, a
  return self~connectNotify(self_, a, "SELCHANGED SELCHANGED EXPANDED EXPANDED EXPANDING EXPANDING GETINFOTIP GETINFOTIP")
::method en_connectTabEvent unguarded
  use arg self_, msg, a
  return self~connectNotify(self_, a, "SELCHANGE SELCHANGE SELCHANGING SELCHANGING")

::method notify unguarded          -- the arguments are those the DLL builds for each event
  use arg key, id, event, extra
  d = self~dialogOf(key)
  if d == .nil then return
  dlg = d~rexxSelf
  parts = extra~makeArray(self~sep)
  kind = d~kinds[id]
  hwnd = "0x"d2x(key * 65536 + id)~right(16, "0")
  do entry over d~notifyTable
    if entry[1] \== id then iterate
    if entry[2] \== event then iterate
    if entry[3] == "@SHEETTAB" then do
      self~sheetTab(dlg)
      iterate
    end
    select
      when kind == "LISTVIEW" then do
        ctl = dlg~newListView(id)
        select
          when event == "CLICK" | event == "DBLCLK" then args = .array~of(id, parts[1], parts[2], parts[3], (event == "CLICK"), ctl)
          when event == "COLUMNCLICK" | event == "ACTIVATE" | event == "KEYDOWN" then args = .array~of(id, extra, ctl)
          when event == "BEGINSCROLL" | event == "ENDSCROLL" then args = .array~of(id, parts[1], parts[2], ctl, (event == "BEGINSCROLL"))
          otherwise args = .array~of(id, parts[1], parts[2], ctl)
        end
      end
      when kind == "TREEVIEW" then do
        ctl = dlg~newTreeView(id)
        if event == "SELCHANGED" then do
          old = self~tvHandle(parts[1])
          new = self~tvHandle(parts[2])
          args = .array~of(id, old, self~itemData(d, id, parts[1]), new, self~itemData(d, id, parts[2]), parts[3], ctl, event)
        end
        else if event == "GETINFOTIP" then do    -- (id, item, text, maxLen, userData): the answer is the tip's text
          text = self~invokeResult(dlg, entry[3], .array~of(id, self~tvHandle(parts[1]), "", 1023, self~itemData(d, id, parts[1])))
          if text == .nil then text = ""
          if \text~isA(.String) then text = text~string
          self~ctlOp(d, 60000 + id, "tip.show", text~left(min(text~length, 1023)))
          iterate
        end
        else args = .array~of(id, self~tvHandle(parts[1]), parts[2], "", ctl, event)
      end
      when kind == "TAB" then args = .array~of(id, hwnd, dlg~newTab(id))
      when kind == "UPDOWN" then args = .array~of(parts[1], parts[2], id, hwnd, dlg~newUpDown(id))
      when kind == "TRACKBAR" then do              -- wParam: the code and the position; lParam: the track bar
        codes = "DRAG 5 ENDTRACK 8 POSITION 4"
        if entry[4] \== parts[2] then iterate
        args = .array~of(parts[1] * 65536 + codes~word(codes~wordPos(parts[2]) + 1), hwnd)
      end
      when kind == "DATETIMEPICKER" then args = .array~of(self~dateTimeOf(extra), .true, id, hwnd, event, dlg~newDateTimePicker(id))
      when kind == "MONTHCALENDAR" then do
        if event == "GETDAYSTATE" then do         -- (start, count, id, hwnd): the method answers a day state buffer
          buffer = self~invokeResult(dlg, entry[3], .array~of(self~dateTimeOf(parts[1]), parts[2], id, hwnd))
          if buffer \== .nil then if buffer~isA(.String) then self~ctlOp(d, id, "mc.dayStateFrom", parts[1], buffer)
          iterate
        end
        args = .array~of(self~dateTimeOf(parts[1]), self~dateTimeOf(parts[2]), id, hwnd)
      end
      otherwise args = .array~of(id, extra)
    end
    self~invoke(dlg, entry[3], args)
  end

/*---- UpDown --------------------------------------------------------------------------*/
::method en_connectUpDownEvent unguarded
  use arg self_, msg, a
  return self~connectNotify(self_, a, "DELTAPOS DELTAPOS")
::method ud_setRange unguarded
  use arg self_, msg, a
  low = 0
  high = 100
  if a~hasIndex(1) then do
    first = a[1]
    if first~isA(.String) then low = first
    else do
      low = first~min
      high = first~max
    end
  end
  if a~hasIndex(2) then high = a[2]
  self~wb_sendWinIntMsg(self_, "", .array~of(1135, low, high))
  return 0
::method ud_getRange unguarded
  use arg self_
  parse value self~op(self_, "ud.range") with low high
  d = .directory~new
  d~min = low
  d~max = high
  return d
::method ud_getPosition unguarded
  use arg self_
  return self~wb_sendWinIntMsg(self_, "", .array~of(1138, 0, 0))
::method ud_getBuddy unguarded
  use arg self_
  p = self_~oodPeer
  id = self~op(self_, "ud.buddy")
  if id == "" | id == 0 then return .nil
  return p~dlg~rexxSelf~newEdit(id)
::method ud_setBuddy unguarded
  use arg self_, msg, a
  old = self~ud_getBuddy(self_)
  self~op(self_, "ud.buddy", a[1]~id)
  return old
::method ud_setAcceleration unguarded
  return .true

/*---- TrackBar, DateTimePicker ---------------------------------------------------------*/
::method trckbar_getRange unguarded
  use arg self_
  d = .directory~new
  d~min = self~wb_sendWinIntMsg(self_, "", .array~of(1025, 0, 0))
  d~max = self~wb_sendWinIntMsg(self_, "", .array~of(1026, 0, 0))
  return d
::method en_connectDateTimePickerEvent unguarded
  use arg self_, msg, a
  return self~connectNotify(self_, a, "DATETIMECHANGE DATETIMECHANGE")
::method dateTimeOf unguarded      -- 2026-11-14T20:36:00 as a .DateTime
  use arg iso
  parse var iso year "-" month "-" day "T" hours ":" minutes ":" seconds
  return .DateTime~new(year, month, day, hours, minutes, seconds)
/*---- Month calendar --------------------------------------------------------------------
   One month is shown and one day is selected (no MULTI selection).  A DayState is a bit
   mask of the bold days of one month; a day state buffer is the masks as words. */
::method mc_date unguarded
  use arg self_
  return self~dateTimeOf(self~op(self_, "mc.get"))
::method mc_setDate unguarded
  use arg self_, date
  self~op(self_, "mc.set", date~isoDate~left(19))
  return 0
::method mc_getMinRect unguarded   -- getMinRect(rect): right and bottom are the size the calendar needs
  use arg self_, msg, a
  parse value self~op(self_, "mc.minRect") with width height .
  if width == "" then return .false
  a[1]~left = 0
  a[1]~top = 0
  a[1]~right = width
  a[1]~bottom = height
  return .true
::method mc_sizeRectToMin unguarded
  use arg self_, msg, a
  parse value self~op(self_, "mc.minRect") with width height .
  if width == "" then return .false
  a[1]~right = a[1]~left + width
  a[1]~bottom = a[1]~top + height
  return a[1]
::method mc_setRange unguarded     -- setRange(array of two DateTime; .nil for no limit)
  use arg self_, msg, a
  range = a[1]
  low = ""
  high = ""
  if range~hasIndex(1) then if range[1] \== .nil then low = range[1]~isoDate~left(19)
  if range~hasIndex(2) then if range[2] \== .nil then high = range[2]~isoDate~left(19)
  self~op(self_, "mc.range", low, high)
  return .true
::method mc_getRange unguarded     -- getRange(array): "none", "min", "max" or "both"
  use arg self_, msg, a
  parse value self~op(self_, "mc.getRange") with low (self~sep) high
  if low \== "" then a[1][1] = self~dateTimeOf(low)
  if high \== "" then a[1][2] = self~dateTimeOf(high)
  if low \== "" & high \== "" then return "both"
  if low \== "" then return "min"
  if high \== "" then return "max"
  return "none"
::method mc_getMonthRange unguarded    -- getMonthRange(array, span): the first and last day shown; answers the months
  use arg self_, msg, a
  span = "D"
  if self~opt(a, 2)~upper~abbrev("P") then span = "P"
  sep = self~sep
  parse value self~op(self_, "mc.months", span) with first (sep) last (sep) count
  if first == "" then return 0
  a[1][1] = self~dateTimeOf(first)
  a[1][2] = self~dateTimeOf(last)
  return count
::method mc_getSelectionRange unguarded
  use arg self_, msg, a
  day = self~dateTimeOf(self~op(self_, "mc.get"))
  a[1][1] = day
  a[1][2] = day
  return .true
::method mc_setSelectionRange unguarded
  use arg self_, msg, a
  self~op(self_, "mc.set", a[1][1]~isoDate~left(19))
  return .true
::method mc_getToday unguarded
  use arg self_
  return self~dateTimeOf(self~op(self_, "mc.today"))
::method mc_setToday unguarded
  use arg self_, msg, a
  if a~hasIndex(1) then self~op(self_, "mc.today", a[1]~isoDate~left(19))
  else self~op(self_, "mc.today", .DateTime~new~isoDate~left(19))
  return 0
::method mc_setDayState unguarded  -- setDayState(array of DayState): for the months from the first one shown
  use arg self_, msg, a
  masks = ""
  do state over a[1]
    masks = masks state~value
  end
  self~op(self_, "mc.dayState", masks~strip)
  return .true
::method mc_setDayStateQuick unguarded
  use arg self_, msg, a
  masks = ""
  do i = 1 to 3
    if a~hasIndex(i) then masks = masks a[i]~value
    else masks = masks 0
  end
  self~op(self_, "mc.dayState", masks~strip)
  return .true
::method mc_getFirstDayOfWeek unguarded    -- 0 Monday ... 6 Sunday
  use arg self_
  return self~op(self_, "mc.firstDay")
::method mc_setFirstDayOfWeek unguarded
  use arg self_, msg, a
  old = self~op(self_, "mc.firstDay")
  day = a[1]
  if \day~datatype("W") then do
    names = "MONDAY TUESDAY WEDNESDAY THURSDAY FRIDAY SATURDAY SUNDAY"
    day = names~wordPos(day~upper) - 1
    if day < 0 then return old
  end
  self~op(self_, "mc.firstDay", day)
  return old
::method mc_getCalendarCount unguarded
  return 1
::method mc_getCurrentView unguarded
  return "Monthly"
::method mc_setCurrentView unguarded
  return .false
::method mc_getCalendarBorder unguarded
  return 4
::method mc_setCalendarBorder unguarded
  return 0
::method mc_getCALID unguarded
  return "GREGORIAN"
::method mc_setCALID unguarded
  return 0
::method mc_getColor unguarded
  return -1
::method mc_setColor unguarded
  return -1
::method mc_getStyle unguarded
  return ""
::method mc_addRemoveStyle unguarded
  return ""
::method mc_replaceStyle unguarded
  return ""
::method mc_hitTestInfo unguarded  -- hitTestInfo(point | x, y): a directory: hit, and date for a day
  use arg self_, msg, a
  if a[1]~isA(.String) then do
    x = a[1]
    y = a[2]
  end
  else do
    x = a[1]~x
    y = a[1]~y
  end
  answer = self~op(self_, "mc.hit", x, y)
  info = .directory~new
  what = answer~word(1)
  select
    when what == "DATE" then do
      info~hit = "CalendarDate"
      info~date = self~dateTimeOf(answer~word(2))
    end
    when what == "PREV" then info~hit = "TitleButtonPrev"
    when what == "NEXT" then info~hit = "TitleButtonNext"
    when what == "TITLE" then info~hit = "TitleBackground"
    when what == "TODAY" then info~hit = "TodayLink"
    otherwise info~hit = "NoWhere"
  end
  return info
::method ds_init unguarded         -- .DayState~new(day, day ...): those days of the month are bold
  use arg self_, msg, a
  mask = 0
  do i = 1 to a~size               -- (an empty array has no last index)
    if \a~hasIndex(i) then iterate
    day = a[i]
    if \day~datatype("W") then raise syntax 93.905 array(i, day)
    if day < 1 | day > 31 then raise syntax 93.907 array(i, 1, 31, day)
    bit = 2 ** (day - 1)
    if mask // (bit * 2) < bit then mask = mask + bit
  end
  self_~oodPeer = mask
  return 0
::method ds_value unguarded
  use arg self_
  return self_~oodPeer
::method dss_makeDayStateBuffer unguarded  -- .DayStates~makeDayStateBuffer(array of DayState)
  use arg self_, msg, a
  masks = ""
  do state over a[1]
    masks = masks state~value
  end
  return masks~strip
::method dss_quickDayStateBuffer unguarded
  use arg self_, msg, a
  masks = ""
  do i = 1 to 3
    if a~hasIndex(i) then masks = masks a[i]~value
    else masks = masks 0
  end
  return masks~strip

::method dtp_getDateTime unguarded
  use arg self_
  return self~dateTimeOf(self~op(self_, "dtp.get"))
::method dtp_setDateTime unguarded
  use arg self_, msg, a
  self~op(self_, "dtp.set", a[1]~isoDate~left(19))
  return 0
::method dtp_setFormat unguarded
  return .true

/*---- bitmaps and images --------------------------------------------------------------------*/
::method ctlOpWhenLive unguarded   -- an operation on a control: now, or when the dialog starts
  use arg d, id, name, a = "", b = "", c = ""
  if d~live then return self~web~op(d~key, id, name, a, b, c)
  d~deferred~append(.array~of(id, name, a, b, c))
  return 1

::method imageKey                  -- a bitmap file, or a handle of loadBitmap, known to the page; "" if not there
  expose bitmaps
  use arg source
  if \var("BITMAPS") then bitmaps = .directory~new
  if \source~isA(.String) then return ""
  if source == "" | source == 0 then return ""
  if bitmaps~hasIndex(source) then return bitmaps[source]      -- a handle
  file = self~path(source)
  if self~web~hasImage(file) == 1 then return file
  if \SysIsFile(file) then return ""
  stream = .stream~new(file)
  if stream~open("READ") \== "READY:" then return ""
  bytes = stream~charIn(1, stream~chars)
  stream~close
  kind = "bmp"
  ext = filespec("EXTENSION", file)~lower
  if "png gif jpg jpeg ico cur svg"~wordPos(ext) > 0 then kind = ext
  if kind == "jpg" then kind = "jpeg"
  if kind == "ico" | kind == "cur" then kind = "x-icon"
  if kind == "svg" then kind = "svg+xml"
  self~web~image(file, "data:image/"kind";base64,"bytes~encodeBase64)
  return file

::method winex_loadBitmap          -- loadBitmap(file): a handle, 0 if the file is not there
  expose bitmaps
  use arg self_, msg, a
  key = self~imageKey(a[1])
  if key == "" then return 0
  handle = "0x"d2x(8192 + bitmaps~items)~right(16, "0")
  bitmaps[handle] = key
  return handle
::method winex_removeBitmap unguarded
  return .true

::method bitmapButton unguarded    -- installBitmapButton / changeBitmapButton
  use arg self_, id, normal, focused, selected, disabled, style
  sep = self~sep
  other = self~imageKey(focused) || sep || self~imageKey(selected) || sep || self~imageKey(disabled)
  self_~oodPeer~store["BMP" id] = self~imageKey(normal)       -- (getBitmapSize, drawBitmap)
  self~ctlOpWhenLive(self_~oodPeer, id, "bitmap", self~imageKey(normal), other, style~upper)
  return 0
::method argOr unguarded
  use arg a, i
  if a~hasIndex(i) then return a[i]
  return ""
::method dlgext_installBitmapButton unguarded   -- (id, msgToRaise, normal, focused, selected, disabled, style)
  use arg self_, msg, a
  id = self~resolveId(self_, a[1])
  if id < 1 then return 1
  method = self~opt(a, 2)
  if method \== "" then self~addCommand(self_, id, 0, method)
  return self~bitmapButton(self_, id, a[3], self~argOr(a, 4), self~argOr(a, 5), self~argOr(a, 6), self~opt(a, 7))
::method dlgext_changeBitmapButton unguarded    -- (id, normal, focused, selected, disabled, style)
  use arg self_, msg, a
  id = self~resolveId(self_, a[1])
  if id < 1 then return 1
  return self~bitmapButton(self_, id, a[2], self~argOr(a, 3), self~argOr(a, 4), self~argOr(a, 5), self~opt(a, 6))

::method dyndlg_createStaticImage unguarded
  use arg self_, msg, a
  id = self~addItem(self_, "IMAGE", a[1], a[2], a[3], a[4], a[5], self~opt(a, 6), "")
  if id < -1 then return id
  return 0

/* .Image: an image file; the object's state is the file's key in the page. */
::method image_getImage_cls unguarded           -- .Image~getImage(file, type, size, flags)
  use arg self_, msg, a
  return self_~new(self~imageKey(a[1]))
::method image_init unguarded
  use arg self_, msg, a
  self_~oodPeer = a[1]
  return 0
::method image_isNull unguarded
  use arg self_
  return self_~oodPeer == ""
::method image_handle unguarded
  use arg self_
  return self_~oodPeer
::method image_release unguarded
  return 0
::method image_systemErrorCode unguarded
  return 0
::method image_colorRef_cls unguarded           -- colorRef(r, g, b)
  use arg self_, msg, a
  red = 0; green = 0; blue = 0
  if a~hasIndex(1) then red = a[1]
  if a~hasIndex(2) then green = a[2]
  if a~hasIndex(3) then blue = a[3]
  return red + green * 256 + blue * 65536
::method image_getRValue_cls unguarded
  use arg self_, msg, a
  return a[1] // 256
::method image_getGValue_cls unguarded
  use arg self_, msg, a
  return (a[1] % 256) // 256
::method image_getBValue_cls unguarded
  use arg self_, msg, a
  return (a[1] % 65536) // 256
::method setImageOf unguarded
  use arg self_, image
  key = ""
  if image \== .nil then key = image~oodPeer
  p = self_~oodPeer
  self~ctlOpWhenLive(p~dlg, p~id, "image", key)
  return .nil
::method stc_setImage unguarded
  use arg self_, msg, a
  return self~setImageOf(self_, a[1])
::method stc_setIcon unguarded
  use arg self_, msg, a
  return self~setImageOf(self_, a[1])

/*---- image lists: kept, counted, accepted by the controls; the page does not draw item icons yet --*/
::method il_create_cls unguarded   -- .ImageList~create(size, flags, count, grow)
  use arg self_, msg, a
  state = .directory~new
  state~images = .array~new
  state~size = .Size~new(16, 16)
  if a~hasIndex(1) then state~size = a[1]
  return self_~new(state)
::method il_init unguarded
  use arg self_, msg, a
  self_~oodPeer = a[1]
  return 0
::method il_add unguarded
  use arg self_, msg, a
  images = self_~oodPeer~images
  images~append(a[1])
  return images~items - 1
::method il_addMasked unguarded
  forward message "il_add"
::method il_addIcon unguarded
  forward message "il_add"
::method il_addImages unguarded
  use arg self_, msg, a
  images = self_~oodPeer~images
  do image over a[1]
    images~append(image)
  end
  return images~items - 1
::method il_getCount unguarded
  use arg self_
  return self_~oodPeer~images~items
::method il_getImageSize unguarded
  use arg self_
  return self_~oodPeer~size
::method il_handle unguarded
  use arg self_
  return "0x"d2x(self_~oodPeer~identityHash~abs)~right(16, "0")
::method il_isNull unguarded
  return .false
::method il_release unguarded
  return 0
::method il_remove unguarded
  use arg self_, msg, a
  images = self_~oodPeer~images
  if a[1] < 0 | a[1] >= images~items then return .false
  images~delete(a[1] + 1)
  return .true
::method il_removeAll unguarded
  use arg self_
  self_~oodPeer~images~empty
  return .true
::method il_duplicate unguarded
  use arg self_
  state = .directory~new
  state~images = self_~oodPeer~images~copy
  state~size = self_~oodPeer~size
  return self_~class~new(state)
::method image_fromFiles_cls unguarded
  use arg self_, msg, a
  out = .array~new
  do file over a[1]
    out~append(self_~new(self~imageKey(file)))
  end
  return out
::method setImageListOf unguarded  -- the control keeps its image list; the previous one is the answer
  use arg self_, list
  p = self_~oodPeer
  key = p~id "imagelist"
  old = p~dlg~store[key]
  p~dlg~store[key] = list
  if old == .nil then return .nil
  return old
::method lv_setImageList unguarded
  use arg self_, msg, a
  return self~setImageListOf(self_, a[1])
::method tv_setImageList unguarded
  use arg self_, msg, a
  return self~setImageListOf(self_, a[1])
::method tab_setImageList unguarded
  use arg self_, msg, a
  return self~setImageListOf(self_, a[1])
/* state / state=: CHECKED UNCHECKED INDETERMINATE (check boxes and radio buttons), PUSHED
   NOTPUSHED, FOCUS (bc_getState and bc_setState of oodControl.cpp). */
::method bc_getState unguarded
  use arg self_
  p = self_~oodPeer
  kind = p~dlg~kinds[p~id]~word(1)
  state = ""
  if kind == "CHECK" | kind == "RADIO" then do
    check = self~winMsg(p~dlg, p~id, 240)
    if check == 1 then state = "CHECKED "
    else if check == 2 then state = "INDETERMINATE "
    else state = "UNCHECKED "
  end
  bits = self~winMsg(p~dlg, p~id, 242)
  if bits~datatype("W") then do
    if bits // 8 >= 4 then state = state"PUSHED "
    if bits // 16 >= 8 then state = state"FOCUS "
  end
  return state~strip
::method bc_setState unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  kind = p~dlg~kinds[p~id]~word(1)
  boxes = (kind == "CHECK" | kind == "RADIO")
  do token over self~opt(a, 1)~upper~makeArray(" ")
    select
      when token == "CHECKED" then if boxes then self~winMsg(p~dlg, p~id, 241, 1)
      when token == "UNCHECKED" then if boxes then self~winMsg(p~dlg, p~id, 241, 0)
      when token == "INDETERMINATE" then if kind == "CHECK" then self~winMsg(p~dlg, p~id, 241, 2)
      when token == "FOCUS" then self~op(self_, "focus")
      when token == "PUSHED" then self~winMsg(p~dlg, p~id, 243, 1)
      when token == "NOTPUSHED" then self~winMsg(p~dlg, p~id, 243, 0)
      otherwise nop
    end
  end
  return 0
::method bc_setImageList unguarded     -- setImageList(imageList, margin, align)
  use arg self_, msg, a
  p = self_~oodPeer
  if a~hasIndex(2) then p~dlg~store[p~id "imagelist margin"] = a[2]
  align = self~opt(a, 3)~upper
  if align \== "" then do
    if "LEFT RIGHT TOP BOTTOM CENTER"~wordPos(align) == 0 then raise syntax 93.900 array('setImageList: the alignment "'a[3]'" is not LEFT, RIGHT, TOP, BOTTOM or CENTER')
    p~dlg~store[p~id "imagelist align"] = align
  end
  return self~setImageListOf(self_, a[1])
::method getImageListOf unguarded
  use arg self_
  p = self_~oodPeer
  list = p~dlg~store[p~id "imagelist"]
  if list == .nil then return .nil
  return list
::method bc_getImageList unguarded     -- a directory: imageList, rect (the margins), alignment, alignmentKeyword; .nil if none
  use arg self_
  p = self_~oodPeer
  list = self~getImageListOf(self_)
  if list == .nil then return .nil
  info = .directory~new
  info~imageList = list
  info~rect = p~dlg~store[p~id "imagelist margin"]
  if info~rect == .nil then info~rect = self~classOf("Rect")~new
  keyword = p~dlg~store[p~id "imagelist align"]
  if keyword == .nil then keyword = "LEFT"
  info~alignmentKeyword = keyword
  info~alignment = "LEFT RIGHT TOP BOTTOM CENTER"~wordPos(keyword) - 1
  return info
::method lv_getImageList unguarded
  use arg self_
  return self~getImageListOf(self_)
::method tv_getImageList unguarded
  use arg self_
  return self~getImageListOf(self_)
::method tab_getImageList unguarded
  use arg self_
  return self~getImageListOf(self_)

/*---- tool tips: the browser's own, set as the control's title ---------------------------------------*/
::method pbdlg_createToolTip unguarded   -- createToolTip(id, style): a ToolTip object
  use arg self_, msg, a
  d = self_~oodPeer
  id = self~resolveId(self_, a[1])
  if id < 1 then return .nil
  cached = d~controls[id "TOOLTIP"]
  if cached \== .nil then return cached
  tip = self~classOf("ToolTip")~new(self_, id, .OodCtl~new(d, id, "TOOLTIP"))
  d~controls[id "TOOLTIP"] = tip
  return tip
::method pbdlg_newToolTip unguarded
  use arg self_, msg, a
  cached = self_~oodPeer~controls[self~resolveId(self_, a[1]) "TOOLTIP"]
  if cached == .nil then return .nil
  return cached
/* A ToolTip is not a control of the page.  Its tools are kept here, by the tool tip's ID,
   in the dialog's store: "TT" id -> a table of tool key -> directory (tool, id, text,
   flags, rect, userData).  A tool is a whole window (key "w" hostId) or a rectangle of a
   window (key "r" hostId "." toolId).  The page decides when a tip is due and sends
   TT events (ttEvent); see the comment "Tool tips" in oodialog-web.js. */
::method ttTools unguarded         -- the tool table of a ToolTip object
  use arg self_
  p = self_~oodPeer
  tools = p~dlg~store["TT" p~id]
  if tools == .nil then do
    tools = .table~new
    p~dlg~store["TT" p~id] = tools
    p~dlg~store["TTOBJ" p~id] = self_
  end
  return tools
::method ttHostId unguarded        -- the page's ID of a window object: 0 for a dialog
  use arg window
  peer = window~oodPeer
  if peer~isA(.OodCtl) then return peer~id
  return 0
::method ttJson unguarded          -- a text as a JSON string
  use arg text
  text = text~changeStr("\", "\\")~changeStr('"', '\"')~changeStr("0d0a"x, "\n")~changeStr("0a"x, "\n")~changeStr("0d"x, "")~changeStr("09"x, "\t")
  return '"'text'"'
::method ttAdd unguarded           -- keep a tool and tell the page
  use arg self_, key, entry
  p = self_~oodPeer
  tools = self~ttTools(self_)
  if tools~hasIndex(key) then entry~seq = tools[key]~seq
  else do
    seq = p~dlg~store["TTSEQ" p~id]
    if seq == .nil then seq = 0
    p~dlg~store["TTSEQ" p~id] = seq + 1
    entry~seq = seq + 1
  end
  tools[key] = entry
  json = '{"key":"'key'","host":'self~ttHostId(entry~tool)',"rect":'
  if entry~rect == .nil then json = json"null"
  else json = json"["entry~rect~left","entry~rect~top","entry~rect~right","entry~rect~bottom"]"
  json = json',"text":'
  if entry~text == .nil then json = json"null}"
  else json = json || self~ttJson(entry~text)"}"
  self~ctlOpWhenLive(p~dlg, p~id, "tip.add", json)
  self~ttSendEvents(self_)
  return .true
::method ttEntry unguarded
  use arg tool, id, text, flags, rect, userData
  entry = .directory~new
  entry~tool = tool
  entry~id = id                    -- .nil: the tool is the window itself
  entry~text = text                -- .nil: asked from the program each time
  entry~flags = flags
  entry~rect = rect
  entry~userData = userData
  return entry
::method ttTextArg unguarded       -- a text argument: omitted, empty or TEXTCALLBACK is "ask the program", as upstream
  use arg a, i
  if \a~hasIndex(i) then return .nil
  if a[i] == "" | a[i]~upper == "TEXTCALLBACK" then return .nil
  return a[i]
::method tt_addTool unguarded      -- addTool(window, text, flags, userData)
  use arg self_, msg, a
  tool = a[1]
  if \tool~hasMethod("oodPeer") then return .false
  userData = .nil
  if a~hasIndex(4) then userData = a[4]
  return self~ttAdd(self_, "w"self~ttHostId(tool), self~ttEntry(tool, .nil, self~ttTextArg(a, 2), self~opt(a, 3), .nil, userData))
::method tt_addToolRect unguarded  -- addToolRect(window, id, rect, text, flags, userData)
  use arg self_, msg, a
  tool = a[1]
  if \tool~hasMethod("oodPeer") then return .false
  id = self~resolveId(self_~oodPeer~dlg~rexxSelf, a[2])
  userData = .nil
  if a~hasIndex(6) then userData = a[6]
  return self~ttAdd(self_, "r"self~ttHostId(tool)"."id, self~ttEntry(tool, id, self~ttTextArg(a, 4), self~opt(a, 5), a[3], userData))
::method tt_addToolEx unguarded    -- addToolEx(toolInfo)
  use arg self_, msg, a
  info = a[1]~oodPeer
  if info~id == .nil then key = "w"self~ttHostId(info~tool)
  else key = "r"self~ttHostId(info~tool)"."info~id
  return self~ttAdd(self_, key, self~ttEntry(info~tool, info~id, info~text, info~flags, info~rect, info~userData))
::method tt_delTool unguarded      -- delTool(window, id)
  use arg self_, msg, a
  if a~hasIndex(2) then key = "r"self~ttHostId(a[1])"."self~resolveId(self_~oodPeer~dlg~rexxSelf, a[2])
  else key = "w"self~ttHostId(a[1])
  self~ttTools(self_)~remove(key)
  self~ctlOpWhenLive(self_~oodPeer~dlg, self_~oodPeer~id, "tip.del", key)
  return 0
::method tt_getToolCount unguarded
  use arg self_
  return self~ttTools(self_)~items
::method ttInfoOf unguarded        -- a tool as a ToolInfo object
  use arg entry
  return self~classOf("ToolInfo")~new(entry~tool, entry~id, entry~text, entry~flags, entry~rect, entry~userData)
::method tt_enumTools unguarded    -- enumTools(index): the tool at that index (from 1, in the order added) as a ToolInfo; .nil past the end
  use arg self_, msg, a
  index = 1
  if a~hasIndex(1) then index = a[1]
  if index < 1 then raise syntax 93.907 array(1, 1, 4294967295, index)
  found = 0
  do entry over self~ttTools(self_)~allItems
    if entry~seq > 0 then found += 1
  end
  if index > found then return .nil
  seqs = .array~new
  do entry over self~ttTools(self_)~allItems
    seqs~append(entry~seq)
  end
  wanted = seqs~sortWith(.NumericComparator~new)[index]
  do entry over self~ttTools(self_)~allItems
    if entry~seq == wanted then return self~ttInfoOf(entry)
  end
  return .nil
/* hitTestInfo(toolInfo, point | x, y): is a tool of the ToolInfo's window at that point of
   its client area?  If so the ToolInfo is filled with that tool. */
::method tt_hitTestInfo unguarded
  use arg self_, msg, a
  info = a[1]~oodPeer
  if a[2]~isA(.String) then parse value a[2] a[3] with x y .
  else do
    x = a[2]~x
    y = a[2]~y
  end
  host = self~ttHostId(info~tool)
  hit = .nil
  do entry over self~ttTools(self_)~allItems
    if self~ttHostId(entry~tool) \== host then iterate
    if entry~rect == .nil then do
      if x < 0 | y < 0 then iterate
      size = self~classOf("Size")~new
      if entry~tool~hasMethod("getRealSize") then size = entry~tool~getRealSize
      if size~width > 0 then if x >= size~width | y >= size~height then iterate
      if hit == .nil then hit = entry
    end
    else if x >= entry~rect~left & x < entry~rect~right & y >= entry~rect~top & y < entry~rect~bottom then hit = entry
  end
  if hit == .nil then return .false
  info~id = hit~id
  info~text = hit~text
  info~flags = hit~flags
  info~rect = hit~rect
  info~userData = hit~userData
  return .true
::method tt_getToolInfo unguarded  -- getToolInfo(window, id)
  use arg self_, msg, a
  if a~hasIndex(2) then key = "r"self~ttHostId(a[1])"."self~resolveId(self_~oodPeer~dlg~rexxSelf, a[2])
  else key = "w"self~ttHostId(a[1])
  entry = self~ttTools(self_)[key]
  if entry == .nil then return .nil
  return self~ttInfoOf(entry)
::method tt_updateTipText unguarded    -- updateTipText(toolInfo): the tool's text is the ToolInfo's text
  use arg self_, msg, a
  info = a[1]~oodPeer
  if info~id == .nil then key = "w"self~ttHostId(info~tool)
  else key = "r"self~ttHostId(info~tool)"."info~id
  entry = self~ttTools(self_)[key]
  if entry == .nil then return 0
  entry~text = info~text
  if entry~text == .nil then self~ctlOpWhenLive(self_~oodPeer~dlg, self_~oodPeer~id, "tip.text", key, self~sep)
  else self~ctlOpWhenLive(self_~oodPeer~dlg, self_~oodPeer~id, "tip.text", key, entry~text)
  return 0
::method tt_setToolInfo unguarded
  forward message "tt_updateTipText"
::method tt_setTitle unguarded     -- setTitle(title, icon)
  use arg self_, msg, a
  self~ctlOpWhenLive(self_~oodPeer~dlg, self_~oodPeer~id, "tip.title", self~opt(a, 1))
  self_~oodPeer~dlg~store["TTTITLE" self_~oodPeer~id] = self~opt(a, 1)
  return .true
::method tt_getTitle unguarded
  use arg self_
  title = self_~oodPeer~dlg~store["TTTITLE" self_~oodPeer~id]
  info = .directory~new
  info~icon = "NONE"
  info~title = ""
  if title \== .nil then info~title = title
  return info
::method tt_activate unguarded     -- activate(.true | .false)
  use arg self_, msg, a
  on = .true
  if a~hasIndex(1) then on = (a[1] == .true)
  self~ctlOpWhenLive(self_~oodPeer~dlg, self_~oodPeer~id, "tip.active", on)
  return 0
::method tt_setMaxTipWidth unguarded   -- setMaxTipWidth(pixels): the width before; -1 for none
  use arg self_, msg, a
  p = self_~oodPeer
  old = p~dlg~store["TTWIDTH" p~id]
  if old == .nil then old = -1
  p~dlg~store["TTWIDTH" p~id] = a[1]
  self~ctlOpWhenLive(p~dlg, p~id, "tip.maxWidth", a[1])
  return old
::method tt_getMaxTipWidth unguarded
  use arg self_
  old = self_~oodPeer~dlg~store["TTWIDTH" self_~oodPeer~id]
  if old == .nil then return -1
  return old
::method ttDelays unguarded        -- AUTOPOP INITIAL RESHOW in milliseconds
  use arg self_
  p = self_~oodPeer
  delays = p~dlg~store["TTDELAY" p~id]
  if delays == .nil then do
    delays = .directory~new
    delays~autopop = 5000
    delays~initial = 500
    delays~reshow = 100
    p~dlg~store["TTDELAY" p~id] = delays
  end
  return delays
::method tt_getDelayTime unguarded -- getDelayTime(AUTOPOP | INITIAL | RESHOW)
  use arg self_, msg, a
  which = self~opt(a, 1)~upper
  if which == "" then which = "AUTOPOP"
  time = self~ttDelays(self_)[which]
  if time == .nil then raise syntax 93.900 array('the delay "'which'" is not AUTOPOP, INITIAL or RESHOW')
  return time
::method tt_setDelayTime unguarded -- setDelayTime(which, milliseconds): AUTOMATIC sets all three from one time
  use arg self_, msg, a
  which = self~opt(a, 1)~upper
  if which == "" then which = "AUTOPOP"
  time = -1
  if a~hasIndex(2) then time = a[2]
  delays = self~ttDelays(self_)
  if which == "AUTOMATIC" then do
    if time < 0 then time = 500
    delays~initial = time
    delays~autopop = time * 10
    delays~reshow = time % 5
  end
  else do
    if \delays~hasIndex(which) then raise syntax 93.900 array('the delay "'which'" is not AUTOPOP, INITIAL, RESHOW or AUTOMATIC')
    if time < 0 then time = .directory~of(("AUTOPOP", 5000), ("INITIAL", 500), ("RESHOW", 100))[which]
    delays[which] = time
  end
  self~ctlOpWhenLive(self_~oodPeer~dlg, self_~oodPeer~id, "tip.delay", delays~initial)
  return 0
::method tt_pop unguarded          -- pop: the tip goes
  use arg self_
  self~ctlOpWhenLive(self_~oodPeer~dlg, self_~oodPeer~id, "tip.pop")
  return 0
::method tt_popUp unguarded
  return 0
::method tt_update unguarded
  return 0
::method tt_hasCurrentTool unguarded
  use arg self_
  p = self_~oodPeer
  if \p~dlg~live then return .false
  return (self~ctlOp(p~dlg, p~id, "tip.shown") \== "")
::method tt_getCurrentTool unguarded   -- getCurrentToolInfo: the tool whose tip is shown; .nil if none
  use arg self_
  p = self_~oodPeer
  if \p~dlg~live then return .nil
  parse value self~ctlOp(p~dlg, p~id, "tip.shown") with key (self~sep) .
  if key == "" then return .nil
  entry = self~ttTools(self_)[key]
  if entry == .nil then return .nil
  return self~ttInfoOf(entry)
::method tt_getText unguarded      -- getText(toolInfo): the tool's text goes into the ToolInfo
  use arg self_, msg, a
  info = a[1]~oodPeer
  if info~id == .nil then key = "w"self~ttHostId(info~tool)
  else key = "r"self~ttHostId(info~tool)"."info~id
  entry = self~ttTools(self_)[key]
  if entry == .nil then return 0
  info~text = entry~text
  return 0
::method tt_trackActivate unguarded
  return 0
::method tt_trackPosition unguarded
  return 0
::method tt_setWindowTheme unguarded
  return 0
/* The tip's margins and colours: kept, and drawn by the page. */
::method ttLook unguarded
  use arg self_
  p = self_~oodPeer
  look = p~dlg~store["TTLOOK" p~id]
  if look == .nil then do
    look = .directory~new
    look~margin = self~classOf("Rect")~new(0, 0, 0, 0)
    look~back = ""                   -- "": the usual colours
    look~fore = ""
    p~dlg~store["TTLOOK" p~id] = look
  end
  return look
::method ttLookSend unguarded
  use arg self_
  p = self_~oodPeer
  look = self~ttLook(self_)
  m = look~margin
  self~ctlOpWhenLive(p~dlg, p~id, "tip.margin", m~left m~top m~right m~bottom)
  self~ctlOpWhenLive(p~dlg, p~id, "tip.colors", self~colorOf(look~back), self~colorOf(look~fore))
  return 0
::method tt_setMargin unguarded    -- setMargin(rect): the space around the text, in pixels
  use arg self_, msg, a
  m = a[1]
  look = self~ttLook(self_)
  look~margin = self~classOf("Rect")~new(m~left, m~top, m~right, m~bottom)
  return self~ttLookSend(self_)
::method tt_getMargin unguarded
  use arg self_
  m = self~ttLook(self_)~margin
  return self~classOf("Rect")~new(m~left, m~top, m~right, m~bottom)
::method tt_setTipBkColor unguarded    -- a COLORREF
  use arg self_, msg, a
  look = self~ttLook(self_)
  look~back = self~number(a[1])
  return self~ttLookSend(self_)
::method tt_setTipTextColor unguarded
  use arg self_, msg, a
  look = self~ttLook(self_)
  look~fore = self~number(a[1])
  return self~ttLookSend(self_)
::method tt_getTipBkColor unguarded    -- the colour set, else the page's usual white
  use arg self_
  v = self~ttLook(self_)~back
  if v == "" then return 16777215
  return v
::method tt_getTipTextColor unguarded  -- the colour set, else the page's usual #333333
  use arg self_
  v = self~ttLook(self_)~fore
  if v == "" then return 3355443
  return v
/* adjustRect(rect, larger): larger is from a text rectangle to the tip window's, else the
   reverse.  The tip is the text plus the page's padding (7 px at the sides, 3 px above and
   below), the margins and a 1 px border. */
::method tt_adjustRect unguarded
  use arg self_, msg, a
  r = a[1]
  m = self~ttLook(self_)~margin
  sign = -1
  if a~hasIndex(2) then if a[2] then sign = 1
  r~left -= sign * (8 + m~left)
  r~top -= sign * (4 + m~top)
  r~right += sign * (8 + m~right)
  r~bottom += sign * (4 + m~bottom)
  return .true
::method ttKeyOf unguarded         -- the key of a tool given as (window, id): the rectangle tool, else the window tool
  use arg self_, a, at
  host = self~ttHostId(a[at])
  if a~hasIndex(at + 1) then return "r"host"."a[at + 1]
  return "w"host
::method tt_getBubbleSize unguarded    -- getBubbleSize(tool, id): the .Size of the tip of that tool's text
  use arg self_, msg, a
  p = self_~oodPeer
  tools = self~ttTools(self_)
  entry = tools[self~ttKeyOf(self_, a, 1)]
  if entry == .nil then if a[1]~isA(.String) then do entry over tools~allItems     -- a tool named by its own ID
    if entry~id == a[1] then leave
    entry = .nil
  end
  if entry == .nil then return self~classOf("Size")~new(0, 0)
  text = entry~text
  if text == .nil then text = ""
  parse value self~ctlOp(p~dlg, p~id, "tip.measure", text) with width height .
  if width == "" then return self~classOf("Size")~new(0, 0)
  return self~classOf("Size")~new(width, height)
::method tt_newToolRect unguarded  -- newToolRect(rect, tool, id): the tool's rectangle in its window; 0
  use arg self_, msg, a
  p = self_~oodPeer
  key = self~ttKeyOf(self_, a, 2)
  entry = self~ttTools(self_)[key]
  if entry == .nil then return 0
  r = a[1]
  entry~rect = self~classOf("Rect")~new(r~left, r~top, r~right, r~bottom)
  self~ctlOpWhenLive(p~dlg, p~id, "tip.toolRect", key, r~left r~top r~right r~bottom)
  return 0
/* manageAtypicalTool(window, events, methods): the events of this tool go to methods of the
   dialog instead of the usual ones.  Events: RELAY NORELAY NEEDTEXT SHOW POP LINKCLICK. */
::method tt_manageAtypicalTool unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  tool = a[1]
  host = self~ttHostId(tool)
  has = .false                       -- (the events of every tool of this window are managed)
  do entry over self~ttTools(self_)~allItems
    if self~ttHostId(entry~tool) == host then has = .true
  end
  if \has then self~ttAdd(self_, "w"host, self~ttEntry(tool, .nil, .nil, "", .nil, .nil))
  managed = .directory~new
  names = .directory~new
  names~relay = "onRelay"
  names~needText = "onNeedText"
  names~show = "onShow"
  names~pop = "onPop"
  names~linkClick = "onLinkClick"
  relay = .true
  if a~hasIndex(2) then do i = 1 to a[2]~items
    event = a[2][i]~upper
    if event == "NORELAY" then do
      relay = .false
      iterate
    end
    if \names~hasIndex(event) then raise syntax 93.900 array('manageAtypicalTool: "'a[2][i]'" is not RELAY, NORELAY, NEEDTEXT, SHOW, POP or LINKCLICK')
    method = names[event]
    if a~hasIndex(3) then if a[3]~hasIndex(i) then if a[3][i] \== "" then method = a[3][i]
    managed[event] = method
  end
  if relay then if \managed~hasIndex("RELAY") then managed~relay = "onRelay"
  p~dlg~store["TTAT" p~id host] = managed
  self~ctlOpWhenLive(p~dlg, p~id, "tip.relay", host, relay)
  self~ttSendEvents(self_)
  return .true
::method ttSendEvents unguarded    -- tell the page which of SHOW and POP somebody wants
  use arg self_
  p = self_~oodPeer
  wanted = ""
  do name over p~dlg~store~allIndexes
    if \name~isA(.String) then iterate
    if name~word(2) \== p~id then iterate
    if name~word(1) == "TTEV" then wanted = wanted name~word(3)
    if name~word(1) == "TTAT" then do event over p~dlg~store[name]~allIndexes
      wanted = wanted event
    end
  end
  self~ctlOpWhenLive(p~dlg, p~id, "tip.events", wanted~strip)
::method en_connectToolTipEvent unguarded  -- connectToolTipEvent(id, event, method, willReply)
  use arg self_, msg, a
  d = self_~oodPeer
  id = self~resolveId(self_, a[1])
  if id < 1 then return .false
  event = self~opt(a, 2)~upper
  names = "LINKCLICK onLinkClick NEEDTEXT onNeedText POP onPop SHOW onShow"
  at = names~wordPos(event)
  if at == 0 then raise syntax 93.900 array('connectToolTipEvent: "'a[2]'" is not LinkClick, NeedText, Pop or Show')
  method = names~word(at + 1)
  if a~hasIndex(3) then if a[3] \== "" then method = a[3]
  d~store["TTEV" id event] = method
  tip = d~store["TTOBJ" id]
  if tip \== .nil then self~ttSendEvents(tip)
  return .true
::method ttEvent unguarded         -- an event of the page's tool tips
  use arg key, ttId, event, extra
  d = self~dialogOf(key)
  if d == .nil then return
  tip = d~store["TTOBJ" ttId]
  if tip == .nil then return
  parse var extra toolKey (self~sep) x (self~sep) y
  entry = self~ttTools(tip)[toolKey]
  if entry == .nil then return
  managed = d~store["TTAT" ttId self~ttHostId(entry~tool)]
  method = .nil
  atypical = .false
  if managed \== .nil then if managed~hasIndex(event) then do
    method = managed[event]
    atypical = .true
  end
  if method == .nil then method = d~store["TTEV" ttId event]
  toolId = entry~tool                -- (a whole window is its own ID)
  if entry~id \== .nil then toolId = entry~id
  dlg = d~rexxSelf
  select
    when event == "NEEDTEXT" then do
      if method == .nil then return
      info = .directory~new
      info~text = ""
      info~userData = entry~userData
      info~flags = entry~flags
      if atypical then self~invoke(dlg, method, .array~of(tip, entry~tool, info, entry~userData, entry~flags))
      else self~invoke(dlg, method, .array~of(toolId, tip, info))
      text = info~text
      if text == .nil then text = ""
      self~ctlOp(d, ttId, "tip.show", text)
    end
    when event == "RELAY" then do
      if method == .nil then return
      self~invoke(dlg, method, .array~of(tip, self~classOf("Point")~new(x, y), "mouseMove", entry~tool))
    end
    otherwise                         -- SHOW, POP
      if method == .nil then return
      if atypical then self~invoke(dlg, method, .array~of(tip, entry~tool, toolId))
      else self~invoke(dlg, method, .array~of(toolId, tip))
  end
/* getToolTips of a tree-view or list-view: the control's own tool tip.  For a tree-view
   the page asks the text of the item under the pointer with the GETINFOTIP notification. */
::method generic_getToolTips unguarded
  use arg self_
  p = self_~oodPeer
  d = p~dlg
  ttId = 60000 + p~id
  cached = d~controls[ttId "TOOLTIP"]
  if cached \== .nil then return cached
  tip = self~classOf("ToolTip")~new(d~rexxSelf, ttId, .OodCtl~new(d, ttId, "TOOLTIP"))
  d~controls[ttId "TOOLTIP"] = tip
  self~ttTools(tip)["tv"p~id] = self~ttEntry(self_, .nil, .nil, "", .nil, .nil)
  self~ttTools(tip)["w"p~id] = self~ttTools(tip)["tv"p~id]
  if d~kinds[p~id]~word(1) == "TREEVIEW" then self~ctlOpWhenLive(d, ttId, "tip.tree", p~id)
  return tip
::method generic_setToolTips unguarded
  return .nil

/* ToolInfo: the description of one tool.  .ToolInfo~new(window, id, text, flags, rect, userData, resource) */
::method ti_init unguarded
  use arg self_, msg, a
  info = .directory~new
  info~tool = a[1]
  info~id = .nil
  if a~hasIndex(2) then info~id = self~resolveId(self~ttDialogOf(a[1]), a[2])
  info~text = self~ttTextArg(a, 3)
  info~flags = self~opt(a, 4)
  info~rect = .nil
  if a~hasIndex(5) then info~rect = a[5]
  info~userData = .nil
  if a~hasIndex(6) then info~userData = a[6]
  info~resource = .nil
  if a~hasIndex(7) then info~resource = a[7]
  self_~oodPeer = info
  return 0
::method ttDialogOf unguarded      -- the dialog object of a window object
  use arg window
  peer = window~oodPeer
  if peer~isA(.OodCtl) then return peer~dlg~rexxSelf
  return window
::method ti_forID_cls unguarded
  use arg self_, msg, a
  if a~hasIndex(2) then return self_~new(a[1], a[2])
  return self_~new(a[1])
::method ti_forHitTest_cls unguarded
  use arg self_, msg, a
  return self_~new(a[1])
::method ti_unInit unguarded
  return 0
::method ti_hitTestHelper unguarded
  return 0
::method ti_flags unguarded
  use arg self_
  return self_~oodPeer~flags
::method ti_setFlags unguarded
  use arg self_, msg, a
  self_~oodPeer~flags = a[1]
::method ti_rect unguarded
  use arg self_
  rect = self_~oodPeer~rect
  if rect == .nil then return self~classOf("Rect")~new
  return rect
::method ti_setRect unguarded
  use arg self_, msg, a
  self_~oodPeer~rect = a[1]
::method ti_resource unguarded
  use arg self_
  return self_~oodPeer~resource
::method ti_rexxHwnd unguarded
  use arg self_
  return self_~oodPeer~tool
::method ti_rexxID unguarded       -- the tool's ID; for a whole window, the window object
  use arg self_
  if self_~oodPeer~id == .nil then return self_~oodPeer~tool
  return self_~oodPeer~id
::method ti_text unguarded
  use arg self_
  text = self_~oodPeer~text
  if text == .nil then return ""
  return text
::method ti_setText unguarded
  use arg self_, msg, a
  self_~oodPeer~text = self~ttTextArg(a, 1)
::method ti_setTextMemoryIsAllocated unguarded
  return
::method ti_userData unguarded
  use arg self_
  return self_~oodPeer~userData
::method ti_setUserData unguarded
  use arg self_, msg, a
  self_~oodPeer~userData = a[1]

/*---- fonts and colours ------------------------------------------------------------------*/
::method newFont                   -- a font "handle": the name, the point size, and B I U for the style
  expose fonts
  use arg name, size, style
  if \var("FONTS") then fonts = .directory~new
  handle = "0x"d2x(4096 + fonts~items)~right(16, "0")
  fonts[handle] = .array~of(name, size, style)
  return handle
::method fontOf
  expose fonts
  use arg handle
  if \var("FONTS") then return .nil
  return fonts[handle]
::method winex_createFontEx unguarded        -- createFontEx(name, size, directory of weight, italic, underline ...)
  use arg self_, msg, a
  size = 8
  if a~hasIndex(2) then size = a[2]
  style = ""
  if a~hasIndex(3) then if a[3]~isA(.String) then do
    words = a[3]~upper
    if words~pos("BOLD") > 0 | words~pos("THICK") > 0 then style = style"B"
    if words~pos("ITALIC") > 0 then style = style"I"
    if words~pos("UNDERLINE") > 0 then style = style"U"
    return self~newFont(a[1], size, style)
  end
  if a~hasIndex(3) then do
    d = a[3]
    if d~hasIndex("WEIGHT") then if d~weight >= 600 then style = style"B"
    if d~hasIndex("ITALIC") then if d~italic == .true then style = style"I"
    if d~hasIndex("UNDERLINE") then if d~underline == .true then style = style"U"
  end
  return self~newFont(a[1], size, style)
::method winex_createFont unguarded          -- createFont(name, size, "BOLD ITALIC UNDERLINE", width)
  use arg self_, msg, a
  name = "MS Shell Dlg"
  if a~hasIndex(1) then name = a[1]
  size = 8
  if a~hasIndex(2) then if a[2]~datatype("W") then size = a[2]
  words = self~opt(a, 3)~upper
  style = ""
  if words~pos("BOLD") > 0 | words~pos("THICK") > 0 then style = style"B"
  if words~pos("ITALIC") > 0 then style = style"I"
  if words~pos("UNDERLINE") > 0 then style = style"U"
  return self~newFont(name, size, style)
::method winex_setFont unguarded
  use arg self_, msg, a
  font = self~fontOf(a[1])
  if font == .nil then return 1
  self~op(self_, "pointFont", font[1], font[2], font[3])
  return 0
::method winex_getFont unguarded
  return "0x0000000000000FFF"
::method dlgext_setControlColor unguarded    -- setControlColor(id, background, foreground)
  use arg self_, msg, a
  background = ""
  foreground = ""
  if a~hasIndex(2) then background = self~colorOf(a[2])
  if a~hasIndex(3) then foreground = self~colorOf(a[3])
  self~ctlOp(self_~oodPeer, self~resolveId(self_, a[1]), "color", background, foreground)
  return 0

/*---- the folder dialog, and what the depth probe named -------------------------------------------*/
::method sfb_getFolder unguarded   -- .SimpleFolderBrowse~getFolder(title, banner, hint, startDir, root, owner): "" if cancelled
  use arg self_, msg, a
  start = self~opt(a, 4)
  if start \== "" then start = self~path(start)
  dlg = self~classOf("OodFileDialog")~new(start, "", .false, self~opt(a, 1), "", .false, " ", .true)
  dlg~execute("SHOWTOP")
  if dlg~chosen == 0 then return ""
  return dlg~chosen

/* ---- The shell dialog classes: BrowseForFolder, OpenFileDialog, SaveFileDialog ----
   Windows shows its own shell dialogs through COM.  Here each is an OodFileDialog
   over the file system of the WASM machine.  The object's state is a directory
   kept as its oodPeer.  COM calls (initCOM, release, setClientGuid ...) answer S_OK. */
::method shellFolder unguarded     -- a Windows directory name as one of this machine, "" if there is none
  use arg name
  if name == .nil then return ""
  if name == "" then return ""
  found = self~path(name)
  if SysIsFileDirectory(found) then return found
  return ""

::method bff_init unguarded        -- .BrowseForFolder~new(title, banner, hint, startDir)
  use arg self_, msg, a
  p = .directory~new
  p~dlgTitle = "ooDialog Browse for Folder"
  p~banner = "Select the folder needed"
  p~hint = "If the needed folder does not exist it can be created"
  p~startDir = ""
  p~root = ""
  p~owner = .nil
  p~options = "RETURNONLYFSDIRS NEWDIALOGSTYLE RETURNFSANCESTORS"
  p~usePathForHint = .false
  if a~hasIndex(1) then p~dlgTitle = a[1]
  if a~hasIndex(2) then p~banner = a[2]
  if a~hasIndex(3) then p~hint = a[3]
  if a~hasIndex(4) then p~startDir = a[4]
  self_~oodPeer = p
  return 0
::method bff_get unguarded
  use arg self_, msg
  return self_~oodPeer[msg]
::method bff_set unguarded
  use arg self_, msg, a
  name = msg~strip("T", "=")
  self_~oodPeer[name] = a[1]
  return
::method bff_banner unguarded
  forward message "bff_get"
::method bff_setBanner unguarded
  forward message "bff_set"
::method bff_dlgTitle unguarded
  forward message "bff_get"
::method bff_setDlgTitle unguarded
  forward message "bff_set"
::method bff_hint unguarded
  forward message "bff_get"
::method bff_setHint unguarded
  forward message "bff_set"
::method bff_options unguarded
  forward message "bff_get"
::method bff_setOptions unguarded
  forward message "bff_set"
::method bff_Owner unguarded
  forward message "bff_get"
::method bff_setOwner unguarded
  forward message "bff_set"
::method bff_root unguarded
  forward message "bff_get"
::method bff_setRoot unguarded
  forward message "bff_set"
::method bff_startDir unguarded
  forward message "bff_get"
::method bff_setStartDir unguarded
  forward message "bff_set"
::method bff_usePathForHint unguarded
  forward message "bff_get"
::method bff_setUsePathForHint unguarded
  forward message "bff_set"
::method bff_initialThread unguarded
  return 0
::method bff_initCOM unguarded
  return .true
::method bff_releaseCOM unguarded
  return 0
::method bff_uninit unguarded
  return 0
::method bff_releaseItemIDList unguarded
  return 0
::method bff_getFolder unguarded   -- the folder chosen, .nil if cancelled
  use arg self_
  p = self_~oodPeer
  dlg = self~classOf("OodFileDialog")~new(self~shellFolder(p~startDir), "", .false, p~dlgTitle, "", .false, " ", .true)
  dlg~execute("SHOWTOP")
  if dlg~chosen == 0 then return .nil
  return dlg~chosen
::method bff_getItemIDList unguarded   -- Windows answers a pointer to an item id list; here the path stands for it
  forward message "bff_getFolder"
::method bff_getDisplayName unguarded  -- getDisplayName(pidl, sigdn): the path, or its last part for the display forms
  use arg self_, msg, a
  if a[1] == .nil then return .nil
  form = self~opt(a, 2)~upper
  if form == "NORMALDISPLAY" | form == "PARENTRELATIVE" | form == "PARENTRELATIVEEDITING" | form == "PARENTRELATIVEFORADDRESSBAR" then do
    name = filespec("NAME", a[1])
    if name \== "" then return name
  end
  return a[1]

::method cidPeer unguarded         -- the state of a CommonItemDialog, made when first needed
  use arg self_, saving
  p = self_~oodPeer
  if p~isA(.directory) then return p
  p = .directory~new
  p~saving = saving
  if saving then p~options = "OVERWRITEPROMPT NOREADONLYRETURN PATHMUSTEXIST NOCHANGEDIR"
  else p~options = "PATHMUSTEXIST FILEMUSTEXIST NOCHANGEDIR"
  p~title = ""
  p~fileName = ""
  p~folder = ""
  p~defaultFolder = ""
  p~types = .array~new
  p~typeIndex = 1
  p~defExt = ""
  p~okLabel = ""
  p~cancelLabel = ""
  p~nameLabel = ""
  p~handler = .nil
  p~filter = .nil
  p~results = .array~new
  p~released = .false
  self_~oodPeer = p
  return p
::method cid_init unguarded
  use arg self_
  self~cidPeer(self_, self_~isA(self~classOf("SaveFileDialog")))
  return 0
::method ofd_init unguarded
  use arg self_
  self~cidPeer(self_, .false)
  return 0
::method sfd_init unguarded
  use arg self_
  self~cidPeer(self_, .true)
  return 0
::method cde_init unguarded
  return 0
::method sif_init unguarded
  return 0
::method cid_options unguarded
  use arg self_
  return self_~oodPeer~options
::method cid_setOptions unguarded
  use arg self_, msg, a
  self_~oodPeer~options = a[1]~upper~space
  return
::method cidStore unguarded        -- keep one value; answers S_OK
  use arg self_, name, a
  self_~oodPeer[name] = a[1]
  return 0
::method cid_setTitle unguarded
  use arg self_, msg, a
  return self~cidStore(self_, "TITLE", a)
::method cid_setFileName unguarded
  use arg self_, msg, a
  return self~cidStore(self_, "FILENAME", a)
::method cid_setFileNameLabel unguarded
  use arg self_, msg, a
  return self~cidStore(self_, "NAMELABEL", a)
::method cid_setOkButtonLabel unguarded
  use arg self_, msg, a
  return self~cidStore(self_, "OKLABEL", a)
::method cid_setCancelButtonLabel unguarded
  use arg self_, msg, a
  return self~cidStore(self_, "CANCELLABEL", a)
::method cid_setFolder unguarded
  use arg self_, msg, a
  return self~cidStore(self_, "FOLDER", a)
::method cid_setDefaultFolder unguarded
  use arg self_, msg, a
  return self~cidStore(self_, "DEFAULTFOLDER", a)
::method cid_setDefaultExtension unguarded
  use arg self_, msg, a
  return self~cidStore(self_, "DEFEXT", a)
::method cid_setFileTypeIndex unguarded
  use arg self_, msg, a
  return self~cidStore(self_, "TYPEINDEX", a)
::method cid_setFilter unguarded
  use arg self_, msg, a
  return self~cidStore(self_, "FILTER", a)
::method cid_advise unguarded
  use arg self_, msg, a
  return self~cidStore(self_, "HANDLER", a)
::method cid_unadvise unguarded
  use arg self_
  self_~oodPeer~handler = .nil
  return 0
::method sfd_setSaveAsItem unguarded   -- the file offered first: its directory and its name
  use arg self_, msg, a
  given = a[1]~changeStr("\", "/")
  self_~oodPeer~fileName = filespec("NAME", given)
  where = filespec("LOCATION", given)
  if where \== "" then self_~oodPeer~folder = where
  return 0
::method cid_setFileTypes unguarded    -- an array of pairs: description, pattern
  use arg self_, msg, a
  types = a[1]
  if \types~isA(.array) then raise syntax 93.948 array(1, "Array")
  if types~items // 2 \== 0 then return 2147942487       -- E_INVALIDARG, as Windows answers
  self_~oodPeer~types = types
  return 0
::method cid_getFileTypeIndex unguarded
  use arg self_
  return self_~oodPeer~typeIndex
::method cid_setClientGuid unguarded
  return 0
::method cid_clearClientData unguarded
  return 0
::method cid_addPlace unguarded
  return 0
::method cid_close unguarded
  return 0
::method cid_initCOM unguarded
  return .true
::method cid_releaseCOM unguarded
  return 0
::method cid_uninit unguarded
  return 0
::method cid_release unguarded
  use arg self_
  self_~oodPeer~released = .true
  return 0
::method cid_isReleased unguarded
  use arg self_
  return self_~oodPeer~released
::method cid_show unguarded        -- show(owner): S_OK, or CANCELED
  use arg self_
  p = self_~oodPeer
  opts = p~options
  folders = (opts~wordPos("PICKFOLDERS") > 0)
  multi = (\p~saving & opts~wordPos("ALLOWMULTISELECT") > 0)
  filter = ""
  do i = 1 to p~types~items by 2
    filter = filter || p~types[i] || "00"x || p~types[i + 1] || "00"x
  end
  if filter == "" then filter = "All Files (*.*)" || "00"x || "*.*" || "00"x
  where = self~shellFolder(p~folder)
  if where == "" then where = self~shellFolder(p~defaultFolder)
  start = where
  if p~fileName \== "" then do
    if where == "" then start = p~fileName
    else start = where"/"p~fileName
  end
  sep = "01"x                        -- no file name holds it
  do forever
    p~owner = self_
    dlg = self~classOf("OodFileDialog")~new(start, filter, p~saving, p~title, p~defExt, multi, sep, folders, p)
    dlg~execute("SHOWTOP")
    p~results = .array~new
    if dlg~chosen == 0 then return 2147943623                 -- CANCELED
    p~typeIndex = dlg~typeIndex
    parts = dlg~chosen~makeArray(sep)
    if parts~items > 1 then do
      do i = 2 to parts~items
        p~results~append(parts[1]"/"parts[i])
      end
    end
    else p~results~append(parts[1])
    if p~handler == .nil then leave
    if p~handler~onFileOk(self_, 0) == 0 then leave           -- anything but S_OK keeps the dialog: it is shown again
    start = p~results[1]
  end
  return 0
::method cid_getResult unguarded   -- the path chosen, .nil if there is none
  use arg self_
  if self_~oodPeer~results~items == 0 then return .nil
  return self_~oodPeer~results[1]
::method ofd_getResults unguarded
  use arg self_
  if self_~oodPeer~results~items == 0 then return .nil
  return self_~oodPeer~results~copy
::method cid_getCurrentSelection unguarded
  forward message "cid_getResult"
::method cid_getFileName unguarded
  use arg self_
  if self_~oodPeer~results~items == 0 then return self_~oodPeer~fileName
  return filespec("NAME", self_~oodPeer~results[1])
::method cid_getFolder unguarded
  use arg self_
  if self_~oodPeer~results~items == 0 then return self~shellFolder(self_~oodPeer~folder)
  return filespec("LOCATION", self_~oodPeer~results[1])~strip("T", "/")


/* ---- Drawing: device contexts, pens, brushes ----
   A DC is a canvas of the page over a dialog's client area or over one control
   (oodialog-web.js, gdi).  The state of a DC is kept here; each call takes the pen,
   the brush, the font and the colours with it.  Colours are palette indexes, as
   ooDialog gives them to PALETTEINDEX(). */
::method gdiNew unguarded          -- keep a DC, pen or brush; answers its handle
  expose gdiObjs gdiCount
  use arg entry
  if \var("GDIOBJS") then do
    gdiObjs = .directory~new
    gdiCount = 0
  end
  gdiCount = gdiCount + 1
  handle = "0x"d2x(218103808 + gdiCount)~right(16, "0")        -- 0x0D000000 + n: no window of this page has such a handle
  gdiObjs[handle] = entry
  return handle
::method gdiGet unguarded
  expose gdiObjs
  use arg handle
  if \var("GDIOBJS") then return .nil
  if \handle~isA(.String) then return .nil
  return gdiObjs[handle]
::method gdiDrop unguarded
  expose gdiObjs
  use arg handle
  if var("GDIOBJS") then gdiObjs~remove(handle)
::method gdiStock unguarded        -- the pen, brush and font a new DC has: black 1 solid, white, the dialog's font
  expose stockPen stockBrush stockFont
  use arg kind
  if \var("STOCKPEN") then do
    stockPen = self~gdiNew(.array~of("PEN", 1, "SOLID", "#000000"))
    stockBrush = self~gdiNew(.array~of("BRUSH", "#ffffff"))
    stockFont = self~gdiNew(.array~of("FONT", ""))
  end
  if kind == "PEN" then return stockPen
  if kind == "BRUSH" then return stockBrush
  return stockFont
::method gdiTarget unguarded       -- the dialog state and control ID of a window handle; .nil if it is no window
  use arg hwnd
  handle = self~number(hwnd)
  owner = self~dialogOf(handle % 65536)
  if owner == .nil then return .nil
  return .array~of(owner, handle // 65536)
::method gdiTargetOf unguarded     -- the same for a dialog or control object
  use arg self_
  p = self_~oodPeer
  if p~isA(.OodCtl) then return .array~of(p~dlg, p~id)
  return .array~of(p, 0)
::method gdiNewDC unguarded
  use arg target
  if target == .nil then return 0
  dc = .directory~new
  dc~kind = "DC"
  dc~d = target[1]
  dc~id = target[2]
  dc~pen = self~gdiStock("PEN")
  dc~brush = self~gdiStock("BRUSH")
  dc~font = self~gdiStock("FONT")
  dc~textColor = "#000000"
  dc~bkMode = "O"
  dc~bkColor = "#ffffff"
  dc~align = "LEFT TOP NOUPDATECP"
  dc~arcDirection = "COUNTERCLOCKWISE"
  dc~x = 0
  dc~y = 0
  return self~gdiNew(dc)
::method gdiDC unguarded           -- the state of a DC handle, .nil if it is none
  use arg handle
  dc = self~gdiGet(handle)
  if dc == .nil then return .nil
  if \dc~isA(.directory) then return .nil
  return dc
::method gdiFontCss unguarded      -- a font handle as a CSS font
  use arg handle
  font = self~fontOf(handle)
  if font == .nil then return ""
  css = ""
  if font[3]~pos("I") > 0 then css = css "italic"
  if font[3]~pos("B") > 0 then css = css "bold"
  return (css font[2]"pt" '"'font[1]'", sans-serif')~strip
::method gdiStyle unguarded        -- what a call takes with it
  use arg dc
  sep = self~sep
  pen = self~gdiGet(dc~pen)
  if pen == .nil then pen = .array~of("PEN", 1, "SOLID", "#000000")
  brush = self~gdiGet(dc~brush)
  fill = ""
  if brush \== .nil then fill = brush[2]
  return pen[4] || sep || pen[2] || sep || pen[3] || sep || fill || sep || self~gdiFontCss(dc~font) || sep || -
         dc~textColor || sep || dc~bkMode || sep || dc~bkColor || sep || dc~align
::method gdiCall unguarded         -- one drawing call on a DC
  use arg dc, verb, values
  return self~ctlOp(dc~d, dc~id, "gdi", verb, values~makeString("L", self~sep), self~gdiStyle(dc))
::method gdiInt unguarded
  use arg v
  if v~isA(.String) then if v~datatype("N") then return v~format(, 0) + 0
  return 0

::method dlgext_getWindowDC unguarded
  use arg self_, msg, a
  return self~gdiNewDC(self~gdiTarget(a[1]))
::method winex_getDC unguarded
  use arg self_
  return self~gdiNewDC(self~gdiTargetOf(self_))
::method dlgext_freeWindowDC unguarded
  use arg self_, msg, a
  if a~hasIndex(2) then self~gdiDrop(a[2])
  return 1
::method winex_freeDC unguarded
  use arg self_, msg, a
  if a~hasIndex(1) then self~gdiDrop(a[1])
  return 1
::method winex_createPen unguarded -- createPen(width, style, colour)
  use arg self_, msg, a
  width = 1
  if a~hasIndex(1) then width = a[1]
  style = self~opt(a, 2)~upper
  if style == "INSIDEFRAME" then style = "NULL"
  if "DASH DOT DASHDOT DASHDOTDOT NULL"~wordPos(style) == 0 then style = "SOLID"
  color = 0
  if a~hasIndex(3) then color = a[3]
  return self~gdiNew(.array~of("PEN", width, style, self~colorOf(color)))
::method winex_createBrush unguarded   -- createBrush(colour, specifier): none of both is the hollow brush
  use arg self_, msg, a
  if \a~hasIndex(1) & \a~hasIndex(2) then return self~gdiNew(.array~of("BRUSH", ""))
  color = 1
  if a~hasIndex(1) then color = a[1]
  css = self~colorOf(color)
  kind = self~opt(a, 2)~upper
  if "UPDIAGONAL DOWNDIAGONAL CROSS DIAGCROSS HORIZONTAL VERTICAL"~wordPos(kind) > 0 then css = "hatch:"kind":"css
  return self~gdiNew(.array~of("BRUSH", css))                  -- a bitmap file as the specifier: the plain colour
::method dlgext_createBrush unguarded
  forward message "winex_createBrush"
::method winex_getSysBrush unguarded
  return self~gdiNew(.array~of("BRUSH", "#f0f0f0"))
::method winex_objectToDC unguarded    -- objectToDC(dc, pen | brush | font): the object it replaces
  use arg self_, msg, a
  dc = self~gdiDC(a[1])
  if dc == .nil then return 0
  obj = self~gdiGet(a[2])
  if obj \== .nil then if obj~isA(.array) then do
    select
      when obj[1] == "PEN" then do
        old = dc~pen
        dc~pen = a[2]
      end
      when obj[1] == "BRUSH" then do
        old = dc~brush
        dc~brush = a[2]
      end
      otherwise
        old = dc~font
        dc~font = a[2]
    end
    return old
  end
  if self~fontOf(a[2]) == .nil then return 0
  old = dc~font
  dc~font = a[2]
  return old
::method winex_drawLine unguarded      -- drawLine(dc, x, y, x2, y2): without x, y from where the last line ended
  use arg self_, msg, a
  dc = self~gdiDC(a[1])
  if dc == .nil then return 1
  if a~hasIndex(2) then dc~x = a[2]
  if a~hasIndex(3) then dc~y = a[3]
  self~gdiCall(dc, "line", .array~of(dc~x, dc~y, a[4], a[5]))
  dc~x = a[4]
  dc~y = a[5]
  return 0
::method winex_rectangle unguarded     -- rectangle(dc, left, top, right, bottom, fill): with fill, filled with the brush
  use arg self_, msg, a
  dc = self~gdiDC(a[1])
  if dc == .nil then return 1
  self~gdiCall(dc, "rect", .array~of(a[2], a[3], a[4], a[5], a~hasIndex(6)))
  dc~x = a[2]
  dc~y = a[3]
  return 0
::method winex_drawArcOrPie unguarded  -- drawArc / drawPie(dc, left, top, right, bottom, startX, startY, endX, endY)
  use arg self_, msg, a
  dc = self~gdiDC(a[1])
  if dc == .nil then return 1
  v = .array~of(a[2], a[3], a[4], a[5], 0, 0, 0, 0, (msg == "DRAWPIE"), dc~arcDirection)
  do i = 6 to 9
    if a~hasIndex(i) then v[i - 1] = a[i]
  end
  self~gdiCall(dc, "arc", v)
  return 0
::method winex_drawAngleArc unguarded  -- drawAngleArc(dc, moveToX, moveToY, x, y, radius, startAngle, sweepAngle)
  use arg self_, msg, a
  dc = self~gdiDC(a[1])
  if dc == .nil then return 1
  if a~hasIndex(2) then dc~x = a[2]
  if a~hasIndex(3) then dc~y = a[3]
  parse value self~gdiCall(dc, "angleArc", .array~of(a[4], a[5], a[6], a[7], a[8], dc~x, dc~y)) with endX endY .
  if endX \== "" then do
    dc~x = endX
    dc~y = endY
  end
  return 0
::method winex_getSetArcDirection unguarded
  use arg self_, msg, a
  dc = self~gdiDC(a[1])
  if dc == .nil then return ""
  old = dc~arcDirection
  if msg == "SETARCDIRECTION" then do
    if self~opt(a, 2)~upper~abbrev("CL") then dc~arcDirection = "CLOCKWISE"
    else dc~arcDirection = "COUNTERCLOCKWISE"
  end
  return old
::method winex_drawPixel unguarded
  use arg self_, msg, a
  dc = self~gdiDC(a[1])
  if dc == .nil then return 1
  self~gdiCall(dc, "pixel", .array~of(a[2], a[3], self~colorOf(a[4])))
  return 0
::method winex_getPixel unguarded      -- the colour at x, y as a COLORREF; -1 where nothing was drawn
  use arg self_, msg, a
  dc = self~gdiDC(a[1])
  if dc == .nil then return -1
  answer = self~gdiCall(dc, "getPixel", .array~of(a[2], a[3]))
  if answer == "" then return -1
  return answer
::method winex_fillDrawing unguarded   -- fillDrawing(dc, x, y, colour): fill with the brush out to the border of that colour
  use arg self_, msg, a
  dc = self~gdiDC(a[1])
  if dc == .nil then return 1
  self~gdiCall(dc, "flood", .array~of(a[2], a[3], self~colorOf(a[4])))
  return 0
::method winex_fillRect unguarded      -- fillRect(dc, rect, brush)
  use arg self_, msg, a
  dc = self~gdiDC(a[1])
  if dc == .nil then return 1
  keep = dc~brush
  if a~hasIndex(3) then if self~gdiGet(a[3]) \== .nil then dc~brush = a[3]
  r = a[2]
  self~gdiCall(dc, "fillRect", .array~of(r~left, r~top, r~right, r~bottom))
  dc~brush = keep
  return 0
::method winex_fontColor unguarded     -- fontColor(colour, dc)
  use arg self_, msg, a
  dc = self~gdiDC(a[2])
  if dc == .nil then return 1
  color = 0
  if a~hasIndex(1) then color = a[1]
  dc~textColor = self~colorOf(color)
  return 0
::method winex_textBkMode unguarded    -- opaqueText(dc), transparentText(dc)
  use arg self_, msg, a
  dc = self~gdiDC(a[1])
  if dc == .nil then return 1
  if msg == "TRANSPARENTTEXT" then dc~bkMode = "T"
  else dc~bkMode = "O"
  return 0
::method winex_setTextAlign unguarded  -- setTextAlign(dc, words): the words before
  use arg self_, msg, a
  dc = self~gdiDC(a[1])
  if dc == .nil then return ""
  old = dc~align
  dc~align = self~opt(a, 2)~upper~space
  if dc~align == "" then dc~align = "LEFT TOP NOUPDATECP"
  return old
::method winex_getTextAlign unguarded
  use arg self_, msg, a
  dc = self~gdiDC(a[1])
  if dc == .nil then return ""
  return dc~align
::method winex_getTextExtent unguarded -- getTextExtent(dc, text): a .Size in pixels
  use arg self_, msg, a
  dc = self~gdiDC(a[1])
  if dc == .nil then return self~classOf("Size")~new(0, 0)
  parse value self~gdiCall(dc, "extent", .array~of(a[2])) with width height .
  if width == "" then return self~classOf("Size")~new(0, 0)
  return self~classOf("Size")~new(width, height)
::method winex_writeDirect unguarded   -- writeDirect(dc, x, y, text)
  use arg self_, msg, a
  dc = self~gdiDC(a[1])
  if dc == .nil then return 1
  self~gdiCall(dc, "text", .array~of(a[2], a[3], a[4]))
  return 0
/* write(x, y, text, fontName, fontSize, fontStyle, fgColor, bkColor) on a window:
   a DC for this one text. */
::method gdiWrite unguarded
  use arg target, a, at
  handle = self~gdiNewDC(target)
  if handle == 0 then return 1
  dc = self~gdiDC(handle)
  if a~hasIndex(at + 3) | a~hasIndex(at + 4) then do
    name = "MS Shell Dlg"
    if a~hasIndex(at + 3) then name = a[at + 3]
    size = 10
    if a~hasIndex(at + 4) then size = a[at + 4]
    words = self~opt(a, at + 5)~upper
    style = ""
    if words~pos("BOLD") > 0 | words~pos("THICK") > 0 then style = style"B"
    if words~pos("ITALIC") > 0 then style = style"I"
    dc~font = self~newFont(name, size, style)
  end
  words = self~opt(a, at + 5)~upper                 -- as drawFontToDC(): the DC's mode (opaque) unless the style says
  if words~pos("TRANSPARENT") > 0 then dc~bkMode = "T"
  else if words~pos("OPAQUE") > 0 then dc~bkMode = "O"
  if a~hasIndex(at + 6) then if a[at + 6] \== -1 then dc~textColor = self~colorOf(a[at + 6])
  if a~hasIndex(at + 7) then if a[at + 7] \== -1 then dc~bkColor = self~colorOf(a[at + 7])
  self~gdiCall(dc, "text", .array~of(a[at], a[at + 1], a[at + 2]))
  self~gdiDrop(handle)
  return 0
::method winex_write unguarded
  use arg self_, msg, a
  return self~gdiWrite(self~gdiTargetOf(self_), a, 1)
::method dlgext_writeToWindow unguarded
  use arg self_, msg, a
  return self~gdiWrite(self~gdiTarget(a[1]), a, 2)
::method gdiClear unguarded        -- erase what was drawn: all of it, or a rectangle (a .Rect or four numbers from index at)
  use arg target, a, at
  if target == .nil then return 1
  v = .array~of("")
  if a~hasIndex(at) then do
    if a[at]~isA(.String) then v = .array~of(a[at], a[at + 1], a[at + 2], a[at + 3])
    else v = .array~of(a[at]~left, a[at]~top, a[at]~right, a[at]~bottom)
  end
  self~ctlOp(target[1], target[2], "gdi", "clear", v~makeString("L", self~sep), "")
  return 0
::method dlgext_clearRect unguarded
  use arg self_, msg, a
  return self~gdiClear(self~gdiTarget(a[1]), a, 2)
::method dlgext_clearWindowRect unguarded
  use arg self_, msg, a
  return self~gdiClear(self~gdiTarget(a[1]), a, 99)
::method dlgext_clearControlRect unguarded
  use arg self_, msg, a
  return self~gdiClear(.array~of(self_~oodPeer, self~resolveId(self_, a[1])), a, 99)
::method dlgext_getControlRect unguarded   -- the control's rectangle on the screen (here: in the page)
  use arg self_, msg, a
  parse value self~ctlOp(self_~oodPeer, self~resolveId(self_, a[1]), "rect") with left top right bottom .
  if left == "" then return self~classOf("Rect")~new
  return self~classOf("Rect")~new(left, top, right, bottom)

/* connectDraw(id, method, willReply): the method draws the control.  Windows asks
   it to (WM_DRAWITEM) whenever the control must be painted; here it is asked when the
   dialog is shown and when the program redraws the control.
   Its arguments: id, lParam, the control object, itemID, flags, dc, rect, itemData. */
::method en_connectDraw unguarded
  use arg self_, msg, a
  id = 0
  if a~hasIndex(1) then do
    id = self~resolveId(self_, a[1])
    if id < 0 then return -1
  end
  method = "onDraw"
  if a~hasIndex(2) then if a[2] \== "" then method = a[2]
  self_~oodPeer~store["DRAW" id] = method
  return 0
::method gdiPaint unguarded        -- ask the draw method of one control, if there is one
  use arg d, id, erase = .true
  if \d~live then return
  method = d~store["DRAW" id]
  if method == .nil then method = d~store["DRAW" 0]
  if method == .nil then return
  if self~ctlOp(d, id, "exists") \== 1 then return
  self~ctlOp(d, id, "gdi", "ownerDraw", "", "")
  if erase then self~ctlOp(d, id, "gdi", "clear", "", "")
  handle = self~gdiNewDC(.array~of(d, id))
  parse value self~ctlOp(d, id, "gdi", "size", "", "") with width height .
  if width == "" then return
  dlg = d~rexxSelf
  control = dlg~newControl(id)
  if control == .nil | control == 0 then control = dlg
  self~invoke(dlg, method, .array~of(id, 0, control, 0, "", handle, self~classOf("Rect")~new(0, 0, width, height), .nil))
  self~gdiDrop(handle)
::method gdiPaintAll unguarded     -- every control that has a draw method
  use arg d
  if d~store == .nil then return
  do name over d~store~allIndexes
    if \name~isA(.String) then iterate
    if name~word(1) \== "DRAW" then iterate
    if name~word(2) == 0 then iterate
    self~gdiPaint(d, name~word(2))
  end
::method dlgext_redrawControl unguarded    -- redrawControl(id, erase)
  use arg self_, msg, a
  erase = .false
  if a~hasIndex(2) then erase = (a[2] == .true)
  self~gdiPaint(self_~oodPeer, self~resolveId(self_, a[1]), erase)
  return 0
::method dlgext_drawButton unguarded
  use arg self_, msg, a
  self~gdiPaint(self_~oodPeer, self~resolveId(self_, a[1]), .true)
  return 0
::method gdiRedraw unguarded
  use arg target, erase
  if target == .nil then return 1
  if target[2] == 0 then do
    if erase then self~ctlOp(target[1], 0, "gdi", "clear", "", "")
    self~gdiPaintAll(target[1])
  end
  else self~gdiPaint(target[1], target[2], erase)
  return 0
::method dlgext_redrawWindowRect unguarded -- redrawWindowRect(hwnd, erase)
  use arg self_, msg, a
  erase = .false
  if a~hasIndex(2) then erase = (a[2] == .true)
  if a~hasIndex(1) then return self~gdiRedraw(self~gdiTarget(a[1]), erase)
  return self~gdiRedraw(.array~of(self_~oodPeer, 0), erase)
::method dlgext_redrawRect unguarded       -- redrawRect(hwnd, left, top, right, bottom, erase)
  use arg self_, msg, a
  erase = .false
  if a~hasIndex(6) then erase = (a[6] == .true)
  if a~hasIndex(1) then return self~gdiRedraw(self~gdiTarget(a[1]), erase)
  return self~gdiRedraw(.array~of(self_~oodPeer, 0), erase)


/* ---- The Mouse class ----
   .Mouse~new(dialog | control).  Its events come from the page's pointer events
   (oodialog-web.js, mouseSub).  The method is invoked on the dialog, as ooDialog does:
     (keyState, point, mouse)          the buttons, MOUSEMOVE, MOUSEHOVER; point in the window's client area
     (keyState, point, mouse, delta)   MOUSEWHEEL; point in the page
     (mouse)                           MOUSELEAVE
   The page cannot move or confine the pointer: setCursorPos and clipCursor do nothing. */
::method mouse_init unguarded
  use arg self_, msg, a
  owner = a[1]
  if \owner~hasMethod("oodPeer") then raise syntax 93.900 array("the owner of a Mouse must be a dialog or a dialog control")
  target = self~gdiTargetOf(owner)
  p = .directory~new
  p~owner = owner
  p~d = target[1]
  p~id = target[2]
  self_~oodPeer = p
  return 0
::method mouseNames unguarded      -- the events and the methods they go to when none is named
  names = .directory~new
  events = "MOUSEMOVE MOUSEWHEEL MOUSELEAVE MOUSEHOVER LBUTTONDOWN LBUTTONUP LBUTTONDBLCLK MBUTTONDOWN MBUTTONUP" -
           "MBUTTONDBLCLK RBUTTONDOWN RBUTTONUP RBUTTONDBLCLK CAPTURECHANGED NCMOUSELEAVE NCMOUSEHOVER"
  methods = "onMouseMove onMouseWheel onMouseLeave onMouseHover onLButtonDown onLButtonUp onLButtonDblClk onMButtonDown onMButtonUp" -
            "onMButtonDblClk onRButtonDown onRButtonUp onRButtonDblClk onCaptureChanged onNcMouseLeave onNcMouseHover"
  do i = 1 to events~words
    names[events~word(i)] = methods~word(i)
  end
  return names
::method mouse_connectEvent unguarded  -- connectEvent(event, method, willReply, opts)
  use arg self_, msg, a
  p = self_~oodPeer
  event = self~opt(a, 1)~upper
  names = self~mouseNames
  if \names~hasIndex(event) then raise syntax 93.900 array("connectEvent: """a[1]""" is not a mouse event")
  method = names[event]
  if a~hasIndex(2) then if a[2] \== "" then method = a[2]
  toDialog = (self~opt(a, 4)~upper == "SENDTODLG")
  p~d~store["MOUSE" p~id event] = .array~of(method, self_, toDialog)
  if p~d~live then self~ctlOp(p~d, p~id, "mouseSub", event)
  return .true
::method mouseEvent unguarded
  use arg key, id, event, extra
  d = self~dialogOf(key)
  if d == .nil then return
  entry = d~store["MOUSE" id event]
  if entry == .nil then return
  if entry[3] then do                 -- SENDTODLG: the control hands the event to its dialog
    entry = d~store["MOUSE" 0 event]
    if entry == .nil then return
  end
  parse var extra state x y delta .
  state = state~translate(" ", ",")
  point = self~classOf("Point")~new(x, y)
  select
    when event == "MOUSELEAVE" | event == "NCMOUSELEAVE" then args = .array~of(entry[2])
    when event == "MOUSEWHEEL" then args = .array~of(state, point, entry[2], delta)
    otherwise args = .array~of(state, point, entry[2])
  end
  self~invoke(d~rexxSelf, entry[1], args)
::method mouseHandle unguarded     -- "key id" of the page as a window handle; 0 for none
  use arg answer
  parse var answer key id .
  if key == "" then return 0
  return "0x"d2x(key * 65536 + id)~right(16, "0")
::method mouse_capture unguarded   -- capture: the window that had the mouse before, 0 if none
  use arg self_
  p = self_~oodPeer
  if \p~d~live then return 0
  return self~mouseHandle(self~ctlOp(p~d, p~id, "mouse", "capture"))
::method mouse_get_release_capture unguarded
  use arg self_, msg
  p = self_~oodPeer
  if \p~d~live then return 0
  if msg == "RELEASECAPTURE" then do
    self~ctlOp(p~d, p~id, "mouse", "release")
    return 0
  end
  return self~mouseHandle(self~ctlOp(p~d, p~id, "mouse", "getCapture"))
::method mousePageState unguarded  -- x, y and the buttons now (bit 1 left, 2 right, 4 middle)
  use arg self_
  p = self_~oodPeer
  if \p~d~live then return "0 0 0"
  answer = self~ctlOp(p~d, p~id, "mouse", "state")
  if answer == "" then return "0 0 0"
  return answer
::method mouse_getCursorPos unguarded  -- a .Point in the page
  use arg self_
  parse value self~mousePageState(self_) with x y .
  return self~classOf("Point")~new(x, y)
::method mouse_isButtonDown unguarded  -- isButtonDown(LEFT | RIGHT | MIDDLE)
  use arg self_, msg, a
  parse value self~mousePageState(self_) with . . buttons
  which = self~opt(a, 1)~upper
  if which == "" then which = "LEFT"
  bit = 1
  if which~abbrev("R") then bit = 2
  if which~abbrev("M") then bit = 4
  return (buttons // (bit * 2) >= bit)
/* dragDetect(point): Windows waits until the left button is released (.false) or the
   pointer has moved a few pixels (.true).  The same here, in steps of 20 ms. */
::method mouse_dragDetect unguarded
  use arg self_
  parse value self~mousePageState(self_) with startX startY buttons
  if buttons // 2 == 0 then return .false
  do 250
    call SysSleep 0.02
    parse value self~mousePageState(self_) with x y buttons
    if buttons // 2 == 0 then return .false
    if abs(x - startX) > 4 | abs(y - startY) > 4 then return .true
  end
  return .false
::method mouseCursor unguarded     -- a cursor handle for a CSS cursor name or a cursor file's key
  expose cursors
  use arg css
  if \var("CURSORS") then cursors = .directory~new
  handle = self~gdiNew(.array~of("CURSOR", css))
  return handle
::method mouse_loadCursor_cls unguarded     -- .Mouse~loadCursor(name)
  use arg self_, msg, a
  names = "APPSTARTING ARROW CROSS HAND HELP IBEAM NO SIZEALL SIZENESW SIZENS SIZENWSE SIZEWE UPARROW WAIT"
  css = "progress default crosshair pointer help text not-allowed move nesw-resize ns-resize nwse-resize ew-resize default wait"
  at = names~wordPos(self~opt(a, 1)~upper)
  if at == 0 then return 0
  return self~mouseCursor(css~word(at))
::method mouse_loadCursorFromFile_cls unguarded
  use arg self_, msg, a
  key = self~imageKey(a[1])
  if key == "" then return 0
  return self~mouseCursor(key)
::method mouse_setCursor unguarded -- setCursor(handle), arrow, appStarting, cross, no, wait: the cursor before
  use arg self_, msg, a
  p = self_~oodPeer
  select
    when msg == "SETCURSOR" then do
      entry = self~gdiGet(a[1])
      css = "default"
      if entry \== .nil then if entry~isA(.array) then if entry[1] == "CURSOR" then css = entry[2]
    end
    when msg == "APPSTARTING" then css = "progress"
    when msg == "CROSS" then css = "crosshair"
    when msg == "NO" then css = "not-allowed"
    when msg == "WAIT" then css = "wait"
    otherwise css = "default"
  end
  if \p~d~live then return 0
  old = self~ctlOp(p~d, p~id, "mouse", "cursor", css)
  if old == "" then old = "default"
  return self~mouseCursor(old)
::method mouse_restoreCursor unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  css = "default"
  if a~hasIndex(1) then do
    entry = self~gdiGet(a[1])
    if entry \== .nil then if entry~isA(.array) then if entry[1] == "CURSOR" then css = entry[2]
  end
  if p~d~live then self~ctlOp(p~d, p~id, "mouse", "cursor", css)
  return 0
::method mouse_trackEvent unguarded    -- hover and leave are always produced once connected
  return .true
::method mouse_doubleClickTime_cls unguarded
  return 500
::method mouse_setDoubleClickTime_cls unguarded
  return .true
::method mouse_swapButton_cls unguarded
  return .false
::method mouse_setCursorPos unguarded
  return .false
::method mouse_clipCursor unguarded
  return 1
::method mouse_releaseClipCursor unguarded
  return 0
::method mouse_getClipCursor unguarded
  use arg self_, msg, a
  return 1
::method mouse_showCursor unguarded
  return 0


/* ---- ResizingAdmin (oodResizableDialog.cpp) ----
   A dialog class that inherits ResizingAdmin can be resized, and its controls follow.
   defineSizing is called at the end of the dialog's init; there the program says how
   each edge of a control is pinned.  The page does the arithmetic (raLayout). */
::method raSetup unguarded
  use arg self_
  d = self_~oodPeer
  ra = .directory~new
  ra~def = .array~of(.array~of("P", "LEFT", 0), .array~of("P", "TOP", 0), .array~of("P", "RIGHT", 0), .array~of("P", "BOTTOM", 0))
  ra~ctrls = .array~new            -- in the order the program names them: id, then the four edges
  ra~min = "initial"
  ra~max = .nil
  ra~ended = .nil
  ra~tabs = .array~new             -- pagedTab: rows of tab id and the pages' dialog IDs
  ra~defined = .false
  d~store["RA"] = ra
  self_~constDir["IDC_DEFAULT_PINTO_WINDOW"] = 0
  self_~initResizing(.nil)
  self_~defineSizing
  ra~defined = .true
::method raState unguarded
  use arg self_
  ra = self_~oodPeer~store["RA"]
  if ra == .nil then raise syntax 93.900 array("this dialog does not inherit ResizingAdmin")
  return ra
::method raEdge unguarded          -- (pinType, pinToEdge, pinToID) checked, for the side 1 left 2 top 3 right 4 bottom
  use arg self_, side, how, which, pinTo
  how = how~upper
  which = which~upper
  select
    when how == "PROPORTIONAL" then type = "P"
    when how == "STATIONARY" then type = "S"
    when how == "MYLEFT" & side == 3 then type = "ML"
    when how == "MYTOP" & side == 4 then type = "MT"
    otherwise raise syntax 93.900 array('the pin type "'how'" is not valid for this edge; use PROPORTIONAL or STATIONARY (MYLEFT for a right edge, MYTOP for a bottom edge)')
  end
  if "LEFT TOP RIGHT BOTTOM XCENTER YCENTER"~wordPos(which) == 0 then raise syntax 93.900 array('"'which'" is not an edge; use LEFT, TOP, RIGHT, BOTTOM, XCENTER or YCENTER')
  id = 0
  if pinTo \== .nil then do
    id = self~resolveId(self_, pinTo)
    if id < 0 then raise syntax 93.900 array("the pin-to ID" pinTo "cannot be resolved")
  end
  return .array~of(type, which, id)
::method raEdgeOf unguarded        -- an edge given as an array (pinType, pinToEdge [, pinToID])
  use arg self_, side, spec
  pinTo = .nil
  if spec~hasIndex(3) then pinTo = spec[3]
  return self~raEdge(self_, side, spec[1], spec[2], pinTo)
::method raControl unguarded       -- the record of a control, made with the default edges when first named
  use arg self_, rxID
  ra = self~raState(self_)
  id = self~resolveId(self_, rxID)
  if id < 1 then raise syntax 93.900 array("the control ID" rxID "cannot be resolved")
  do row over ra~ctrls
    if row[1] == id then return row
  end
  row = .array~of(id, ra~def[1], ra~def[2], ra~def[3], ra~def[4])
  ra~ctrls~append(row)
  return row
::method ra_initResizing unguarded
  return 0
::method ra_controlSide unguarded  -- controlLeft / Top / Right / Bottom(id, howPinned, whichEdge, pinToID)
  use arg self_, msg, a
  side = "CONTROLLEFT CONTROLTOP CONTROLRIGHT CONTROLBOTTOM"~wordPos(msg)
  row = self~raControl(self_, a[1])
  pinTo = .nil
  if a~hasIndex(4) then pinTo = a[4]
  row[side + 1] = self~raEdge(self_, side, a[2], a[3], pinTo)
  return 0
::method ra_controlSizing unguarded    -- controlSizing(id, left, top, right, bottom): an omitted edge keeps the default
  use arg self_, msg, a
  row = self~raControl(self_, a[1])
  do side = 1 to 4
    if a~hasIndex(side + 1) then row[side + 1] = self~raEdgeOf(self_, side, a[side + 1])
  end
  return 0
::method ra_useDefaultSizing unguarded
  use arg self_, msg, a
  self~raControl(self_, a[1])
  return 0
::method ra_defaultSide unguarded  -- defaultLeft / Top / Right / Bottom(howPinned, whichEdge, pinToID)
  use arg self_, msg, a
  side = "DEFAULTLEFT DEFAULTTOP DEFAULTRIGHT DEFAULTBOTTOM"~wordPos(msg)
  pinTo = .nil
  if a~hasIndex(3) then pinTo = a[3]
  self~raState(self_)~def[side] = self~raEdge(self_, side, a[1], a[2], pinTo)
  return 0
::method ra_defaultSizing unguarded
  use arg self_, msg, a
  ra = self~raState(self_)
  do side = 1 to 4
    if a~hasIndex(side) then ra~def[side] = self~raEdgeOf(self_, side, a[side])
  end
  return 0
::method raSizeJson unguarded      -- a size limit for the page: "initial", null or [w, h]
  use arg limit
  if limit == .nil then return "null"
  if limit == "initial" then return '"initial"'
  return "["limit~width","limit~height"]"
::method raSpec unguarded          -- the whole definition as JSON for the page
  use arg d
  ra = d~store["RA"]
  json = '{"def":'self~raEdgesJson(ra~def)',"ctrls":['
  first = .true
  do row over ra~ctrls
    if \first then json = json","
    first = .false
    json = json"["row[1]","self~raEdgesJson(.array~of(row[2], row[3], row[4], row[5]))~substr(2)
  end
  json = json'],"min":'self~raSizeJson(ra~min)',"max":'self~raSizeJson(ra~max)',"ended":'
  if ra~ended == .nil then json = json"0}"
  else json = json"1}"
  return json
::method raEdgesJson unguarded
  use arg edges
  json = "["
  do i = 1 to edges~items
    if i > 1 then json = json","
    json = json'["'edges[i][1]'","'edges[i][2]'",'edges[i][3]']'
  end
  return json"]"
::method raLimits unguarded
  use arg self_
  d = self_~oodPeer
  ra = self~raState(self_)
  if d~live then self~ctlOp(d, 0, "ra.limits", self~raSizeJson(ra~min), self~raSizeJson(ra~max))
::method ra_minSize unguarded
  use arg self_
  limit = self~raState(self_)~min
  if limit == "initial" then return .nil
  return limit
::method ra_maxSize unguarded
  use arg self_
  return self~raState(self_)~max
::method ra_setMinSize unguarded   -- a .Size in pixels
  use arg self_, msg, a
  self~raState(self_)~min = a[1]
  self~raLimits(self_)
  return 0
::method ra_setMaxSize unguarded
  use arg self_, msg, a
  self~raState(self_)~max = a[1]
  self~raLimits(self_)
  return 0
::method ra_noMinSize unguarded
  use arg self_
  self~raState(self_)~min = .nil
  self~raLimits(self_)
  return 0
::method ra_noMaxSize unguarded
  use arg self_
  self~raState(self_)~max = .nil
  self~raLimits(self_)
  return 0
::method ra_wantSizeEnded unguarded    -- wantSizeEnded(method, willReply): the method is invoked when the user stops sizing
  use arg self_, msg, a
  method = "onSizeEnded"
  if a~hasIndex(1) then if a[1] \== "" then method = a[1]
  self~raState(self_)~ended = method
  self_~oodPeer~wmTable~append(.array~of("RASIZEENDED", method))
  return .true
/* pagedTab(tabID, dlgIDs): the ControlDialogs with these dlgID values are pages of that tab
   control.  When the tab control changes size, each page takes its display area. */
::method ra_pagedTab unguarded
  use arg self_, msg, a
  ra = self~raState(self_)
  if ra~defined == .true then raise syntax 93.900 array("pagedTab can only be invoked during the defineSizing method")
  tabId = self~resolveId(self_, a[1])
  if tabId < 1 then return -1
  if \a~hasIndex(2) then raise syntax 93.903 array(2)
  if \a[2]~isA(.Array) then raise syntax 93.948 array(2, "Array")
  if ra~tabs~items >= 4 then raise syntax 93.900 array("the number of paged tabs has reached the maximum (4)")
  ids = .array~new
  do id over a[2]
    ids~append(self~resolveId(self_, id))
  end
  ra~tabs~append(.array~of(tabId, ids))
  return 0
::method raPage unguarded          -- a ControlDialog went live in its owner: is it a page of a paged tab?
  use arg self_
  d = self_~oodPeer
  if d~ownerDialog == .nil then return
  od = d~ownerDialog~oodPeer
  ra = od~store["RA"]
  if ra == .nil then return
  do row over ra~tabs
    if row[2]~hasItem(self_~dlgID) then self~ctlOp(od, row[1], "ra.page", d~key)
  end

::method winex_deleteObject unguarded
  return 0
::method winex_deleteFont unguarded
  return 0
::method e_style unguarded         -- addStyle, removeStyle, replaceStyle of an edit control: not applied yet
  return 0
::method ud_getAcceleration unguarded
  return .array~new
::method cb_setFullColor unguarded
  use arg self_, msg, a
  self~op(self_, "color", self~colorOf(self~argOr(a, 1)), self~colorOf(self~argOr(a, 2)))
  return .true
::method cb_removeFullColor unguarded
  return .true
::method cb_setCue unguarded
  use arg self_, msg, a
  self~op(self_, "cue", a[1])
  return 0
::method dlgext_scrollText unguarded -- scrollText(control, text ...): the text is shown, not scrolled
  use arg self_, msg, a
  target = a[1]
  if \target~isA(.String) then target = target~hwnd
  id = self~number(target) // 65536
  if \target~left(2)~caselessEquals("0x") then id = self~resolveId(self_, target)
  self~ctlOp(self_~oodPeer, id, "setText", self~opt(a, 2))
  return 0

/*---- more small ones ------------------------------------------------------------------------------*/
::method wb_screenClient unguarded -- screen2client, client2screen: a Point or Rect converted in place
  use arg self_, msg, a
  t = self~target(self_)
  parse value self~ctlOp(t[1], 0, "origin") with left top
  if left == "" then return .false
  if t[2] \== 0 then do
    parse value self~op(self_, "rect") with left top .
  end
  sign = 1
  if msg == "SCREEN2CLIENT" then sign = -1
  obj = a[1]
  if obj~hasMethod("RIGHT") then do
    obj~left = obj~left + sign * left
    obj~right = obj~right + sign * left
    obj~top = obj~top + sign * top
    obj~bottom = obj~bottom + sign * top
  end
  else do
    obj~x = obj~x + sign * left
    obj~y = obj~y + sign * top
  end
  return .true
::method pbdlg_backgroundBitmap unguarded    -- backgroundBitmap(file, opts): the dialog's background picture
  use arg self_, msg, a
  key = self~imageKey(a[1])
  if key == "" then return 1
  self~ctlOpWhenLive(self_~oodPeer, 0, "backdrop", key, self~opt(a, 2)~upper)
  return 0
::method cb_setItemHeight unguarded
  return 0
::method cb_addDirectory unguarded
  forward message "lb_addDirectory"
::method bc_setStyle unguarded
  return ""
::method dlgext_setBitmapPosition unguarded -- setBitmapPosition(id, x, y | point): where the button's bitmap is drawn
  use arg self_, msg, a
  id = self~resolveId(self_, a[1])
  if id < 1 then return -1
  if \a~hasIndex(2) then return 1
  if a[2]~isA(.String) then do
    x = a[2]
    y = 0
    if a~hasIndex(3) then y = a[3]
  end
  else do
    x = a[2]~x
    y = a[2]~y
  end
  self_~oodPeer~store["BMPPOS" id] = .array~of(x, y)
  self~ctlOpWhenLive(self_~oodPeer, id, "bitmapPos", x, y)
  return 0
::method dlgext_getBitmapPosition unguarded -- getBitmapPosition(id, point): the point is filled in
  use arg self_, msg, a
  id = self~resolveId(self_, a[1])
  if id < 1 then return .false
  pos = self_~oodPeer~store["BMPPOS" id]
  if pos == .nil then pos = .array~of(0, 0)
  if a~hasIndex(2) then do
    a[2]~x = pos[1]
    a[2]~y = pos[2]
  end
  return .true
::method imageSize unguarded       -- width and height of an image known to the page, from the file's header; .nil if unknown
  use arg key
  if key == "" then return .nil
  if \SysIsFile(key) then return .nil
  stream = .stream~new(key)
  if stream~open("READ") \== "READY:" then return .nil
  head = stream~charIn(1, 32)
  stream~close
  if head~left(2) == "BM" then return .array~of(self~le32(head~substr(19, 4)), self~le32(head~substr(23, 4))~abs)
  if head~substr(2, 3) == "PNG" then return .array~of(head~substr(17, 4)~c2x~x2d, head~substr(21, 4)~c2x~x2d)
  if head~left(3) == "GIF" then return .array~of(self~le32(head~substr(7, 2)), self~le32(head~substr(9, 2)))
  return .nil
::method le32 unguarded            -- a little-endian number of up to four bytes (signed when four)
  use arg bytes
  v = bytes~reverse~c2x~x2d
  if bytes~length == 4 then if v > 2147483647 then v = v - 4294967296
  return v
::method dlgext_getBitmapSize unguarded     -- getBitmapSize(id), getBitmapSizeX(id), getBitmapSizeY(id)
  use arg self_, msg, a
  id = self~resolveId(self_, a[1])
  if id < 1 then return -1
  size = self~imageSize(self_~oodPeer~store["BMP" id])
  if size == .nil then return -1
  if msg == "GETBITMAPSIZEX" then return size[1]
  if msg == "GETBITMAPSIZEY" then return size[2]
  return self~classOf("Size")~new(size[1], size[2])
::method dlgext_drawBitmap unguarded        -- drawBitmap(hwnd, id, x, y, xSource, ySource, width, height): onto the button
  use arg self_, msg, a
  id = self~resolveId(self_, a[2])
  if id < 1 then return -1
  d = self_~oodPeer
  key = d~store["BMP" id]
  if key == .nil then return 1
  v = .array~of(key, 0, 0, 0, 0, 0, 0)
  do i = 3 to 8
    if a~hasIndex(i) then v[i - 1] = a[i]
  end
  self~ctlOp(d, id, "gdi", "image", v~makeString("L", self~sep), "")
  return 0
::method dlgext_resizeMoveControl unguarded -- resizeControl(id, width, height | size, opts), moveControl(id, x, y | point, opts): pixels
  use arg self_, msg, a
  id = self~resolveId(self_, a[1])
  if id < 1 then return -1
  if \a~hasIndex(2) then return 1
  if a[2]~isA(.String) then do
    first = a[2]
    second = 0
    if a~hasIndex(3) then second = a[3]
  end
  else if msg~left(1) == "R" then do
    first = a[2]~width
    second = a[2]~height
  end
  else do
    first = a[2]~x
    second = a[2]~y
  end
  if msg~left(1) == "R" then self~ctlOp(self_~oodPeer, id, "size", first, second)
  else self~ctlOp(self_~oodPeer, id, "move", first, second)
  return 0
::method dlgext_scrollButton unguarded      -- scrollButton(id, dx, dy, left, top, right, bottom): that part of what is drawn on the button moves
  use arg self_, msg, a
  id = self~resolveId(self_, a[1])
  if id < 1 then return 1
  v = .array~of(a[2], a[3], a[4], a[5], a[6], a[7])
  self~ctlOp(self_~oodPeer, id, "gdi", "scroll", v~makeString("L", self~sep), "")
  return 0
::method winex_scroll unguarded    -- scroll(dx, dy | size): what is drawn on the window moves
  use arg self_, msg, a
  if \a~hasIndex(1) then return 1
  if a[1]~isA(.String) then do
    dx = a[1]
    dy = 0
    if a~hasIndex(2) then dy = a[2]
  end
  else do
    dx = a[1]~width
    dy = a[1]~height
  end
  target = self~gdiTargetOf(self_)
  self~ctlOp(target[1], target[2], "gdi", "scroll", dx || self~sep || dy, "")
  return 0
::method dlgutil_getGuid_cls unguarded
  hex = ""
  do 32
    hex = hex || "0123456789ABCDEF"~subChar(random(1, 16))
  end
  return hex~left(8)"-"hex~substr(9, 4)"-"hex~substr(13, 4)"-"hex~substr(17, 4)"-"hex~substr(21)
::method spi_getWorkArea_cls unguarded
  parse value self~web~screen with w h
  return .Rect~new(0, 0, w, h)
::method wb_sendWinHandleMsg unguarded
  use arg self_, msg, a
  answer = self~wb_sendWinIntMsg(self_, msg, a)
  return "0x"d2x(answer~abs)~right(16, "0")
::method notProduced unguarded     -- an event family this layer accepts and never sends
  use arg what, a
  say "ooDialog/WASM:" what "event" self~opt(a, 2) "is connected but is not produced yet"
  return 0
::method en_connectMonthCalendarEvent unguarded
  use arg self_, msg, a
  return self~connectNotify(self_, a, "GETDAYSTATE GETDAYSTATE SELCHANGE SELCHANGE SELECT SELECT")
::method en_connectReBarEvent unguarded     -- (the RBN_ events are not produced)
  use arg self_, msg, a
  return self~notProduced("re-bar", a)
::method en_connectToolBarEvent unguarded   -- (a button's click is a command: connectButtonEvent. The TBN_ events are not produced)
  use arg self_, msg, a
  return self~notProduced("tool bar", a)
::method en_connectStatusBarEvent unguarded
  use arg self_, msg, a
  return self~notProduced("status bar", a)
/* ScrollBar (oodControl.cpp, oodMessaging.cpp).  The position is the program's: it changes
   only by setPos.  An event's method gets (wParam, lParam): wParam is the code in its low
   word and the thumb's position in its high word, lParam is the scroll bar's handle.  The
   ScrollBar class's determinePosition works on that. */
::method sbCodes unguarded         -- an event keyword as its SB_ code; "" if unknown
  use arg event
  names = "UP 0 LINEUP 0 LINELEFT 0 DOWN 1 LINEDOWN 1 LINERIGHT 1 PAGEUP 2 PAGELEFT 2 PAGEDOWN 3 PAGERIGHT 3 POSITION 4 DRAG 5 TOP 6 LEFT 6 BOTTOM 7 RIGHT 7 ENDSCROLL 8"
  at = names~wordPos(event~upper)
  if at == 0 then return ""
  return names~word(at + 1)
::method sbTable unguarded
  use arg d, id
  table = d~store["SB" id]
  if table == .nil then do
    table = .table~new
    d~store["SB" id] = table
  end
  return table
::method en_connectScrollBarEvent unguarded    -- connectScrollBarEvent(id, event, method, willReply)
  use arg self_, msg, a
  id = self~resolveId(self_, a[1])
  if id < 1 then return -1
  code = self~sbCodes(self~opt(a, 2))
  if code == "" then return 1
  method = "on"self~opt(a, 2)
  if a~hasIndex(3) then if a[3] \== "" then method = a[3]
  self~sbTable(self_~oodPeer, id)[code] = method
  return 0
::method sbStart unguarded         -- the range and position given with a connection
  use arg self_, id, a, at
  d = self_~oodPeer
  if a~hasIndex(at) & a~hasIndex(at + 1) then self~ctlOpWhenLive(d, id, "sb.range", a[at], a[at + 1])
  if a~hasIndex(at + 2) then self~ctlOpWhenLive(d, id, "sb.pos", a[at + 2])
::method en_connectAllSBEvents unguarded       -- connectAllSBEvents(id, method, min, max, pos, willReply)
  use arg self_, msg, a
  id = self~resolveId(self_, a[1])
  if id < 1 then return -1
  table = self~sbTable(self_~oodPeer, id)
  do code = 0 to 8
    table[code] = a[2]
  end
  self~sbStart(self_, id, a, 3)
  return 0
/* connectEachSBEvent(id, methUp, methDown, methPos, min, max, pos, methPgUp, methPgDown,
   methTop, methBottom, methTrack, methEndScroll, willReply) */
::method en_connectEachSBEvent unguarded
  use arg self_, msg, a
  id = self~resolveId(self_, a[1])
  if id < 1 then return -1
  table = self~sbTable(self_~oodPeer, id)
  table[0] = a[2]
  table[1] = a[3]
  places = .array~of(.array~of(4, 4), .array~of(8, 2), .array~of(9, 3), .array~of(10, 6), .array~of(11, 7), .array~of(12, 5), .array~of(13, 8))
  do place over places
    if a~hasIndex(place[1]) then if a[place[1]] \== "" then table[place[2]] = a[place[1]]
  end
  self~sbStart(self_, id, a, 5)
  return 0
::method sbEvent unguarded
  use arg key, id, code, pos
  d = self~dialogOf(key)
  if d == .nil then return
  table = d~store["SB" id]
  if table == .nil then return
  method = table[code]
  if method == .nil then return
  if \pos~datatype("W") then pos = 0
  self~invoke(d~rexxSelf, method, .array~of(pos * 65536 + code, "0x"d2x(key * 65536 + id)~right(16, "0")))
::method sb_getPosition unguarded
  use arg self_
  if \self_~oodPeer~dlg~live then return 0
  return self~op(self_, "sb.getPos")
::method sb_setPosition unguarded
  use arg self_, msg, a
  self~ctlOpWhenLive(self_~oodPeer~dlg, self_~oodPeer~id, "sb.pos", a[1])
  return .true
::method sb_getRange unguarded     -- a directory with min and max
  use arg self_
  parse value self~op(self_, "sb.getRange") with low high .
  range = .directory~new
  range~min = low
  range~max = high
  return range
::method sb_setRange unguarded
  use arg self_, msg, a
  self~ctlOpWhenLive(self_~oodPeer~dlg, self_~oodPeer~id, "sb.range", a[1], a[2])
  return .true
::method dyndlg_createScrollBar unguarded  -- createScrollBar(id, x, y, cx, cy, options): VERTICAL or HORIZONTAL
  use arg self_, msg, a
  id = self~resolveId(self_, a[1])
  if id < 1 then return -1
  self~addItem(self_, "SCROLLBAR", id, a[2], a[3], a[4], a[5], self~opt(a, 6), "")
  return 0
::method winex_getScrollPos unguarded  -- hScrollPos, vScrollPos: how far the window's own content is scrolled, in pixels
  use arg self_, msg
  return self~winOpOf(self_, "scrollPos", msg~left(1), "")
::method winex_setScrollPos unguarded  -- answers the position before
  use arg self_, msg, a
  return self~winOpOf(self_, "scrollPos", msg~substr(4, 1), a[1])
::method winOpOf unguarded         -- an operation on a dialog or a control object
  use arg self_, name, a = "", b = ""
  peer = self_~oodPeer
  if peer~isA(.OodCtl) then return self~ctlOp(peer~dlg, peer~id, name, a, b)
  return self~ctlOp(peer, 0, name, a, b)

/* PropertySheetDialog: pages added and removed, buttons, IDs (oodPropertySheetDialog.cpp).
   A page's ID is its dialog's handle; before the page is first shown it has none. */
::method psRenumber unguarded
  use arg sheet
  info = sheet~oodPeer~sheet
  do i = 1 to info~pages~items
    pageInfo = self~pageInfoOf(info~pages[i])
    pageInfo~sheet = sheet
    pageInfo~number = i - 1
  end
::method psPut unguarded           -- a page into the sheet before 1-based index at (0: at the end)
  use arg self_, page, at
  d = self_~oodPeer
  info = d~sheet
  if \page~isA(self~classOf("PropertySheetPage")) then raise syntax 93.948 array(1, "PropertySheetPage")
  if info~pages~hasItem(page) then return .false
  if at < 1 | at > info~pages~items then do
    info~pages~append(page)
    at = 0
  end
  else if at == 1 then info~pages~insert(page, .nil)
  else info~pages~insert(page, at - 1)
  self~psRenumber(self_)
  if d~live then do
    page~initTemplate
    if \info~wizard then self~ctlOp(d, 12320, "tab.ins", at - 1, self~pageInfoOf(page)~title)
    if at > 0 & info~current >= at then do
      info~current = info~current + 1
      self~winMsg(d, 12320, 4876, info~current - 1)
    end
  end
  return .true
::method psdlg_addPage unguarded
  use arg self_, msg, a
  return self~psPut(self_, a[1], 0)
::method psdlg_insertPage unguarded    -- insertPage(page, index): before the page at index
  use arg self_, msg, a
  if a[2] < 1 then raise syntax 93.907 array(2, 1, 4294967295, a[2])
  return self~psPut(self_, a[1], a[2])
::method psdlg_removePage unguarded    -- removePage(index): omitted: the page that is shown.  The last page stays.
  use arg self_, msg, a
  d = self_~oodPeer
  info = d~sheet
  index = info~current
  if a~hasIndex(1) then index = a[1]
  if index < 1 | index > info~pages~items | info~pages~items < 2 then return .false
  page = info~pages[index]
  wasCurrent = (info~current == index)
  pd = page~oodPeer
  if self~pageInfoOf(page)~activated then if pd~live then do
    self~web~destroy(pd~key)
    pd~live = .false
    self~deregister(pd)
    self~pageInfoOf(page)~activated = .false
  end
  info~pages~delete(index)
  self~psRenumber(self_)
  if d~live then do
    if \info~wizard then self~winMsg(d, 12320, 4872, index - 1)      -- TCM_DELETEITEM
    if wasCurrent then do
      info~current = 0
      self~sheetActivate(self_, min(index, info~pages~items), .false)
    end
    else if info~current > index then do
      info~current = info~current - 1
      self~winMsg(d, 12320, 4876, info~current - 1)
    end
  end
  return .true
::method psdlg_idToIndex unguarded     -- 0 if no page has that ID
  use arg self_, msg, a
  pages = self_~oodPeer~sheet~pages
  do i = 1 to pages~items
    if self~pageInfoOf(pages[i])~activated then if pages[i]~oodPeer~hwnd == a[1] then return i
  end
  return 0
::method psdlg_hwndToIndex unguarded
  forward message "psdlg_idToIndex"
::method psdlg_indexToID unguarded     -- 0 if there is no such page or it has not been shown yet
  use arg self_, msg, a
  pages = self_~oodPeer~sheet~pages
  if a[1] < 1 | a[1] > pages~items then return 0
  if \self~pageInfoOf(pages[a[1]])~activated then return 0
  return pages[a[1]]~oodPeer~hwnd
::method psdlg_indexToHandle unguarded -- indexToHwnd, indexToPage
  forward message "psdlg_indexToID"
::method psdlg_setCurSelByID unguarded
  use arg self_, msg, a
  index = self~psdlg_idToIndex(self_, msg, a)
  if index == 0 then return .false
  return self~sheetActivate(self_, index, .true)
::method psButtonId unguarded      -- a button keyword as the button's ID; 0 if unknown
  use arg word
  names = "APPLYNOW 12321 BACK 12323 CANCEL 2 FINISH 12325 HELP 9 NEXT 12324 OK 1"
  at = names~wordPos(word~upper)
  if at == 0 then return 0
  return names~word(at + 1)
::method psdlg_pressButton unguarded   -- pressButton(APPLYNOW | BACK | CANCEL | FINISH | HELP | NEXT | OK)
  use arg self_, msg, a
  id = self~psButtonId(a[1])
  if id == 0 then raise syntax 93.900 array('pressButton: "'a[1]'" is not APPLYNOW, BACK, CANCEL, FINISH, HELP, NEXT or OK')
  if \self_~oodPeer~live then return 0
  self~sheetButton(self_~oodPeer, id)
  return 0
::method psdlg_apply unguarded         -- as the Apply button: .true if every page accepted
  use arg self_
  d = self_~oodPeer
  if \d~live then return .false
  before = d~sheet~current
  self~sheetButton(d, 12321)
  return .true
::method psdlg_setButtonText unguarded -- setButtonText(button, text)
  use arg self_, msg, a
  id = self~psButtonId(a[1])
  if id == 0 then raise syntax 93.900 array('setButtonText: "'a[1]'" is not APPLYNOW, BACK, CANCEL, FINISH, HELP, NEXT or OK')
  self~ctlOpWhenLive(self_~oodPeer, id, "setText", a[2])
  return 0
::method psWizButtons unguarded    -- enableWizButtons / showWizButtons(opts, optsButtons): of the buttons named in optsButtons, those in opts
  use arg self_, a, op
  d = self_~oodPeer
  if \d~live then return 0
  opts = self~opt(a, 1)~upper
  buttons = self~opt(a, 2)~upper
  if buttons == "" then buttons = "BACK NEXT FINISH CANCEL"
  do word over buttons~makeArray(" ")
    id = self~psButtonId(word)
    if id == 0 then iterate
    on = (opts~wordPos(word) > 0)
    if op == "enable" then self~ctlOp(d, id, "enable", on)
    else if on then self~ctlOp(d, id, "show")
    else self~ctlOp(d, id, "hide")
  end
  return 0
::method psdlg_enableWizButtons unguarded
  use arg self_, msg, a
  return self~psWizButtons(self_, a, "enable")
::method psdlg_showWizButtons unguarded
  use arg self_, msg, a
  return self~psWizButtons(self_, a, "show")
::method psdlg_resetPageText unguarded -- setHeaderTitle, setHeaderSubTitle: a wizard's header is not drawn; the text is kept
  use arg self_, msg, a
  self_~oodPeer~store[msg a[1]] = a[2]
  return 0
::method psdlg_popup unguarded         -- the sheet runs without the caller waiting for it
  use arg self_
  self_~oodPeer~sheet["MODELESS"] = .true
  self_~start("EXECUTE")
  return .true
::method psdlg_popupAsChild unguarded  -- as popup; the sheet ends when the parent dialog ends
  use arg self_, msg, a
  if \a[1]~isA(self~classOf("PlainBaseDialog")) then raise syntax 93.948 array(1, "PlainBaseDialog")
  self_~oodPeer~ownerDialog = a[1]
  self_~oodPeer~sheet["MODELESS"] = .true
  self_~start("EXECUTE")
  return .true
::method psp_init_cls unguarded
  return 0

/* DateTimePicker: range, sizes, parts (oodViewControls.cpp). */
::method dtp_setRange unguarded    -- setRange(array): index 1 the earliest, index 2 the latest DateTime; one may be missing
  use arg self_, msg, a
  if \a[1]~isA(.Array) then raise syntax 93.948 array(1, "Array")
  if \a[1]~hasIndex(1) & \a[1]~hasIndex(2) then raise syntax 93.900 array("The date times array must have an item at index 1 or index 2")
  parse value self~op(self_, "dtp.getRange") with low (self~sep) high
  if a[1]~hasIndex(1) then low = a[1][1]~isoDate~left(10)
  if a[1]~hasIndex(2) then high = a[1][2]~isoDate~left(10)
  return self~op(self_, "dtp.range", low, high) == 1
::method dtp_getRange unguarded    -- getRange(array): none, min, max or both; the array takes the DateTime objects, 0 for no limit
  use arg self_, msg, a
  parse value self~op(self_, "dtp.getRange") with low (self~sep) high
  a[1][1] = 0
  a[1][2] = 0
  if low \== "" then a[1][1] = .DateTime~fromIsoDate(low"T00:00:00.000000")
  if high \== "" then a[1][2] = .DateTime~fromIsoDate(high"T23:59:59.000000")
  if low \== "" & high \== "" then return "both"
  if low \== "" then return "min"
  if high \== "" then return "max"
  return "none"
::method dtp_getIdealSize unguarded    -- the Size object takes the size the control needs
  use arg self_, msg, a
  parse value self~op(self_, "idealSize") with w h .
  if w == "" then return .false
  a[1]~width = w
  a[1]~height = h
  return .true
::method dtp_getInfo unguarded     -- (the control's parts are the browser's: only the whole is known)
  use arg self_
  info = .directory~new
  size = self_~getRealSize
  info~checkRect = self~classOf("Rect")~new
  info~checkState = ""
  info~buttonRect = self~classOf("Rect")~new(size~width - 20, 0, size~width, size~height)
  info~buttonState = ""
  info~dropDown = .nil
  info~edit = .nil
  info~upDown = .nil
  return info
::method dtp_getMonthCal unguarded -- (the drop-down calendar is the browser's, not a control: .nil)
  return .nil
::method dtp_closeMonthCal unguarded
  return 0
::method dtp_getMonthCalStyle unguarded
  use arg self_
  style = self_~oodPeer~dlg~store[self_~oodPeer~id "mcstyle"]
  if style == .nil then return ""
  return style
::method dtp_setMonthCalStyle unguarded    -- answers the style before
  use arg self_, msg, a
  old = self~dtp_getMonthCalStyle(self_)
  self_~oodPeer~dlg~store[self_~oodPeer~id "mcstyle"] = a[1]~upper
  return old
::method dtp_getMonthCalColor unguarded    -- (kept and answered; the browser's calendar is not coloured) -1 if none was set
  use arg self_, msg, a
  color = self_~oodPeer~dlg~store[self_~oodPeer~id "mccolor" a[1]~upper]
  if color == .nil then return -1
  return color
::method dtp_setMonthCalColor unguarded
  use arg self_, msg, a
  old = self~dtp_getMonthCalColor(self_, msg, a)
  self_~oodPeer~dlg~store[self_~oodPeer~id "mccolor" a[1]~upper] = a[2]
  return old


/*---- small ones ----------------------------------------------------------------------------*/
::method lb_addDirectory unguarded -- the names matching a file pattern, added to the list
  use arg self_, msg, a
  call SysFileTree self~path(a[1]), "found.", "FO"
  last = 0
  do i = 1 to found.0
    last = self~op(self_, "add", filespec("NAME", found.i)) + 1
  end
  return last
::method cb_getItemHeight unguarded
  return 16
::method tv_setItemHeight unguarded
  return 16
::method bc_getIdealSize unguarded
  use arg self_
  d = self~dlgOf(self_)
  parse value self~web~measure(self~op(self_, "getText"), d~fontName, d~fontSize) with . . width height .
  return .Size~new(width + 16, height + 8)

/*---- user data of list-view and tree-view items ------------------------------------*/
::method itemData unguarded
  use arg d, id, uid
  value = d~store[id uid]
  if value == .nil then return .nil
  return value
::method setItemDataOf unguarded
  use arg d, id, uid, value
  if uid == 0 | uid == "" then return .false
  if value == .nil then d~store~remove(id uid)
  else d~store[id uid] = value
  return .true

/*---- ListView -------------------------------------------------------------------------*/
::method lvIndex unguarded         -- an optional item index: the last item if omitted
  use arg self_, a, i
  if a~hasIndex(i) then return a[i]
  return self~wb_sendWinIntMsg(self_, "", .array~of(4100, 0, 0)) - 1

::method lv_insertColumnPx unguarded
  use arg self_, msg, a
  at = -1
  if a~hasIndex(1) then at = a[1]
  fmt = self~opt(a, 4)~strip~upper
  align = "left"
  if fmt~pos("CENTER") > 0 then align = "center"
  if fmt~pos("RIGHT") > 0 then align = "right"
  return self~op(self_, "lv.insCol", at, a[2] || self~sep || a[3] || self~sep || align)
::method lv_deleteColumn unguarded
  use arg self_, msg, a
  return self~op(self_, "lv.delCol", a[1]) == 1
::method lv_getColumnCount unguarded
  use arg self_
  return self~op(self_, "lv.colCount")
::method lv_getColumnText unguarded
  use arg self_, msg, a
  sep = self~sep
  parse value self~op(self_, "lv.colInfo", a[1]) with text (sep) .
  return text
::method lv_getColumnInfo unguarded
  use arg self_, msg, a
  info = self~op(self_, "lv.colInfo", a[1])
  if info == "" then return .false
  sep = self~sep
  parse var info text (sep) width (sep) align
  d = a[2]
  d~text = text
  d~width = width
  d~column = a[1]
  d~fmt = align~upper
  d~alignment = align~upper
  return .true
::method lv_setColumnWidthPx unguarded
  use arg self_, msg, a
  width = -1
  if a~hasIndex(2) then if a[2]~datatype("W") then width = a[2]
  return self~op(self_, "lv.setColWidth", a[1], width) == 1

::method lv_addRow unguarded       -- addRow(index, imageIndex, text, subitem texts ...)
  use arg self_, msg, a
  at = -1
  if a~hasIndex(1) then at = a[1]
  texts = self~opt(a, 3)
  do i = 4 to a~size
    texts = texts || self~sep || self~opt(a, i)
  end
  return self~op(self_, "lv.insRow", at, texts)
::method lv_add unguarded          -- add(text, imageIndex): a new item; add(,, text): the next subitem of the last item
  use arg self_, msg, a
  first = a~first
  if first == .nil then return -1
  if first == 1 then return self~op(self_, "lv.insRow", -1, a[1])
  last = self~wb_sendWinIntMsg(self_, "", .array~of(4100, 0, 0)) - 1
  if last < 0 then return -1
  self~op(self_, "lv.setCell", last, first - 1, a[first])
  return last
::method lv_insert unguarded       -- insert(itemIndex, subitemIndex, text, imageIndex)
  use arg self_, msg, a
  sub = 0
  if a~hasIndex(2) then sub = a[2]
  if sub == 0 then do
    at = -1
    if a~hasIndex(1) then at = a[1]
    return self~op(self_, "lv.insRow", at, a[3])
  end
  item = self~lvIndex(self_, a, 1)
  if self~op(self_, "lv.setCell", item, sub, a[3]) == 1 then return item
  return -1
::method lv_modify unguarded
  use arg self_, msg, a
  if a~hasIndex(1) then item = a[1]
  else item = self~op(self_, "lv.next", -1, "SELECTED")
  sub = 0
  if a~hasIndex(2) then sub = a[2]
  if self~op(self_, "lv.setCell", item, sub, a[3]) == 1 then return 0
  return -1
::method lv_setItemText unguarded
  use arg self_, msg, a
  sub = 0
  if a~hasIndex(2) then sub = a[2]
  if self~op(self_, "lv.setCell", a[1], sub, a[3]) == 1 then return 0
  return -1
::method lv_arrange unguarded     -- arrange, alignLeft, alignTop, snapToGrid: the icons of the page's list-view flow by themselves
  return 0
::method lv_getItemInfo unguarded  -- getItemInfo(index, directory, subItem): the text, image and state of an item go into the directory
  use arg self_, msg, a
  index = a[1]
  info = a[2]
  if \info~isA(.directory) then raise syntax 93.948 array(2, "Directory")
  sub = 0
  if a~hasIndex(3) then sub = a[3]
  if index < 0 | self~op(self_, "lv.uid", index) == 0 then return .false
  info~text = self~op(self_, "lv.cell", index, sub)
  info~image = -1
  if sub == 0 then do
    state = ""
    words = self~op(self_, "lv.itemState", index)~upper
    if words~wordPos("FOCUSED") > 0 then state = state "Focused"
    if words~wordPos("SELECTED") > 0 then state = state "Selected"
    info~state = state~strip
  end
  return .true
::method lv_itemText unguarded
  use arg self_, msg, a
  sub = 0
  if a~hasIndex(2) then sub = a[2]
  return self~op(self_, "lv.cell", a[1], sub)
::method lv_delete unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  self~setItemDataOf(p~dlg, p~id, self~op(self_, "lv.uid", a[1]), .nil)
  if self~op(self_, "lv.del", a[1]) == 1 then return 0
  return 1
::method lv_deleteAll unguarded
  use arg self_
  self~op(self_, "lv.clear")
  return 0
::method lv_getNextItem unguarded  -- next, previous, nextSelected, previousSelected ...
  use arg self_, msg, a
  start = -1
  if a~hasIndex(1) then start = a[1]
  flags = "ANY"
  if msg~pos("SELECTED") > 0 then flags = "SELECTED"
  if msg~left(8) == "PREVIOUS" then do
    flags = flags "PREV"
    if \a~hasIndex(1) then start = self~wb_sendWinIntMsg(self_, "", .array~of(4100, 0, 0))
  end
  return self~op(self_, "lv.next", start, flags)
::method lv_getNextItemWithState unguarded   -- selected, focused, dropHighlighted
  use arg self_, msg
  if msg == "DROPHIGHLIGHTED" then return -1
  return self~op(self_, "lv.next", -1, msg)
::method lv_setSpecificState unguarded       -- select, deselect, focus
  use arg self_, msg, a
  if self~op(self_, "lv.state", a[1], msg) == 1 then return 0
  return -1
::method lv_deselectAll unguarded
  use arg self_
  self~op(self_, "lv.deselAll")
  return 0
::method lv_itemState unguarded
  use arg self_, msg, a
  return self~op(self_, "lv.itemState", a[1])
::method lv_checkUncheck unguarded
  use arg self_, msg, a
  self~op(self_, "lv.check", a[1], (msg == "CHECK"))
  return 0
::method lv_isChecked unguarded
  use arg self_, msg, a
  return self~op(self_, "lv.isChecked", a[1]) == 1
::method lv_getCheck unguarded
  use arg self_, msg, a
  if self~op(self_, "lv.ex", "GET")~wordPos("CHECKBOXES") == 0 then return -1
  return self~op(self_, "lv.isChecked", a[1])
::method lv_hasCheckBoxes unguarded
  use arg self_
  return self~op(self_, "lv.ex", "GET")~wordPos("CHECKBOXES") > 0
::method lv_addClearExtendStyle unguarded    -- addExtendedStyle, removeExtendedStyle
  use arg self_, msg, a
  how = "ADD"
  if msg~left(6) == "REMOVE" then how = "REMOVE"
  self~op(self_, "lv.ex", how, a[1]~upper)
  return 0
::method lv_replaceExtendStyle unguarded
  use arg self_, msg, a
  self~op(self_, "lv.ex", "REMOVE", a[1]~upper)
  self~op(self_, "lv.ex", "ADD", a[2]~upper)
  return 0
::method lv_getExtendedStyle unguarded
  use arg self_
  return self~op(self_, "lv.ex", "GET")
::method lv_find unguarded         -- find, findPartial
  use arg self_, msg, a
  start = -1
  if a~hasIndex(2) then start = a[2]
  flags = ""
  if a~hasIndex(3) then if a[3] == .true then flags = "W"
  if msg == "FINDPARTIAL" then flags = flags"P"
  return self~op(self_, "lv.find", a[1], start, flags)
::method lv_setView unguarded
  use arg self_, msg, a
  self~op(self_, "lv.view", a[1]~strip~upper)
  return 0
::method lv_getView unguarded
  use arg self_
  return self~op(self_, "lv.view", "")
::method lv_getItemData unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  return self~itemData(p~dlg, p~id, self~op(self_, "lv.uid", a[1]))
::method lv_setItemData unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  return self~setItemDataOf(p~dlg, p~id, self~op(self_, "lv.uid", a[1]), a[2])
::method lv_removeItemData unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  uid = self~op(self_, "lv.uid", a[1])
  old = self~itemData(p~dlg, p~id, uid)
  self~setItemDataOf(p~dlg, p~id, uid, .nil)
  return old

/* LvItem, LvSubItem, LvFullRow: descriptions of a list-view item, a subitem and a whole row
   (oodListView.cpp).  Each object's peer is a directory.  What the page's list-view does not
   keep for a row (image indexes, indent, group, columns) is kept in the dialog's store under
   (id "lvx" uid).  The image indexes are kept and answered; the page draws no item images. */
::method lvMaskOf unguarded        -- the mask an item has from what was given
  use arg info
  mask = ""
  if info~text \== .nil then mask = mask "TEXT"
  if info~imageIndex \== .nil then mask = mask "IMAGE"
  if info~hasIndex("ITEMDATA") then if info~itemData \== .nil then mask = mask "PARAM"
  if info~hasIndex("ITEMSTATE") then if info~itemState \== "" then mask = mask "STATE"
  if info~hasIndex("INDENT") then if info~indent \== .nil then mask = mask "INDENT"
  if info~hasIndex("GROUPID") then if info~groupID \== .nil then mask = mask "GROUPID"
  if info~hasIndex("COLUMNS") then if info~columns \== .nil then mask = mask "COLUMNS"
  return mask~strip
::method lvi_init unguarded        -- LvItem~new(index, text, imageIndex, itemData, mask, itemState, itemStateMask, indent, groupID, columns)
  use arg self_, msg, a
  info = .directory~new
  info["INDEX"] = 0
  if a~hasIndex(1) then info["INDEX"] = a[1]
  info~text = .nil
  if a~hasIndex(2) then info~text = a[2]
  info~imageIndex = .nil
  if a~hasIndex(3) then info~imageIndex = a[3]
  info~itemData = .nil
  if a~hasIndex(4) then info~itemData = a[4]
  info~itemState = self~opt(a, 6)
  info~itemStateMask = self~opt(a, 7)
  if info~itemState \== "" & info~itemStateMask == "" then info~itemStateMask = info~itemState
  info~indent = .nil
  if a~hasIndex(8) then info~indent = a[8]
  info~groupID = .nil
  if a~hasIndex(9) then info~groupID = a[9]
  info~columns = .nil
  if a~hasIndex(10) then info~columns = a[10]
  info~columnFormats = .nil
  info~overlayImageIndex = 0
  info~stateImageIndex = 0
  info~mask = self~opt(a, 5)
  info~maskGiven = (info~mask \== "")
  self_~oodPeer = info
  return 0
::method lvi_init_cls unguarded
  return 0
::method lvi_unInit unguarded
  return 0
::method lviGet unguarded
  use arg self_, name, default
  value = self_~oodPeer[name]
  if value == .nil then return default
  return value
::method lvi_index unguarded
  use arg self_
  return self_~oodPeer["INDEX"]
::method lvi_setIndex unguarded
  use arg self_, msg, a
  self_~oodPeer["INDEX"] = a[1]
::method lvi_text unguarded
  use arg self_
  return self~lviGet(self_, "TEXT", "")
::method lvi_setText unguarded
  use arg self_, msg, a
  self_~oodPeer~text = a[1]
::method lvi_imageIndex unguarded
  use arg self_
  return self~lviGet(self_, "IMAGEINDEX", -1)
::method lvi_setImageIndex unguarded
  use arg self_, msg, a
  self_~oodPeer~imageIndex = a[1]
::method lvi_itemData unguarded
  use arg self_
  return self_~oodPeer~itemData
::method lvi_setItemData unguarded
  use arg self_, msg, a
  self_~oodPeer~itemData = a[1]
::method lvi_itemState unguarded
  use arg self_
  return self_~oodPeer~itemState
::method lvi_setItemState unguarded
  use arg self_, msg, a
  self_~oodPeer~itemState = a[1]
  if self_~oodPeer~itemStateMask == "" then self_~oodPeer~itemStateMask = a[1]
::method lvi_itemStateMask unguarded
  use arg self_
  return self_~oodPeer~itemStateMask
::method lvi_setItemStateMask unguarded
  use arg self_, msg, a
  self_~oodPeer~itemStateMask = a[1]
::method lvi_indent unguarded
  use arg self_
  return self~lviGet(self_, "INDENT", 0)
::method lvi_setIndent unguarded
  use arg self_, msg, a
  self_~oodPeer~indent = a[1]
::method lvi_groupID unguarded
  use arg self_
  return self~lviGet(self_, "GROUPID", -2)
::method lvi_setGroupID unguarded
  use arg self_, msg, a
  self_~oodPeer~groupID = a[1]
::method lvi_columns unguarded
  use arg self_
  return self_~oodPeer~columns
::method lvi_setColumns unguarded
  use arg self_, msg, a
  self_~oodPeer~columns = a[1]
::method lvi_columnFormats unguarded
  use arg self_
  return self_~oodPeer~columnFormats
::method lvi_setColumnFormats unguarded
  use arg self_, msg, a
  self_~oodPeer~columnFormats = a[1]
::method lvi_overLayImageIndex unguarded
  use arg self_
  return self_~oodPeer~overlayImageIndex
::method lvi_setOverlayImageIndex unguarded
  use arg self_, msg, a
  self_~oodPeer~overlayImageIndex = a[1]
::method lvi_stateImageIndex unguarded
  use arg self_
  return self_~oodPeer~stateImageIndex
::method lvi_setStateImageIndex unguarded
  use arg self_, msg, a
  self_~oodPeer~stateImageIndex = a[1]
::method lvi_mask unguarded        -- the mask given, or the one that follows from what is set
  use arg self_
  info = self_~oodPeer
  if info~maskGiven then return info~mask
  return self~lvMaskOf(info)
::method lvi_setMask unguarded
  use arg self_, msg, a
  self_~oodPeer~mask = a[1]
  self_~oodPeer~maskGiven = .true
::method lvsi_init unguarded       -- LvSubItem~new(item, subItem, text, imageIndex, mask)
  use arg self_, msg, a
  info = .directory~new
  info~item = a[1]
  info~subItem = a[2]
  if info~subItem < 1 then raise syntax 93.907 array(2, 1, 4294967295, info~subItem)
  info~text = .nil
  if a~hasIndex(3) then info~text = a[3]
  info~imageIndex = .nil
  if a~hasIndex(4) then info~imageIndex = a[4]
  info~mask = self~opt(a, 5)
  info~maskGiven = (info~mask \== "")
  self_~oodPeer = info
  return 0
::method lvsi_init_cls unguarded
  return 0
::method lvsi_unInit unguarded
  return 0
::method lvsi_item unguarded
  use arg self_
  return self_~oodPeer~item
::method lvsi_setItem unguarded
  use arg self_, msg, a
  self_~oodPeer~item = a[1]
::method lvsi_subItem unguarded
  use arg self_
  return self_~oodPeer~subItem
::method lvsi_setSubItem unguarded
  use arg self_, msg, a
  self_~oodPeer~subItem = a[1]
::method lvsi_text unguarded
  use arg self_
  return self~lviGet(self_, "TEXT", "")
::method lvsi_setText unguarded
  use arg self_, msg, a
  self_~oodPeer~text = a[1]
::method lvsi_imageIndex unguarded
  use arg self_
  return self~lviGet(self_, "IMAGEINDEX", -1)
::method lvsi_setImageIndex unguarded
  use arg self_, msg, a
  self_~oodPeer~imageIndex = a[1]
::method lvsi_mask unguarded
  use arg self_
  info = self_~oodPeer
  if info~maskGiven then return info~mask
  return self~lvMaskOf(info)
::method lvsi_setMask unguarded
  use arg self_, msg, a
  self_~oodPeer~mask = a[1]
  self_~oodPeer~maskGiven = .true
/* LvFullRow~new(lvItem, lvSubItem ..., useForSorting): the last argument may be a logical. */
::method lvfr_init unguarded
  use arg self_, msg, a
  if \a~hasIndex(1) then raise syntax 93.903 array(1)
  if \a[1]~isA(self~classOf("LvItem")) then raise syntax 93.948 array(1, "LvItem")
  row = .directory~new
  row~item = a[1]
  row~subs = .array~new
  row~forSorting = .false
  row~userData = .nil
  do i = 2 to a~size
    if \a~hasIndex(i) then raise syntax 93.903 array(i)
    if a[i]~isA(self~classOf("LvSubItem")) then do
      a[i]~oodPeer~item = row~item~oodPeer["INDEX"]
      row~subs~append(a[i])
    end
    else if i == a~size & (a[i] == .true | a[i] == .false) then row~forSorting = a[i]
    else raise syntax 93.948 array(i, "LvSubItem")
  end
  self_~oodPeer = row
  return 0
::method lvfr_init_cls unguarded
  return 0
::method lvfr_unInit unguarded
  return 0
::method lvfr_fromArray_cls unguarded  -- fromArray(data, itemIndex, strIfNil, useForSorting)
  use arg self_, msg, a
  data = a[1]
  if \data~isA(.Array) then raise syntax 93.948 array(1, "Array")
  if data~items == 0 then return .nil
  index = 0
  if a~hasIndex(2) then index = a[2]
  nullStr = self~opt(a, 3)
  args = .array~new
  do i = 1 to data~size
    if \data~hasIndex(i) then raise syntax 93.900 array("The data array can not be sparse; index" i "is missing")
    text = data[i]
    if text == .nil then text = nullStr
    else text = text~string
    if i == 1 then args~append(self~classOf("LvItem")~new(index, text))
    else args~append(self~classOf("LvSubItem")~new(index, i - 1, text))
  end
  if a~hasIndex(4) then args~append(a[4] == .true)
  return self_~sendWith("NEW", args)
::method lvfr_item unguarded
  use arg self_
  return self_~oodPeer~item
::method lvfr_subitems unguarded
  use arg self_
  return self_~oodPeer~subs~items
::method lvfr_subitem unguarded    -- subitem(index): index 1 is the first subitem
  use arg self_, msg, a
  subs = self_~oodPeer~subs
  if a[1] < 1 | a[1] > subs~items then return .nil
  return subs[a[1]]
::method lvfr_addSubitem unguarded -- the new subitem is the last; answers its index
  use arg self_, msg, a
  if \a[1]~isA(self~classOf("LvSubItem")) then raise syntax 93.948 array(1, "LvSubItem")
  row = self_~oodPeer
  row~subs~append(a[1])
  a[1]~oodPeer~subItem = row~subs~items
  a[1]~oodPeer~item = row~item~oodPeer["INDEX"]
  return row~subs~items
::method lvfr_insertSubitem unguarded  -- insertSubitem(subitem, colIndex): the later subitems move up one
  use arg self_, msg, a
  if \a[1]~isA(self~classOf("LvSubItem")) then raise syntax 93.948 array(1, "LvSubItem")
  row = self_~oodPeer
  at = a[2]
  if at < 1 | at > row~subs~items + 1 then return .false
  if at == 1 then row~subs~insert(a[1], .nil)       -- (.nil: before the first)
  else row~subs~insert(a[1], at - 1)
  do i = 1 to row~subs~items
    row~subs[i]~oodPeer~subItem = i
  end
  a[1]~oodPeer~item = row~item~oodPeer["INDEX"]
  return .true
::method lvfr_removeSubitem unguarded  -- answers the removed subitem; .nil if there is none
  use arg self_, msg, a
  row = self_~oodPeer
  if a[1] < 1 | a[1] > row~subs~items then return .nil
  removed = row~subs~delete(a[1])
  do i = 1 to row~subs~items
    row~subs[i]~oodPeer~subItem = i
  end
  return removed
::method lvfr_userData unguarded
  use arg self_
  return self_~oodPeer~userData
::method lvfr_setUserData unguarded
  use arg self_, msg, a
  self_~oodPeer~userData = a[1]
::method lvExtra unguarded         -- what the page does not keep for a row
  use arg self_, uid
  p = self_~oodPeer
  extra = p~dlg~store[p~id "lvx" uid]
  if extra == .nil then do
    extra = .directory~new
    extra~images = .table~new      -- column -> image index
    p~dlg~store[p~id "lvx" uid] = extra
  end
  return extra
::method lvPutItem unguarded       -- what an LvItem says, onto the row at index
  use arg self_, index, item, withText, uid = ""
  info = item~oodPeer
  mask = self~lvi_mask(item)~upper
  if uid == "" then uid = self~op(self_, "lv.uid", index)
  if uid == 0 then return .false
  if withText & info~text \== .nil & mask~wordPos("TEXT") > 0 then self~op(self_, "lv.setCell", index, 0, info~text)
  extra = self~lvExtra(self_, uid)
  if info~imageIndex \== .nil & mask~wordPos("IMAGE") > 0 then extra~images[0] = info~imageIndex
  if info~indent \== .nil then extra~indent = info~indent
  if info~groupID \== .nil then extra~groupID = info~groupID
  if info~columns \== .nil then extra~columns = info~columns
  if info~itemData \== .nil & mask~wordPos("PARAM") > 0 then self~setItemDataOf(self_~oodPeer~dlg, self_~oodPeer~id, uid, info~itemData)
  if mask~wordPos("STATE") > 0 then do word over info~itemStateMask~upper~makeArray(" ")
    on = info~itemState~upper~wordPos(word) > 0
    select
      when word == "SELECTED" then if on then self~op(self_, "lv.state", index, "SELECT"); else self~op(self_, "lv.state", index, "DESELECT")
      when word == "FOCUSED" then if on then self~op(self_, "lv.state", index, "FOCUS")
      otherwise nop
    end
  end
  return .true
::method lvPutRow unguarded        -- a new row from a full row, at index (-1: the end); answers its index
  use arg self_, row, at
  r = row~oodPeer
  texts = self~lvi_text(r~item)
  do sub over r~subs
    texts = texts || self~sep || self~lvsi_text(sub)
  end
  parse value self~op(self_, "lv.insRow", at, texts, "U") with index uid .
  if index == "" | index < 0 then return -1
  r~item~oodPeer["INDEX"] = index
  self~lvPutItem(self_, index, r~item, .false, uid)
  extra = self~lvExtra(self_, uid)
  do sub over r~subs
    sub~oodPeer~item = index
    if sub~oodPeer~imageIndex \== .nil then extra~images[sub~oodPeer~subItem] = sub~oodPeer~imageIndex
  end
  if r~forSorting then self~setItemDataOf(self_~oodPeer~dlg, self_~oodPeer~id, uid, row)
  return index
::method lvRowArg unguarded
  use arg a
  if \a~hasIndex(1) then raise syntax 93.903 array(1)
  if \a[1]~isA(self~classOf("LvFullRow")) then raise syntax 93.948 array(1, "LvFullRow")
  return a[1]
::method lv_addFullRow unguarded   -- the row becomes the last row
  use arg self_, msg, a
  return self~lvPutRow(self_, self~lvRowArg(a), -1)
::method lv_prependFullRow unguarded
  use arg self_, msg, a
  return self~lvPutRow(self_, self~lvRowArg(a), 0)
::method lv_insertFullRow unguarded    -- at the index the row's item has
  use arg self_, msg, a
  row = self~lvRowArg(a)
  return self~lvPutRow(self_, row, row~oodPeer~item~oodPeer["INDEX"])
::method lv_addRowFromArray unguarded  -- addRowFromArray(data, itemIndex, strIfNil): at itemIndex, or at the end
  use arg self_, msg, a
  if \a[1]~isA(.Array) then raise syntax 93.948 array(1, "Array")
  at = -1
  if a~hasIndex(2) then at = a[2]
  nullStr = self~opt(a, 3)
  texts = ""
  do i = 1 to a[1]~size
    if \a[1]~hasIndex(i) then raise syntax 93.900 array("The data array can not be sparse; index" i "is missing")
    text = a[1][i]
    if text == .nil then text = nullStr
    if i > 1 then texts = texts || self~sep
    texts = texts || text~string
  end
  return self~op(self_, "lv.insRow", at, texts)
::method lv_getItem unguarded      -- getItem(lvItem): the LvItem takes what the row at its index has
  use arg self_, msg, a
  if \a[1]~isA(self~classOf("LvItem")) then raise syntax 93.948 array(1, "LvItem")
  info = a[1]~oodPeer
  uid = self~op(self_, "lv.uid", info["INDEX"])
  if uid == 0 then return .false
  extra = self~lvExtra(self_, uid)
  info~text = self~op(self_, "lv.cell", info["INDEX"], 0)
  info~imageIndex = extra~images[0]
  info~itemData = self~itemData(self_~oodPeer~dlg, self_~oodPeer~id, uid)
  state = ""
  words = self~op(self_, "lv.itemState", info["INDEX"])~upper
  if words~wordPos("FOCUSED") > 0 then state = state "FOCUSED"
  if words~wordPos("SELECTED") > 0 then state = state "SELECTED"
  info~itemState = state~strip
  info~itemStateMask = "FOCUSED SELECTED"
  info~indent = extra~indent
  info~groupID = extra~groupID
  info~columns = extra~columns
  return .true
::method lv_getSubitem unguarded   -- getSubitem(lvSubItem), or getSubitem(itemIndex, subitemIndex) which answers a new LvSubItem
  use arg self_, msg, a
  if a[1]~isA(self~classOf("LvSubItem")) then sub = a[1]
  else do
    if \a~hasIndex(2) then raise syntax 93.903 array(2)
    sub = self~classOf("LvSubItem")~new(a[1], a[2])
  end
  info = sub~oodPeer
  uid = self~op(self_, "lv.uid", info~item)
  if uid == 0 | info~subItem >= self~op(self_, "lv.colCount") then do
    if a[1]~isA(self~classOf("LvSubItem")) then return .false
    return .nil
  end
  info~text = self~op(self_, "lv.cell", info~item, info~subItem)
  info~imageIndex = self~lvExtra(self_, uid)~images[info~subItem]
  if a[1]~isA(self~classOf("LvSubItem")) then return .true
  return sub
::method lv_getFullRow unguarded   -- getFullRow(index, useForSorting): .nil if there is no such row
  use arg self_, msg, a
  index = a[1]
  if self~op(self_, "lv.uid", index) == 0 then return .nil
  item = self~classOf("LvItem")~new(index)
  self~lv_getItem(self_, "GETITEM", .array~of(item))
  args = .array~of(item)
  do c = 1 to self~op(self_, "lv.colCount") - 1
    args~append(self~lv_getSubitem(self_, "GETSUBITEM", .array~of(index, c)))
  end
  if a~hasIndex(2) then args~append(a[2] == .true)
  return self~classOf("LvFullRow")~sendWith("NEW", args)
::method lv_modifyItem unguarded
  use arg self_, msg, a
  if \a[1]~isA(self~classOf("LvItem")) then raise syntax 93.948 array(1, "LvItem")
  return self~lvPutItem(self_, a[1]~oodPeer["INDEX"], a[1], .true)
::method lv_modifySubitem unguarded
  use arg self_, msg, a
  if \a[1]~isA(self~classOf("LvSubItem")) then raise syntax 93.948 array(1, "LvSubItem")
  info = a[1]~oodPeer
  uid = self~op(self_, "lv.uid", info~item)
  if uid == 0 then return .false
  if info~text \== .nil then self~op(self_, "lv.setCell", info~item, info~subItem, info~text)
  if info~imageIndex \== .nil then self~lvExtra(self_, uid)~images[info~subItem] = info~imageIndex
  return .true
::method lv_modifyFullRow unguarded    -- the row at the index of the full row's item takes all the full row says
  use arg self_, msg, a
  row = self~lvRowArg(a)~oodPeer
  if \self~lvPutItem(self_, row~item~oodPeer["INDEX"], row~item, .true) then return .false
  do sub over row~subs
    sub~oodPeer~item = row~item~oodPeer["INDEX"]
    self~lv_modifySubitem(self_, "MODIFYSUBITEM", .array~of(sub))
  end
  return .true
::method lv_setFullRowText unguarded   -- only the texts
  use arg self_, msg, a
  row = self~lvRowArg(a)~oodPeer
  index = row~item~oodPeer["INDEX"]
  if self~op(self_, "lv.uid", index) == 0 then return .false
  if row~item~oodPeer~text \== .nil then self~op(self_, "lv.setCell", index, 0, row~item~oodPeer~text)
  do sub over row~subs
    if sub~oodPeer~text \== .nil then self~op(self_, "lv.setCell", index, sub~oodPeer~subItem, sub~oodPeer~text)
  end
  return .true
::method lv_fixFullRowColumns unguarded    -- (the rows are read from the page when they are wanted: nothing to fix)
  return .true
/* sortItems(method, param).  "InternalListViewSort": by the texts of param~column, with
   param~ascending and param~caseless.  Any other name is a method of the dialog: it gets
   the item data of two rows and param, and answers -1, 0 or 1. */
::method lv_sortItems unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  method = a[1]
  param = .nil
  if a~hasIndex(2) then param = a[2]
  uids = self~op(self_, "lv.uids")~makeArray(" ")
  if uids~items < 2 then return .true
  if method~upper == "INTERNALLISTVIEWSORT" then do
    column = 0
    ascending = .true
    caseless = .true
    if param \== .nil then do
      if param~hasIndex("COLUMN") then column = param~column
      if param~hasIndex("ASCENDING") then ascending = (param~ascending == .true)
      if param~hasIndex("CASELESS") then caseless = (param~caseless == .true)
    end
    keys = .array~new
    do i = 1 to uids~items
      key = self~op(self_, "lv.cell", i - 1, column)
      if caseless then key = key~upper
      keys~append(.array~of(key, uids[i]))
    end
    sorted = keys~sortWith(.OodPairOrder~new(ascending))
  end
  else do
    dlg = p~dlg~rexxSelf
    if \dlg~hasMethod(method) then raise syntax 93.900 array('sortItems: the dialog has no method "'method'"')
    keys = .array~new
    do uid over uids
      keys~append(.array~of(self~itemData(p~dlg, p~id, uid), uid))
    end
    sorted = keys~stableSortWith(.OodCallOrder~new(dlg, method, param))
  end
  order = ""
  do pair over sorted
    order = order pair[2]
  end
  self~op(self_, "lv.order", order~strip)
  return .true
::method lv_setItemState unguarded -- setItemState(index, keywords): SELECTED FOCUSED and their NOT forms
  use arg self_, msg, a
  if self~op(self_, "lv.uid", a[1]) == 0 then return .false
  do word over a[2]~upper~makeArray(" ")
    select
      when word == "SELECTED" then self~op(self_, "lv.state", a[1], "SELECT")
      when word == "NOTSELECTED" then self~op(self_, "lv.state", a[1], "DESELECT")
      when word == "FOCUSED" then self~op(self_, "lv.state", a[1], "FOCUS")
      otherwise nop
    end
  end
  return .true

/*---- TreeView -------------------------------------------------------------------------*/
::method tvHandle unguarded        -- an item of the page as the handle Rexx sees; 0 is no item
  use arg h
  if h == 0 | h == "" then return 0
  return "0x"d2x(h)~right(16, "0")
::method tvItem unguarded          -- a handle argument as the page's item; ROOT and omitted are 0
  use arg a, i
  if \a~hasIndex(i) then return 0
  v = a[i]~strip~upper
  if v == "ROOT" | v == "TVI_ROOT" then return 0
  return self~number(v)

::method tv_insert unguarded       -- insert(parent, after, label, image, selectedImage, opts, children, userData)
  use arg self_, msg, a
  parent = self~tvItem(a, 1)
  after = "LAST"
  if a~hasIndex(2) then do
    after = a[2]~strip~upper
    if after~left(4) == "TVI_" then after = after~substr(5)
    if after~wordPos("FIRST LAST SORT ROOT") == 0 then after = self~number(after)
    if after == "ROOT" then after = "LAST"
  end
  h = self~op(self_, "tv.ins", parent, after, self~opt(a, 3) || self~sep || self~opt(a, 6)~upper)
  if h == "" | h == 0 then return 0
  p = self_~oodPeer
  if a~hasIndex(8) then self~setItemDataOf(p~dlg, p~id, h, a[8])
  image = -1                         -- (image indexes are kept and answered; the page draws no item images)
  if a~hasIndex(4) then image = a[4]
  selected = image
  if a~hasIndex(5) then selected = a[5]
  if image \== -1 | selected \== -1 then p~dlg~store[p~id "tvimg" h] = .array~of(image, selected)
  return self~tvHandle(h)
::method tv_delete unguarded
  use arg self_, msg, a
  if self~op(self_, "tv.del", self~tvItem(a, 1)) == 1 then return 0
  return 1
::method tv_deleteAll unguarded
  use arg self_
  self~op(self_, "tv.clear")
  return 0
::method tv_expand unguarded       -- expand, collapse, collapseAndReset, toggle
  use arg self_, msg, a
  how = "EXPAND"
  if msg~left(8) == "COLLAPSE" then how = "COLLAPSE"
  if msg == "TOGGLE" then how = "TOGGLE"
  if self~op(self_, "tv.expand", self~tvItem(a, 1), how) == 1 then return 0
  return 1
::method tv_find unguarded
  use arg self_, msg, a
  abbrev = 0
  if a~hasIndex(3) then if a[3] == .true then abbrev = 1
  return self~tvHandle(self~op(self_, "tv.find", a[1], self~tvItem(a, 2), abbrev))
::method tv_getNextItem unguarded  -- child, next, nextVisible, parent, previous, previousVisible
  use arg self_, msg, a
  return self~tvHandle(self~op(self_, "tv.rel", self~tvItem(a, 1), msg))
::method tv_getSpecificItem unguarded        -- root, selected, firstVisible, dropHighlighted
  use arg self_, msg
  return self~tvHandle(self~op(self_, "tv.special", msg))
::method tv_itemText unguarded
  use arg self_, msg, a
  return self~op(self_, "tv.text", self~tvItem(a, 1))
::method tv_itemInfo unguarded
  use arg self_, msg, a
  info = self~op(self_, "tv.info", self~tvItem(a, 1))
  if info == "" then return -1
  sep = self~sep
  parse var info text (sep) children (sep) state
  p = self_~oodPeer
  h = self~tvItem(a, 1)
  images = p~dlg~store[p~id "tvimg" h]
  if images == .nil then images = .array~of(-1, -1)
  d = .stem~new("InternalTVItemInfo")      -- a stem, as upstream answers: info.!Text, info.!State ...
  d["!TEXT"] = text
  d["!CHILDREN"] = (children > 0)
  d["!IMAGE"] = images[1]
  d["!SELECTEDIMAGE"] = images[2]
  d["!STATE"] = state
  d["!ITEMDATA"] = self~itemData(p~dlg, p~id, h)
  return d
::method tv_modify unguarded       -- modify(item, label, image, selectedImage, opts, children, userData)
  use arg self_, msg, a
  if a~hasIndex(1) then h = self~tvItem(a, 1)
  else h = self~op(self_, "tv.special", "SELECTED")
  flag = ""
  if a~hasIndex(2) then flag = flag"T"
  if a~hasIndex(5) then flag = flag"O"
  change = flag || self~sep || self~opt(a, 2) || self~sep || self~opt(a, 5)~upper
  if a~hasIndex(3) | a~hasIndex(4) then do       -- the image indexes
    p = self_~oodPeer
    images = p~dlg~store[p~id "tvimg" h]
    if images == .nil then images = .array~of(-1, -1)
    if a~hasIndex(3) then images[1] = a[3]
    if a~hasIndex(4) then images[2] = a[4]
    p~dlg~store[p~id "tvimg" h] = images
  end
  if a~hasIndex(7) then self~setItemDataOf(self_~oodPeer~dlg, self_~oodPeer~id, h, a[7])
  if self~op(self_, "tv.modify", h, change) == 1 then return 0
  return -1
::method tv_selectItem unguarded   -- select, makeFirstVisible, dropHighlight
  use arg self_, msg, a
  if msg \== "SELECT" then return 0
  if self~op(self_, "tv.select", self~tvItem(a, 1)) == 1 then return 0
  return 1
::method tv_getItemData unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  return self~itemData(p~dlg, p~id, self~tvItem(a, 1))
::method tv_setItemData unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  value = .nil
  if a~hasIndex(2) then value = a[2]
  old = self~itemData(p~dlg, p~id, self~tvItem(a, 1))
  self~setItemDataOf(p~dlg, p~id, self~tvItem(a, 1), value)
  return old

/*---- Tab ---------------------------------------------------------------------------------*/
::method tab_insert unguarded      -- insert(index, label, imageIndex, userData)
  use arg self_, msg, a
  at = -1
  if a~hasIndex(1) then at = a[1]
  return self~op(self_, "tab.ins", at, self~opt(a, 2))
::method tab_addSequence unguarded
  use arg self_, msg, a
  last = -1
  do tabText over a
    last = self~op(self_, "tab.ins", -1, tabText)
  end
  return last
::method tab_addFullSeq unguarded  -- label, imageIndex, userData triples
  use arg self_, msg, a
  last = -1
  do i = 1 to a~size by 3
    last = self~op(self_, "tab.ins", -1, self~opt(a, i))
  end
  return last
::method tab_itemInfo unguarded
  use arg self_, msg, a
  count = self~wb_sendWinIntMsg(self_, "", .array~of(4868, 0, 0))
  if a[1] < 0 | a[1] >= count then return -1
  d = .directory~new
  d~text = self~op(self_, "tab.text", a[1])
  d~image = -1
  d~userData = .nil
  return d
::method tab_modify unguarded
  use arg self_, msg, a
  if a~hasIndex(2) then if self~op(self_, "tab.setText", a[1], a[2]) \== 1 then return 1
  return 0
::method tab_select unguarded
  use arg self_, msg, a
  return self~op(self_, "tab.selectText", a[1])
::method tab_selected unguarded
  use arg self_
  current = self~wb_sendWinIntMsg(self_, "", .array~of(4875, 0, 0))
  if current < 0 then return ""
  return self~op(self_, "tab.text", current)
::method tab_calcRect unguarded    -- calcDisplayRect(rect) / calcWindowRect(rect), as TCM_ADJUSTRECT
  use arg self_, msg, a
  /* calcDisplayRect: the rect is the tab control's rectangle in any coordinates (programs give
     windowRect); it becomes the area for the pages in the same coordinates.  calcWindowRect is
     the reverse.  The page answers the display area in the dialog's client pixels. */
  parse value self~op(self_, "tab.rect") with left top right bottom
  if left == "" then return .false
  parse value self~op(self_, "tab.outer") with tabLeft tabTop tabRight tabBottom
  if tabLeft == "" then return .false
  sign = 1
  if msg == "CALCWINDOWRECT" then sign = -1
  r = a[1]
  r~left += sign * (left - tabLeft)
  r~top += sign * (top - tabTop)
  r~right -= sign * (tabRight - right)
  r~bottom -= sign * (tabBottom - bottom)
  return .true
::method tab_setItemSize unguarded
  return .Size~new
::method tab_setPadding unguarded
  return 0

/*---- WindowBase: dialogs and controls -----------------------------------------*/
::method wb_init_windowBase unguarded
  return 0
::method wb_getInitCode unguarded
  use arg self_
  p = self_~oodPeer
  if p~isA(.OodDlg) then return p~initCode
  return 0
::method wb_setInitCode unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  if p~isA(.OodDlg) then p~initCode = a[1]
  return
::method wb_getHwnd unguarded
  use arg self_
  p = self_~oodPeer
  if p~isA(.OodDlg) then if \p~live then return 0
  return p~hwnd
::method dlgOf unguarded
  use arg obj
  p = obj~oodPeer
  if p~isA(.OodDlg) then return p
  return p~dlg
::method wb_getSizeX unguarded
  use arg self_
  return self~dlgOf(self_)~sizeX
::method wb_setSizeX unguarded
  use arg self_, msg, a
  self~dlgOf(self_)~sizeX = a[1]
  return
::method wb_getSizeY unguarded
  use arg self_
  return self~dlgOf(self_)~sizeY
::method wb_setSizeY unguarded
  use arg self_, msg, a
  self~dlgOf(self_)~sizeY = a[1]
  return
::method wb_getFactorX unguarded
  use arg self_
  return self~dlgOf(self_)~factorX
::method wb_setFactorX unguarded
  use arg self_, msg, a
  self~dlgOf(self_)~factorX = a[1]
  return
::method wb_getFactorY unguarded
  use arg self_
  return self~dlgOf(self_)~factorY
::method wb_setFactorY unguarded
  use arg self_, msg, a
  self~dlgOf(self_)~factorY = a[1]
  return
::method wb_getPixelCX unguarded
  use arg self_
  return self~dlgOf(self_)~pixelCX
::method wb_getPixelCY unguarded
  use arg self_
  return self~dlgOf(self_)~pixelCY

::method wb_getText unguarded      -- getText, title
  use arg self_
  return self~op(self_, "getText")
::method wb_setText unguarded      -- setText, setTitle, title=
  use arg self_, msg, a
  if self~op(self_, "setText", a[1]) == 1 then return 0
  return 1
::method wb_enable unguarded       -- enable, disable
  use arg self_, msg
  self~op(self_, "enable", (msg == "ENABLE"))
  return 0
::method wb_isEnabled unguarded
  use arg self_
  return self~op(self_, "isEnabled") == 1
::method wb_show unguarded         -- show, hide
  use arg self_, msg
  if msg == "HIDE" then self~op(self_, "hide")
  else self~op(self_, "show")
  return 0
::method wb_showFast unguarded
  use arg self_, msg
  if msg == "HIDEFAST" then self~op(self_, "hide")
  else self~op(self_, "show")
  return 0
::method wb_isVisible unguarded
  use arg self_
  return self~op(self_, "isVisible") == 1
::method wb_display unguarded
  use arg self_, msg, a
  how = self~opt(a, 1)~upper
  if how~pos("HIDE") > 0 then self~op(self_, "hide")
  else self~op(self_, "show")
  return 0
::method wb_redraw unguarded
  return 0
::method wb_redrawClient unguarded
  return 0
::method wb_updateWindow unguarded
  return 0
::method wb_clear unguarded
  return 0
::method wb_foreGroundWindow unguarded
  return 0

::method wb_windowRect unguarded    -- of this window, or of the window whose handle is given
  use arg self_, msg, a
  if a~hasIndex(1) then do
    handle = self~number(a[1])
    owner = self~dialogOf(handle % 65536)
    if owner == .nil then return .Rect~new
    answer = self~ctlOp(owner, handle // 65536, "rect")
  end
  else answer = self~op(self_, "rect")
  parse var answer left top right bottom
  if left == "" then return .Rect~new
  return .Rect~new(left, top, right, bottom)
::method lv_hitTestInfo unguarded  -- hitTestInfo(point | x, y [, info]): the index of the item there, -1 for none
  use arg self_, msg, a
  if \a~hasIndex(1) then return -1
  at = 2
  if a[1]~isA(.String) then do
    x = a[1]
    y = 0
    if a~hasIndex(2) then y = a[2]
    at = 3
  end
  else do
    x = a[1]~x
    y = a[1]~y
  end
  parse value self~op(self_, "lv.hit", x, y) with row col .
  if row == "" then row = -1
  if a~hasIndex(at) then if a[at]~isA(.directory) then do
    info = a[at]
    info~info = "OnLabel OnItem"
    if row < 0 then info~info = "NoWhere"
    info~infoEx = ""
    info~subItem = col
    info~group = -1
  end
  return row
::method wb_mapWindowPoints unguarded   -- mapWindowPoints(hwndTo, point | rect): from this window's client area to that one's (0: the page)
  use arg self_, msg, a
  parse value self~op(self_, "rect") with fromLeft fromTop .
  if fromLeft == "" then return .false
  toLeft = 0
  toTop = 0
  handle = 0
  if a~hasIndex(1) then if a[1] \== .nil then handle = self~number(a[1])
  if handle \== 0 then do
    owner = self~dialogOf(handle % 65536)
    if owner == .nil then return .false
    parse value self~ctlOp(owner, handle // 65536, "rect") with toLeft toTop .
    if toLeft == "" then return .false
  end
  dx = fromLeft - toLeft
  dy = fromTop - toTop
  what = a[2]
  if what~isA(.Rect) then do
    what~left = what~left + dx
    what~right = what~right + dx
    what~top = what~top + dy
    what~bottom = what~bottom + dy
  end
  else do
    what~x = what~x + dx
    what~y = what~y + dy
  end
  return .true
::method wb_clientRect unguarded    -- of this window, or of the window whose handle is given
  use arg self_, msg, a
  if a~hasIndex(1) then do
    handle = self~number(a[1])
    owner = self~dialogOf(handle % 65536)
    if owner == .nil then return .Rect~new
    answer = self~ctlOp(owner, handle // 65536, "clientRect")
  end
  else answer = self~op(self_, "clientRect")
  parse var answer left top right bottom
  if left == "" then return .Rect~new
  return .Rect~new(left, top, right, bottom)
::method wb_getSizePos unguarded   -- getRealPos, getRealSize
  use arg self_, msg
  parse value self~op(self_, "rect") with left top right bottom
  if left == "" then do
    if msg == "GETREALPOS" then return .Point~new
    return .Size~new
  end
  if msg == "GETREALPOS" then return .Point~new(left, top)
  return .Size~new(right - left, bottom - top)
::method wb_resizeMove unguarded   -- moveTo(point | x, y), resizeTo(size | w, h)
  use arg self_, msg, a
  first = a[1]
  if first~isA(.String) then do
    v1 = first
    v2 = a[2]
  end
  else if msg == "MOVETO" then do
    v1 = first~x
    v2 = first~y
  end
  else do
    v1 = first~width
    v2 = first~height
  end
  if msg == "MOVETO" then self~op(self_, "move", v1, v2)
  else self~op(self_, "size", v1, v2)
  return 0
::method wb_setRect unguarded      -- setRect(point, size, opts) and its variations
  use arg self_, msg, a
  opts = ""
  nums = .array~new
  do i = 1 to a~items
    v = a[i]
    select
      when v~isA(.String) then do
        if v~datatype("N") then nums~append(v)
        else opts = v~upper
      end
      when v~hasMethod("WIDTH") then do
        nums~append(v~width)
        nums~append(v~height)
      end
      when v~hasMethod("RIGHT") then do
        nums~append(v~left); nums~append(v~top)
        nums~append(v~right - v~left); nums~append(v~bottom - v~top)
      end
      otherwise do
        nums~append(v~x)
        nums~append(v~y)
      end
    end
  end
  if nums~items < 4 then return .false
  if opts~pos("NOMOVE") == 0 then self~op(self_, "move", nums[1], nums[2])
  if opts~pos("NOSIZE") == 0 then self~op(self_, "size", nums[3], nums[4])
  return .true

/* Win32 messages: a control's go to the page; a dialog's few are done here. */
::method wb_sendWinIntMsg unguarded
  use arg self_, msg, a
  t = self~target(self_)
  code = self~number(a[1])
  wParam = 0
  lParam = 0
  if a~hasIndex(2) then wParam = self~number(a[2])
  if a~hasIndex(3) then lParam = self~number(a[3])
  if t[2] == 0 then do
    select
      when code == 40 then self~ctlOp(t[1], 0, "tab", (wParam == 0))        -- WM_NEXTDLGCTL
      when code == 1025 then self~ctlOp(t[1], 0, "default", wParam)         -- DM_SETDEFID
      otherwise nop
    end
    return 0
  end
  return self~winMsg(t[1], t[2], code, wParam, lParam)
::method wb_sendWinUintMsg unguarded
  forward message "wb_sendWinIntMsg"
::method wb_sendMessage unguarded
  forward message "wb_sendWinIntMsg"
::method wb_getWindowLong_pvt unguarded
  use arg self_, msg, a
  t = self~target(self_)
  if a[1] == -12 then return t[2]
  return 0
::method wb_setWindowLong_pvt unguarded
  return 0

/*---- controls ------------------------------------------------------------------*/
/* In-place editing: an edit or combo box made the child of a list-view.
   setParent(control): this control is shown on that one and placed in its client area.
   isGrandChild(method, wantTab): RETURN, ESCAPE, (TAB) and losing the focus go to the
   dialog's method (id, "enter" | "escape" | "tab" | "killfocus", control). */
::method dlgctrl_setParent unguarded
  use arg self_, msg, a
  parent = a[1]
  if \parent~hasMethod("oodPeer") then return .false
  if \parent~oodPeer~isA(.OodCtl) then return .false
  return (self~op(self_, "setParent", parent~oodPeer~id) == 1)
::method e_isGrandchild unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  method = "onEditGrandChildEvent"
  if self_~isA(self~classOf("ComboBox")) then method = "onComboBoxGrandChildEvent"   -- (the edit of a combo box reports as an edit)
  if a~hasIndex(1) then if a[1] \== "" then method = a[1]
  wantTab = .false
  if a~hasIndex(2) then wantTab = (a[2] == .true)
  p~dlg~store["GC" p~id] = .array~of(method, self_)
  return (self~op(self_, "grandChild", wantTab) == 1)
::method cb_getEditControl unguarded   -- the edit part of a combo box as an Edit object; .nil for a drop-down list
  use arg self_
  p = self_~oodPeer
  if \p~dlg~live then return .nil
  if self~op(self_, "isDropList") == 1 then return .nil
  cached = p~dlg~controls[p~id "COMBOEDIT"]
  if cached \== .nil then return cached
  edit = self~classOf("Edit")~new(p~dlg~rexxSelf, p~id, .OodCtl~new(p~dlg, p~id, "EDIT"))
  p~dlg~controls[p~id "COMBOEDIT"] = edit
  return edit
::method cb_setMinVisible unguarded    -- the rows of the dropped list: the browser decides; the number is kept
  use arg self_, msg, a
  self_~oodPeer~dlg~store["CBMINVISIBLE" self_~oodPeer~id] = a[1]
  return .true
::method cb_getMinVisible unguarded
  use arg self_
  count = self_~oodPeer~dlg~store["CBMINVISIBLE" self_~oodPeer~id]
  if count == .nil then return 30
  return count
::method cb_isGrandchild unguarded
  forward message "e_isGrandchild"
::method grandChildEvent unguarded
  use arg key, id, what
  d = self~dialogOf(key)
  if d == .nil then return
  entry = d~store["GC" id]
  if entry == .nil then return
  self~invoke(d~rexxSelf, entry[1], .array~of(id, what, entry[2]))
::method tv_getItemRect unguarded      -- getItemRect(item, rect, textOnly): the item's row in the tree-view's client area
  use arg self_, msg, a
  textOnly = 0
  if a~hasIndex(3) then textOnly = (a[3] == .true)
  parse value self~op(self_, "tv.rect", self~tvItem(a, 1), textOnly) with left top right bottom .
  if left == "" then return .false       -- (the item is not shown)
  a[2]~left = left
  a[2]~top = top
  a[2]~right = right
  a[2]~bottom = bottom
  return .true
::method tv_hitTestInfo unguarded      -- hitTestInfo(point | x, y): a directory with HITEM and LOCATION
  use arg self_, msg, a
  if a[1]~isA(.String) then parse value a[1] a[2] with x y .
  else do
    x = a[1]~x
    y = a[1]~y
  end
  parse value self~op(self_, "tv.hit", x, y) with h location
  info = .directory~new
  info~hItem = self~tvHandle(h)
  info~location = location~strip
  return info
::method lv_getItemRect unguarded      -- getItemRect(index, part): a .Rect in the list-view's client area
  use arg self_, msg, a
  parse value self~op(self_, "lv.rect", a[1], "") with left top right bottom .
  if left == "" then return .nil
  return self~classOf("Rect")~new(left, top, right, bottom)
::method lv_getSubitemRect unguarded   -- getSubitemRect(index, subIndex, part)
  use arg self_, msg, a
  parse value self~op(self_, "lv.rect", a[1], a[2]) with left top right bottom .
  if left == "" then return .nil
  return self~classOf("Rect")~new(left, top, right, bottom)
/* setTabulators(stops...) of a list box, setListTabulators(id, stops...) of a dialog:
   the tab stops in dialog units; one stop is repeated.  0 on success. */
::method generic_setListTabulators unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  first = 1
  if p~isA(.OodCtl) then do
    d = p~dlg
    id = p~id
  end
  else do
    d = p
    if \a~hasIndex(1) then return -1
    id = self~resolveId(self_, a[1])
    if id < 1 then return -1
    first = 2
  end
  if \d~live then return -1
  stops = ""
  do i = first to a~size
    if \a~hasIndex(i) then iterate
    if \a[i]~datatype("N") then iterate
    stops = stops (a[i] * d~factorX)~format(, 0)
  end
  if stops~words == 1 then do      -- one stop: every multiple of it
    one = stops~strip
    stops = ""
    do k = 1 to 12
      stops = stops (one * k)
    end
  end
  self~ctlOp(d, id, "tabStops", stops~strip)
  return 0
::method dlgctrl_assignFocus unguarded
  use arg self_
  self~op(self_, "focus")
  return 0
::method dlgctrl_tabGroup unguarded
  return 0
::method dlgctrl_setColor unguarded
  use arg self_, msg, a
  self~op(self_, "color", self~colorOf(a[1]), self~colorOf(self~opt(a, 2)))
  return 0
::method colorOf unguarded         -- a palette index or COLORREF as a CSS colour
  use arg v
  if v == "" then return ""
  if \v~datatype("W") then return ""
  palette = "#000000 #800000 #008000 #808000 #000080 #800080 #008080 #c0c0c0 #c0dcc0 #a6caf0 #fffbf0 #a0a0a4 #808080 #ff0000 #00ff00 #ffff00 #0000ff #ff00ff #00ffff #ffffff"
  if v >= 0 then if v < 20 then return palette~word(v + 1)
  red = v // 256
  green = (v % 256) // 256
  blue = (v % 65536) // 256
  return "rgb(" || red || "," || green || "," || blue || ")"

::method rb_checkInGroup_cls unguarded  -- .RadioButton~checkInGroup(dlg, idFirst, idLast, idCheck): CheckRadioButton()
  use arg self_, msg, a
  dlg = a[1]
  d = dlg~oodPeer
  first = self~resolveId(dlg, a[2])
  last = self~resolveId(dlg, a[3])
  check = -1
  if a~hasIndex(4) then check = self~resolveId(dlg, a[4])
  if first < 0 | last < first then return 1
  do id = first to last
    self~winMsg(d, id, 241, (id == check))        -- BM_SETCHECK
  end
  return 0
::method rb_check unguarded
  use arg self_
  self~wb_sendWinIntMsg(self_, "", .array~of(241, 1, 0))
  return 0
::method rb_uncheck unguarded
  use arg self_
  self~wb_sendWinIntMsg(self_, "", .array~of(241, 0, 0))
  return 0
::method rb_checked unguarded
  use arg self_
  return self~wb_sendWinIntMsg(self_, "", .array~of(240, 0, 0)) == 1
::method rb_getCheckState unguarded
  use arg self_
  state = self~wb_sendWinIntMsg(self_, "", .array~of(240, 0, 0))
  if state == 1 then return "CHECKED"
  if state == 2 then return "INDETERMINATE"
  return "UNCHECKED"
::method rb_isChecked unguarded
  forward message "rb_getCheckState"
::method rb_indeterminate unguarded
  use arg self_
  self~wb_sendWinIntMsg(self_, "", .array~of(241, 2, 0))
  return 0
::method ckbx_isIndeterminate unguarded
  use arg self_
  return self~wb_sendWinIntMsg(self_, "", .array~of(240, 0, 0)) == 2
::method ckbx_setIndeterminate unguarded
  use arg self_
  self~wb_sendWinIntMsg(self_, "", .array~of(241, 2, 0))
  return 0

::method e_isSingleLine unguarded
  use arg self_
  p = self_~oodPeer
  return self~kindOpts(p~dlg, p~id)~pos("MULTILINE") == 0
::method e_selection unguarded
  use arg self_
  parse value self~op(self_, "sel") with first last
  d = .directory~new
  d~startChar = first
  d~endChar = last
  return d
::method e_replaceSelText unguarded
  use arg self_, msg, a
  self~op(self_, "replaceSel", a[1])
  return 0
::method e_getLine unguarded
  use arg self_, msg, a
  return self~op(self_, "line", a[1])
::method e_setCue unguarded
  use arg self_, msg, a
  self~op(self_, "cue", a[1])
  return 0

::method lb_add unguarded          -- positions are one-based in Rexx
  use arg self_, msg, a
  return self~op(self_, "add", a[1]) + 1
::method lb_insert unguarded
  use arg self_, msg, a
  at = -1
  if a~hasIndex(1) then at = a[1] - 1
  return self~op(self_, "insert", at, a[2]) + 1
::method lb_getText unguarded
  use arg self_, msg, a
  return self~op(self_, "itemText", a[1] - 1)
::method lb_find unguarded
  use arg self_, msg, a
  start = -1
  if a~hasIndex(2) then start = a[2] - 1
  exact = 0
  if a~hasIndex(3) then if a[3]~left(1)~upper == "E" | a[3] == 1 then exact = 1
  return self~op(self_, "find", a[1], start, exact) + 1
::method lb_select unguarded
  use arg self_, msg, a
  return self~op(self_, "selectText", a[1]) + 1
::method lb_selectedIndex unguarded
  use arg self_
  return self~wb_sendWinIntMsg(self_, "", .array~of(392, 0, 0)) + 1
::method lb_selectIndex unguarded
  use arg self_, msg, a
  at = 0
  if a~hasIndex(1) then at = a[1]
  p = self_~oodPeer
  if self~kindOpts(p~dlg, p~id)~pos("MULTI") > 0 then do
    if at == 0 then self~winMsg(p~dlg, p~id, 389, 0, -1)
    else self~winMsg(p~dlg, p~id, 389, 1, at - 1)
    return at
  end
  return self~winMsg(p~dlg, p~id, 390, at - 1) + 1
::method lb_deselectIndex unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  at = 0
  if a~hasIndex(1) then at = a[1]
  self~winMsg(p~dlg, p~id, 389, 0, at - 1)
  return 0
::method lb_isSingleSelection unguarded
  use arg self_
  p = self_~oodPeer
  return self~kindOpts(p~dlg, p~id)~pos("MULTI") == 0

::method cb_add unguarded
  forward message "lb_add"
::method cb_insert unguarded
  forward message "lb_insert"
::method cb_getText unguarded
  forward message "lb_getText"
::method cb_find unguarded
  forward message "lb_find"
::method cb_select unguarded
  forward message "lb_select"
::method cb_isDropDown unguarded   -- isDropDown, isDropDownList, isSimple
  use arg self_, msg
  p = self_~oodPeer
  opts = self~kindOpts(p~dlg, p~id)
  isList = (opts~pos("LIST") > 0)
  isSimple = (opts~pos("SIMPLE") > 0)
  if msg == "ISDROPDOWNLIST" then return isList
  if msg == "ISSIMPLE" then return isSimple
  if isList then return .false
  return \isSimple

::method pbc_setFullRange unguarded
  use arg self_, msg, a
  low = 0
  high = 100
  if a~hasIndex(1) then do
    first = a[1]
    if first~isA(.String) then low = first
    else do
      low = first~min
      high = first~max
    end
  end
  if a~hasIndex(2) then high = a[2]
  self~wb_sendWinIntMsg(self_, "", .array~of(1030, low, high))
  return 0
::method pbc_getFullRange unguarded
  use arg self_
  d = .directory~new
  d~min = self~wb_sendWinIntMsg(self_, "", .array~of(1031, 1, 0))
  d~max = self~wb_sendWinIntMsg(self_, "", .array~of(1031, 0, 0))
  return d
::method pbc_setMarquee unguarded
  return .true

/*---- the system menu: its close item ------------------------------------------------*/
::method sysMenu_init unguarded
  use arg self_, msg, a
  self_~oodPeer = a[1]             -- the dialog whose system menu this is
  return 0
::method menu_disable unguarded
  use arg self_, msg, a
  target = self_~oodPeer
  if target~isA(.OodMenu) then return self~menuFlag(self_, a, "GRAYED", "")
  if a[1] == 61536 then self~op(target, "closeBox", 0)
  return .true
::method menu_enable unguarded
  use arg self_, msg, a
  target = self_~oodPeer
  if target~isA(.OodMenu) then return self~menuFlag(self_, a, "", "GRAYED DISABLED")
  if a[1] == 61536 then self~op(target, "closeBox", 1)
  return .true

/*---- menus ---------------------------------------------------------------------------*/
::method newMenu unguarded         -- the state of a menu object
  use arg self_, isBar, rxID
  m = .OodMenu~new(self_, isBar)
  if rxID \== .nil then do
    id = self~resolveId(.nil, rxID)
    if id \== -1 then m~wID = id
  end
  self_~oodPeer = m
  return m

::method userMenu_init unguarded   -- UserMenuBar~new(id, helpID, count, autoConnect, methodName)
  use arg self_, msg, a
  rxID = .nil
  if a~hasIndex(1) then rxID = a[1]
  m = self~newMenu(self_, .true, rxID)
  if a~hasIndex(4) then m~autoConnect = (a[4] == .true)
  m~autoMethod = self~opt(a, 5)
  return
::method userMenu_complete unguarded
  return .true
::method scriptMenu_init unguarded -- ScriptMenuBar~new(rcFile, id, helpID, count, connect, attachTo)
  use arg self_, msg, a
  rxID = .nil
  if a~hasIndex(2) then rxID = a[2]
  m = self~newMenu(self_, .true, rxID)
  connect = .false
  if a~hasIndex(5) then connect = (a[5] == .true)
  menuName = ""
  if m~wID == -1 then if a~hasIndex(2) then menuName = a[2]
  self_~load(a[1], m~wID, connect, 100, \a~hasIndex(2), menuName)
  if a~hasIndex(6) then self~menuBar_attachTo(self_, "", .array~of(a[6]))
  return
::method popMenu_init unguarded
  use arg self_, msg, a
  rxID = .nil
  if a~hasIndex(1) then rxID = a[1]
  self~newMenu(self_, .false, rxID)
  return
::method binMenu_init unguarded    -- BinaryMenuBar~new(src, id, helpID, attachTo, autoConnect, methodName)
  use arg self_, msg, a
  provider = self~needProvider("a BinaryMenuBar")
  src = ""
  if a~hasIndex(1) then src = a[1]
  if \src~isA(.String) then src = src~library     -- a ResDialog: the menu is in its module
  rxID = .nil
  if a~hasIndex(2) then rxID = a[2]
  m = self~newMenu(self_, .true, rxID)
  owner = .nil
  if a~hasIndex(1) then if \a[1]~isA(.String) then owner = a[1]
  if m~wID == -1 then if rxID \== .nil then m~wID = self~resolveId(owner, rxID)
  records = provider~menuTemplate(self~path(src), m~wID)
  if records == .nil then return
  path = .array~of(m)                  -- the menu being filled at each depth
  do r over records
    popup = .nil
    item = self~menuItem(r~id, r~text, r~flags, .nil)
    path[r~depth + 1]~items~append(item)
    path[r~depth + 2] = .nil
    item~popup = .OodMenu~new(.nil, .false)
    item~popup~owner = path[r~depth + 1]
    path[r~depth + 2] = item~popup
  end
  self~menuPrune(m)
  if a~hasIndex(5) then m~autoConnect = (a[5] == .true)
  m~autoMethod = self~opt(a, 6)
  if a~hasIndex(4) then self~menuBar_attachTo(self_, "", .array~of(a[4]))
  return
::method menuPrune unguarded       -- an item whose popup stayed empty is a command item
  use arg m
  do item over m~items
    if item~popup \== .nil then do
      if item~popup~items~items == 0 then item~popup = .nil
      else self~menuPrune(item~popup)
    end
  end
::method menu_menuInit_pvt unguarded
  return 0

/* The menu template: items arrive in order, END closes a level. */
::method templateAdd unguarded
  use arg m, item, opts
  frame = m~stack~peek
  if frame == .nil then return .false
  frame[1]~items~append(item)
  ends = (opts~wordPos("END") > 0)
  if item~popup \== .nil then m~stack~push(.array~of(item~popup, ends))
  else if ends then do
    do while m~stack~items > 0
      closed = m~stack~pull
      if \closed[2] then leave
    end
  end
  return .true
::method menuItem unguarded
  use arg rxID, text, opts, popup
  item = .directory~new
  id = self~resolveId(.nil, rxID)
  item~id = id
  item~text = text
  item~flags = opts~upper
  item~popup = popup
  return item
::method menuTemplate_addPopup unguarded
  use arg self_, msg, a
  m = self_~oodPeer
  sub = .OodMenu~new(.nil, .false)
  return self~templateAdd(m, self~menuItem(a[1], a[2], self~opt(a, 3), sub), self~opt(a, 3)~upper)
::method menuTemplate_addItem unguarded
  use arg self_, msg, a
  m = self_~oodPeer
  item = self~menuItem(a[1], a[2], self~opt(a, 3), .nil)
  if a~hasIndex(4) then if a[4] \== "" then m~pending~append(.array~of(item~id, a[4]))
  return self~templateAdd(m, item, self~opt(a, 3)~upper)
::method menuTemplate_addSeparator unguarded
  use arg self_, msg, a
  m = self_~oodPeer
  rxID = 0
  if a~hasIndex(1) then rxID = a[1]
  return self~templateAdd(m, self~menuItem(rxID, "", "SEPARATOR" self~opt(a, 2), .nil), self~opt(a, 2)~upper)
::method menuTemplate_isComplete unguarded
  use arg self_
  return self_~oodPeer~stack~items == 0

/* Find an item: (menu, position) or .nil.  By ID the popups are searched too. */
::method menuFind unguarded
  use arg m, rxID, byPosition
  if byPosition then do
    if \rxID~datatype("W") then return .nil
    if rxID < 1 | rxID > m~items~items then return .nil
    return .array~of(m, rxID)
  end
  id = self~resolveId(.nil, rxID)
  do i = 1 to m~items~items
    item = m~items[i]
    if item~id == id then if item~flags~wordPos("SEPARATOR") == 0 | id \== 0 then return .array~of(m, i)
    if item~popup \== .nil then do
      found = self~menuFind(item~popup, rxID, .false)
      if found \== .nil then return found
    end
  end
  return .nil
::method menuItemOf unguarded
  use arg self_, a, idArg, posArg
  byPosition = .false
  if a~hasIndex(posArg) then byPosition = (a[posArg] == .true)
  found = self~menuFind(self_~oodPeer, a[idArg], byPosition)
  if found == .nil then return .nil
  return found[1]~items[found[2]]
::method menuInsert unguarded
  use arg self_, before, item, byPosition
  m = self_~oodPeer
  found = self~menuFind(m, before, byPosition)
  if found == .nil then m~items~append(item)
  else if found[2] == 1 then found[1]~items~insert(item, .nil)
  else found[1]~items~insert(item, found[2] - 1)
  self~menuSync(m)
  return .true
::method menu_insertItem unguarded -- insertItem(before, id, text, stateOpts, typeOpts, byPosition, connect, methodName)
  use arg self_, msg, a
  m = self_~oodPeer
  item = self~menuItem(a[2], a[3], self~opt(a, 4) self~opt(a, 5), .nil)
  byPosition = .false
  if a~hasIndex(6) then byPosition = (a[6] == .true)
  if a~hasIndex(7) then if a[7] == .true then do
    method = self~opt(a, 8)
    if method == "" then method = self~menu_itemTextToMethodName(self_, "", .array~of(a[3]))
    self~menuConnect(m, item~id, method, .nil)
  end
  return self~menuInsert(self_, a[1], item, byPosition)
::method menu_insertPopup unguarded -- insertPopup(before, id, popup, text, stateOpts, typeOpts, byPosition)
  use arg self_, msg, a
  sub = a[3]~oodPeer
  sub~owner = self_~oodPeer
  byPosition = .false
  if a~hasIndex(7) then byPosition = (a[7] == .true)
  return self~menuInsert(self_, a[1], self~menuItem(a[2], a[4], self~opt(a, 5) self~opt(a, 6), sub), byPosition)
::method menu_insertSeparator unguarded
  use arg self_, msg, a
  byPosition = .false
  if a~hasIndex(3) then byPosition = (a[3] == .true)
  return self~menuInsert(self_, a[1], self~menuItem(a[2], "", "SEPARATOR", .nil), byPosition)
::method menuRemove unguarded
  use arg self_, a
  byPosition = .false
  if a~hasIndex(2) then byPosition = (a[2] == .true)
  found = self~menuFind(self_~oodPeer, a[1], byPosition)
  if found == .nil then return .false
  found[1]~items~delete(found[2])
  self~menuSync(self_~oodPeer)
  return .true
::method menu_removeItem unguarded
  use arg self_, msg, a
  return self~menuRemove(self_, a)
::method menu_removeSeparator unguarded
  use arg self_, msg, a
  return self~menuRemove(self_, a)
::method menu_deletePopup unguarded
  use arg self_, msg, a
  return self~menuRemove(self_, a)
::method menu_removePopup unguarded
  use arg self_, msg, a
  item = self~menuItemOf(self_, a, 1, 2)
  if item == .nil then return 0
  popup = item~popup
  self~menuRemove(self_, a)
  if popup == .nil then return 0
  if popup~rexxSelf == .nil then return 0
  return popup~rexxSelf

::method menuFlag unguarded        -- set or clear a flag of one item or of several
  use arg self_, a, add, remove
  m = self_~oodPeer
  byPosition = .false
  if a~hasIndex(2) then byPosition = (a[2] == .true)
  ids = a[1]
  if ids~isA(.String) then ids = ids~makeArray(" ")
  ok = .true
  do rxID over ids
    found = self~menuFind(m, rxID, byPosition)
    if found == .nil then do
      ok = .false
      iterate
    end
    item = found[1]~items[found[2]]
    flags = item~flags
    do word over remove~makeArray(" ")
      p = flags~wordPos(word)
      if p > 0 then flags = flags~delWord(p, 1)
    end
    if add \== "" then if flags~wordPos(add) == 0 then flags = flags add
    item~flags = flags
  end
  self~menuSync(m)
  return ok
::method menu_check unguarded
  use arg self_, msg, a
  return self~menuFlag(self_, a, "CHECKED", "UNCHECKED")
::method menu_unCheck unguarded
  use arg self_, msg, a
  return self~menuFlag(self_, a, "", "CHECKED")
::method menu_hilite unguarded
  return .true
::method menu_unHilite unguarded
  return .true
::method menu_checkRadio unguarded -- checkRadio(start, end, check, byPosition)
  use arg self_, msg, a
  m = self_~oodPeer
  byPosition = .false
  if a~hasIndex(4) then byPosition = (a[4] == .true)
  first = self~menuFind(m, a[1], byPosition)
  last = self~menuFind(m, a[2], byPosition)
  pick = self~menuFind(m, a[3], byPosition)
  if first == .nil | last == .nil | pick == .nil then return .false
  do i = first[2] to last[2]
    item = first[1]~items[i]
    flags = item~flags
    p = flags~wordPos("CHECKED")
    if p > 0 then flags = flags~delWord(p, 1)
    if flags~wordPos("RADIO") == 0 then flags = flags "RADIO"
    if i == pick[2] then flags = flags "CHECKED"
    item~flags = flags
  end
  self~menuSync(m)
  return .true

::method menuHas unguarded
  use arg self_, a, word
  item = self~menuItemOf(self_, a, 1, 2)
  if item == .nil then return .false
  return item~flags~wordPos(word) > 0
::method menu_isChecked unguarded
  use arg self_, msg, a
  return self~menuHas(self_, a, "CHECKED")
::method menu_isSeparator unguarded
  use arg self_, msg, a
  return self~menuHas(self_, a, "SEPARATOR")
::method menu_isDisabled unguarded
  use arg self_, msg, a
  if self~menuHas(self_, a, "DISABLED") then return .true
  return self~menuHas(self_, a, "GRAYED")
::method menu_isEnabled unguarded
  use arg self_, msg, a
  if self~menuItemOf(self_, a, 1, 2) == .nil then return .false
  return \self~menu_isDisabled(self_, msg, a)
::method menu_isPopup unguarded
  use arg self_, msg, a
  item = self~menuItemOf(self_, a, 1, 2)
  if item == .nil then return .false
  return item~popup \== .nil
::method menu_isCommandItem unguarded
  use arg self_, msg, a
  item = self~menuItemOf(self_, a, 1, 2)
  if item == .nil then return .false
  if item~popup \== .nil then return .false
  return item~flags~wordPos("SEPARATOR") == 0
::method menu_isValidItemID unguarded
  use arg self_, msg, a
  return self~menuItemOf(self_, a, 1, 2) \== .nil
::method menu_getItemState unguarded
  use arg self_, msg, a
  item = self~menuItemOf(self_, a, 1, 2)
  if item == .nil then return ""
  state = "ENABLED"
  if item~flags~wordPos("GRAYED") > 0 | item~flags~wordPos("DISABLED") > 0 then state = "DISABLED GRAYED"
  if item~flags~wordPos("CHECKED") > 0 then state = state "CHECKED"
  else state = state "UNCHECKED"
  if item~flags~wordPos("DEFAULT") > 0 then state = state "DEFAULT"
  return state
::method menu_getItemType unguarded
  use arg self_, msg, a
  item = self~menuItemOf(self_, a, 1, 2)
  if item == .nil then return ""
  if item~flags~wordPos("SEPARATOR") > 0 then return "SEPARATOR"
  if item~flags~wordPos("RADIO") > 0 then return "STRING RADIO"
  return "STRING"
::method menu_getText unguarded
  use arg self_, msg, a
  item = self~menuItemOf(self_, a, 1, 2)
  if item == .nil then return ""
  return item~text
::method menu_setText unguarded
  use arg self_, msg, a
  item = self~menuItemOf(self_, a, 1, 3)
  if item == .nil then return .false
  item~text = a[2]
  self~menuSync(self_~oodPeer)
  return .true
::method menu_setID unguarded
  use arg self_, msg, a
  item = self~menuItemOf(self_, a, 1, 3)
  if item == .nil then return .false
  item~id = self~resolveId(.nil, a[2])
  self~menuSync(self_~oodPeer)
  return .true
::method menu_getCount unguarded
  use arg self_
  return self_~oodPeer~items~items
::method menu_getID unguarded
  use arg self_, msg, a
  item = self_~oodPeer~items[a[1]]
  if item == .nil then return -1
  if item~popup \== .nil then return -1
  return item~id
::method menu_getPopup unguarded
  use arg self_, msg, a
  item = self~menuItemOf(self_, a, 1, 2)
  if item == .nil then return 0
  if item~popup == .nil then return 0
  if item~popup~rexxSelf == .nil then do   -- a popup of a template: its PopupMenu object is made when asked for
    popup = self~classOf("PopupMenu")~new
    item~popup~rexxSelf = popup
    item~popup~owner = self_~oodPeer
    popup~oodPeer = item~popup
  end
  return item~popup~rexxSelf
::method menu_wID unguarded
  use arg self_
  return self_~oodPeer~wID
::method menu_getHMenu unguarded
  use arg self_
  return "0x"d2x(self_~oodPeer~identityHash~abs)~right(16, "0")
::method menu_getMenuHandle unguarded
  forward message "menu_getHMenu"
::method menu_isValidMenu unguarded
  return .true
::method menu_isValidMenuHandle unguarded
  return .true
::method menu_releaseMenuHandle unguarded
  return .true
::method menu_destroy unguarded
  use arg self_
  m = self_~oodPeer
  if m~dlg \== .nil then self~menuBar_detach(self_)
  return .true
::method menu_uninit unguarded
  return 0
::method menu_getHelpID unguarded
  return 0
::method menu_setHelpID unguarded
  return .true
::method menu_getMaxHeight unguarded
  return 0
::method menu_setMaxHeight unguarded
  return .true
::method menu_getAutoConnectStatus unguarded
  use arg self_
  d = .directory~new
  d~autoConnect = self_~oodPeer~autoConnect
  d~methodName = self_~oodPeer~autoMethod
  return d
::method menu_setAutoConnection unguarded
  use arg self_, msg, a
  self_~oodPeer~autoConnect = (a[1] == .true)
  self_~oodPeer~autoMethod = self~opt(a, 2)
  return 0
::method menu_itemTextToMethodName unguarded
  use arg self_, msg, a
  parse value a[1] with text (x2c("09")) .
  text = text~changeStr("&", "")~changeStr("...", "")
  name = ""
  do i = 1 to text~length
    ch = text~subChar(i)
    if ch~datatype("A") then name = name || ch
  end
  return name

/* Connections: to the dialog at once if there is one, else when the menu is attached. */
::method menuRoot unguarded
  use arg m
  do while m~owner \== .nil
    m = m~owner
  end
  return m
::method menuConnect unguarded
  use arg m, id, method, dlg
  if id < 1 then return .false
  root = self~menuRoot(m)
  if dlg == .nil then dlg = root~dlg
  if dlg == .nil then root~pending~append(.array~of(id, method))
  else self~addCommand(dlg, id, 0, method)
  return .true
::method menuDlgArg unguarded
  use arg a, i
  if a~hasIndex(i) then return a[i]
  return .nil
::method menu_connectCommandEvent unguarded   -- connectCommandEvent(id, methodName, dlg)
  use arg self_, msg, a
  return self~menuConnect(self_~oodPeer, self~resolveId(.nil, a[1]), a[2], self~menuDlgArg(a, 3))
::method menu_connectCommandEvent_cls unguarded
  use arg self_, msg, a
  return self~addCommand(a[3], self~resolveId(a[3], a[1]), 0, a[2])
::method menuConnectAll unguarded
  use arg m, top, method, dlg
  do item over m~items
    if item~popup \== .nil then self~menuConnectAll(item~popup, top, method, dlg)
    else if item~flags~wordPos("SEPARATOR") == 0 then do
      name = method
      if name == "" then name = self~menu_itemTextToMethodName(.nil, "", .array~of(item~text))
      if name \== "" then self~menuConnect(top, item~id, name, dlg)
    end
  end
  return .true
::method menu_connectAllCommandEvents unguarded   -- connectAllCommandEvents(methodName, dlg)
  use arg self_, msg, a
  m = self_~oodPeer
  return self~menuConnectAll(m, m, self~opt(a, 1), self~menuDlgArg(a, 2))
::method menu_connectSomeCommandEvents unguarded  -- connectSomeCommandEvents(ids, methodName, byPosition, dlg)
  use arg self_, msg, a
  m = self_~oodPeer
  byPosition = .false
  if a~hasIndex(3) then byPosition = (a[3] == .true)
  ids = a[1]
  if ids~isA(.String) then ids = ids~makeArray(" ")
  do rxID over ids
    found = self~menuFind(m, rxID, byPosition)
    if found == .nil then return .false
    item = found[1]~items[found[2]]
    name = self~opt(a, 2)
    if name == "" then name = self~menu_itemTextToMethodName(.nil, "", .array~of(item~text))
    self~menuConnect(m, item~id, name, self~menuDlgArg(a, 4))
  end
  return .true

/* The menu as the page wants it: one record per item, depth first. */
::method menuRecords unguarded
  use arg m, depth, out
  sep = self~sep
  do item over m~items
    out~append(depth || sep || item~id || sep || item~text || sep || item~flags)
    if item~popup \== .nil then self~menuRecords(item~popup, depth + 1, out)
  end
  return out
::method menuSync unguarded        -- show the menu bar's present state in the page
  use arg m
  root = self~menuRoot(m)
  if \root~isBar then return
  if root~dlg == .nil then return
  d = root~dlg~oodPeer
  if \d~live then return
  records = self~menuRecords(root, 0, .array~new)
  self~web~setMenu(d~key, records~makeString("L", x2c("1E")))
  return

::method menuBar_attachTo unguarded
  use arg self_, msg, a
  m = self_~oodPeer
  dlg = a[1]
  m~dlg = dlg
  dlg~oodPeer~menu = m
  dlg~menuBar = self_
  do entry over m~pending
    self~addCommand(dlg, entry[1], 0, entry[2])
  end
  m~pending~empty
  if m~autoConnect then self~menuConnectAll(m, m, m~autoMethod, dlg)
  self~menuSync(m)
  return .true
::method menuBar_detach unguarded
  use arg self_
  m = self_~oodPeer
  if m~dlg == .nil then return .false
  d = m~dlg~oodPeer
  if d~live then self~web~setMenu(d~key, "")
  d~menu = .nil
  m~dlg~menuBar = .nil
  m~dlg = .nil
  return .true
::method menuBar_isAttached unguarded
  use arg self_
  return self_~oodPeer~dlg \== .nil
::method menuBar_redraw unguarded
  use arg self_
  self~menuSync(self_~oodPeer)
  return .true
::method menuBar_replace unguarded
  use arg self_, msg, a
  m = self_~oodPeer
  dlg = m~dlg
  if dlg == .nil then return .nil
  self~menuBar_detach(self_)
  self~menuBar_attachTo(a[1], "", .array~of(dlg))
  return self_

/* Popup (context) menus. */
::method popMenu_assignTo unguarded
  use arg self_, msg, a
  m = self_~oodPeer
  m~dlg = a[1]
  do entry over m~pending
    self~addCommand(a[1], entry[1], 0, entry[2])
  end
  m~pending~empty
  if a~hasIndex(2) then if a[2] == .true then self~menuConnectAll(m, m, self~opt(a, 3), a[1])
  return .true
::method popMenu_isAssigned unguarded
  use arg self_
  return self_~oodPeer~dlg \== .nil
::method popMenu_track unguarded   -- track(location, dlg, ...): the ID chosen, 0 for none
  expose msgResults
  use arg self_, msg, a
  m = self_~oodPeer
  token = self~newToken
  records = self~menuRecords(m, 0, .array~new)
  where = a[1]
  self~web~popupMenu(token, where~x, where~y, records~makeString("L", x2c("1E")))
  do while \msgResults~hasIndex(token)
    event = .js~nextEvent(0.2)
    if event \== .nil then event~dispatch
  end
  return msgResults~remove(token)
::method popMenu_show unguarded    -- show(location, dlg, ...): the choice arrives as the dialog's command event
  use arg self_, msg, a
  m = self_~oodPeer
  dlg = m~dlg
  if a~hasIndex(2) then dlg = a[2]
  id = self~popMenu_track(self_, msg, a)
  if id > 0 then if dlg \== .nil then self~command(dlg~oodPeer~key, id, 0)
  return .true
::method popMenu_connectContextMenu unguarded -- connectContextMenu(methodName, hwnd, dlg)
  use arg self_, msg, a
  dlg = self_~oodPeer~dlg
  if a~hasIndex(3) then dlg = a[3]
  if dlg == .nil then return .false
  return self~connectContext(dlg, a[1])
::method popMenu_connectContextMenu_cls unguarded
  use arg self_, msg, a
  return self~connectContext(a[1], a[2])
::method connectContext unguarded
  use arg dlg, method
  d = dlg~oodPeer
  d~contextMethod = method~upper
  d~cmdTable~append(.array~of(0, "CTX", ""))
  if d~live then self~web~sub(d~key, 0, "CTX")
  return .true

/*---- files: upstream's Rexx and the samples write Windows paths -----------------*/
::method path unguarded            -- "rc\CALC.RC" names rc/calc.rc: separators, and case as Windows ignores it
  use arg name
  file = name~changeStr("\", "/")
  if SysIsFile(file) then return file
  if SysIsFileDirectory(file) then return file
  parts = file~makeArray("/")
  found = ""
  if file~left(1) == "/" then found = "/"
  else found = "./"
  do part over parts
    if part == "" then iterate
    candidate = found || part
    if SysIsFile(candidate) | SysIsFileDirectory(candidate) then do
      found = candidate"/"
      iterate
    end
    match = ""
    call SysFileTree found"*", "entries.", "BO"
    do i = 1 to entries.0
      entryName = filespec("NAME", entries.i)
      if entryName~caselessEquals(part) then do
        match = entryName
        leave
      end
    end
    if match == "" then return file
    found = found || match"/"
  end
  return found~strip("T", "/")
::method stream unguarded
  use arg name
  return .stream~new(self~path(name))
::method isFile unguarded
  use arg name
  return SysIsFile(self~path(name))
::method searchPath unguarded      -- SysSearchPath("PATH", file): here the file itself, if it is there
  use arg , name
  file = self~path(name)
  if SysIsFile(file) then return file
  return ""
::method locate unguarded          -- locate(): the directory of the calling program, with its separator
  use arg program
  if program == "" then return ""
  return filespec("LOCATION", program)

/*---- routines -------------------------------------------------------------------*/
::method newToken
  expose nextToken
  nextToken = nextToken + 1
  return nextToken

::method messageDialog_rtn unguarded
  expose msgResults
  use arg , , a
  token = self~newToken
  title = "ooDialog Application Message"
  if a~hasIndex(3) then title = a[3]
  buttons = "OK"
  if a~hasIndex(4) then buttons = a[4]~space(0)~upper
  icon = ""
  if a~hasIndex(5) then icon = a[5]~strip~upper
  self~web~msgBox(token, a[1], title, buttons, icon)
  do while \msgResults~hasIndex(token)
    event = .js~nextEvent(0.2)
    if event \== .nil then event~dispatch
  end
  return msgResults~remove(token)

::method fileNameDlg_rtn unguarded -- FileNameDialog(preselected, hwnd, filter, loadOrSave, title, defExt, multi, sepChar)
  use arg , , a
  saving = .false
  if a~hasIndex(4) then if a[4] \== "" then do
    first = a[4]~left(1)~upper
    saving = (first == "S" | first == "0")
  end
  multi = .false
  if \saving then if a~hasIndex(7) then if a[7] \== "" then do
    first = a[7]~left(1)~upper
    multi = (first == "M" | first == "1")
  end
  sepChar = " "
  if a~hasIndex(8) then if a[8] \== "" then sepChar = a[8]~left(1)
  dlg = self~classOf("OodFileDialog")~new(self~opt(a, 1), self~opt(a, 3), saving, self~opt(a, 5), self~opt(a, 6), multi, sepChar)
  dlg~execute("SHOWTOP")
  return dlg~chosen

/* msSleep(ms).  ooDialog runs an event method on a thread of its own, so a method that
   draws in a loop and sleeps between the steps leaves the dialog alive: its Interrupt
   button still works.  Here the event methods run on the thread that takes the page's
   events, so the sleep takes them meanwhile: the other events are handled inside it.
   (Only there: see onPumpThread.) */
::method msSleep_rtn unguarded
  use arg , , a
  numeric digits 20
  ms = a[1]
  if \ms~datatype("N") then return 0
  -- An event method that is still looping after the last dialog has gone (the
  -- user closed it meanwhile) has nothing to wait for: on Windows it would run on
  -- its own thread beside the program's end; here the program ends only when it returns.
  if self~handlerOutlivedDialogs then return 0
  -- Only the thread that takes the page's events may take them here.  A thread the
  -- program started itself (an animation) just sleeps: were it to run an event method
  -- inside its own sleep, a method that waits for that thread to stop would wait for ever.
  if \self~onPumpThread then do
    call SysSleep ms / 1000
    return 0
  end
  until = time("F") + ms * 1000
  do forever
    left = (until - time("F")) / 1000000
    if left <= 0 then leave
    event = .js~nextEvent(min(left, 0.05))
    if event \== .nil then event~dispatch
  end
  return 0

::method play_rtn unguarded
  return 0

/*============================================================================*/
/* The page-side runtime (src/oodialog-web.js), embedded by the build.         */
/*============================================================================*/
/*==== v0.24.0: natives scattered over the classes ======================================*/
::method trckbar_getSelRange unguarded     -- a directory: start, end
  use arg self_
  d = .directory~new
  d["START"] = self~wb_sendWinIntMsg(self_, "", .array~of(1041, 0, 0))
  d["END"] = self~wb_sendWinIntMsg(self_, "", .array~of(1042, 0, 0))
  return d
::method tab_getItemRect unguarded     -- getItemRect(index, rect): the tab's rectangle in the control's client area
  use arg self_, msg, a
  parse value self~op(self_, "tab.itemRect", a[1]) with left top right bottom .
  if left == "" then return .false
  r = a[2]
  r~left = left; r~top = top; r~right = right; r~bottom = bottom
  return .true
::method pointArgs unguarded       -- (point | x, y) from an argument array: x, y, and the place of the next argument
  use arg a
  if \a~hasIndex(1) then return .array~of(0, 0, 1)
  if a[1]~isA(.String) then do
    y = 0
    if a~hasIndex(2) then y = a[2]
    return .array~of(a[1], y, 3)
  end
  return .array~of(a[1]~x, a[1]~y, 2)
/* hitTestInfo(point | x, y [, info]): the 1-based index of the item nearest the point, as
   Windows answers; info~inClientArea, info~itemIndex.  0 for an empty list. */
::method lb_hitTestInfo unguarded
  use arg self_, msg, a
  at = self~pointArgs(a)
  parse value self~op(self_, "optAt", at[1], at[2]) with index inside .
  if index == "" then index = -1
  if inside == "" then inside = 0
  if a~hasIndex(at[3]) then do
    info = a[at[3]]
    info~inClientArea = (inside == 1)
    info~itemIndex = index + 1
  end
  return index + 1
::method lv_getItemPos unguarded       -- getItemPos(index): the .Point of the item's upper left corner; 0 if no such item
  use arg self_, msg, a
  parse value self~op(self_, "lv.rect", a[1], "") with left top .
  if left == "" then return 0
  return self~classOf("Point")~new(left, top)
/* setItemPos, findNearestXY: Windows does these in the icon views only, where the user places
   the items.  The page lays every view out in rows, so they answer as Windows does for a
   report view: not moved, no item. */
::method lv_setItemPos unguarded
  return .false
::method lv_findNearestXY unguarded
  return -1
::method lv_modifyColumnPx unguarded   -- modifyColumnPx(index, label, width, align): 0, 1 if no such column
  use arg self_, msg, a
  sep = self~sep
  label = ""
  given = 0
  if a~hasIndex(2) then do
    label = a[2]
    given = 1
  end
  width = ""
  if a~hasIndex(3) then width = a[3]
  fmt = self~opt(a, 4)~strip~upper
  align = ""
  if fmt~pos("LEFT") > 0 then align = "left"
  if fmt~pos("CENTER") > 0 then align = "center"
  if fmt~pos("RIGHT") > 0 then align = "right"
  if self~op(self_, "lv.setCol", a[1], label || sep || width || sep || align || sep || given) == 1 then return 0
  return 1
::method keyNames unguarded        -- the names of the 256 virtual keys, from upstream's oodKeyNames.hpp
  expose keyNames
  if var("KEYNAMES") then return keyNames
  keyNames = ",LBUTTON,RBUTTON,CANCEL,MBUTTON,XBUTTON1,XBUTTON2,,BACK,TAB,,,CLEAR,RETURN,,,SHIFT,CONTROL,MENU,PAUSE,CAPITAL,KANA,,JUNJA,FINAL,HANJA,,ESCAPE,CONVERT,NONCONVERT,ACCEPT,MODECHANGE,SPACE,PRIOR,NEXT,END,HOME,LEFT,UP,RIGHT,DOWN,SELECT,PRINT,EXECUTE,SNAPSHOT,INSERT,DELETE,HELP,0,1,2,3,4,5,6,7,8,9,,,,,,,,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,LWIN,RWIN,APPS,,SLEEP,NUMPAD0,NUMPAD1,NUMPAD2,NUMPAD3,NUMPAD4,NUMPAD5,NUMPAD6,NUMPAD7,NUMPAD8,NUMPAD9,MULTIPLY,ADD,SEPARATOR,SUBTRACT,DECIMAL,DIVIDE,F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,F21,F22,F23,F24,,,,,,,,,NUMLOCK,SCROLL,OEM_NEC_EQUAL,OEM_FJ_MASSHOU,OEM_FJ_TOUROKU,OEM_FJ_LOYA,OEM_FJ_ROYA,,,,,,,,,,LSHIFT,RSHIFT,LCONTROL,RCONTROL,LMENU,RMENU,BROWSER_BACK,BROWSER_FORWARD,BROWSER_REFRESH,BROWSER_STOP,BROWSER_SEARCH,BROWSER_FAVORITES,BROWSER_HOME,VOLUME_MUTE,VOLUME_DOWN,VOLUME_UP,MEDIA_NEXT_TRACK,MEDIA_PREV_TRACK,MEDIA_STOP,MEDIA_PLAY_PAUSE,LAUNCH_MAIL,LAUNCH_MEDIA_SELECT,LAUNCH_APP1,LAUNCH_APP2,,,OEM_1,OEM_PLUS,OEM_COMMA,OEM_MINUS,OEM_PERIOD,OEM_2,OEM_3,,,,,,,,,,,,,,,,,,,,,,,,,,,OEM_4,OEM_5,OEM_6,OEM_7,OEM_8,,OEM_AX,OEM_102,ICO_HELP,ICO_00,PROCESSKEY,ICO_CLEAR,PACKET,,OEM_RESET,OEM_JUMP,OEM_PA1,OEM_PA2,OEM_PA3,OEM_WSCTRL,OEM_CUSEL,OEM_ATTN,OEM_FINISH,OEM_COPY,OEM_AUTO,OEM_ENLW,OEM_BACKTAB,ATTN,CRSEL,EXSEL,EREOF,PLAY,ZOOM,NONAME,PA1,OEM_CLEAR,"~makeArray(",")
  return keyNames
::method vk_key2name unguarded     -- key2name(code): "RETURN" for 13; "" for a code with no name
  use arg self_, msg, a
  code = self~number(a[1])
  names = self~keyNames
  if code < 0 | code > 255 then raise syntax 93.907 array(1, 0, 255, a[1])
  if code + 1 > names~items then return ""
  return names[code + 1]
::method kb_getAsyncKeyState_cls unguarded     -- .Keyboard~getAsyncKeyState(key): is the key down in the page now
  use arg self_, msg, a
  return self~web~keyDown(self~number(a[1])) == 1
/* childWindowFromPoint(point, flags): the handle of the child at a point of this window's
   client area; the dialog's own handle where there is no child; 0 outside the dialog. */
::method wb_childWindowFromPoint unguarded
  use arg self_, msg, a
  t = self~target(self_)
  if \t[1]~live then return 0
  answer = self~web~op(t[1]~key, 0, "childAt", a[1]~x, a[1]~y)
  if answer == "" then return 0
  return "0x"d2x(t[1]~key * 65536 + answer)~right(16, "0")
::method wb_sendWinHandle2Msg unguarded        -- as sendWinIntMsg, the answer a handle
  forward message "wb_sendWinHandleMsg"
::method gb_setStyle unguarded     -- GroupBox~style=: the title LEFT, CENTER or RIGHT; 0
  use arg self_, msg, a
  opts = self~opt(a, 1)~upper
  align = "LEFT"
  if opts~wordPos("RIGHT") > 0 then align = "RIGHT"
  if opts~wordPos("CENTER") > 0 then align = "CENTER"
  p = self_~oodPeer
  self~ctlOpWhenLive(p~dlg, p~id, "gbAlign", align)
  return 0
/* The state image of a tree-view item: its place in the state image list.  The number is
   kept and answered; the page does not draw state images. */
::method tv_setStateImage unguarded
  use arg self_, msg, a
  p = self_~oodPeer
  h = self~tvItem(a, 1)
  if self~op(self_, "tv.info", h) == "" then return .false
  p~dlg~store[p~id "tvstate" h] = a[2]
  return .true
::method tv_getStateImage unguarded    -- -1 if there is no such item
  use arg self_, msg, a
  p = self_~oodPeer
  h = self~tvItem(a, 1)
  if self~op(self_, "tv.info", h) == "" then return -1
  kept = p~dlg~store[p~id "tvstate" h]
  if kept == .nil then return 0
  return kept
/* A button's or static control's own image: the one set is the one answered. */
::method bc_setImage unguarded     -- setImage(image): the image before, .nil if none
  use arg self_, msg, a
  p = self_~oodPeer
  old = p~dlg~store[p~id "image"]
  p~dlg~store[p~id "image"] = a[1]
  self~setImageOf(self_, a[1])
  return old
::method bc_getImage unguarded
  use arg self_
  p = self_~oodPeer
  return p~dlg~store[p~id "image"]
::method stc_getImage unguarded
  use arg self_
  p = self_~oodPeer
  return p~dlg~store[p~id "image"]
::method stc_getIcon unguarded
  use arg self_
  p = self_~oodPeer
  return p~dlg~store[p~id "image"]
::method il_getIcon unguarded      -- getIcon(index): the image at that 0-based place; .nil if none
  use arg self_, msg, a
  images = self_~oodPeer~images
  if a[1] < 0 | a[1] >= images~items then return .nil
  return images[a[1] + 1]
::method sysMenu_revert unguarded  -- the system menu back to its first state: there is one state here
  return .true
::method dlgext_setForgroundWindow unguarded   -- setForegroundWindow(handle): the handle of the dialog in front before, 0 if none
  use arg self_, msg, a
  before = self~web~topDialog
  w = self~windowOfHandle(a[1])
  if w \== .nil then self~ctlOp(w[1], 0, "top")
  if before == "" then return 0
  return "0x"d2x(before * 65536)~right(16, "0")
::method dlgext_setWindowRect unguarded        -- setWindowRect(handle, x, y, width, height [, opts]) in pixels: 0, 1 on error
  use arg self_, msg, a
  w = self~windowOfHandle(a[1])
  if w == .nil then return 1
  opts = self~opt(a, 6)~upper
  do i = 2 to 5
    if \a~hasIndex(i) then return 1
  end
  if opts~pos("NOMOVE") == 0 then self~ctlOp(w[1], w[2], "move", a[2], a[3])
  if opts~pos("NOSIZE") == 0 then self~ctlOp(w[1], w[2], "size", a[4], a[5])
  return 0
/* getComboBoxInfo: the parts of a combo box.  The page's combo box is one element, so the
   parts that are windows on Windows (the edit, the list) are answered as the combo box. */
::method cb_getComboBoxInfo unguarded
  use arg self_
  p = self_~oodPeer
  d = .directory~new
  parse value self~op(self_, "rect") with left top right bottom .
  if left == "" then return .nil
  width = right - left
  height = bottom - top
  d~textObj = self_
  d~listBoxObj = self_
  d~buttonRect = self~classOf("Rect")~new(width - 18, 0, width, height)
  d~textRect = self~classOf("Rect")~new(0, 0, width - 18, height)
  d~buttonState = "notpressed"
  return d
::method pd_setInterruptible unguarded -- ProgressDialog: the dialog always takes the user's Cancel here
  return 0

::resource oodjs
@@OODJS@@
::END

/* Orders for the sorts of a list-view's rows.  A pair is (key, uid). */
::class OodPairOrder
::method init
  expose ascending
  use arg ascending
::method compare
  expose ascending
  use arg left, right
  order = left[1]~compareTo(right[1])
  if left[1]~datatype("N") & right[1]~datatype("N") then order = sign(left[1] - right[1])
  if ascending then return order
  return -order
::class OodCallOrder
::method init
  expose dlg method param
  use arg dlg, method, param
::method compare
  expose dlg method param
  use arg left, right
  if param == .nil then answer = dlg~send(method, left[1], right[1])
  else answer = dlg~send(method, left[1], right[1], param)
  if \answer~datatype("W") then return 0
  return answer
