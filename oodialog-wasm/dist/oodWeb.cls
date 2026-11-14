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
  return "0.2.0"
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
::attribute parentDlg unguarded
::attribute ownerDialog unguarded
::method init
  expose key rexxSelf library resourceID dlgID autoDetect fontName fontSize sizeX sizeY factorX factorY -
         pixelCX pixelCY initCode live templateActive spec template dataTable cmdTable controls kinds -
         parentDlg ownerDialog notifyTable store
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
  parentDlg = .nil
  ownerDialog = .nil
::method hwnd unguarded
  expose key
  return "0x"d2x(key * 65536)~right(16, "0")

/* State of a control object. */
::class OodCtl
::method module_version class
  return "0.2.0"
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
  return "0.2.0"
::method module_lastChanged class
  return "2026-11-14"
::method module_version unguarded
  return self~class~module_version
::method module_lastChanged unguarded
  return self~class~module_lastChanged

::method init
  expose dialogs nextKey pkg msgResults nextToken appAutoDetect defFontName defFontSize
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
    otherwise nop
  end

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

/*---- menus: only the system menu's close item so far ------------------------------*/
::method sysMenu_init unguarded
  use arg self_, msg, a
  self_~oodPeer = a[1]             -- the dialog whose system menu this is
  return 0
::method systemMenuItem unguarded  -- enable or disable an item of a dialog's system menu
  use arg self_, msg, a, enable
  dlg = self_~oodPeer
  if \dlg~isA(self~classOf("PlainBaseDialog")) then
    raise syntax 98.900 array("ooDialog/WASM: native function" msg "is implemented for the system menu only so far")
  if a[1] == 61536 then self~op(dlg, "closeBox", enable)
  return .true
::method menu_disable unguarded
  use arg self_, msg, a
  return self~systemMenuItem(self_, "MENU_DISABLE", a, 0)
::method menu_enable unguarded
  use arg self_, msg, a
  return self~systemMenuItem(self_, "MENU_ENABLE", a, 1)

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
/* oodialog-web.js -- the page side of ooDialog for ooRexx/WASM.
 * Architecture: Tom Dyer.  Code: Claude (Fable 5.2).
 *
 * Runs in the page's realm (window.__ood).  It stands where user32/comctl32
 * stand for the Windows DLL: it owns the dialogs and controls (DOM elements),
 * answers a subset of the Win32 control messages (msg), and posts WM_COMMAND
 * style events to Rexx through one queued handler.
 */
