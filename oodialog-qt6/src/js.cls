/* js.cls for ooDialog on Qt6 (Linux).
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14.
 *
 * oodWeb.cls (Claude (Fable 5.2)) is written for ooRexx/WASM, where js.cls
 * is Josep Maria Blasco's bridge to the browser.  oodWeb.cls uses exactly
 * four things from it:
 *     .js~page["__ood"]               the renderer object
 *     .js~undefined                   "not loaded yet"
 *     .js~handler(target, message)    where the renderer's events go
 *     .js~nextEvent(seconds)          wait for one event; ~dispatch delivers it
 * This file supplies those four on Qt6, so oodWeb.cls and the generated
 * upstream ooDialog.cls run on Linux byte for byte as they run in the
 * browser.  The renderer is the native library oodqt (native/oodqt.cpp).
 * It is not a JavaScript bridge and offers nothing else of the real js.cls.
 */

::class "JS" public
::method page class
  expose page
  if \var("PAGE") then do
    page = .directory~new
    page["__ood"] = .OodQtRenderer~new
  end
  return page

::method undefined class
  expose undefined
  if \var("UNDEFINED") then undefined = .object~new
  return undefined

::method handler class
  use strict arg target, message
  return .OodQtHandler~new(target, message)

/* resourceProvider: the reader of binary Windows resources (.dll, .exe, .res) this renderer offers, or .nil.
 * It is alchemy's oorexx_win_resources (WinResources.cls), found on REXX_PATH; one reader serves every dialog.
 * oodWeb.cls asks for it when a ResDialog or BinaryMenuBar needs one and none was set (.oodn~resourceProvider). */
::method resourceProvider class
  expose provider
  if var("PROVIDER") then return provider
  provider = .nil
  file = SysSearchPath("REXX_PATH", "WinResources.cls")
  if file \== "" then do
    provider = .context~package~loadPackage(file)~findClass("WinResourceProvider")~new
  end
  return provider

/* Run Qt for up to SECONDS; .nil, or the next event. */
::method nextEvent class
  use arg seconds = 0
  record = oodqt_next(trunc(seconds * 1000))
  if record == "" then return .nil
  return .OodQtEvent~new(self~page["__ood"]~handler, record)


::class OodQtHandler public
::attribute target get
::attribute message get
::method init
  expose target message
  use strict arg target, message


::class OodQtEvent public
::method init
  expose handler fields
  use strict arg handler, record
  -- key, kind, id, code, then the extra, which keeps its own separators (a NOTIFY's parts)
  fs = "1F"x
  parse var record key (fs) kind (fs) id (fs) code (fs) extra
  fields = .array~of(key, kind, id, code, extra)
::method dispatch
  expose handler fields
  if handler == .nil then return
  handler~target~sendWith(handler~message, fields~section(1, 5))


/* The renderer: the 15 messages of oodialog-web.js's __ood, answered by oodqt. */
::class OodQtRenderer public
::attribute handler get
::constant FS "1F"x
::constant RS "1E"x

::method setHandler
  expose handler
  use strict arg handler
  return "1"

::method create
  use strict arg spec, ctrls
  out = .array~of(self~record(spec))
  do c over ctrls
    out~append(self~record(c))
  end
  return oodqt_call("create", out~makeString("L", self~RS))

::method addControl
  use strict arg key, c
  return oodqt_call("addControl", key || self~FS || self~RS || self~record(c))

::method show;       return self~send("show", arg(1, "A"))
::method destroy;    return self~send("destroy", arg(1, "A"))
::method sub;        return self~send("sub", arg(1, "A"))
::method msg;        return self~send("msg", arg(1, "A"))
::method op;         return self~send("op", arg(1, "A"))
::method msgBox;     return self~send("msgBox", arg(1, "A"))
::method measure;    return self~send("measure", arg(1, "A"))
::method setMenu;    return self~send("setMenu", arg(1, "A"))
::method popupMenu;  return self~send("popupMenu", arg(1, "A"))
::method image;      return self~send("image", arg(1, "A"))
::method hasImage;   return self~send("hasImage", arg(1, "A"))
::method screen;     return oodqt_call("screen", "")

::method send private
  use strict arg name, args
  parts = .array~new
  do i = 1 to args~last
    -- an argument may hold the page's own separator (text SEP opts, a row's cells): 1D stands for it on the wire
    if args~hasIndex(i) then parts~append(args[i]~string~changeStr(self~FS, "1D"x))
    else parts~append("")
  end
  return oodqt_call(name, parts~makeString("L", self~FS))

/* a StringTable or Directory as "name=value" fields */
::method record private
  use strict arg table
  out = .array~new
  do name over table~allIndexes
    value = table[name]
    if value == .nil then value = ""
    out~append(name"="value~string)
  end
  return out~makeString("L", self~FS)

::routine oodqt_call public external "LIBRARY oodqt oodqt_call"
::routine oodqt_next public external "LIBRARY oodqt oodqt_next"
