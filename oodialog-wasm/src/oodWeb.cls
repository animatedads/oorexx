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
  return "0.3.0"
::method module_lastChanged class
  return "2026-11-14"
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
::attribute contextMethod unguarded   -- the method of the context menu event
::attribute parentDlg unguarded
::attribute ownerDialog unguarded
::method init
  expose key rexxSelf library resourceID dlgID autoDetect fontName fontSize sizeX sizeY factorX factorY -
         pixelCX pixelCY initCode live templateActive spec template dataTable cmdTable controls kinds -
         parentDlg ownerDialog notifyTable store menu contextMethod
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
  return "0.3.0"
::method module_lastChanged class
  return "2026-11-14"
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
  return "0.3.0"
::method module_lastChanged class
  return "2026-11-14"
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
  return "0.3.0"
::method module_lastChanged class
  return "2026-11-14"
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
    otherwise nop
  end

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

/* Send an event method.  An error in it is reported and the dialog goes on. */
::method invoke unguarded
  use arg dlg, method, args
  signal on syntax                 -- (a class may answer events in UNKNOWN, as the DLL allowed)
  dlg~sendWith(method, args)
  return
syntax:
  co = condition("O")
  say "ooDialog: error in event method" method": rc" rc "line" sigl condition("C") condition("D")
  if co \== .nil then do
    say "  " co~message
    if co~traceback \== .nil then do line over co~traceback
      say line
    end
  end
  return

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
::method app_srcDir_atr unguarded
  parse source . . program
  return filespec("LOCATION", program)

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

/*---- PlainBaseDialog ---------------------------------------------------------*/
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
    self~web~destroy(d~key)
    d~live = .false
    self~deregister(d)
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
          if n~datatype("W") then self~winMsg(d, id, 389, 1, n - 1)
        end
      end
      else if data \== "" then self~ctlOp(d, id, "selectText", data)
    end
    when kind == "COMBO" then do
      if data \== "" then self~ctlOp(d, id, "selectText", data)
    end
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
  answer = self~web~create(spec, d~template)
  parse var answer fx fy pw ph
  d~factorX = fx
  d~factorY = fy
  d~pixelCX = pw
  d~pixelCY = ph
  d~live = .true
  d~templateActive = .false
  self~register(d)
  do entry over d~cmdTable
    self~web~sub(d~key, entry[1], entry[2])
  end
  if d~menu \== .nil then self~menuSync(d~menu)
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

::method dyndlg_createNamedControl unguarded  -- list-view, tree-view, tab ...: shown as a placeholder for now
  use arg self_, msg, a
  id = self~addItem(self_, msg~substr(7), a[1], a[2], a[3], a[4], a[5], self~opt(a, 6), "")
  if id < 1 then return id
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

::method resdlg_startDialog_pvt unguarded
  use arg self_, msg, a
  d = self_~oodPeer
  provider = self~needProvider("a ResDialog")
  id = self~resolveId(self_, a[2])
  t = provider~dialogTemplate(self~path(a[1]), id)
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
  return self~dyndlg_startParentDialog(self_, msg, .array~of(a[3], a[4]))
::method resdlg_getDataTableIDs_pvt unguarded
  use arg self_
  ids = .array~new
  do entry over self_~oodPeer~dataTable
    ids~append(entry[1])
  end
  return ids

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
  if p == 0 then
    raise syntax 98.900 array("ooDialog/WASM: the event" keyword "is not available yet")
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
  return self~connectNotify(self_, a, "SELCHANGED SELCHANGED EXPANDED EXPANDED EXPANDING EXPANDING")
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
    select
      when kind == "LISTVIEW" then do
        ctl = dlg~newListView(id)
        select
          when event == "CLICK" | event == "DBLCLK" then args = .array~of(id, parts[1], parts[2], parts[3], (event == "CLICK"), ctl)
          when event == "COLUMNCLICK" | event == "ACTIVATE" | event == "KEYDOWN" then args = .array~of(id, extra, ctl)
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
        else args = .array~of(id, self~tvHandle(parts[1]), parts[2], "", ctl, event)
      end
      when kind == "TAB" then args = .array~of(id, hwnd, dlg~newTab(id))
      when kind == "UPDOWN" then args = .array~of(parts[1], parts[2], id, hwnd, dlg~newUpDown(id))
      when kind == "DATETIMEPICKER" then args = .array~of(self~dateTimeOf(extra), .true, id, hwnd, event, dlg~newDateTimePicker(id))
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
::method dtp_getDateTime unguarded
  use arg self_
  return self~dateTimeOf(self~op(self_, "dtp.get"))
::method dtp_setDateTime unguarded
  use arg self_, msg, a
  self~op(self_, "dtp.set", a[1]~isoDate~left(19))
  return 0
::method dtp_setFormat unguarded
  return .true

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
  do i = 4 to a~last
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
  if a~hasIndex(8) then do
    p = self_~oodPeer
    self~setItemDataOf(p~dlg, p~id, h, a[8])
  end
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
  d = .directory~new
  d~text = text
  d~children = children
  d~image = -1
  d~selectedImage = -1
  d~state = state
  return d
::method tv_modify unguarded       -- modify(item, label, image, selectedImage, opts, children, userData)
  use arg self_, msg, a
  if a~hasIndex(1) then h = self~tvItem(a, 1)
  else h = self~op(self_, "tv.special", "SELECTED")
  flag = ""
  if a~hasIndex(2) then flag = flag"T"
  if a~hasIndex(5) then flag = flag"O"
  change = flag || self~sep || self~opt(a, 2) || self~sep || self~opt(a, 5)~upper
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
  do i = 1 to a~last by 3
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
::method tab_calcRect unguarded    -- calcDisplayRect(rect): the area for the pages, in the dialog's client pixels
  use arg self_, msg, a
  parse value self~op(self_, "tab.rect") with left top right bottom
  if left == "" then return .false
  r = a[1]
  r~left = left; r~top = top; r~right = right; r~bottom = bottom
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

::method wb_windowRect unguarded
  use arg self_, msg, a
  parse value self~op(self_, "rect") with left top right bottom
  if left == "" then return .Rect~new
  if a~hasIndex(1) then do
    r = a[1]
    r~left = left; r~top = top; r~right = right; r~bottom = bottom
    return 0
  end
  return .Rect~new(left, top, right, bottom)
::method wb_clientRect unguarded
  use arg self_, msg, a
  parse value self~op(self_, "clientRect") with left top right bottom
  if left == "" then return .Rect~new
  if a~hasIndex(1) then do
    r = a[1]
    r~left = left; r~top = top; r~right = right; r~bottom = bottom
    return 0
  end
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
  return "0x"d2x(self_~oodPeer~identityHash)~right(16, "0")
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

::method fileNameDlg_rtn unguarded -- not ported yet: says so, and answers as a cancelled dialog does
  self~messageDialog_rtn(.nil, "", .array~of("The file selection dialog is not available in ooDialog for ooRexx/WASM yet.", 0, "ooDialog", "OK", "WARNING"))
  return 0

::method msSleep_rtn unguarded
  use arg , , a
  call SysSleep a[1] / 1000
  return 0

::method play_rtn unguarded
  return 0

/*============================================================================*/
/* The page-side runtime (src/oodialog-web.js), embedded by the build.         */
/*============================================================================*/
::resource oodjs
@@OODJS@@
::END