(function (W) {
  'use strict';
  if (W.__ood) return;
  const D = W.document;
  const ood = W.__ood = { version: '0.1.0', dialogs: new Map(), handler: null, z: 5000, scale: 1.25, log: [] };

  const CSS = `
.ood-back{position:fixed;inset:0;background:rgba(0,0,0,.18)}
.ood-dlg{position:fixed;background:#f0f0f0;color:#000;border:1px solid #6b6b6b;box-shadow:0 6px 24px rgba(0,0,0,.35);
  font-family:"Segoe UI",Tahoma,"DejaVu Sans",Arial,sans-serif;line-height:normal;user-select:none;-webkit-user-select:none}
.ood-dlg *{box-sizing:border-box;font:inherit}
.ood-title{display:flex;align-items:center;height:1.9em;background:#fff;border-bottom:1px solid #d0d0d0;cursor:move;padding-left:.5em;touch-action:none}
.ood-dlg.ood-inactive .ood-title{color:#777}
.ood-title span{flex:1;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}
.ood-x{width:2.6em;height:100%;border:0;background:transparent;cursor:pointer;font-size:1em}
.ood-x:hover{background:#e81123;color:#fff}
.ood-client{position:relative;overflow:hidden}
.ood-c{position:absolute;margin:0}
.ood-c[hidden]{display:none}
button.ood-c{padding:0;border:1px solid #adadad;background:#e1e1e1;border-radius:0;cursor:default;white-space:nowrap;overflow:hidden;color:#000}
button.ood-c:hover{border-color:#0078d7;background:#e5f1fb}
button.ood-c.ood-def{border:2px solid #0078d7}
button.ood-c:disabled{color:#838383;border-color:#bfbfbf;background:#ccc}
.ood-static{overflow:hidden;white-space:pre-wrap}
.ood-static.ood-oneline{white-space:pre}
.ood-edit{border:1px solid #7a7a7a;background:#fff;color:#000;padding:0 2px;user-select:text;-webkit-user-select:text;border-radius:0;outline:none;resize:none}
.ood-edit:focus{border-color:#0078d7}
.ood-edit:disabled,.ood-edit[readonly]{background:#f0f0f0}
.ood-check{display:flex;align-items:center;gap:.3em;white-space:nowrap;overflow:hidden}
.ood-check input{margin:0}
fieldset.ood-c{border:1px solid #d5d5d5;padding:0;pointer-events:none;min-width:0}
fieldset.ood-c legend{padding:0 .2em;margin-left:.5em;line-height:1}
select.ood-c{border:1px solid #7a7a7a;background:#fff;color:#000;border-radius:0;padding:0}
.ood-progress{border:1px solid #bcbcbc;background:#e6e6e6;overflow:hidden}
.ood-progress div{height:100%;width:0;background:#06b025}
.ood-frame{pointer-events:none}
.ood-todo{border:1px dashed #a33;color:#a33;font-size:.85em;overflow:hidden;padding:2px}
.ood-u{text-decoration:underline}
.ood-lv,.ood-tv{border:1px solid #7a7a7a;background:#fff;overflow:auto;outline:none;cursor:default}
.ood-lv table{border-collapse:collapse;table-layout:fixed}
.ood-lv th{position:sticky;top:0;background:#fff;border-right:1px solid #e5e5e5;border-bottom:1px solid #e5e5e5;font-weight:normal;padding:2px 6px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ood-lv th:hover{background:#d9ebf9}
.ood-lv td{padding:1px 6px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ood-lv table.ood-grid td{border:1px solid #f0f0f0}
.ood-lv tr.ood-sel td,.ood-tv .ood-tvrow.ood-sel{background:#cce8ff}
.ood-lv:focus tr.ood-sel td,.ood-tv:focus .ood-tvrow.ood-sel{background:#0078d7;color:#fff}
.ood-lvchk{margin:0 .4em 0 0;vertical-align:middle}
.ood-tvrow{white-space:nowrap;padding:1px 4px}
.ood-tvtw{display:inline-block;width:1.1em;text-align:center;color:#555}
.ood-ud{display:flex;flex-direction:column}
.ood-ud button{flex:1;min-height:0;padding:0;border:1px solid #adadad;background:#e1e1e1;font-size:.6em;line-height:1;color:#000;cursor:default}
.ood-ud button:hover{background:#e5f1fb;border-color:#0078d7}
.ood-tab{pointer-events:none}
.ood-tabstrip{display:flex;pointer-events:auto;height:1.75em;align-items:flex-end;padding-left:2px}
.ood-tabbtn{border:1px solid #d9d9d9;border-bottom:0;background:#f0f0f0;padding:0 .7em;height:1.5em;margin-right:-1px;cursor:default;color:#000}
.ood-tabbtn.ood-cur{background:#fff;height:1.75em;position:relative;top:1px}
.ood-tabpage{position:absolute;left:0;right:0;top:1.75em;bottom:0;border:1px solid #d9d9d9;background:#fff}
`;

  function boot() {
    if (ood.booted) return;
    const st = D.createElement('style');
    st.textContent = CSS;
    D.head.appendChild(st);
    ood.booted = true;
  }

  function fire(key, kind, id, code, extra) {
    if (ood.handler) ood.handler(String(key), kind, String(id), String(code), extra == null ? '' : String(extra));
  }
  const has = (opts, word) => opts.indexOf(word) >= 0;       // as StrStrI in the DLL
  function label(el, text) {                                  // & marks the accelerator
    el.textContent = '';
    const p = text.search(/&[^&]/);
    if (p < 0) { el.textContent = text.replace(/&&/g, '&'); return; }
    el.append(text.slice(0, p).replace(/&&/g, '&'));
    const u = D.createElement('span'); u.className = 'ood-u'; u.textContent = text[p + 1];
    el.append(u, text.slice(p + 2).replace(/&&/g, '&'));
  }
  const plain = (text) => text.replace(/&(.)/g, '$1');

  /* ---- dialogs ---------------------------------------------------------- */
  ood.create = function (spec, ctrls) {
    boot();
    const key = Number(spec.key);
    const opts = String(spec.opts || '').toUpperCase();
    const dlg = { key, opts, ctrls: new Map(), all: [], subs: new Set(), group: 0, defId: 1, modal: !spec.modeless, prevFocus: D.activeElement };
    const px = Math.round(Number(spec.fontSize || 8) * 96 / 72 * ood.scale * 100) / 100;
    const el = dlg.el = D.createElement('div');
    el.className = 'ood-dlg'; el.tabIndex = -1; el.style.outline = 'none';
    el.style.fontSize = px + 'px';
    if (spec.fontName && !/^MS Shell Dlg|^MS Sans Serif|^System$/i.test(spec.fontName))
      el.style.fontFamily = '"' + spec.fontName + '",' + '"Segoe UI",Tahoma,sans-serif';
    el.style.visibility = 'hidden';
    const title = dlg.titleEl = D.createElement('div'); title.className = 'ood-title';
    const cap = dlg.capEl = D.createElement('span'); cap.textContent = spec.title || '';
    title.appendChild(cap);
    if (!has(opts, 'NOMENU')) {
      const x = D.createElement('button'); x.className = 'ood-x'; x.textContent = '✕'; x.tabIndex = -1;
      x.addEventListener('click', () => fire(key, 'CMD', 2, 0));
      title.appendChild(x);
    }
    const client = dlg.client = D.createElement('div'); client.className = 'ood-client';
    el.append(title, client);
    if (dlg.modal) { dlg.back = D.createElement('div'); dlg.back.className = 'ood-back'; dlg.back.style.zIndex = ++ood.z; D.body.appendChild(dlg.back); dlg.back.hidden = true; }
    el.style.zIndex = ++ood.z;
    D.body.appendChild(el);

    // dialog base units, as Windows computes them from the dialog font
    const s = D.createElement('span');
    s.style.cssText = 'position:absolute;visibility:hidden;white-space:nowrap';
    s.textContent = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    client.appendChild(s);
    const r = s.getBoundingClientRect();
    client.removeChild(s);
    dlg.fx = Math.floor((r.width / 26 + 1) / 2) / 4;
    dlg.fy = Math.round(r.height) / 8;
    dlg.cx = Number(spec.cx); dlg.cy = Number(spec.cy);
    client.style.width = Math.round(dlg.cx * dlg.fx) + 'px';
    client.style.height = Math.round(dlg.cy * dlg.fy) + 'px';
    const rect = el.getBoundingClientRect();
    let left = Math.round(Number(spec.x) * dlg.fx), top = Math.round(Number(spec.y) * dlg.fy);
    if (has(opts, 'CENTER')) { left = Math.max(0, (W.innerWidth - rect.width) / 2); top = Math.max(0, (W.innerHeight - rect.height) / 2); }
    el.style.left = Math.round(left) + 'px'; el.style.top = Math.round(top) + 'px';
    ood.dialogs.set(key, dlg);
    for (const c of ctrls || []) addControl(dlg, c);
    wireDialog(dlg);
    return dlg.fx + ' ' + dlg.fy + ' ' + Math.round(rect.width) + ' ' + Math.round(rect.height);
  };

  function wireDialog(dlg) {
    const el = dlg.el;
    let drag = null;
    dlg.titleEl.addEventListener('pointerdown', (e) => {
      if (e.target.closest('.ood-x')) return;
      drag = { x: e.clientX - el.offsetLeft, y: e.clientY - el.offsetTop };
      dlg.titleEl.setPointerCapture(e.pointerId);
    });
    dlg.titleEl.addEventListener('pointermove', (e) => {
      if (!drag) return;
      el.style.left = (e.clientX - drag.x) + 'px'; el.style.top = Math.max(0, e.clientY - drag.y) + 'px';
    });
    dlg.titleEl.addEventListener('pointerup', () => { drag = null; });
    el.addEventListener('pointerdown', () => { if (el.style.zIndex != ood.z && !dlg.modal) el.style.zIndex = ++ood.z; }, true);
    el.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') { e.preventDefault(); if (!dlg.noClose) fire(dlg.key, 'CMD', 2, 0); return; }
      if (e.key === 'F1') { e.preventDefault(); fire(dlg.key, 'CMD', 9, 0); return; }
      if (e.key === 'Enter') {
        const t = e.target;
        if (t.tagName === 'TEXTAREA' && !t.dataset.noreturn) return;
        if (t.tagName === 'BUTTON') return;                 // the button's own click
        e.preventDefault();
        const def = dlg.ctrls.get(dlg.defId);
        if (def && def.kind === 'BUTTON') { if (!def.main.disabled) def.main.click(); }
        else fire(dlg.key, 'CMD', 1, 0);
      }
    });
  }

  ood.show = function (key, how) {
    const dlg = ood.dialogs.get(Number(key)); if (!dlg) return '0';
    how = String(how || '').toUpperCase();
    const hide = has(how, 'HIDE');
    dlg.el.style.visibility = hide ? 'hidden' : 'visible';
    if (dlg.back) dlg.back.hidden = hide;
    if (!hide && !dlg.shown) {
      dlg.shown = true;
      const first = dlg.all.find((c) => c.main && c.main.tabIndex >= 0 && !c.main.disabled && c.focusable);
      if (first) first.main.focus(); else dlg.el.focus();
    }
    return '1';
  };

  ood.destroy = function (key) {
    const dlg = ood.dialogs.get(Number(key)); if (!dlg) return '0';
    dlg.el.remove(); if (dlg.back) dlg.back.remove();
    ood.dialogs.delete(Number(key));
    if (dlg.prevFocus && dlg.prevFocus.isConnected) dlg.prevFocus.focus();   // as Windows activates the owner again
    return '1';
  };

  ood.sub = function (key, id, code) {
    const dlg = ood.dialogs.get(Number(key)); if (dlg) dlg.subs.add(id + '.' + code);
    return '1';
  };
  function cmd(dlg, c, code, always) {
    if (always || dlg.subs.has(c.id + '.' + code) || dlg.subs.has(c.id + '.*') || dlg.subs.has('*.' + code))
      fire(dlg.key, 'CMD', c.id, code);
  }

  /* ---- controls --------------------------------------------------------- */
  function place(dlg, el, c) {
    el.classList.add('ood-c');
    el.style.left = Math.round(c.x * dlg.fx) + 'px'; el.style.top = Math.round(c.y * dlg.fy) + 'px';
    el.style.width = Math.round(c.cx * dlg.fx) + 'px'; el.style.height = Math.round(c.cy * dlg.fy) + 'px';
  }

  function addControl(dlg, spec) {
    const o = String(spec.opts || '').toUpperCase();
    const c = { id: Number(spec.id), kind: spec.kind, opts: o, x: +spec.x, y: +spec.y, cx: +spec.cx, cy: +spec.cy, focusable: true };
    const text = spec.text == null ? '' : String(spec.text);
    if (has(o, 'GROUP')) dlg.group++;
    let el, main;
    switch (spec.kind) {
      case 'BUTTON':
        el = main = D.createElement('button'); main.type = 'button'; label(main, text);
        if (has(o, 'DEFAULT')) { main.classList.add('ood-def'); dlg.defId = c.id; }
        main.addEventListener('click', () => cmd(dlg, c, 0, true));
        main.addEventListener('dblclick', () => cmd(dlg, c, 5));
        main.addEventListener('focus', () => cmd(dlg, c, 6));
        main.addEventListener('blur', () => cmd(dlg, c, 7));
        break;
      case 'CHECK': case 'RADIO': {
        el = D.createElement('label'); el.className = 'ood-check';
        main = D.createElement('input'); main.type = spec.kind === 'RADIO' ? 'radio' : 'checkbox';
        if (spec.kind === 'RADIO') main.name = 'oodg' + dlg.key + '_' + dlg.group;
        c.tri = has(o, '3STATE');
        const sp = D.createElement('span'); label(sp, text); c.textEl = sp;
        if (has(o, 'LTEXT')) el.append(sp, main); else el.append(main, sp);
        main.addEventListener('click', () => {
          if (c.tri) {                                      // unchecked -> checked -> indeterminate
            c.state = ((c.state || 0) + 1) % 3;
            main.checked = c.state === 1; main.indeterminate = c.state === 2;
          }
          cmd(dlg, c, 0, true);
        });
        break; }
      case 'GROUP': {
        el = main = D.createElement('fieldset'); const lg = D.createElement('legend'); label(lg, text);
        if (text !== '') el.appendChild(lg); c.textEl = lg; c.focusable = false;
        break; }
      case 'STATIC':
        el = main = D.createElement('div'); el.className = 'ood-static'; label(el, text); c.focusable = false;
        if (c.cy <= 12) el.classList.add('ood-oneline');
        if (has(o, 'CENTER')) el.style.textAlign = 'center'; else if (has(o, 'RIGHT')) el.style.textAlign = 'right';
        if (has(o, 'BORDER')) el.style.border = '1px solid #7a7a7a';
        if (has(o, 'NOTIFY')) { el.addEventListener('click', () => cmd(dlg, c, 0, true)); el.addEventListener('dblclick', () => cmd(dlg, c, 1, true)); }
        break;
      case 'FRAME': {                                       // createBlackRect, createGrayFrame ...
        el = main = D.createElement('div'); el.className = 'ood-frame'; c.focusable = false;
        const col = has(o, 'WHITE') ? '#fff' : has(o, 'GRAY') ? '#a0a0a0' : has(o, 'ETCHED') ? '#d5d5d5' : '#000';
        if (has(o, 'RECT')) el.style.background = col; else el.style.border = '1px solid ' + col;
        break; }
      case 'EDIT':
        if (has(o, 'MULTILINE')) {
          el = main = D.createElement('textarea'); main.wrap = has(o, 'HSCROLL') || has(o, 'AUTOSCROLLH') ? 'off' : 'soft';
          if (has(o, 'NOWANTRETURN')) main.dataset.noreturn = '1';
        } else {
          el = main = D.createElement('input'); main.type = has(o, 'PASSWORD') ? 'password' : 'text';
          if (has(o, 'NUMBER')) main.inputMode = 'numeric';
        }
        el.className = 'ood-edit'; main.value = text; main.spellcheck = false; main.autocomplete = 'off';
        if (has(o, 'READONLY')) main.readOnly = true;
        if (has(o, 'CENTER')) main.style.textAlign = 'center'; else if (has(o, 'RIGHT')) main.style.textAlign = 'right';
        if (has(o, 'NOBORDER')) main.style.border = '0';
        main.addEventListener('input', () => {
          if (has(o, 'NUMBER')) main.value = main.value.replace(/\D/g, '');
          if (has(o, 'UPPER')) main.value = main.value.toUpperCase();
          if (has(o, 'LOWER')) main.value = main.value.toLowerCase();
          c.modified = true; cmd(dlg, c, 0x400); cmd(dlg, c, 0x300);
        });
        main.addEventListener('focus', () => cmd(dlg, c, 0x100));
        main.addEventListener('blur', () => cmd(dlg, c, 0x200));
        break;
      case 'LIST':
        el = main = D.createElement('select'); main.size = 2; main.multiple = has(o, 'MULTI');
        c.sort = has(o, 'SORT');
        main.addEventListener('change', () => cmd(dlg, c, 1));
        main.addEventListener('dblclick', () => cmd(dlg, c, 2));
        main.addEventListener('focus', () => cmd(dlg, c, 4));
        main.addEventListener('blur', () => cmd(dlg, c, 5));
        break;
      case 'COMBO':                                         // LIST -> drop-down list; else editable
        c.sort = has(o, 'SORT');
        if (has(o, 'LIST') && !has(o, 'SIMPLE')) {
          el = main = D.createElement('select'); c.droplist = true;
          main.addEventListener('change', () => { cmd(dlg, c, 9); cmd(dlg, c, 1); });
        } else {
          el = D.createElement('div'); main = D.createElement('input'); main.className = 'ood-edit';
          main.style.cssText = 'width:100%;height:100%'; main.autocomplete = 'off';
          const dl = D.createElement('datalist'); dl.id = 'oodl' + dlg.key + '_' + c.id; main.setAttribute('list', dl.id);
          el.append(main, dl); c.items = dl;
          main.addEventListener('input', () => { cmd(dlg, c, 6); cmd(dlg, c, 5); });
          main.addEventListener('change', () => { cmd(dlg, c, 9); cmd(dlg, c, 1); });
        }
        main.addEventListener('focus', () => cmd(dlg, c, 3));
        main.addEventListener('blur', () => cmd(dlg, c, 4));
        break;
      case 'PROGRESS':
        el = main = D.createElement('div'); el.className = 'ood-progress'; c.bar = D.createElement('div'); el.appendChild(c.bar);
        c.min = 0; c.max = 100; c.pos = 0; c.step = 10; c.focusable = false; c.vertical = has(o, 'VERTICAL');
        if (c.vertical) { el.style.position = 'absolute'; c.bar.style.cssText = 'position:absolute;left:0;bottom:0;width:100%;height:0'; }
        break;
      case 'LISTVIEW':
        el = main = D.createElement('div'); el.className = 'ood-lv'; el.tabIndex = 0;
        c.cols = []; c.rows = []; c.uid = 0; c.focusIdx = -1; c.ex = new Set(); c.single = has(o, 'SINGLESEL');
        c.view = has(o, 'REPORT') ? 'REPORT' : has(o, 'SMALLICON') ? 'SMALLICON' : has(o, 'LIST') ? 'LIST' : 'ICON';
        c.table = D.createElement('table'); c.thead = D.createElement('thead'); c.tbody = D.createElement('tbody');
        c.table.append(c.thead, c.tbody); el.appendChild(c.table); c.el = el; lvWire(dlg, c);
        break;
      case 'TREEVIEW':
        el = main = D.createElement('div'); el.className = 'ood-tv'; el.tabIndex = 0;
        c.nodes = new Map(); c.roots = []; c.nextH = 0; c.selH = 0; c.body = D.createElement('div'); el.appendChild(c.body); c.el = el; tvWire(dlg, c);
        break;
      case 'TAB':
        el = main = D.createElement('div'); el.className = 'ood-tab'; c.tabs = []; c.cur = -1;
        c.strip = D.createElement('div'); c.strip.className = 'ood-tabstrip'; c.page = D.createElement('div'); c.page.className = 'ood-tabpage';
        el.append(c.strip, c.page); tabWire(dlg, c);
        break;
      case 'UPDOWN': {
        el = main = D.createElement('div'); el.className = 'ood-ud'; c.focusable = false;
        c.min = 0; c.max = 100; c.pos = 0; c.buddy = 0;
        const up = D.createElement('button'), dn = D.createElement('button');
        up.type = dn.type = 'button'; up.tabIndex = dn.tabIndex = -1; up.textContent = '\u25B4'; dn.textContent = '\u25BE';
        el.append(up, dn);
        if (has(o, 'AUTOBUDDY') && dlg.all.length) c.buddy = dlg.all[dlg.all.length - 1].id;
        c.setInt = has(o, 'SETBUDDYINT'); c.wrap = has(o, 'WRAP');
        const step = (d) => {
          let np = c.pos + d;
          if (np > c.max) np = c.wrap ? c.min : c.max; if (np < c.min) np = c.wrap ? c.max : c.min;
          note(dlg, c, 'DELTAPOS', c.pos + SEP + (np - c.pos));
          udSet(dlg, c, np);
        };
        up.addEventListener('click', () => step(1)); dn.addEventListener('click', () => step(-1));
        break; }
      default:                                              // a control kind not ported yet
        el = main = D.createElement('div'); el.className = 'ood-todo'; el.textContent = spec.kind + ' ' + c.id; c.focusable = false;
    }
    c.el = el; c.main = main;
    place(dlg, el, c);
    if (c.kind === 'COMBO' && c.droplist) el.style.height = Math.round(12 * dlg.fy) + 'px';   // cy is the dropped height
    if (c.kind === 'COMBO' && !c.droplist) el.style.height = Math.round(12 * dlg.fy) + 'px';
    if (c.kind === 'UPDOWN' && c.buddy && (has(o, 'RIGHT') || has(o, 'LEFT'))) {   // sits inside its buddy's edge
      const b = dlg.ctrls.get(c.buddy);
      if (b) {
        const w = Math.round(9 * dlg.fx), bl = parseInt(b.el.style.left), bw = parseInt(b.el.style.width);
        el.style.left = (has(o, 'RIGHT') ? bl + bw - w - 1 : bl + 1) + 'px'; el.style.top = (parseInt(b.el.style.top) + 1) + 'px';
        el.style.width = w + 'px'; el.style.height = (parseInt(b.el.style.height) - 2) + 'px';
      }
    }
    if (has(o, 'HIDDEN')) el.hidden = true;
    if (has(o, 'DISABLED')) main.disabled = true;
    if (has(o, 'NOTAB')) main.tabIndex = -1;
    dlg.client.appendChild(el);
    dlg.all.push(c);
    if (c.id > 0 && !dlg.ctrls.has(c.id)) dlg.ctrls.set(c.id, c);
    return c;
  }
  ood.addControl = function (key, spec) {
    const dlg = ood.dialogs.get(Number(key)); if (!dlg) return '0';
    addControl(dlg, spec); return '1';
  };

  /* ---- list-view, tree-view, tab ----------------------------------------- */
  const SEP = '\x1f';
  function note(dlg, c, ev, extra) {                           // a WM_NOTIFY to Rexx, if connected
    if (dlg.subs.has(c.id + '.' + ev)) fire(dlg.key, 'NOTIFY', c.id, ev, extra);
  }
  function later(c, fn) { if (c.dirty) return; c.dirty = true; queueMicrotask(() => { c.dirty = false; fn(c); }); }

  function lvRender(c) {
    const report = c.view === 'REPORT';
    c.thead.textContent = ''; c.tbody.textContent = '';
    c.table.classList.toggle('ood-grid', c.ex.has('GRIDLINES'));
    if (report) {
      const tr = D.createElement('tr');
      c.cols.forEach((col) => {
        const th = D.createElement('th'); th.textContent = col.text; th.style.width = col.w < 0 ? 'auto' : col.w + 'px';
        th.style.minWidth = th.style.maxWidth = th.style.width; th.style.textAlign = col.fmt; tr.appendChild(th);
      });
      c.thead.appendChild(tr);
    }
    c.rows.forEach((row, i) => {
      const tr = D.createElement('tr');
      if (row.sel) tr.classList.add('ood-sel');
      if (i === c.focusIdx) tr.classList.add('ood-foc');
      const n = report ? Math.max(1, c.cols.length) : 1;
      for (let k = 0; k < n; k++) {
        const td = D.createElement('td');
        if (k === 0 && c.ex.has('CHECKBOXES')) {
          const cb = D.createElement('input'); cb.type = 'checkbox'; cb.checked = !!row.chk; cb.tabIndex = -1; cb.className = 'ood-lvchk'; td.appendChild(cb);
        }
        td.append(row.cells[k] == null ? '' : row.cells[k]);
        if (report && c.cols[k]) td.style.textAlign = c.cols[k].fmt;
        tr.appendChild(td);
      }
      c.tbody.appendChild(tr);
    });
  }
  function lvSel(dlg, c, i, on) {
    const row = c.rows[i]; if (!row || !!row.sel === on) return;
    row.sel = on; later(c, lvRender);
    note(dlg, c, 'SEL', i + SEP + (on ? 'SELECTED' : 'UNSELECTED'));
  }
  function lvFocus(dlg, c, i) {
    if (c.focusIdx === i) return;
    const old = c.focusIdx; c.focusIdx = i; later(c, lvRender);
    if (old >= 0 && old < c.rows.length) note(dlg, c, 'FOC', old + SEP + 'UNFOCUSED');
    if (i >= 0) note(dlg, c, 'FOC', i + SEP + 'FOCUSED');
  }
  function lvPick(dlg, c, i, e) {                              // a click or key chooses row i
    const ctrl = e && (e.ctrlKey || e.metaKey), shift = e && e.shiftKey;
    if (i < 0) { c.rows.forEach((r, k) => lvSel(dlg, c, k, false)); return; }
    if (c.single || (!ctrl && !shift)) {
      c.rows.forEach((r, k) => { if (k !== i) lvSel(dlg, c, k, false); });
      lvSel(dlg, c, i, true); c.anchor = i;
    } else if (ctrl) { lvSel(dlg, c, i, !c.rows[i].sel); c.anchor = i; }
    else {
      const a = c.anchor == null ? i : c.anchor, lo = Math.min(a, i), hi = Math.max(a, i);
      c.rows.forEach((r, k) => lvSel(dlg, c, k, k >= lo && k <= hi));
    }
    lvFocus(dlg, c, i);
  }
  const keysOf = (e) => [e.shiftKey ? 'SHIFT' : '', e.ctrlKey ? 'CONTROL' : '', e.altKey ? 'ALT' : ''].filter(Boolean).join(' ') || 'NONE';
  function lvWire(dlg, c) {
    const hit = (e) => {
      const tr = e.target.closest('tbody tr'), td = e.target.closest('td');
      return tr ? [tr.sectionRowIndex, td ? td.cellIndex : 0] : [-1, -1];
    };
    c.el.addEventListener('click', (e) => {
      const th = e.target.closest('th');
      if (th) { note(dlg, c, 'COLUMNCLICK', th.cellIndex); return; }
      const [i, sub] = hit(e);
      if (e.target.classList.contains('ood-lvchk')) {
        c.rows[i].chk = e.target.checked; note(dlg, c, 'CHECK', i + SEP + (e.target.checked ? 'CHECKED' : 'UNCHECKED')); return;
      }
      lvPick(dlg, c, i, e);
      note(dlg, c, 'CLICK', i + SEP + sub + SEP + keysOf(e));
    });
    c.el.addEventListener('dblclick', (e) => {
      const [i, sub] = hit(e); if (e.target.closest('th')) return;
      note(dlg, c, 'DBLCLK', i + SEP + sub + SEP + keysOf(e));
      if (i >= 0) note(dlg, c, 'ACTIVATE', i);
    });
    c.el.addEventListener('keydown', (e) => {
      const n = c.rows.length; let i = c.focusIdx;
      if (e.key === 'ArrowDown' && n) { e.preventDefault(); lvPick(dlg, c, Math.min(n - 1, i + 1), e); }
      else if (e.key === 'ArrowUp' && n) { e.preventDefault(); lvPick(dlg, c, Math.max(0, i - 1), e); }
      else if (e.key === 'Enter' && i >= 0) { e.stopPropagation(); note(dlg, c, 'ACTIVATE', i); }
      note(dlg, c, 'KEYDOWN', e.keyCode);
    });
  }
  function lvNext(c, start, flags) {
    const back = has(flags, 'PREV'), n = c.rows.length;
    for (let i = start + (back ? -1 : 1); i >= 0 && i < n; i += back ? -1 : 1) {
      if (has(flags, 'SELECTED') && !c.rows[i].sel) continue;
      if (has(flags, 'FOCUSED') && i !== c.focusIdx) continue;
      return i;
    }
    return -1;
  }

  function tvRender(c) {
    c.body.textContent = '';
    const walk = (list, depth) => list.forEach((h) => {
      const nd = c.nodes.get(h), row = D.createElement('div'); row.className = 'ood-tvrow'; row.dataset.h = h;
      row.style.paddingLeft = (depth * 1.3 + 0.2) + 'em';
      if (h === c.selH) row.classList.add('ood-sel');
      const tw = D.createElement('span'); tw.className = 'ood-tvtw';
      tw.textContent = nd.kids.length ? (nd.open ? '▾' : '▸') : '';
      const tx = D.createElement('span'); tx.textContent = nd.text; if (nd.bold) tx.style.fontWeight = 'bold';
      row.append(tw, tx); c.body.appendChild(row);
      if (nd.open) walk(nd.kids, depth + 1);
    });
    walk(c.roots, 0);
  }
  function tvSelect(dlg, c, h, action) {
    if (c.selH === h) return;
    const old = c.selH; c.selH = h; later(c, tvRender);
    note(dlg, c, 'SELCHANGED', old + SEP + h + SEP + action);
  }
  function tvOpen(dlg, c, h, how) {
    const nd = c.nodes.get(h); if (!nd) return false;
    const open = how === 'TOGGLE' ? !nd.open : how === 'EXPAND';
    if (nd.open === open) return true;
    note(dlg, c, 'EXPANDING', h + SEP + (open ? 'EXPANDED' : 'COLLAPSED'));
    nd.open = open; later(c, tvRender);
    note(dlg, c, 'EXPANDED', h + SEP + (open ? 'EXPANDED' : 'COLLAPSED'));
    return true;
  }
  function tvVisible(c) { const out = []; const walk = (l) => l.forEach((h) => { out.push(h); const nd = c.nodes.get(h); if (nd.open) walk(nd.kids); }); walk(c.roots); return out; }
  function tvDrop(c, h) { const nd = c.nodes.get(h); if (!nd) return; nd.kids.slice().forEach((k) => tvDrop(c, k)); c.nodes.delete(h); if (c.selH === h) c.selH = 0; }
  function tvWire(dlg, c) {
    c.el.addEventListener('click', (e) => {
      const row = e.target.closest('.ood-tvrow'); if (!row) return;
      const h = Number(row.dataset.h);
      if (e.target.classList.contains('ood-tvtw')) tvOpen(dlg, c, h, 'TOGGLE'); else tvSelect(dlg, c, h, 'MOUSE');
    });
    c.el.addEventListener('dblclick', (e) => {
      const row = e.target.closest('.ood-tvrow'); if (row && !e.target.classList.contains('ood-tvtw')) tvOpen(dlg, c, Number(row.dataset.h), 'TOGGLE');
    });
    c.el.addEventListener('keydown', (e) => {
      const vis = tvVisible(c), i = vis.indexOf(c.selH), nd = c.nodes.get(c.selH);
      if (e.key === 'ArrowDown' && i < vis.length - 1) { e.preventDefault(); tvSelect(dlg, c, vis[i + 1], 'KEYBOARD'); }
      else if (e.key === 'ArrowUp' && i > 0) { e.preventDefault(); tvSelect(dlg, c, vis[i - 1], 'KEYBOARD'); }
      else if (e.key === 'ArrowRight' && nd) { e.preventDefault(); tvOpen(dlg, c, c.selH, 'EXPAND'); }
      else if (e.key === 'ArrowLeft' && nd) { e.preventDefault(); tvOpen(dlg, c, c.selH, 'COLLAPSE'); }
    });
  }

  function udSet(dlg, c, pos) {
    c.pos = Math.max(c.min, Math.min(c.max, pos));
    const b = dlg.ctrls.get(c.buddy);
    if (b && c.setInt && b.kind === 'EDIT') { b.main.value = String(c.pos); cmd(dlg, b, 0x400); cmd(dlg, b, 0x300); }
  }
  function tabRender(c) {
    c.strip.textContent = '';
    c.tabs.forEach((t, i) => {
      const b = D.createElement('button'); b.type = 'button'; b.className = 'ood-tabbtn'; b.tabIndex = i === c.cur ? 0 : -1;
      label(b, t.text); if (i === c.cur) b.classList.add('ood-cur'); c.strip.appendChild(b);
    });
  }
  function tabWire(dlg, c) {
    c.strip.addEventListener('click', (e) => {
      const b = e.target.closest('.ood-tabbtn'); if (!b) return;
      const i = Array.prototype.indexOf.call(c.strip.children, b); if (i === c.cur) return;
      note(dlg, c, 'SELCHANGING', ''); c.cur = i; tabRender(c); note(dlg, c, 'SELCHANGE', '');
    });
  }

  /* list helpers: positions are zero-based here, as in the Win32 messages */
  const optsOf = (c) => (c.items ? c.items : c.main).children;
  function listInsert(c, at, text) {
    const op = D.createElement('option'); op.textContent = text; if (c.items) op.value = text;
    const kids = optsOf(c), box = c.items || c.main;
    if (c.sort && at < 0) {
      at = 0; while (at < kids.length && kids[at].textContent.localeCompare(text, undefined, { sensitivity: 'base' }) <= 0) at++;
    }
    if (at < 0 || at >= kids.length) { box.appendChild(op); at = kids.length - 1; } else box.insertBefore(op, kids[at]);
    if (c.droplist && kids.length === 1) c.main.selectedIndex = -1;
    return at;
  }
  function listFind(c, text, start, exact) {
    const kids = optsOf(c), n = kids.length, t = text.toLowerCase();
    for (let k = 0; k < n; k++) {
      const i = (start + 1 + k) % n, v = kids[i].textContent.toLowerCase();
      if (exact ? v === t : v.startsWith(t)) return i;
    }
    return -1;
  }
  function curSel(c) {
    if (c.kind === 'COMBO' && !c.droplist) {
      const kids = optsOf(c);
      for (let i = 0; i < kids.length; i++) if (kids[i].textContent === c.main.value) return i;
      return -1;
    }
    return c.main.selectedIndex;
  }
  function setProgress(c) {
    const span = c.max - c.min; c.pos = Math.max(c.min, Math.min(c.max, c.pos));
    const pct = (span > 0 ? (c.pos - c.min) * 100 / span : 0) + '%';
    if (c.vertical) c.bar.style.height = pct; else c.bar.style.width = pct;
  }

  /* ---- Win32 messages (the subset upstream's Rexx code sends) ------------ */
  ood.msg = function (key, id, msg, w, l) {
    const dlg = ood.dialogs.get(Number(key)); if (!dlg) return '0';
    const c = dlg.ctrls.get(Number(id)); if (!c) return '0';
    msg = Number(msg); w = Number(w); l = Number(l);
    const m = c.main;
    switch (c.kind) {
      case 'BUTTON': case 'CHECK': case 'RADIO':
        switch (msg) {
          case 0xF5: m.click(); return '0';                                   // BM_CLICK
          case 0xF0: return String(c.tri ? (c.state || 0) : (m.checked ? 1 : 0)); // BM_GETCHECK
          case 0xF1: if (c.tri) c.state = w; m.checked = w === 1; m.indeterminate = w === 2; return '0'; // BM_SETCHECK
          case 0xF2: return String((m.checked ? 1 : 0) | (D.activeElement === m ? 8 : 0)); // BM_GETSTATE
        }
        break;
      case 'EDIT':
        switch (msg) {
          case 0xB1: m.setSelectionRange(w, l < 0 ? m.value.length : l); return '1';   // EM_SETSEL
          case 0xB8: return c.modified ? '1' : '0';                                    // EM_GETMODIFY
          case 0xB9: c.modified = w !== 0; return '0';                                 // EM_SETMODIFY
          case 0xBA: return String(m.value.split('\n').length);                        // EM_GETLINECOUNT
          case 0xC5: if (w > 0) m.maxLength = w; else m.removeAttribute('maxlength'); return '0'; // EM_LIMITTEXT
          case 0xC6: return '0';
          case 0xCC: if (m.tagName === 'INPUT') m.type = w === 0 ? 'text' : 'password'; return '0'; // EM_SETPASSWORDCHAR
          case 0xD2: return m.type === 'password' ? '42' : '0';                        // EM_GETPASSWORDCHAR
          case 0xCF: m.readOnly = w !== 0; return '1';                                 // EM_SETREADONLY
          case 0xB7: m.scrollTop = m.scrollHeight; return '0';                         // EM_SCROLLCARET
          case 0x303: m.setRangeText(''); return '0';                                  // WM_CLEAR
        }
        break;
      case 'LIST':
        switch (msg) {
          case 0x182: if (w < 0 || w >= m.options.length) return '-1'; m.remove(w); return String(m.options.length); // LB_DELETESTRING
          case 0x184: m.textContent = ''; return '0';                                  // LB_RESETCONTENT
          case 0x185: if (l < 0) { for (const op of m.options) op.selected = w !== 0; } else if (m.options[l]) m.options[l].selected = w !== 0; return '0'; // LB_SETSEL
          case 0x186: m.selectedIndex = w; return String(m.selectedIndex);             // LB_SETCURSEL
          case 0x187: return m.options[w] && m.options[w].selected ? '1' : '0';        // LB_GETSEL
          case 0x188: return String(m.selectedIndex);                                  // LB_GETCURSEL
          case 0x18B: return String(m.options.length);                                 // LB_GETCOUNT
          case 0x190: return String(m.selectedOptions.length);                         // LB_GETSELCOUNT
          case 0x18E: return '0';                                                      // LB_GETTOPINDEX
          case 0x197: if (m.options[w]) m.options[w].scrollIntoView({ block: 'nearest' }); return '0'; // LB_SETTOPINDEX
        }
        break;
      case 'COMBO': {
        const kids = optsOf(c);
        switch (msg) {
          case 0x144: if (w < 0 || w >= kids.length) return '-1'; kids[w].remove(); return String(kids.length); // CB_DELETESTRING
          case 0x146: return String(kids.length);                                      // CB_GETCOUNT
          case 0x147: return String(curSel(c));                                        // CB_GETCURSEL
          case 0x14B: (c.items || m).textContent = ''; if (!c.droplist) m.value = ''; return '0'; // CB_RESETCONTENT
          case 0x14E:                                                                  // CB_SETCURSEL
            if (c.droplist) { m.selectedIndex = w; return String(m.selectedIndex); }
            if (w >= 0 && w < kids.length) { m.value = kids[w].textContent; return String(w); }
            m.value = ''; return '-1';
          case 0x14F: if (w && m.showPicker) { try { m.showPicker(); } catch (e) { } } return '1'; // CB_SHOWDROPDOWN
          case 0x157: return '0';                                                      // CB_GETDROPPEDSTATE
          case 0x142: if (!c.droplist) m.setSelectionRange(l & 0xFFFF, (l >>> 16) === 0xFFFF ? m.value.length : l >>> 16); return '1'; // CB_SETEDITSEL
        }
        break; }
      case 'PROGRESS':
        switch (msg) {
          case 0x401: c.min = l & 0xFFFF; c.max = l >>> 16; setProgress(c); return '0';  // PBM_SETRANGE
          case 0x406: c.min = w; c.max = l; setProgress(c); return '0';                  // PBM_SETRANGE32
          case 0x407: return String(w ? c.min : c.max);                                  // PBM_GETRANGE
          case 0x402: { const old = c.pos; c.pos = w; setProgress(c); return String(old); } // PBM_SETPOS
          case 0x403: { const old = c.pos; c.pos += w; setProgress(c); return String(old); } // PBM_DELTAPOS
          case 0x404: { const old = c.step; c.step = w; return String(old); }            // PBM_SETSTEP
          case 0x405: { const old = c.pos; c.pos += c.step; if (c.pos > c.max) c.pos = c.min + (c.pos - c.max); setProgress(c); return String(old); } // PBM_STEPIT
          case 0x408: return String(c.pos);                                              // PBM_GETPOS
          case 0x409: c.bar.style.background = bgr(w === 0xFF000000 ? 0x25B006 : l); return '0'; // PBM_SETBARCOLOR
          case 0x2001: c.el.style.background = bgr(l); return '0';                        // PBM_SETBKCOLOR
        }
        break;
    }
    if (c.kind === 'LISTVIEW') switch (msg) {
      case 0x1004: return String(c.rows.length);                                       // LVM_GETITEMCOUNT
      case 0x1032: return String(c.rows.filter((r) => r.sel).length);                  // LVM_GETSELECTEDCOUNT
      case 0x101D: return String(c.cols[w] ? Math.max(0, c.cols[w].w) : 0);            // LVM_GETCOLUMNWIDTH
      case 0x1013: { const tr = c.tbody.children[w]; if (tr) tr.scrollIntoView({ block: 'nearest' }); return '1'; } // LVM_ENSUREVISIBLE
      case 0x102F: case 0x1027: case 0x102A: case 0x1015: return '0';
    }
    if (c.kind === 'TREEVIEW') switch (msg) {
      case 0x1105: return String(c.nodes.size);                                        // TVM_GETCOUNT
      case 0x1114: return '1';                                                         // TVM_ENSUREVISIBLE
    }
    if (c.kind === 'UPDOWN') switch (msg) {
      case 0x471: { const old = c.pos; udSet(dlg, c, l); return String(old); }         // UDM_SETPOS32
      case 0x472: return String(c.pos);                                                // UDM_GETPOS32
      case 0x46F: c.min = Math.min(w, l); c.max = Math.max(w, l); udSet(dlg, c, c.pos); return '0'; // UDM_SETRANGE32
      case 0x46E: return '10';                                                         // UDM_GETBASE
      case 0x46D: return '10';                                                         // UDM_SETBASE
    }
    if (c.kind === 'TAB') switch (msg) {
      case 0x1304: return String(c.tabs.length);                                       // TCM_GETITEMCOUNT
      case 0x130B: return String(c.cur);                                               // TCM_GETCURSEL
      case 0x130C: { const old = c.cur; if (w >= 0 && w < c.tabs.length) { c.cur = w; tabRender(c); } return String(old); } // TCM_SETCURSEL
      case 0x1308: if (w < 0 || w >= c.tabs.length) return '0'; c.tabs.splice(w, 1); if (c.cur >= c.tabs.length) c.cur = c.tabs.length - 1; tabRender(c); return '1'; // TCM_DELETEITEM
      case 0x1309: c.tabs = []; c.cur = -1; tabRender(c); return '1';                  // TCM_DELETEALLITEMS
      case 0x132F: return String(c.cur);                                               // TCM_GETCURFOCUS
      case 0x1330: if (w >= 0 && w < c.tabs.length) { c.cur = w; tabRender(c); } return '0'; // TCM_SETCURFOCUS
      case 0x132C: return '1';                                                         // TCM_GETROWCOUNT
    }
    ood.log.push('msg ' + c.kind + ' 0x' + msg.toString(16));
    return '0';
  };
  const bgr = (v) => 'rgb(' + (v & 255) + ',' + ((v >> 8) & 255) + ',' + ((v >> 16) & 255) + ')';

  /* ---- operations that carry text, and window operations ---------------- */
  ood.op = function (key, id, name, a, b, c2) {
    const dlg = ood.dialogs.get(Number(key)); if (!dlg) return '';
    id = Number(id);
    const c = id === 0 ? null : dlg.ctrls.get(id);
    if (id !== 0 && !c) return name === 'exists' ? '0' : '';
    const el = c ? c.el : dlg.el, m = c ? c.main : dlg.el;
    switch (name) {
      case 'exists': return '1';
      case 'kind': return c.kind;
      case 'getText':
        if (!c) return dlg.capEl.textContent;
        if (c.kind === 'EDIT' || (c.kind === 'COMBO' && !c.droplist)) return m.value;
        if (c.kind === 'COMBO') return m.selectedIndex >= 0 ? m.options[m.selectedIndex].textContent : '';
        if (c.kind === 'LIST') return m.selectedIndex >= 0 ? m.options[m.selectedIndex].textContent : '';
        return c.rawText != null ? c.rawText : (c.textEl || m).textContent;
      case 'setText':
        a = String(a);
        if (!c) { dlg.capEl.textContent = a; return '1'; }
        if (c.kind === 'EDIT' || (c.kind === 'COMBO' && !c.droplist)) { m.value = a; return '1'; }
        if (c.kind === 'GROUP' && !c.textEl.parentNode && a !== '') el.appendChild(c.textEl);
        c.rawText = a; label(c.textEl || m, a); return '1';
      case 'show': el.hidden = false; if (!c) el.style.visibility = 'visible'; return '1';
      case 'hide': if (c) el.hidden = true; else el.style.visibility = 'hidden'; return '1';
      case 'isVisible': return c ? (el.hidden ? '0' : '1') : (el.style.visibility === 'hidden' ? '0' : '1');
      case 'enable': if (c) m.disabled = (a === '0'); else el.inert = (a === '0'); return '1';
      case 'isEnabled': return c ? (m.disabled ? '0' : '1') : (el.inert ? '0' : '1');
      case 'focus': m.focus(); return '1';
      case 'focusId': { const f = dlg.all.find((x) => x.main === D.activeElement); return f ? String(f.id) : '0'; }
      case 'tab': {
        const f = dlg.all.filter((x) => x.focusable && !x.main.disabled && !x.el.hidden && x.main.tabIndex >= 0);
        const i = f.findIndex((x) => x.main === D.activeElement);
        if (f.length) f[(i + (a === '1' ? 1 : f.length - 1)) % f.length].main.focus();
        return '1'; }
      case 'rect': { const r = el.getBoundingClientRect(); return [r.left, r.top, r.right, r.bottom].map(Math.round).join(' '); }
      case 'clientRect': { const r = (c ? el : dlg.client).getBoundingClientRect(); return '0 0 ' + Math.round(r.width) + ' ' + Math.round(r.height); }
      case 'origin': { const r = dlg.client.getBoundingClientRect(); return Math.round(r.left) + ' ' + Math.round(r.top); }
      case 'move': el.style.left = Number(a) + 'px'; el.style.top = Number(b) + 'px'; return '1';
      case 'size':
        if (c) { el.style.width = Number(a) + 'px'; el.style.height = Number(b) + 'px'; }
        else { dlg.client.style.width = Number(a) + 'px'; dlg.client.style.height = Math.max(0, Number(b) - dlg.titleEl.offsetHeight) + 'px'; }
        return '1';
      case 'closeBox': { const x = dlg.titleEl.querySelector('.ood-x'); if (x) { x.disabled = (a === '0'); x.style.opacity = a === '0' ? '.35' : ''; } dlg.noClose = (a === '0'); return '1'; }
      case 'top': el.style.zIndex = ++ood.z; return '1';
      case 'default': {                                     // DM_SETDEFID
        const old = dlg.ctrls.get(dlg.defId); if (old && old.kind === 'BUTTON') old.main.classList.remove('ood-def');
        dlg.defId = Number(a); const nw = dlg.ctrls.get(dlg.defId); if (nw && nw.kind === 'BUTTON') nw.main.classList.add('ood-def');
        return '1'; }
      case 'color': if (a !== '') m.style.background = a; if (b !== '') m.style.color = b; return '1';
      case 'font': if (a !== '') m.style.fontFamily = a; if (b !== '') m.style.fontSize = b; if (c2) m.style.fontWeight = c2; return '1';
      case 'textSize': {
        const s = D.createElement('span'); s.style.cssText = 'position:absolute;visibility:hidden;white-space:pre'; s.textContent = String(a);
        dlg.client.appendChild(s); const r = s.getBoundingClientRect(); s.remove();
        return Math.ceil(r.width) + ' ' + Math.ceil(r.height); }
      // edit
      case 'sel': return (m.selectionStart + 1) + ' ' + (m.selectionEnd + 1);
      case 'replaceSel': m.setRangeText(String(a), m.selectionStart, m.selectionEnd, 'end'); c.modified = true; return '1';
      case 'line': { const ls = m.value.split('\n'); return ls[Number(a) - 1] == null ? '' : ls[Number(a) - 1]; }
      case 'cue': m.placeholder = String(a); return '1';
      // list box and combo box; positions zero-based
      case 'add': return String(listInsert(c, -1, String(a)));
      case 'insert': return String(listInsert(c, Number(a), String(b)));
      case 'itemText': { const k = optsOf(c)[Number(a)]; return k ? k.textContent : ''; }
      case 'find': return String(listFind(c, String(a), Number(b), c2 === '1'));
      case 'selItems': return Array.from(m.options).map((op, i) => op.selected ? i + 1 : 0).filter(Boolean).join(' ');
      case 'selectText': {
        const i = listFind(c, String(a), -1, false);
        if (c.kind === 'LIST' || c.droplist) m.selectedIndex = i; else m.value = i >= 0 ? optsOf(c)[i].textContent : String(a);
        return String(i); }
    }
    if (c && name === 'ud.range') return c.min + ' ' + c.max;
    if (c && name === 'ud.buddy') { const old = c.buddy; if (a !== '') c.buddy = Number(a); return String(old); }
    if (c && name.startsWith('lv.')) return lvOp(dlg, c, name.slice(3), a, b, c2);
    if (c && name.startsWith('tv.')) return tvOp(dlg, c, name.slice(3), a, b, c2);
    if (c && name.startsWith('tab.')) return tabOp(dlg, c, name.slice(4), a, b, c2);
    ood.log.push('op ' + name);
    return '';
  };

  function lvOp(dlg, c, name, a, b, c2) {
    const i = Number(a);
    switch (name) {
      case 'insCol': {
        const [text, w, fmt] = String(b).split(SEP); const at = i < 0 || i > c.cols.length ? c.cols.length : i;
        c.cols.splice(at, 0, { text, w: Number(w), fmt: fmt || 'left' });
        c.rows.forEach((r) => { if (r.cells.length > at) r.cells.splice(at, 0, ''); });
        later(c, lvRender); return String(at); }
      case 'delCol': if (!c.cols[i]) return '0'; c.cols.splice(i, 1); c.rows.forEach((r) => r.cells.splice(i, 1)); later(c, lvRender); return '1';
      case 'colCount': return String(c.cols.length);
      case 'colInfo': return c.cols[i] ? c.cols[i].text + SEP + c.cols[i].w + SEP + c.cols[i].fmt : '';
      case 'setColWidth': if (!c.cols[i]) return '0'; c.cols[i].w = Number(b); later(c, lvRender); return '1';
      case 'insRow': {
        const at = i < 0 || i > c.rows.length ? c.rows.length : i;
        c.rows.splice(at, 0, { cells: String(b).split(SEP), sel: false, chk: false, uid: ++c.uid });
        if (c.focusIdx >= at) c.focusIdx++;
        later(c, lvRender); return String(at); }
      case 'setCell': if (!c.rows[i]) return '0'; c.rows[i].cells[Number(b)] = String(c2); later(c, lvRender); return '1';
      case 'cell': return c.rows[i] && c.rows[i].cells[Number(b)] != null ? c.rows[i].cells[Number(b)] : '';
      case 'del': if (!c.rows[i]) return '0'; c.rows.splice(i, 1); if (c.focusIdx === i) c.focusIdx = -1; else if (c.focusIdx > i) c.focusIdx--; later(c, lvRender); return '1';
      case 'clear': c.rows = []; c.focusIdx = -1; later(c, lvRender); return '1';
      case 'next': return String(lvNext(c, i, String(b)));
      case 'state':
        if (!c.rows[i]) return '0';
        if (b === 'SELECT') { if (c.single) c.rows.forEach((r, k) => { if (k !== i) lvSel(dlg, c, k, false); }); lvSel(dlg, c, i, true); }
        else if (b === 'DESELECT') lvSel(dlg, c, i, false); else lvFocus(dlg, c, i);
        return '1';
      case 'itemState': return c.rows[i] ? [(c.rows[i].sel ? 'SELECTED' : ''), (i === c.focusIdx ? 'FOCUSED' : '')].filter(Boolean).join(' ') : '';
      case 'deselAll': c.rows.forEach((r, k) => lvSel(dlg, c, k, false)); return '1';
      case 'check':
        c.rows.forEach((r, k) => { if ((i < 0 || k === i) && !!r.chk !== (b === '1')) { r.chk = b === '1'; note(dlg, c, 'CHECK', k + SEP + (r.chk ? 'CHECKED' : 'UNCHECKED')); } });
        later(c, lvRender); return '1';
      case 'isChecked': return c.rows[i] && c.rows[i].chk ? '1' : '0';
      case 'ex':
        if (a === 'GET') return Array.from(c.ex).join(' ');
        String(b).split(/\s+/).filter(Boolean).forEach((w) => { if (a === 'ADD') c.ex.add(w); else c.ex.delete(w); });
        later(c, lvRender); return '1';
      case 'find': {
        const t = String(a).toLowerCase(), n = c.rows.length, start = Number(b), partial = has(String(c2), 'P'), wrap = has(String(c2), 'W');
        for (let k = 1; k <= n; k++) {
          let j = start + k; if (j >= n) { if (!wrap) break; j -= n; }
          const v = String(c.rows[j].cells[0] || '').toLowerCase();
          if (partial ? v.startsWith(t) : v === t) return String(j);
        }
        return '-1'; }
      case 'view': if (a === '') return c.view; c.view = String(a); later(c, lvRender); return '1';
      case 'uid': return c.rows[i] ? String(c.rows[i].uid) : '0';
      case 'sort': { const col = i, dir = b === 'D' ? -1 : 1; c.rows.sort((x, y) => dir * String(x.cells[col] || '').localeCompare(String(y.cells[col] || ''), undefined, { numeric: true })); c.focusIdx = -1; later(c, lvRender); return '1'; }
    }
    return '';
  }
  function tvOp(dlg, c, name, a, b, c2) {
    const h = Number(a), nd = c.nodes.get(h);
    const sibs = (x) => (x.parent ? c.nodes.get(x.parent).kids : c.roots);
    switch (name) {
      case 'ins': {
        const [text, opts] = String(c2).split(SEP); const parent = c.nodes.get(h);
        const id = ++c.nextH, list = parent ? parent.kids : c.roots;
        c.nodes.set(id, { h: id, text, parent: parent ? h : 0, kids: [], open: has(opts || '', 'EXPANDED'), bold: has(opts || '', 'BOLD') });
        if (b === 'FIRST') list.unshift(id);
        else if (b === 'SORT') { let k = 0; while (k < list.length && c.nodes.get(list[k]).text.localeCompare(text) <= 0) k++; list.splice(k, 0, id); }
        else if (b === 'LAST' || b === '') list.push(id);
        else { const k = list.indexOf(Number(b)); if (k < 0) list.push(id); else list.splice(k + 1, 0, id); }
        later(c, tvRender); return String(id); }
      case 'del': if (!nd) return '0'; { const l = sibs(nd); l.splice(l.indexOf(h), 1); tvDrop(c, h); later(c, tvRender); return '1'; }
      case 'clear': c.nodes.clear(); c.roots = []; c.selH = 0; later(c, tvRender); return '1';
      case 'expand': return tvOpen(dlg, c, h, String(b)) ? '1' : '0';
      case 'find': {
        const t = String(a).toLowerCase(); let go = Number(b) === 0;
        const all = []; const walk = (l) => l.forEach((x) => { all.push(x); walk(c.nodes.get(x).kids); }); walk(c.roots);
        for (const x of all) {
          if (!go) { if (x === Number(b)) go = true; continue; }
          const v = c.nodes.get(x).text.toLowerCase(); if (c2 === '1' ? v.startsWith(t) : v === t) return String(x);
        }
        return '0'; }
      case 'rel': {
        if (!nd) return '0';
        if (b === 'CHILD') return String(nd.kids[0] || 0);
        if (b === 'PARENT') return String(nd.parent);
        const l = b.endsWith('VISIBLE') ? tvVisible(c) : sibs(nd), k = l.indexOf(h);
        if (k < 0) return '0';
        return String((b.startsWith('NEXT') ? l[k + 1] : l[k - 1]) || 0); }
      case 'special': return String(a === 'ROOT' ? (c.roots[0] || 0) : a === 'SELECTED' ? c.selH : a === 'FIRSTVISIBLE' ? (c.roots[0] || 0) : 0);
      case 'info': return nd ? nd.text + SEP + nd.kids.length + SEP + [(nd.open ? 'EXPANDED' : ''), (nd.bold ? 'BOLD' : ''), (h === c.selH ? 'SELECTED' : '')].filter(Boolean).join(' ') : '';
      case 'text': return nd ? nd.text : '';
      case 'modify': {
        if (!nd) return '0'; const [flag, text, opts] = String(b).split(SEP);
        if (has(flag, 'T')) nd.text = text;
        if (has(flag, 'O')) { nd.bold = has(opts, 'BOLD') ? true : has(opts, 'NOTBOLD') ? false : nd.bold; if (has(opts, 'EXPANDED')) nd.open = !has(opts, 'NOTEXPANDED'); }
        later(c, tvRender); return '1'; }
      case 'select': if (h !== 0 && !nd) return '0'; { let p = nd && nd.parent; while (p) { c.nodes.get(p).open = true; p = c.nodes.get(p).parent; } tvSelect(dlg, c, h, 'UNKNOWN'); later(c, tvRender); return '1'; }
    }
    return '';
  }
  function tabOp(dlg, c, name, a, b) {
    const i = Number(a);
    switch (name) {
      case 'ins': { const at = i < 0 || i > c.tabs.length ? c.tabs.length : i; c.tabs.splice(at, 0, { text: String(b) }); if (c.cur < 0) c.cur = 0; else if (at <= c.cur) c.cur++; tabRender(c); return String(at); }
      case 'text': return c.tabs[i] ? c.tabs[i].text : '';
      case 'setText': if (!c.tabs[i]) return '0'; c.tabs[i].text = String(b); tabRender(c); return '1';
      case 'selectText': { const t = String(a).toLowerCase(), k = c.tabs.findIndex((x) => plain(x.text).toLowerCase() === t || x.text.toLowerCase() === t); if (k >= 0) { c.cur = k; tabRender(c); } return String(k); }
      case 'rect': { const o = dlg.client.getBoundingClientRect(), r = c.page.getBoundingClientRect(); return [r.left - o.left + 2, r.top - o.top + 2, r.right - o.left - 2, r.bottom - o.top - 2].map(Math.round).join(' '); }
    }
    return '';
  }

  /* ---- message box ------------------------------------------------------ */
  ood.msgBox = function (token, text, title, buttons, icon) {
    boot();
    const key = -Number(token);
    const names = { OK: ['OK:1'], OKCANCEL: ['OK:1', 'Cancel:2'], YESNO: ['Yes:6', 'No:7'], YESNOCANCEL: ['Yes:6', 'No:7', 'Cancel:2'],
      RETRYCANCEL: ['Retry:4', 'Cancel:2'], ABORTRETRYIGNORE: ['Abort:3', 'Retry:4', 'Ignore:5'], CANCELTRYCONTINUE: ['Cancel:2', 'Try Again:10', 'Continue:11'] };
    const set = names[String(buttons || 'OK').toUpperCase()] || names.OK;
    const back = D.createElement('div'); back.className = 'ood-back'; back.style.zIndex = ++ood.z;
    const el = D.createElement('div'); el.className = 'ood-dlg ood-msgbox'; el.style.zIndex = ++ood.z;
    el.style.fontSize = Math.round(9 * 96 / 72 * ood.scale) + 'px';
    const t = D.createElement('div'); t.className = 'ood-title'; const cap = D.createElement('span'); cap.textContent = title || ''; t.appendChild(cap);
    const body = D.createElement('div'); body.style.cssText = 'padding:1.4em 1.6em;background:#fff;white-space:pre-wrap;display:flex;gap:1em;align-items:flex-start;max-width:34em;user-select:text';
    const glyph = { ERROR: '⛔', HAND: '⛔', STOP: '⛔', WARNING: '⚠️', EXCLAMATION: '⚠️', QUESTION: '❓', INFORMATION: 'ℹ️', ASTERISK: 'ℹ️' }[String(icon || '').toUpperCase()];
    if (glyph) { const g = D.createElement('div'); g.textContent = glyph; g.style.fontSize = '2em'; g.style.lineHeight = '1'; body.appendChild(g); }
    const msg = D.createElement('div'); msg.className = 'ood-msgtext'; msg.textContent = text; body.appendChild(msg);
    const row = D.createElement('div'); row.style.cssText = 'padding:.8em 1em;display:flex;gap:.6em;justify-content:flex-end';
    const prevFocus = D.activeElement;
    const done = (v) => { el.remove(); back.remove(); if (prevFocus && prevFocus.isConnected) prevFocus.focus(); fire(key, 'MSGBOX', token, v); };
    set.forEach((s, i) => {
      const [name, v] = s.split(':'); const b = D.createElement('button'); b.className = 'ood-c'; b.textContent = name;
      b.style.cssText = 'position:static;min-width:6em;height:1.9em;padding:0 .8em'; if (i === 0) b.classList.add('ood-def');
      b.dataset.value = v; b.addEventListener('click', () => done(v)); row.appendChild(b);
    });
    el.addEventListener('keydown', (e) => { if (e.key === 'Escape') done(set.some((s) => s.endsWith(':2')) ? '2' : set[0].split(':')[1]); });
    el.append(t, body, row); D.body.append(back, el);
    el.style.left = Math.max(0, (W.innerWidth - el.offsetWidth) / 2) + 'px'; el.style.top = Math.max(0, (W.innerHeight - el.offsetHeight) / 3) + 'px';
    row.firstChild.focus();
    return '1';
  };

  /* The size of a text in dialog units of a font (no dialog needed), and in pixels. */
  ood.measure = function (text, fontName, fontSize) {
    boot();
    const box = D.createElement('div'); box.className = 'ood-dlg';
    box.style.cssText = 'visibility:hidden;left:0;top:0;border:0';
    box.style.fontSize = Math.round(Number(fontSize || 8) * 96 / 72 * ood.scale * 100) / 100 + 'px';
    if (fontName && !/^MS Shell Dlg|^MS Sans Serif|^System$/i.test(fontName)) box.style.fontFamily = '"' + fontName + '","Segoe UI",Tahoma,sans-serif';
    const base = D.createElement('span'); base.style.whiteSpace = 'nowrap';
    base.textContent = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    const t = D.createElement('span'); t.style.cssText = 'white-space:pre;display:inline-block'; t.textContent = String(text);
    box.append(base, D.createElement('br'), t); D.body.appendChild(box);
    const b = base.getBoundingClientRect(), r = t.getBoundingClientRect();
    box.remove();
    const fx = Math.floor((b.width / 26 + 1) / 2) / 4, fy = Math.round(b.height) / 8;
    return Math.ceil(r.width / fx) + ' ' + Math.ceil(r.height / fy) + ' ' + Math.ceil(r.width) + ' ' + Math.ceil(r.height) + ' ' + fx + ' ' + fy;
  };

  ood.screen = () => W.innerWidth + ' ' + W.innerHeight;
  ood.setHandler = function (fn) { ood.handler = fn; return '1'; };
})(window);
::END
