/*----------------------------------------------------------------------------*/
/* OodDesigner.cls -- the ooDialog Designer's model, control catalogue,       */
/* program generator and round-trip reader.                                   */
/*                                                                            */
/* Architecture: Tom Dyer.  Code: Claude (Opus 5.5).                          */
/*                                                                            */
/* The design is owned here, in ooRexx.  The designer page only shows it and  */
/* reports what the user did (a drop, a move, a property typed); every change */
/* is a message to an OodDesign, which checks it and keeps the truth.         */
/*                                                                            */
/* What it writes is plain upstream ooDialog: a UserDialog subclass whose     */
/* defineDialog creates the controls with createXxx and connects the events   */
/* with connectXxxEvent, one accessor method per control (self~display), and  */
/* one method per event holding the few lines of Rexx the user typed.  The    */
/* design rides in the same file as ::RESOURCE oodDesign (DrDialog kept it    */
/* in a .RES file), so a program is also the design it was made from:        */
/* OodDesign~fromSource reads it back, event code included.                   */
/*----------------------------------------------------------------------------*/

::requires "OodUi.cls"    -- the designer's texts, and OodNls: the language support of the designer and its programs

::class OodModule public mixinclass Object
::method module_version class
  return "0.13.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.13.0"
::method module_lastChanged
  return "2026-11-15"


/* One kind of control in the catalogue (a "kind" line of ::RESOURCE oodCatalog). */
::class OodKind public inherit OodModule
::attribute type
::attribute label
::attribute prefix
::attribute create
::attribute access
::attribute args
::attribute w
::attribute h
::attribute text
::attribute events
::attribute connect
::attribute opts
::attribute defopts
::attribute props
::attribute nonvisual
::attribute exopts
::method init
  expose type label prefix create access args w h text events connect opts defopts props nonvisual exopts
  use strict arg f
  type = oodAt(f, "TYPE")~upper
  label = oodAt(f, "LABEL")
  prefix = oodAt(f, "PREFIX")
  create = oodAt(f, "CREATE")
  access = oodAt(f, "ACCESS")
  args = oodAt(f, "ARGS")
  w = oodAt(f, "W")
  h = oodAt(f, "H")
  text = oodAt(f, "TEXT")
  events = oodAt(f, "EVENTS")~upper
  connect = oodAt(f, "CONNECT")
  opts = oodAt(f, "OPTS")~upper
  defopts = oodAt(f, "DEFOPTS")~upper
  props = oodAt(f, "PROPS")~lower
  nonvisual = (oodAt(f, "NONVISUAL") == "1")
  exopts = oodAt(f, "EXOPTS")~upper
  if label == "" then label = type


/* The catalogue: control kinds, form events, insertable actions and the names
   a UserDialog subclass already has.  All of it is data in the resources at
   the end of this file, read once. */
::class OodCatalog public inherit OodModule
::attribute kinds class        -- .Directory  TYPE -> OodKind
::attribute order class        -- .Array of TYPE, palette order
::attribute formEvents class   -- blank-separated
::attribute actions class      -- .Array of .Directory  TYPES LABEL CODE
::attribute reserved class     -- .Set of lower-case method names
::attribute evargs class       -- .Directory  "TYPE.EVENT" -> the event method's arguments
::method activate class
  expose kinds order formEvents actions reserved evargs
  kinds = .directory~new
  order = .array~new
  actions = .array~new
  reserved = .set~new
  evargs = .directory~new
  formEvents = ""
  do line over .resources~oodKinds
    if line~strip == "" then iterate
    if line~strip~left(2) == "--" then iterate
    f = oodFields(line)
    select
      when f["*"] == "kind" then do
        k = .OodKind~new(f)
        kinds[k~type] = k
        order~append(k~type)
      end
      when f["*"] == "form" then formEvents = f["EVENTS"]~upper
      when f["*"] == "action" then actions~append(f)
      when f["*"] == "evargs" then evargs[(f["TYPE"]"."f["EVENT"])~upper] = f["ARGS"]
      otherwise raise syntax 93.900 array(oodT("err.catalogue", line))
    end
  end
  do line over .resources~oodReserved
    parse var line word list
    if word \== "reserved" then iterate
    do n over list~makeArray(" ")
      if n \== "" then reserved~put(n~lower)
    end
  end
  -- the pseudo-control that carries the form's own events
  reserved~put("form")

-- the catalogue's lines, for the designer page to draw its palette
::method catalogText class
  return .resources~oodKinds~makeString("L", "0a"x)

::method kind class
  expose kinds
  use strict arg type
  k = kinds~at(type~upper)
  if k == .nil then raise syntax 93.900 array(oodT("err.type", type))
  return k

::method isReserved class
  expose reserved
  use strict arg name
  return reserved~hasIndex(name~lower)


/* One control of a design. */
::class OodControl public inherit OodModule
::attribute type
::attribute name
::attribute id
::attribute x
::attribute y
::attribute w
::attribute h
::attribute props            -- .Directory  lower-case property -> value
::method init
  expose type name id x y w h props
  use strict arg type, name, id, x, y, w, h
  props = .directory~new
::method kind
  expose type
  return .OodCatalog~kind(type)
::method prop
  expose props
  use strict arg key
  v = props~at(key~lower)
  if v == .nil then return ""
  return v
::method setProp
  expose props
  use strict arg key, value
  props[key~lower] = value
-- the id ooDialog sees: OK and Cancel buttons take IDOK and IDCANCEL
::method dlgId
  expose id
  role = self~prop("role")~upper
  if role == "OK" then return "IDOK"
  if role == "CANCEL" then return "IDCANCEL"
  return id
::method opts
  expose type
  o = self~prop("opts")~upper
  if type == "PUSHBUTTON" then do
    if self~prop("role")~upper == "OK" then do
      if wordpos("DEFAULT", o) = 0 then o = o "DEFAULT"
    end
  end
  if type == "RADIOBUTTON" then do
    if self~prop("groupstart") == "1" then do
      if wordpos("GROUP", o) = 0 then o = o "GROUP"
    end
  end
  return o~space


/* A design: the form, its controls, its variables and its event code. */
::class OodDesign public inherit OodModule
::attribute form            -- .Directory  NAME TITLE W H STYLE, and its binding: OBJECT OBJECTFILE OBJECTKEY DATABASES
::attribute controls        -- .Array of OodControl, in creation (tab) order
::attribute vars            -- .Array of .Directory  NAME VALUE
::attribute events          -- .Directory  "CTL.EVENT" -> .Directory CONTROL EVENT THREAD CODE
::attribute methods         -- .Array of .Directory  NAME CODE: the form's own methods
::attribute requires        -- .Array of file names: the form's ::requires besides ooDialog.cls
::attribute shared          -- .Array of .Directory  NAME VALUE: the entries of self~sharedScope
::attribute languages       -- .Array of language codes, the base first; empty: texts written as literals
::attribute userStrings     -- .Array of .Directory  KEY TEXT: strings for event code, base language
::attribute translations    -- .Directory  LANG -> .Directory KEY(upper) -> .Array(key, text)

::method init
  expose form controls vars events methods requires shared languages userStrings translations
  use strict arg name = "MyDialog"
  languages = .array~new
  userStrings = .array~new
  translations = .directory~new
  form = .directory~new
  form["NAME"] = name
  form["TITLE"] = "My Dialog"
  form["W"] = 200
  form["H"] = 120
  form["STYLE"] = "CENTER"
  form["OBJECT"] = ""; form["OBJECTFILE"] = ""; form["OBJECTKEY"] = ""; form["DATABASES"] = ""
  controls = .array~new
  vars = .array~new
  events = .directory~new
  methods = .array~new
  requires = .array~new
  shared = .array~new
  self~checkName(name, .nil)

/* ---- names --------------------------------------------------------------- */

-- A name must be a Rexx symbol, unused, and not a method UserDialog already
-- has: it becomes an accessor method, a data attribute and part of event
-- method names.  forCtl is the control being renamed (.nil for a new name).
::method checkName
  expose controls vars methods
  use strict arg name, forCtl
  if name == "" then raise syntax 93.900 array(oodT("err.name.needed"))
  if name~left(1)~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_") > 0 then
    raise syntax 93.900 array(oodT("err.name.start", name))
  if name~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789") > 0 then
    raise syntax 93.900 array(oodT("err.name.chars", name))
  if .OodCatalog~isReserved(name) then
    raise syntax 93.900 array(oodT("err.name.reserved", name))
  if .OodCatalog~isReserved(name"_data") then
    raise syntax 93.900 array(oodT("err.name.reservedData", name))
  do c over controls
    if c \== forCtl then do
      if c~name~caselessEquals(name) then raise syntax 93.900 array(oodT("err.name.inUse", name))
      if (c~name"_data")~caselessEquals(name) then raise syntax 93.900 array(oodT("err.name.inUseBy", name, c~name))
      if (c~name"_enabled")~caselessEquals(name) then raise syntax 93.900 array(oodT("err.name.inUseBy", name, c~name))
    end
  end
  do v over vars
    if v["NAME"]~caselessEquals(name) then raise syntax 93.900 array(oodT("err.name.variable", name))
  end
  do m over methods
    if m["NAME"]~caselessEquals(name) then raise syntax 93.900 array(oodT("err.name.method", name))
  end
  if name~caselessEquals("sharedScope") then raise syntax 93.900 array(oodT("err.name.sharedScope"))
  if name~left(3)~caselessEquals("on_") then raise syntax 93.900 array(oodT("err.name.on"))
  if name~left(6)~caselessEquals("timer_") then raise syntax 93.900 array(oodT("err.name.timer"))
  if name~left(3)~caselessEquals("nls") then raise syntax 93.900 array(oodT("err.name.nls"))
  return 0

::method newName
  expose controls
  use strict arg prefix
  n = 1
  do forever
    name = prefix || n
    clash = .false
    do c over controls
      if c~name~caselessEquals(name) then clash = .true
    end
    if \clash then return name
    n = n + 1
  end

::method control
  expose controls
  use strict arg name
  do c over controls
    if c~name~caselessEquals(name) then return c
  end
  raise syntax 93.900 array(oodT("err.noControl", name))

::method controlNames
  expose controls
  names = .array~new
  do c over controls
    names~append(c~name)
  end
  return names~makeString("L", " ")

/* ---- editing ------------------------------------------------------------- */

::method addControl
  expose controls
  use strict arg type, x, y
  k = .OodCatalog~kind(type)
  name = self~newName(k~prefix)
  id = 100
  do c over controls
    if c~id >= id then id = c~id + 1
  end
  w = k~w
  h = k~h
  if k~nonvisual then do
    w = 0
    h = 0
  end
  c = .OodControl~new(k~type, name, id, self~toUnit(x), self~toUnit(y), w, h)
  do p over k~props~makeArray(" ")
    c~setProp(p, "")
  end
  if k~props~wordpos("text") > 0 then c~setProp("text", k~text)
  if k~props~wordpos("opts") > 0 then c~setProp("opts", k~defopts)
  if k~props~wordpos("checked") > 0 then c~setProp("checked", "0")
  if k~type == "PUSHBUTTON" then c~setProp("role", "")
  if k~type == "RADIOBUTTON" then do
    first = "1"
    do o over controls
      if o~type == "RADIOBUTTON" then first = "0"
    end
    c~setProp("groupstart", first)
  end
  if k~type == "PROGRESSBAR" then do
    c~setProp("min", 0)
    c~setProp("max", 100)
    c~setProp("pos", 0)
  end
  if k~type == "TIMER" then do
    c~setProp("interval", 1)
    c~setProp("enabled", 1)
  end
  if k~type == "LISTVIEW" then do
    c~setProp("columns", "Name:60|Value:50")
    c~setProp("exstyles", "FULLROWSELECT")
  end
  if k~type == "TAB" then c~setProp("tabs", "Page 1|Page 2")
  if k~type == "TREEVIEW" then c~setProp("nodes", "Top|.Child|.Child")
  if k~type == "TRACKBAR" then do
    c~setProp("min", 0)
    c~setProp("max", 100)
    c~setProp("pos", 0)
  end
  if k~type == "MENUITEM" then do
    popup = "&File"
    do o over controls
      if o~type == "MENUITEM" then popup = o~prop("popup")
    end
    c~setProp("popup", popup)
    c~setProp("text", "&" || name)
    c~setProp("grayed", "0")
  end
  controls~append(c)
  return name

::method removeControl
  expose controls events
  use strict arg name
  c = self~control(name)
  controls~removeItem(c)
  -- controls on its pages stay, on no page
  do o over controls
    if o~prop("page")~caselessPos(c~name":") = 1 then o~setProp("page", "")
  end
  gone = .array~new
  do key over events~allIndexes
    if events[key]["CONTROL"]~caselessEquals(c~name) then gone~append(key)
  end
  do key over gone
    events~remove(key)
  end
  self~dropStrings(c~name".")
  return 0

-- Geometry is in dialog units, whole numbers, inside the form.
::method toUnit
  use strict arg v
  if \datatype(v, "N") then raise syntax 93.900 array(oodT("err.number", v))
  v = format(v, , 0)
  if v < 0 then v = 0
  return v

::method setGeometry
  expose form
  use strict arg name, x, y, w, h
  c = self~control(name)
  x = self~toUnit(x)
  y = self~toUnit(y)
  w = self~toUnit(w)
  h = self~toUnit(h)
  if c~kind~nonvisual then return 0
  if w < 4 then w = 4
  if h < 4 then h = 4
  if x + w > form["W"] then x = max(0, form["W"] - w)
  if y + h > form["H"] then y = max(0, form["H"] - h)
  c~x = x
  c~y = y
  c~w = w
  c~h = h
  return 0

::method moveControl
  use strict arg name, x, y
  c = self~control(name)
  return self~setGeometry(name, x, y, c~w, c~h)

-- The property names of a control, its kind's props plus the geometry.
::method propNames
  use strict arg name
  if name~caselessEquals("form") then return "name title w h object objectfile objectkey databases"
  c = self~control(name)
  if c~kind~nonvisual then return ("name" c~kind~props)~space
  names = "name x y w h" c~kind~props
  if self~onPageAllowed(c) then names = names "page"
  return names~space

-- A visual control other than a tab strip can sit on a page of a tab strip:
-- the program shows it only while that tab is selected.
::method onPageAllowed
  expose controls
  use strict arg c
  if c~kind~nonvisual | c~type == "TAB" then return .false
  do o over controls
    if o~type == "TAB" then return .true
  end
  return .false

-- "tabName:n" -> the pages of tab strip tabName (1 = its first tab)
::method checkPage
  expose controls
  use strict arg value
  if value == "" then return ""
  parse var value tabName ":" n
  t = .nil
  do o over controls
    if o~name~caselessEquals(tabName) then t = o
  end
  if t == .nil then raise syntax 93.900 array(oodT("err.page.noTab", tabName))
  if t~type \== "TAB" then raise syntax 93.900 array(oodT("err.page.notTab", tabName))
  count = t~prop("tabs")~makeArray("|")~items
  if \datatype(n, "W") then raise syntax 93.900 array(oodT("err.page.number"))
  if n < 1 | n > count then raise syntax 93.900 array(oodT("err.page.range", tabName, count))
  return t~name":"format(n)

::method getProp
  expose form
  use strict arg name, key
  key = key~lower
  if name~caselessEquals("form") then return oodAt(form, key~upper)
  c = self~control(name)
  select
    when key == "name" then return c~name
    when key == "type" then return c~type
    when key == "id" then return c~id
    when key == "x" then return c~x
    when key == "y" then return c~y
    when key == "w" then return c~w
    when key == "h" then return c~h
    otherwise return c~prop(key)
  end

::method setProp
  expose form controls
  use strict arg name, key, value
  key = key~lower
  if name~caselessEquals("form") then do
    select
      when key == "name" then do
        self~checkName(value, .nil)
        form["NAME"] = value
      end
      when key == "title" then form["TITLE"] = value
      -- the binding: the dialog edits one object of a mapped class
      -- (oorexx_mapped_objects): its class, the file it is in, the key it
      -- opens unless the program is given one, the databases ("ent=data/ent ...")
      when key == "object" then do
        value = value~strip
        if value \== "", \oodIsSymbol(value) then raise syntax 93.900 array(oodT("err.bind.class", value))
        form["OBJECT"] = value
      end
      when key == "objectfile" then form["OBJECTFILE"] = value~strip
      when key == "objectkey" then form["OBJECTKEY"] = value~strip
      when key == "databases" then do
        do d over value~space~makeArray(" ")
          parse var d sch "=" path
          if sch == "" | path == "" | \oodIsSymbol(sch) then raise syntax 93.900 array(oodT("err.bind.databases", d))
        end
        form["DATABASES"] = value~space
      end
      when key == "w" | key == "h" then do
        value = self~toUnit(value)
        if value < 20 then value = 20
        form[key~upper] = value
      end
      otherwise raise syntax 93.900 array(oodT("err.form.prop", key))
    end
    return value
  end
  c = self~control(name)
  select
    when key == "name" then do
      self~renameControl(c, value)
    end
    when key == "x" then self~setGeometry(name, value, c~y, c~w, c~h)
    when key == "y" then self~setGeometry(name, c~x, value, c~w, c~h)
    when key == "w" then self~setGeometry(name, c~x, c~y, value, c~h)
    when key == "h" then self~setGeometry(name, c~x, c~y, c~w, value)
    when key == "page" then do
      if \self~onPageAllowed(c) then raise syntax 93.900 array(oodT("err.page.not", c~name))
      c~setProp(key, self~checkPage(value))
    end
    when c~kind~props~wordpos(key) = 0 then
      raise syntax 93.900 array(oodT("err.prop", c~type, key))
    when key == "bind" then c~setProp(key, self~checkBind(c, value))
    when key == "opts" then do
      allowed = c~kind~opts
      value = value~upper~space
      do o over value~makeArray(" ")
        if wordpos(o, allowed) = 0 then
          raise syntax 93.900 array(oodT("err.style", o, c~type, allowed))
      end
      c~setProp(key, value)
    end
    when key == "exstyles" then do
      allowed = c~kind~exopts
      value = value~upper~space
      do o over value~makeArray(" ")
        if wordpos(o, allowed) = 0 then
          raise syntax 93.900 array(oodT("err.exstyle", o, c~type, allowed))
      end
      c~setProp(key, value)
    end
    when key == "columns" then do
      do col over value~makeArray("|")
        parse var col title ":" width
        if title~strip == "" then raise syntax 93.900 array(oodT("err.columns"))
        if width \== "" then do
          if \datatype(width, "W") then raise syntax 93.900 array(oodT("err.columnWidth", title))
        end
      end
      c~setProp(key, value)
    end
    when key == "tabs" then do
      if value == "" then raise syntax 93.900 array(oodT("err.tabs"))
      c~setProp(key, value)
    end
    when key == "popup" then do
      if value~strip == "" then raise syntax 93.900 array(oodT("err.popup"))
      c~setProp(key, value)
    end
    when key == "checked" | key == "enabled" | key == "groupstart" | key == "grayed" then do
      if value \== "0" & value \== "1" then raise syntax 93.900 array(oodT("err.bool", key))
      c~setProp(key, value)
    end
    when key == "role" then do
      value = value~upper
      if wordpos(value, "OK CANCEL") = 0 & value \== "" then
        raise syntax 93.900 array(oodT("err.role"))
      if value \== "" then do
        if self~eventSummary(c~name)~pos(":1") > 0 then
          raise syntax 93.900 array(oodT("err.role.code", c~name, value))
        do o over controls
          if o \== c then do
            if o~prop("role")~upper == value then raise syntax 93.900 array(oodT("err.role.taken", o~name, value))
          end
        end
      end
      c~setProp(key, value)
    end
    when wordpos(key, "min max pos") > 0 then do
      if \datatype(value, "W") then raise syntax 93.900 array(oodT("err.whole", key))
      c~setProp(key, value)
    end
    when key == "interval" then do
      if \datatype(value, "N") then raise syntax 93.900 array(oodT("err.interval"))
      if value <= 0 then raise syntax 93.900 array(oodT("err.interval.positive"))
      c~setProp(key, value)
    end
    when key == "nodes" then do
      do node over value~makeArray("|")
        depth = node~verify(".") - 1
        if depth < 0 then raise syntax 93.900 array(oodT("err.node", node))
        if node~substr(depth + 1)~strip == "" then raise syntax 93.900 array(oodT("err.node", node))
      end
      if value~left(1) == "." then raise syntax 93.900 array(oodT("err.node.first"))
      c~setProp(key, value)
    end
    when key == "text" | key == "items" | key == "rows" then do
      if value~pos("0a"x) > 0 | value~pos("0d"x) > 0 then raise syntax 93.900 array(oodT("err.oneLine", key))
      c~setProp(key, value)
    end
    otherwise c~setProp(key, value)
  end
  return self~getProp(c~name, key)

-- Renaming moves the control's events to the new name and rewrites
-- self~old in all the event and method code, where it is a whole symbol.
::method renameControl
  expose events methods controls translations
  use strict arg c, newName
  old = c~name
  if old == newName then return 0
  self~checkName(newName, c)
  moved = .directory~new
  do key over events~allIndexes
    e = events[key]
    if e["CONTROL"]~caselessEquals(old) then do
      e["CONTROL"] = newName
      moved[(newName"."e["EVENT"])~upper] = e
      events~remove(key)
    end
  end
  do key over moved~allIndexes
    events[key] = moved[key]
  end
  do key over events~allIndexes
    e = events[key]
    e["CODE"] = oodRenameRef(e["CODE"], old, newName)
  end
  do m over methods
    m["CODE"] = oodRenameRef(m["CODE"], old, newName)
  end
  do o over controls
    p = o~prop("page")
    if p~caselessPos(old":") = 1 then o~setProp("page", newName":"p~substr(length(old) + 2))
  end
  -- its strings' keys follow it, in every language
  do lang over translations~allIndexes
    t = translations[lang]
    do k over t~allIndexes
      if k~left(length(old) + 1) == (old".")~upper then do
        entry = t[k]
        t~remove(k)
        newKey = newName || entry[1]~substr(length(old) + 1)
        t[newKey~upper] = .array~of(newKey, entry[2])
      end
    end
  end
  c~name = newName
  return 0

/* ---- variables ----------------------------------------------------------- */

-- A form variable is an ::attribute of the dialog, so every event method,
-- on whatever thread, sees the same value.  value is a Rexx expression.
::method setVar
  expose vars
  use strict arg name, value
  do v over vars
    if v["NAME"]~caselessEquals(name) then do
      v["VALUE"] = value
      return 0
    end
  end
  self~checkName(name, .nil)
  v = .directory~new
  v["NAME"] = name
  v["VALUE"] = value
  vars~append(v)
  return 0

::method removeVar
  expose vars
  use strict arg name
  do v over vars
    if v["NAME"]~caselessEquals(name) then do
      vars~removeItem(v)
      return 0
    end
  end
  return 0

/* ---- the form's own methods (DrDialog's global procedures) --------------- */

-- A method of the dialog any event can call: self~digit(7).  The code is the
-- whole body, use arg included.  Empty code removes the method.
::method setMethod
  expose methods
  use strict arg name, code
  code = oodCleanCode(code)
  do m over methods
    if m["NAME"]~caselessEquals(name) then do
      if code == "" then methods~removeItem(m)
      else m["CODE"] = code
      return 0
    end
  end
  if code == "" then return 0
  self~checkName(name, .nil)
  m = .directory~new
  m["NAME"] = name
  m["CODE"] = code
  methods~append(m)
  return 0

::method getMethod
  expose methods
  use strict arg name
  do m over methods
    if m["NAME"]~caselessEquals(name) then return m["CODE"]
  end
  return ""

::method methodNames
  expose methods
  names = .array~new
  do m over methods
    names~append(m["NAME"])
  end
  return names~makeString("L", " ")

::method varNames
  expose vars
  out = .array~new
  do v over vars
    out~append(v["NAME"] || "09"x || v["VALUE"])
  end
  return out~makeString("L", "0a"x)

/* ---- libraries and the shared scope -------------------------------------- */

-- A ::requires of the program besides ooDialog.cls: a library installed from
-- a provider (lib/alchemy/LoggingCore.cls) or any file the program can find.
::method addRequire
  expose requires
  use strict arg file
  file = file~strip~strip("B", '"')~strip("B", "'")
  if file == "" then raise syntax 93.900 array(oodT("err.require.which"))
  if file~caselessEquals("ooDialog.cls") then raise syntax 93.900 array(oodT("err.require.ood"))
  do r over requires
    if r~caselessEquals(file) then return 0
  end
  requires~append(file)
  return 0
::method removeRequire
  expose requires
  use strict arg file
  do i = 1 to requires~items
    if requires[i]~caselessEquals(file) then do
      requires~delete(i)
      return 0
    end
  end
  return 0
::method requireNames
  expose requires
  return requires~makeString("L", "0a"x)

-- An entry of the form's shared scope: self~sharedScope[name], made once in
-- init from a Rexx expression.  Every event method can reach it with
-- "expose sharedScope", on whatever thread it runs.
::method setShared
  expose shared
  use strict arg name, value
  if name == "" then raise syntax 93.900 array(oodT("err.name.needed"))
  if value~strip == "" then raise syntax 93.900 array(oodT("err.shared.value"))
  if value~pos("0a"x) > 0 then raise syntax 93.900 array(oodT("err.shared.oneLine"))
  do e over shared
    if e["NAME"] == name then do
      e["VALUE"] = value
      return 0
    end
  end
  e = .directory~new
  e["NAME"] = name
  e["VALUE"] = value
  shared~append(e)
  return 0
::method removeShared
  expose shared
  use strict arg name
  do i = 1 to shared~items
    if shared[i]["NAME"] == name then do
      shared~delete(i)
      return 0
    end
  end
  return 0
::method sharedNames
  expose shared
  out = .array~new
  do e over shared
    out~append(e["NAME"] || "09"x || e["VALUE"])
  end
  return out~makeString("L", "0a"x)

/* ---- events -------------------------------------------------------------- */

-- An OK or Cancel button has no events of its own: ooDialog's ok and cancel
-- answer it, so its code goes in the form's OK or CANCEL event.
::method eventNames
  use strict arg name
  if name~caselessEquals("form") then return .OodCatalog~formEvents
  c = self~control(name)
  if c~prop("role") \== "" then return ""
  return c~kind~events

::method eventKey
  use strict arg name, event
  event = event~upper
  if wordpos(event, self~eventNames(name)) = 0 then
    raise syntax 93.900 array(oodT("err.event", name, event))
  return (name"."event)~upper

-- the arguments ooDialog passes the event's method, "" when none are useful
::method eventArgs
  use strict arg name, event
  if name~caselessEquals("form") then return ""
  a = .OodCatalog~evargs~at((self~control(name)~type"."event)~upper)
  if a == .nil then return ""
  return a

::method methodName
  use strict arg name, event
  if name~caselessEquals("form") then do
    if event~upper == "OK" then return "ok"
    if event~upper == "CANCEL" then return "cancel"
  end
  return "on_"name"_"event~lower

-- Code is kept as typed, less trailing blanks and blank trailing lines.
-- A line may not start with "::": it would end the method.
::method setEventCode
  expose events
  use strict arg name, event, code
  key = self~eventKey(name, event)
  if \name~caselessEquals("form") then name = self~control(name)~name
  code = oodCleanCode(code)
  if code == "" then do
    events~remove(key)
    return 0
  end
  e = events~at(key)
  if e == .nil then do
    e = .directory~new
    e["CONTROL"] = name
    e["EVENT"] = event~upper
    e["THREAD"] = "ui"
    if self~isTimer(name) then e["THREAD"] = "timer"
    events[key] = e
  end
  e["CODE"] = code
  return 0

-- All the code the user wrote, in the order of the form: the form's events,
-- each control's (in its catalogue order), then the form's methods.  Each
-- piece starts with a heading line: "@@" TAB kind (EVENT or METHOD) TAB
-- control TAB event (or method name) TAB generated method TAB thread; the
-- code follows as it is.  The page shows it to read straight through.
::method allCode
  expose events methods controls
  out = .array~new
  names = .array~of("form")
  do c over controls
    names~append(c~name)
  end
  do n over names
    do ev over self~eventNames(n)~makeArray(" ")
      e = events~at(self~eventKey(n, ev))
      if e == .nil then iterate
      out~append("@@" || "09"x || "EVENT" || "09"x || n || "09"x || ev || "09"x || self~methodName(n, ev) || "09"x || e["THREAD"])
      out~append(e["CODE"])
    end
  end
  do m over methods
    out~append("@@" || "09"x || "METHOD" || "09"x || "form" || "09"x || m["NAME"] || "09"x || m["NAME"] || "09"x || "")
    out~append(m["CODE"])
  end
  return out~makeString("L", "0a"x)

-- The first ooRexx revision with CATCH and FINALLY (RFE #31).
::method catchRevision class
  return 13514

-- Does any code here use CATCH or FINALLY?
::method usesCatch
  return self~catchWords \== ""

-- Which of CATCH and FINALLY the code uses ("", "CATCH", "FINALLY" or both):
-- a clause starting with either word, not an assignment to a variable of
-- that name (catch = 1) nor a label.  Read from the text, so the model needs
-- no parser: the graph shows the parse itself.
::method catchWords
  expose events methods
  found = ""
  pieces = .array~new
  do e over events~allItems
    pieces~append(e["CODE"])
  end
  do m over methods
    pieces~append(m["CODE"])
  end
  do code over pieces
    do line over code~changeStr("0d"x, "")~makeArray("0a"x)
      do clause over line~makeArray(";")
        c = clause~strip("B", " " || "09"x)
        do kw over .array~of("CATCH", "FINALLY")
          n = kw~length
          if c~left(n)~upper \== kw then iterate
          if c~length > n, verify(c~substr(n + 1, 1), " " || "09"x) > 0 then iterate   -- catcher, finally2
          after = c~substr(n + 1)~strip("B", " " || "09"x)
          if after~left(1) == "=" | after~left(1) == ":" then iterate                 -- catch = 1
          if wordpos(kw, found) = 0 then found = (found kw)~strip
        end
      end
    end
  end
  return found

-- "" when the code may run here; otherwise why not.  CATCH needs ooRexx
-- r13514 or later (an older one reads it as a command and runs every
-- clause).  FINALLY is in no ooRexx yet (2026-11-15: trunk has CATCH since
-- r13514, not FINALLY): the Rexx Parser knows it, so the graph draws it,
-- but nothing can run it.
::method catchRefusal
  w = self~catchWords
  if wordpos("FINALLY", w) > 0 then return oodT("err.finally.runtime")
  if w == "" then return ""
  if .RexxInfo~revision >= .OodDesign~catchRevision then return ""
  return oodT("err.catch.runtime", .OodDesign~catchRevision, .RexxInfo~revision)

::method getEventCode
  expose events
  use strict arg name, event
  e = events~at(self~eventKey(name, event))
  if e == .nil then return ""
  return e["CODE"]

::method isTimer
  use strict arg name
  if name~caselessEquals("form") then return .false
  return self~control(name)~type == "TIMER"

-- Every method the designer writes is UNGUARDED, as the ooDialog guide
-- (4.3.2) asks of event handlers and as upstream's own execute, initDialog,
-- ok and cancel are: on Windows the dialog's thread calls them while
-- execute waits.  The form's variables are ::attributes, guarded, so each
-- read or write of one is whole.
-- ui: runs on the dialog's thread, as on Windows.  background: the method
-- replies at once and carries on on its own thread, unguarded, so the
-- dialog keeps answering while it runs.  Timers always run on their own.
::method setEventThread
  expose events
  use strict arg name, event, thread
  thread = thread~lower
  e = events~at(self~eventKey(name, event))
  if e == .nil then raise syntax 93.900 array(oodT("err.thread.noCode"))
  if self~isTimer(name) then return "timer"
  if name~caselessEquals("form") then do
    if thread \== "ui" then raise syntax 93.900 array(oodT("err.thread.form"))
  end
  if wordpos(thread, "ui background") = 0 then raise syntax 93.900 array(oodT("err.thread"))
  e["THREAD"] = thread
  return thread

::method getEventThread
  expose events
  use strict arg name, event
  e = events~at(self~eventKey(name, event))
  if e == .nil then return ""
  return e["THREAD"]

-- "EVENT:mark EVENT:mark ...", mark 1 where the event has code
::method eventSummary
  expose events
  use strict arg name
  out = ""
  do ev over self~eventNames(name)~makeArray(" ")
    if ev == "" then iterate
    has = 0
    if events~hasIndex((name"."ev)~upper) then has = 1
    out = out ev":"has
  end
  return out~strip

/* ---- code insertion (VisPro's drag a control onto the code) -------------- */

-- "label<tab>code" lines of the actions for a control, %n replaced by its name
::method actionsFor
  use strict arg name
  if name~caselessEquals("form") then type = "FORM"
  else type = self~control(name)~type
  out = .array~new
  do a over .OodCatalog~actions
    types = a["TYPES"]~upper
    take = .false
    if wordpos(type, types) > 0 then take = .true
    if types == "*" then do
      if type \== "FORM" then do
        if \.OodCatalog~kind(type)~nonvisual then take = .true
      end
    end
    if take then out~append(a["LABEL"] || "09"x || a["CODE"]~changeStr("%n", name))
  end
  return out~makeString("L", "0a"x)

/* ---- languages: the texts as ::RESOURCE string tables ---------------------

   ::RESOURCE is ooRexx's place for text that is not code, and its first use
   is text in more than one language.  With languages set, the program keeps
   every text the user sees in a ::RESOURCE strings.<lang> per language,
   key = text, and asks self~nls(key) for it; the base language's table is
   written from the design itself.  Keys: form.title, <control>.text (not an
   entry field's: that is data), .items, .tabs, .columns, and <item>.popup
   for the first item of each menu; event code's own strings have keys of
   their own (self~nls("key", arg1, ...): %1, %2, ... in the text take the
   arguments).  A key with no text in a language takes the base language's.
   The language: the program's argument (rexx Calc.rex de), else the first
   two letters of LANG, else the base. */

-- The translatable properties of a control: prop names.
::method nlsProps
  use strict arg c
  select
    when c~type == "EDIT" then return ""
    when c~type == "MENUITEM" then do
      -- the menu's (popup's) name: on its first item; a separator has no text
      p = "text"
      if c~prop("text") == "-" then p = ""
      if self~firstInPopup(c) then p = "popup" p
      return p~strip
    end
    otherwise nop
  end
  out = ""
  do p over "text items tabs columns"~makeArray(" ")
    if c~kind~props~wordpos(p) > 0 then out = out p
  end
  return out~strip

::method firstInPopup
  expose controls
  use strict arg c
  do o over controls
    if o~type == "MENUITEM", o~prop("popup") == c~prop("popup") then return o == c
  end
  return .false

::method isNls
  expose languages
  return languages~items > 0

::method baseLanguage
  expose languages
  if languages~items = 0 then return ""
  return languages[1]

-- languages: "en de fr", the base first.  Turning them on keeps every text;
-- a language taken out loses its table; "" turns language support off.
::method setLanguages
  expose languages translations
  use strict arg list
  new = .array~new
  do code over list~space~makeArray(" ")
    code = .OodDesign~checkLanguage(code)
    do n over new
      if n == code then raise syntax 93.900 array(oodT("err.lang.twice", code))
    end
    new~append(code)
  end
  if languages~items > 0, new~items > 0 then do
    if new[1] \== languages[1] then
      raise syntax 93.900 array(oodT("err.lang.base", languages[1]))
  end
  do lang over translations~allIndexes
    keep = .false
    do n over new
      if n == lang then keep = .true
    end
    if \keep then translations~remove(lang)
  end
  do n over new
    if \translations~hasIndex(n), n \== new[1] then translations[n] = .directory~new
  end
  languages = new
  return languages~makeString("L", " ")

::method addLanguage
  expose languages
  use strict arg code
  if languages~items = 0 then raise syntax 93.900 array(oodT("err.lang.baseFirst"))
  return self~setLanguages(languages~makeString("L", " ") code)

-- a language code: two or three letters, perhaps _ and a region (de, de_AT, pt_BR)
::method checkLanguage class
  use strict arg code
  parse var code lang "_" region
  if lang~length < 2 | lang~length > 3 | \datatype(lang, "M") then
    raise syntax 93.900 array(oodT("err.lang.code"))
  if code~pos("_") > 0 then do
    if region~length < 2 | region~length > 3 | \datatype(region, "A") then
      raise syntax 93.900 array(oodT("err.lang.code"))
    return lang~lower"_"region~upper
  end
  return lang~lower

-- every key, in order: the form's, each control's, then the event code's
::method nlsKeys
  expose controls userStrings
  keys = .array~of("form.title")
  do c over controls
    do p over self~nlsProps(c)~makeArray(" ")
      if p \== "" then keys~append(c~name"."p)
    end
  end
  do u over userStrings
    keys~append(u["KEY"])
  end
  return keys

-- key -> .array(control or "form" or .nil for a user key, prop)
::method keyOwner
  use strict arg key
  parse var key owner "." prop
  if key~caselessEquals("form.title") then return .array~of("form", "title")
  do k over self~nlsKeys
    if k~caselessEquals(key) then do
      if self~userString(key) \== .nil then return .array~of(.nil, "")
      return .array~of(self~control(owner)~name, prop~lower)
    end
  end
  raise syntax 93.900 array(oodT("err.string.none", key))

::method userString
  expose userStrings
  use strict arg key
  do u over userStrings
    if u["KEY"]~caselessEquals(key) then return u
  end
  return .nil

-- the base language's text of a key
::method baseText
  use strict arg key
  o = self~keyOwner(key)
  if o[1] == .nil then return self~userString(key)["TEXT"]
  return self~getProp(o[1], o[2])

-- a key's text in a language; "" when it has none there (the base's is used)
::method stringIn
  expose translations
  use strict arg lang, key
  if lang == self~baseLanguage then return self~baseText(key)
  t = translations[lang]
  if t == .nil then raise syntax 93.900 array(oodT("err.lang.none", lang))
  e = t[key~upper]
  if e == .nil then return ""
  return e[2]

-- A key's text in a language.  The base language's texts are the design's:
-- setting one sets the property (or the event string).  "" in another
-- language removes the text there.
::method setString
  expose translations
  use strict arg lang, key, text
  if text~pos("0a"x) > 0 | text~pos("0d"x) > 0 then raise syntax 93.900 array(oodT("err.string.oneLine"))
  o = self~keyOwner(key)
  if lang == self~baseLanguage then do
    if o[1] == .nil then do
      if text == "" then raise syntax 93.900 array(oodT("err.string.baseNeeded"))
      u = self~userString(key)
      u["TEXT"] = text
    end
    else if o[2] == "popup" then do
      was = self~getProp(o[1], "popup")
      do c over self~controls
        if c~type == "MENUITEM", c~prop("popup") == was then self~setProp(c~name, "popup", text)
      end
    end
    else self~setProp(o[1], o[2], text)
    return text
  end
  t = translations[lang]
  if t == .nil then raise syntax 93.900 array(oodT("err.lang.none", lang))
  realKey = self~nlsKeys~at(self~keyIndex(key))
  if text == "" then t~remove(key~upper)
  else t[key~upper] = .array~of(realKey, text)
  return text

::method keyIndex
  use strict arg key
  keys = self~nlsKeys
  do i = 1 to keys~items
    if keys[i]~caselessEquals(key) then return i
  end
  raise syntax 93.900 array(oodT("err.string.none", key))

-- a string for event code: self~nls(key) in any method
::method addString
  expose userStrings
  use strict arg key, text
  if \self~isNls then raise syntax 93.900 array(oodT("err.lang.first"))
  if key == "" | key~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.") > 0 then
    raise syntax 93.900 array(oodT("err.key.chars"))
  do k over self~nlsKeys
    if k~caselessEquals(key) then raise syntax 93.900 array(oodT("err.key.inUse", key))
  end
  if key~pos(".") > 0 then do
    parse var key owner "."
    taken = owner~caselessEquals("form")
    do c over self~controls
      if c~name~caselessEquals(owner) then taken = .true
    end
    if taken then raise syntax 93.900 array(oodT("err.key.owned", owner))
  end
  if text == "" then raise syntax 93.900 array(oodT("err.string.text"))
  d = .directory~new
  d["KEY"] = key
  d["TEXT"] = text
  userStrings~append(d)
  return key

::method removeString
  expose userStrings
  use strict arg key
  u = self~userString(key)
  if u == .nil then raise syntax 93.900 array(oodT("err.string.remove"))
  userStrings~removeItem(u)
  self~dropStrings(key, .true)
  return 0

-- translations of a key, or of every key starting with prefix
::method dropStrings
  expose translations
  use strict arg prefix, whole = .false
  do lang over translations~allIndexes
    t = translations[lang]
    do k over t~allIndexes
      if whole then do
        if k == prefix~upper then t~remove(k)
      end
      else if k~left(length(prefix)) == prefix~upper then t~remove(k)
    end
  end
  return 0

-- the string table for the editor: a line of languages, then per key
-- key TAB base TAB lang2 ... (TAB separated; "" where there is none)
::method stringLines
  expose languages
  out = .array~new
  out~append("languages" || "09"x || languages~makeString("L", "09"x))
  do key over self~nlsKeys
    line = key
    do lang over languages
      line = line || "09"x || self~stringIn(lang, key)
    end
    o = self~keyOwner(key)
    if o[1] == .nil then line = line || "09"x || "event"
    else line = line || "09"x || o[1]
    out~append(line)
  end
  return out~makeString("L", "0a"x)

-- every key's text in a language, the base's where it has none: for drawing
-- the design in that language
::method textsIn
  use strict arg lang
  out = .array~new
  do key over self~nlsKeys
    t = ""
    if lang \== self~baseLanguage then t = self~stringIn(lang, key)
    if t == "" then t = self~baseText(key)
    out~append(key || "09"x || t)
  end
  return out~makeString("L", "0a"x)

-- A language as a file for a translator: key = text, each with the base
-- text above it; a key not yet translated has nothing after its =.
::method exportLanguage
  expose form
  use strict arg lang
  base = self~baseLanguage
  out = .array~new
  out~append("--" form["NAME"]": strings in" lang "(base" base")")
  out~append("-- Put the" lang "text after each =.  & marks the key letter (&File).")
  out~append("-- %1, %2 ... stand for values the program puts in.  A key left empty uses the" base "text.")
  do key over self~nlsKeys
    out~append("")
    out~append("--" base":" self~baseText(key))
    t = ""
    if lang \== base then t = self~stringIn(lang, key)
    else t = self~baseText(key)
    if t == "" then out~append(key "=")
    else out~append(key "=" t)
  end
  return out~makeString("L", "0a"x) || "0a"x

-- Read a translator's file back.  Answers what it did, one line each:
-- the count set, and any key the design does not have.
::method importLanguage
  use strict arg lang, text
  if lang == self~baseLanguage then raise syntax 93.900 array(oodT("err.lang.importBase"))
  n = 0
  unknown = .array~new
  do l over text~changeStr("0d0a"x, "0a"x)~makeArray("0a"x)
    parse var l key "=" t
    key = key~strip
    if key == "" | key~left(2) == "--" | l~pos("=") = 0 then iterate
    t = t~strip("L")
    if self~keyIndexOrZero(key) = 0 then do
      unknown~append(key)
      iterate
    end
    self~setString(lang, key, t)
    if t \== "" then n = n + 1
  end
  out = .array~of(n "strings set in" lang)
  do k over unknown
    out~append("not in the design:" k)
  end
  return out~makeString("L", "0a"x)

::method keyIndexOrZero
  use strict arg key
  keys = self~nlsKeys
  do i = 1 to keys~items
    if keys[i]~caselessEquals(key) then return i
  end
  return 0

-- one ::RESOURCE strings.<lang>: the base language's from the design, the
-- others' from their translations, in key order
::method resourceTable
  use strict arg lang
  out = .array~new
  do key over self~nlsKeys
    -- the base table has every key, an empty text too; another table only
    -- the texts it has
    if lang == self~baseLanguage then out~append((key "=" self~baseText(key))~strip("T"))
    else do
      t = self~stringIn(lang, key)
      if t \== "" then out~append(key "=" t)
    end
  end
  return out

-- The language support written into the program (in the dialog's class):
-- OodNls's own methods, copied from their source (OodNls.cls).
::method nlsMethods
  expose form
  use strict arg out
  out~append("::attribute nlsChosen class      -- the program's argument: rexx" form["NAME"]".rex de")
  do l over .OodNls~programLines(self~baseLanguage)
    out~append(l)
  end
  return out

-- the routine nlsAnsi, after the class
::method nlsRoutine
  use strict arg out
  do l over .OodNls~routineLines
    out~append(l)
  end
  return out

/* ---- the design as text (::RESOURCE oodDesign) ---------------------------- */

::method resourceLines
  expose form controls vars events methods requires shared languages userStrings
  out = .array~new
  out~append("designer version="self~module_version)
  out~append("form name="oodQ(form["NAME"]) "title="oodQ(form["TITLE"]) "w="form["W"] "h="form["H"] "style="oodQ(form["STYLE"]))
  if self~isBound then out~append("binding object="oodQ(form["OBJECT"]) "file="oodQ(form["OBJECTFILE"]) "key="oodQ(form["OBJECTKEY"]) "databases="oodQ(form["DATABASES"]))
  if languages~items > 0 then out~append("languages list="oodQ(languages~makeString("L", " ")))
  do r over requires
    out~append("requires file="oodQ(r))
  end
  do e over shared
    out~append("shared name="oodQ(e["NAME"]) "value="oodQ(e["VALUE"]))
  end
  do v over vars
    out~append("var name="v["NAME"] "value="oodQ(v["VALUE"]))
  end
  do c over controls
    line = "control type="c~type "name="c~name "id="c~id "x="c~x "y="c~y "w="c~w "h="c~h
    do p over c~kind~props~makeArray(" ")
      if p == "" then iterate
      if p == "bind", c~prop(p) == "" then iterate       -- not bound: as before the binding came
      line = line p"="oodQ(c~prop(p))
    end
    if c~prop("page") \== "" then line = line "page="c~prop("page")
    out~append(line)
  end
  do m over methods
    out~append("method name="m["NAME"])
  end
  do u over userStrings
    out~append("string key="u["KEY"])   -- its texts: ::RESOURCE strings.<language>
  end
  do key over self~eventOrder
    e = events[key]
    out~append("event control="e["CONTROL"] "event="e["EVENT"] "thread="e["THREAD"])
  end
  return out

-- form events first, then by control order, then by the kind's event order
::method eventOrder
  expose controls events
  keys = .array~new
  do ev over .OodCatalog~formEvents~makeArray(" ")
    if events~hasIndex(("FORM."ev)~upper) then keys~append(("FORM."ev)~upper)
  end
  do c over controls
    do ev over c~kind~events~makeArray(" ")
      if ev == "" then iterate
      key = (c~name"."ev)~upper
      if events~hasIndex(key) then keys~append(key)
    end
  end
  return keys

::method snapshot
  return self~resourceLines~makeString("L", "0a"x)

-- Read a design back from its resource lines and the program's event methods.
::method fromSource class
  use strict arg text
  lines = text~changeStr("0d0a"x, "0a"x)~makeArray("0a"x)
  res = .array~new
  tables = .directory~new      -- language -> lines of ::RESOURCE strings.<language>
  inRes = .false
  inTable = .nil
  do l over lines
    s = l~strip
    if inRes then do
      if s~caselessEquals("::END") then inRes = .false
      else res~append(l)
    end
    else if inTable \== .nil then do
      if s~caselessEquals("::END") then inTable = .nil
      else inTable~append(l)
    end
    else do
      if s~upper~space == "::RESOURCE OODDESIGN" then inRes = .true
      else if s~upper~word(1) == "::RESOURCE", s~word(2)~upper~left(8) == "STRINGS." then do
        inTable = .array~new
        tables[s~word(2)~substr(9)~lower] = inTable
      end
    end
  end
  userKeys = .array~new
  if res~items = 0 then raise syntax 93.900 array(oodT("err.read.noDesign"))
  d = .nil
  evs = .array~new
  do l over res
    if l~strip == "" then iterate
    f = oodFields(l)
    select
      when f["*"] == "designer" then nop
      when f["*"] == "form" then do
        d = self~new(f["NAME"])
        d~setProp("form", "title", oodAt(f, "TITLE"))
        d~setProp("form", "w", f["W"])
        d~setProp("form", "h", f["H"])
        d~form["STYLE"] = oodAt(f, "STYLE")
      end
      when f["*"] == "var" then d~setVar(f["NAME"], oodAt(f, "VALUE"))
      when f["*"] == "binding" then do
        d~setProp("form", "object", oodAt(f, "OBJECT"))
        d~setProp("form", "objectfile", oodAt(f, "FILE"))
        d~setProp("form", "objectkey", oodAt(f, "KEY"))
        d~setProp("form", "databases", oodAt(f, "DATABASES"))
      end
      when f["*"] == "requires" then d~addRequire(f["FILE"])
      when f["*"] == "shared" then d~setShared(f["NAME"], oodAt(f, "VALUE"))
      when f["*"] == "control" then d~readControl(f)
      when f["*"] == "event" then evs~append(f)
      when f["*"] == "languages" then d~setLanguages(f["LIST"])
      when f["*"] == "string" then userKeys~append(f["KEY"])
      when f["*"] == "method" then do
        code = oodMethodBody(lines, f["NAME"])
        if code == .nil then raise syntax 93.900 array(oodT("err.read.method", f["NAME"]))
        d~setMethod(f["NAME"], code)
      end
      otherwise raise syntax 93.900 array(oodT("err.read.line", l))
    end
  end
  -- the strings: event strings' keys from the design, every text from the
  -- tables (an edit made to a table by hand is kept)
  if d~isNls then do
    base = d~baseLanguage
    texts = .directory~new
    do l over oodTableOr(tables, base)
      parse var l key "=" t
      key = key~strip
      if key \== "", key~left(2) \== "--", l~pos("=") > 0 then texts[key~upper] = t~strip("L")
    end
    do k over userKeys
      d~addString(k, oodAt(texts, k~upper))
    end
    do k over d~nlsKeys
      if texts~hasIndex(k~upper), texts[k~upper] \== d~baseText(k) then d~setString(base, k, texts[k~upper])
    end
    do lang over d~languages
      if lang == base then iterate
      do l over oodTableOr(tables, lang)
        parse var l key "=" t
        key = key~strip
        if key == "" | key~left(2) == "--" | l~pos("=") = 0 then iterate
        if d~keyIndexOrZero(key) > 0 then d~setString(lang, key, t~strip("L"))
      end
    end
  end
  -- event code: the body of each event's method, less what the generator adds
  do f over evs
    m = d~methodName(f["CONTROL"], f["EVENT"])
    code = oodMethodBody(lines, m)
    if code == .nil then raise syntax 93.900 array(oodT("err.read.event", m, f["CONTROL"], f["EVENT"]))
    d~setEventCode(f["CONTROL"], f["EVENT"], code)
    d~setEventThread(f["CONTROL"], f["EVENT"], f["THREAD"])
  end
  return d

::method readControl
  expose controls
  use strict arg f
  k = .OodCatalog~kind(f["TYPE"])
  self~checkName(f["NAME"], .nil)
  c = .OodControl~new(k~type, f["NAME"], f["ID"], f["X"], f["Y"], f["W"], f["H"])
  do p over (k~props "page")~makeArray(" ")
    if p == "" then iterate
    v = f~at(p~upper)
    if v \== .nil then c~setProp(p, v)
  end
  controls~append(c)
  return c

/* ---- the program ----------------------------------------------------------- */

-- The program.  filter (optional) may change each method's code before it
-- is written: a trace run's probes (OodTraceFilter, OodGraph.cls).
::method generate
  expose form controls vars events methods requires shared languages
  use strict arg filter = .nil
  nm = form["NAME"]
  nls = self~isNls
  out = .array~new
  out~append("/*" nm".rex -- an ooDialog program made with the ooDialog Designer" self~module_version)
  out~append("   Design: the ::RESOURCE oodDesign at the end.  The designer writes this")
  out~append("   whole file; what you type is the body of each event method.")
  out~append("   ooDialog Designer -- architecture: Tom Dyer; code: Claude (Opus 5.5). */")
  if self~usesCatch then do
    out~append("-- CATCH needs ooRexx r" || .OodDesign~catchRevision "or later: an older one reads it as a command")
    out~append("if .RexxInfo~revision <" .OodDesign~catchRevision "then do")
    out~append('  call errorDialog "This program uses CATCH or FINALLY: it needs ooRexx r' || .OodDesign~catchRevision 'or later (this is r" || .RexxInfo~revision || ")."')
    out~append("  return 1")
    out~append("end")
  end
  bound = self~isBound
  if bound then do
    if nls then out~append("parse arg key lang                 -- the key of the" form["OBJECT"] "to edit; the language: de, fr_CA, ...")
    else out~append("parse arg key                      -- the key of the" form["OBJECT"] "to edit (none: the design's)")
  end
  else if nls then out~append("parse arg lang                     -- the language: de, fr_CA, ...")
  if nls then out~append("."nm"~nlsChosen = lang~strip")
  if bound then out~append("dlg = ."nm"~new(key~strip)")
  else out~append("dlg = ."nm"~new")
  out~append("if dlg~initCode \= 0 then return dlg~initCode")
  out~append("return dlg~execute(""SHOWTOP"")")
  out~append("")
  out~append("::requires ""ooDialog.cls""")
  if bound then do
    out~append("::requires ""MappedObjects.cls""        -- the object over its tables (oorexx_mapped_objects)")
    if form["OBJECTFILE"] \== "", requires~index(form["OBJECTFILE"]) == .nil then out~append("::requires" oodRx(form["OBJECTFILE"]))
  end
  do r over requires
    out~append("::requires" oodRx(r))
  end
  out~append("")
  out~append("::class" nm "subclass UserDialog")
  out~append("")
  if shared~items > 0 then out~append("::attribute sharedScope        -- reach it in any method with: expose sharedScope")
  if bound then do
    out~append("::attribute store                    -- the databases (an ObjectStore)")
    out~append("::attribute session                  -- the unit of work: committed by OK")
    out~append("::attribute object                   -- the" form["OBJECT"] "this dialog edits")
    do c over controls
      if c~type == "COMBOBOX", c~prop("bind") \== "" then out~append("::attribute" c~name"_choices          -- what" c~name "offers: OBJECTS, LABELS")
      if self~isManagedList(c) then out~append("::attribute" c~name"_current          -- the row its fields show (-1: none)")
    end
  end
  do v over vars
    out~append("::attribute" v["NAME"])
  end
  do c over controls
    if c~type == "TIMER" then out~append("::attribute" c~name"_enabled")
  end
  out~append("")
  -- init: variables, the dialog template, data attributes' first values
  out~append("::method init")
  if bound then do
    out~append("  use strict arg key = """"")
    out~append("  forward class (super) arguments (.array~new) continue")
  end
  else out~append("  forward class (super) continue")
  if nls then out~append("  self~nlsUse(self~class~nlsChosen," oodRx(self~baseLanguage)")")
  if shared~items > 0 then do
    out~append("  self~sharedScope = .directory~new")
    do e over shared
      out~append("  self~sharedScope["oodRx(e["NAME"])"] =" e["VALUE"])
    end
  end
  do v over vars
    if v["VALUE"] == "" then out~append("  self~"v["NAME"] "= """"")
    else out~append("  self~"v["NAME"] "=" v["VALUE"])
  end
  do c over controls
    if c~type == "TIMER" then out~append("  self~"c~name"_enabled =" oodBool(c~prop("enabled")))
  end
  out~append("  self~create(0, 0," form["W"]"," form["H"]"," self~textExpr("form", "title", form["TITLE"])"," oodRx(form["STYLE"])")")
  if bound then self~generateOpen(out, nls)
  do c over controls
    if c~kind~args~wordpos("attr") = 0 then iterate
    if bound, c~prop("bind") \== "" then do
      b = c~prop("bind")
      if c~type == "EDIT", b~left(1) == "@" then do
        out~append("  self~"c~name"_data = """"               -- shown when a row of" self~boundList(c) "is selected")
        iterate
      end
      if c~type == "COMBOBOX" then do
        parse var b part ":" show
        out~append("  self~"c~name"_choices = oodChoices(self~store, self~session, self~object," oodRx(part)"," oodRx(show)")")
        out~append("  self~"c~name"_data = oodLabelOf(self~"c~name"_choices, self~object~"part")")
        iterate
      end
      if c~type == "EDIT" then out~append("  self~"c~name"_data = oodValueOf(self~object," oodRx(c~prop("bind"))")")
      if c~type == "CHECKBOX" then out~append("  self~"c~name"_data = (oodValueOf(self~object," oodRx(c~prop("bind"))") == 1)")
      iterate
    end
    if c~type == "EDIT" then out~append("  self~"c~name"_data =" oodRx(c~prop("text")))
    if c~type == "CHECKBOX" | c~type == "RADIOBUTTON" then out~append("  self~"c~name"_data =" oodNum(c~prop("checked")))
  end
  do c over controls
    if self~isManagedList(c) then out~append("  self~"c~name"_current = -1")
  end
  out~append("")
  -- defineDialog: the controls and their events
  out~append("::method defineDialog")
  do c over controls
    k = c~kind
    if k~nonvisual then iterate
    line = "  self~"k~create"("c~dlgId"," c~x"," c~y"," c~w"," c~h"," oodRx(c~opts)
    do a over k~args~makeArray(" ")
      if a == "text" then line = line"," self~textExpr(c, "text", c~prop("text"))
      if a == "attr" then line = line"," oodRx(c~name"_data")
    end
    out~append(line")")
  end
  do key over self~eventOrder
    e = events[key]
    if e["CONTROL"]~caselessEquals("form") then iterate
    c = self~control(e["CONTROL"])
    if c~kind~nonvisual then iterate
    if c~type == "TAB" then do
      if self~pageMembers(c)~items > 0 then iterate
    end
    if self~boundEvent(c) == e["EVENT"] then iterate      -- its bound method connects, then forwards to this one
    out~append("  self~"c~kind~connect"("c~dlgId"," oodRx(e["EVENT"])"," oodRx(self~methodName(c~name, e["EVENT"]))")")
  end
  -- bound buttons and lists: their own methods (Add, Remove; the fields of the selected row)
  do c over controls
    ev = self~boundEvent(c)
    if ev == "" then iterate
    out~append("  self~"c~kind~connect"("c~dlgId"," oodRx(ev)"," oodRx(c~name"_bound")")")
  end
  -- a tab strip with controls on its pages: its own method shows the page
  do c over controls
    if c~type \== "TAB" then iterate
    if self~pageMembers(c)~items = 0 then iterate
    out~append("  self~connectTabEvent("c~dlgId", ""SELCHANGE"", "oodRx(c~name"_pageChanged")")")
  end
  out~append("")
  -- initDialog: list items, ranges, timers, then the form's INIT code
  out~append("::method initDialog unguarded")
  do c over controls
    if c~type == "COMBOBOX", bound, c~prop("bind") \== "" then do
      out~append("  do choice over self~"c~name"_choices[""LABELS""]   -- not LABEL: DO LABEL names a loop")
      out~append("    self~"c~name"~add(choice)")
      out~append("  end")
    end
    else if c~type == "LISTBOX" | c~type == "COMBOBOX" then do
      if c~prop("items") \== "" then do
        if nls then do
          out~append("  do item over self~nls("oodRx(c~name".items")")~makeArray(""|"")")
          out~append("    self~"c~name"~add(item)")
          out~append("  end")
        end
        else do item over c~prop("items")~makeArray("|")
          out~append("  self~"c~name"~add("oodRx(item)")")
        end
      end
    end
    if c~type == "STATIC", bound, c~prop("bind") \== "" then
      out~append("  self~"c~name"~setText(oodValueOf(self~object," oodRx(c~prop("bind"))"))")
    if c~type == "PROGRESSBAR" then do
      out~append("  self~"c~name"~setRange("c~prop("min")"," c~prop("max")")")
      out~append("  self~"c~name"~setPos("c~prop("pos")")")
    end
    if c~type == "LISTVIEW" then do
      if c~prop("exstyles") \== "" then out~append("  self~"c~name"~addExtendedStyle("oodRx(c~prop("exstyles"))")")
      i = 0
      if nls, c~prop("columns") \== "" then do
        out~append("  i = 0")
        out~append("  do col over self~nls("oodRx(c~name".columns")")~makeArray(""|"")")
        out~append("    parse var col title "":"" width")
        out~append("    if width == """" then width = 50")
        out~append("    self~"c~name"~insertColumn(i, title, width)")
        out~append("    i = i + 1")
        out~append("  end")
      end
      else do col over c~prop("columns")~makeArray("|")
        parse var col title ":" width
        if width == "" then width = 50
        out~append("  self~"c~name"~insertColumn("i"," oodRx(title)"," width")")
        i = i + 1
      end
      if bound, c~prop("bind") \== "" then do
        parse value c~prop("bind") with part ":" attrs
        out~append("  do part over oodPartsOf(self~object," oodRx(part)")")
        line = "    self~"c~name"~addRow( , "
        do a over attrs~makeArray(",")
          line = line"," "oodValueOf(part," oodRx(a)")"
        end
        out~append(line")")
        out~append("  end")
        if self~isManagedList(c) then out~append("  self~"c~name"_load(0)")
      end
      else if c~prop("rows") \== "" then do
        do row over c~prop("rows")~makeArray("|")
          line = "  self~"c~name"~addRow( , "
          do cell over row~makeArray(";")
            line = line"," oodRx(cell)
          end
          out~append(line")")
        end
      end
    end
    if c~type == "TREEVIEW" then do
      -- a node's dots are its depth: TreeView~add takes it as leading blank
      -- arguments; a node with children starts expanded
      nodes = c~prop("nodes")~makeArray("|")
      do i = 1 to nodes~items
        node = nodes[i]
        depth = node~verify(".") - 1
        tail = ""
        if i < nodes~items then do
          if nodes[i + 1]~verify(".") - 1 > depth then tail = ", , , ""EXPANDED"""
        end
        if depth = 0 then out~append("  self~"c~name"~add("oodRx(node) || tail")")
        else out~append("  self~"c~name"~add(" || copies(" ,", depth) || " " || oodRx(node~substr(depth + 1)) || tail || ")")
      end
    end
    if c~type == "TRACKBAR" then do
      out~append("  self~"c~name"~initRange("c~prop("min")"," c~prop("max")")")
      out~append("  self~"c~name"~pos =" c~prop("pos"))
    end
    if c~type == "TAB" then do
      line = ""
      do t over c~prop("tabs")~makeArray("|")
        if line \== "" then line = line", "
        line = line || oodRx(t)
      end
      if nls then do
        out~append("  do t over self~nls("oodRx(c~name".tabs")")~makeArray(""|"")")
        out~append("    self~"c~name"~addSequence(t)")
        out~append("  end")
      end
      else out~append("  self~"c~name"~addSequence("line")")
      if self~pageMembers(c)~items > 0 then out~append("  self~"c~name"_show(1)")
    end
  end
  self~generateMenu(out)
  -- execute sets the controls from their data attributes after initDialog,
  -- so INIT runs between a setData and a getData: it sees the first values,
  -- and what it sets is kept (the same order holds on Windows)
  hasData = .false
  do c over controls
    if c~kind~args~wordpos("attr") > 0 then hasData = .true
  end
  if events~hasIndex("FORM.INIT") then do
    if hasData then out~append("  self~setData")
    out~append("  self~on_form_init")
    if hasData then out~append("  self~getData")
  end
  do c over controls
    if c~type == "TIMER" then do
      if events~hasIndex((c~name".TICK")~upper) then out~append("  self~start(""timer_"c~name""")")
    end
  end
  out~append("")
  -- accessors: self~display is the control object, as DrDialog's Dlg.display
  -- (a menu item's accessor is its id: self~menuBar~check(self~mnuRuler))
  do c over controls
    if c~type == "MENUITEM" then do
      out~append("::method" c~name "unguarded")
      out~append("  return" c~id)
    end
    if c~kind~nonvisual then iterate
    out~append("::method" c~name "unguarded")
    out~append("  return self~"c~kind~access"("c~dlgId")")
  end
  if controls~items > 0 then out~append("")
  -- tab strips: show the controls of the selected page, hide the others
  do c over controls
    if c~type \== "TAB" then iterate
    members = self~pageMembers(c)
    if members~items = 0 then iterate
    out~append("::method" c~name"_pageChanged unguarded")
    out~append("  self~"c~name"_show(self~"c~name"~selectedIndex + 1)")
    if events~hasIndex((c~name".SELCHANGE")~upper) then
      out~append("  forward message ("oodRx(self~methodName(c~name, "SELCHANGE"))")")
    out~append("")
    out~append("::method" c~name"_show unguarded")
    out~append("  use strict arg page")
    do o over members
      parse value o~prop("page") with . ":" n
      out~append("  if page ="  n "then self~"o~name"~show")
      out~append("  else self~"o~name"~hide")
    end
    out~append("")
  end
  -- timers: a thread each, ticking while the dialog is up
  do c over controls
    if c~type \== "TIMER" then iterate
    if \events~hasIndex((c~name".TICK")~upper) then iterate
    out~append("::method timer_"c~name "unguarded")
    out~append("  do while self~isDialogActive")
    out~append("    call SysSleep" c~prop("interval"))
    out~append("    if self~"c~name"_enabled then do")
    out~append("      if self~isDialogActive then self~on_"c~name"_tick")
    out~append("    end")
    out~append("  end")
    out~append("")
  end
  if bound then self~generateListMethods(out)
  if nls then self~nlsMethods(out)
  if bound then self~generateValidate(out)
  -- the form's own methods
  do m over methods
    out~append("::method" m["NAME"] "unguarded")
    code = m["CODE"]
    if filter \== .nil then code = filter~filter(m["NAME"], code, "caller")
    do l over code~makeArray("0a"x)
      if l == "" then out~append("")
      else out~append("  "l)
    end
    out~append("")
  end
  -- the event methods: the user's code
  do key over self~eventOrder
    e = events[key]
    m = self~methodName(e["CONTROL"], e["EVENT"])
    out~append("::method" m "unguarded")
    code = e["CODE"]
    if filter \== .nil then code = filter~filter(m, code, e["THREAD"])
    codeLines = code~makeArray("0a"x)
    -- background: reply at once; after EXPOSE, which must come first
    replyAt = 0
    if e["THREAD"] == "background" then do
      replyAt = 1
      if codeLines~items > 0 then do
        if codeLines[1]~strip~word(1)~caselessEquals("expose") then replyAt = 2
      end
    end
    if replyAt = 1 then out~append(.OodDesign~replyLine)
    do i = 1 to codeLines~items
      l = codeLines[i]
      if l == "" then out~append("")
      else out~append("  "l)
      if replyAt = 2 & i = 1 then out~append(.OodDesign~replyLine)
    end
    if m == "ok" | m == "cancel" then out~append(.OodDesign~superLine)
    out~append("")
  end
  if filter \== .nil then do l over filter~extraLines
    out~append(l)
  end
  if bound then self~generateBindRoutines(out)
  if nls then do
    self~nlsRoutine(out)
    do lang over languages
      out~append("::resource strings."lang)
      do l over self~resourceTable(lang)
        out~append(l)
      end
      out~append("::END")
    end
  end
  out~append("::resource oodDesign")
  do l over self~resourceLines
    out~append(l)
  end
  out~append("::END")
  return out~makeString("L", "0a"x) || "0a"x

-- init, for a bound design: the store, its databases, the session and the
-- object (the key given, else the design's; none: a new one)
::method generateOpen
  expose form
  use strict arg out, nls
  cls = form["OBJECT"]
  lang = """en"""
  if nls then lang = "self~class~nlsChosen"
  out~append("  -- the" cls "it edits: its tables, a unit of work, the object")
  out~append("  self~store = .ObjectStore~new("lang")")
  do d over form["DATABASES"]~makeArray(" ")
    parse var d sch "=" path
    out~append("  self~store~attach("oodRx(sch)", oodBeside("oodRx(path)"))")
  end
  out~append("  self~session = self~store~session")
  if form["OBJECTKEY"] \== "" then out~append("  if key == """" then key =" oodRx(form["OBJECTKEY"]))
  out~append("  if key == """" then self~object = self~session~new(."cls")")
  out~append("  else self~object = self~session~find(."cls", key)")
  out~append("  if self~object == .nil then do")
  out~append("    say ""There is no"" "oodRx(cls)" ""with key"" key")
  out~append("    self~initCode = 1")
  out~append("    return")
  out~append("  end")
  return

-- validate, for a bound design: the fields into the object, then the commit;
-- a refusal is shown and the dialog stays open
::method generateValidate
  expose controls events
  use strict arg out
  out~append("::method validate unguarded")
  out~append("  self~getData")
  do c over controls
    if self~isManagedList(c) then out~append("  self~"c~name"_save                 -- the selected row's fields into its object")
  end
  do c over controls
    b = c~prop("bind")
    if c~type == "COMBOBOX", b \== "" then do
      parse var b part ":" .
      out~append("  self~object~"part "= oodChosen(self~"c~name"_choices, self~"c~name"_data)")
      iterate
    end
    if b == "" | b~pos(".") > 0 | b~pos(":") > 0 then iterate
    if c~type == "EDIT" then out~append("  self~object~" || b "= oodFromText(self~"c~name"_data)")
    if c~type == "CHECKBOX" then out~append("  self~object~" || b "= self~"c~name"_data")
  end
  out~append("  signal on syntax name refused")
  out~append("  self~session~commit")
  if events~hasIndex("FORM.SAVED") then out~append("  self~on_form_saved")
  out~append("  return .true")
  out~append("refused:")
  out~append("  c = condition(""O"")")
  out~append("  msg = c~at(""MESSAGE"")")
  out~append("  if c~at(""CODE"") == ""93.900"", c~at(""ADDITIONAL"")~isA(.Array) then msg = c~at(""ADDITIONAL"")[1]")
  out~append("  call errorDialog msg")
  out~append("  return .false")
  out~append("")
  return

-- a bound list view with buttons or detail fields: its rows are edited
::method isManagedList
  use strict arg c
  if c~type \== "LISTVIEW" | c~prop("bind") == "" then return .false
  if \self~isBound then return .false
  return self~listHelpers(c~name)~items > 0

-- the event a bound control's own method takes ("" for none): the user's
-- method for it is called from there
::method boundEvent
  use strict arg c
  if \self~isBound then return ""
  if c~type == "PUSHBUTTON", c~prop("bind") \== "" then return "CLICKED"
  if self~isManagedList(c) then return "SELECTCHANGED"
  return ""

-- the methods of bound buttons and lists: Add, Remove, and the detail
-- fields of the selected row (saved into its object as the row changes)
::method generateListMethods
  expose controls events form
  use strict arg out
  do c over controls
    if c~type \== "PUSHBUTTON" | c~prop("bind") == "" then iterate
    parse value c~prop("bind") with verb ":" list
    out~append("::method" c~name"_bound unguarded")
    out~append("  self~"list"_"verb)
    user = (c~name".CLICKED")~upper
    if events~hasIndex(user) then out~append("  forward message ("oodRx(self~methodName(c~name, "CLICKED"))")")
    else out~append("  return 0")
    out~append("")
  end
  do lv over controls
    if \self~isManagedList(lv) then iterate
    n = lv~name
    parse value lv~prop("bind") with part ":" attrs
    details = .array~new
    do h over self~listHelpers(n)
      if h~type == "EDIT" then details~append(h)
    end
    -- a row selected
    out~append("::method" n"_bound unguarded")
    out~append("  use arg id, item, state")
    out~append("  if state~wordPos(""SELECTED"") > 0, item \= self~"n"_current then do")
    out~append("    self~getData")
    out~append("    self~"n"_save")
    out~append("    self~"n"_load(item)")
    out~append("  end")
    if events~hasIndex((n".SELECTCHANGED")~upper) then out~append("  forward message ("oodRx(self~methodName(n, "SELECTCHANGED"))")")
    else out~append("  return 0")
    out~append("")
    -- load
    out~append("::method" n"_load unguarded")
    out~append("  -- row i of" part "into the fields (0: the first); none: the fields cleared and off")
    out~append("  use strict arg i")
    out~append("  parts = oodPartsOf(self~object," oodRx(part)")")
    out~append("  if i >= parts~items then i = parts~items - 1")
    out~append("  self~"n"_current = i")
    out~append("  if i < 0 then do")
    do d over details
      out~append("    self~"d~name"_data = """"")
      out~append("    self~"d~name"~setText("""")")
      out~append("    self~"d~name"~disable")
    end
    out~append("    return 0")
    out~append("  end")
    if details~items > 0 then out~append("  part = parts[i + 1]")
    do d over details
      parse value d~prop("bind") with "@" . "." attr
      out~append("  self~"d~name"_data = oodValueOf(part," oodRx(attr)")")
      out~append("  self~"d~name"~setText(self~"d~name"_data)")
      out~append("  self~"d~name"~enable")
    end
    out~append("  self~"n"~select(i)")
    out~append("  return 0")
    out~append("")
    -- save
    out~append("::method" n"_save unguarded")
    out~append("  -- the fields into the object of the row they show, and its cells")
    if details~items > 0 then do
      out~append("  i = self~"n"_current")
      out~append("  parts = oodPartsOf(self~object," oodRx(part)")")
      out~append("  if i < 0 | i >= parts~items then return 0")
      out~append("  part = parts[i + 1]")
      do d over details
        parse value d~prop("bind") with "@" . "." attr
        out~append("  part~"attr "= oodFromText(self~"d~name"_data)")
      end
      out~append("  call oodRow self~"n", i, part," oodRx(attrs))
    end
    out~append("  return 0")
    out~append("")
    -- add
    out~append("::method" n"_add unguarded")
    out~append("  -- a new object at the end of" part": its row, selected, its fields to fill in")
    out~append("  self~getData")
    out~append("  self~"n"_save")
    out~append("  parts = oodPartsOf(self~object," oodRx(part)")")
    out~append("  part = self~session~new(oodPartOf(self~store, self~object," oodRx(part)")~targetClass)")
    out~append("  parts~append(part)")
    line = "  self~"n"~addRow( , "
    do a over attrs~makeArray(",")
      line = line"," "oodValueOf(part," oodRx(a)")"
    end
    out~append(line")")
    out~append("  self~"n"_load(parts~items - 1)")
    if details~items > 0 then out~append("  self~"details[1]~name"~assignFocus")
    out~append("  return 0")
    out~append("")
    -- remove
    out~append("::method" n"_remove unguarded")
    out~append("  -- the selected row's object out of" part": a new one is dropped, an owned one deleted at OK")
    out~append("  i = self~"n"~selected")
    out~append("  parts = oodPartsOf(self~object," oodRx(part)")")
    out~append("  if i < 0 | i >= parts~items then return 0")
    out~append("  part = parts[i + 1]")
    out~append("  self~"n"_current = -1            -- first: no field is saved into the next row")
    out~append("  parts~delete(i + 1)")
    out~append("  if self~session~stateOf(part) == ""NEW"" then self~session~delete(part)")
    out~append("  self~"n"~delete(i)")
    out~append("  self~"n"_load(i)")
    out~append("  return 0")
    out~append("")
  end
  return

::method generateBindRoutines
  use strict arg out
  -- each routine's comment inside it: what is between the last event
  -- method and the next directive is read back as that method's code
  out~append("::routine oodValueOf")
  out~append("  -- a value of the object: an attribute, or a path of them (employer.name); """" for none")
  out~append("  use strict arg obj, path")
  out~append("  v = obj")
  out~append("  do a over path~makeArray(""."")")
  out~append("    if v == .nil then return """"")
  out~append("    v = v~send(a)")
  out~append("  end")
  out~append("  if v == .nil then return """"")
  out~append("  return v")
  out~append("")
  out~append("::routine oodBeside")
  out~append("  -- a database's folder: as given if absolute, else beside this program")
  out~append("  use strict arg path")
  out~append("  if path~left(1) == ""/"" | path~left(1) == ""\"" | path~substr(2, 1) == "":"" then return path")
  out~append("  return .File~new(.context~package~name)~parent || .File~separator || path")
  out~append("")
  out~append("::routine oodPartsOf")
  out~append("  -- the objects of a many-part: its own array, so a change to it is the object's")
  out~append("  use strict arg obj, attr")
  out~append("  v = obj~send(attr)")
  out~append("  if v == .nil then do")
  out~append("    v = .array~new")
  out~append("    obj~send(attr""="", v)")
  out~append("  end")
  out~append("  return v")
  out~append("")
  out~append("::routine oodPartOf")
  out~append("  -- the part attr of the object's class (an ObjectPart): what it holds, and how")
  out~append("  use strict arg store, obj, attr")
  out~append("  do p over store~map(obj~class)~parts")
  out~append("    if p~attribute~caselessEquals(attr) then return p")
  out~append("  end")
  out~append("  raise syntax 93.900 array(obj~class~id ""has no part"" attr)")
  out~append("")
  out~append("::routine oodChoices")
  out~append("  -- what a one-part may hold: its objects, and a label each; the first label, """", is none")
  out~append("  use strict arg store, session, obj, attr, show")
  out~append("  r = .directory~new")
  out~append("  r[""OBJECTS""] = .array~new")
  out~append("  r[""LABELS""] = .array~of("""")")
  out~append("  do o over session~all(oodPartOf(store, obj, attr)~targetClass)")
  out~append("    t = oodValueOf(o, show)")
  out~append("    label = t")
  out~append("    n = 1")
  out~append("    do while r[""LABELS""]~hasItem(label)       -- two the same: (2), (3) ...")
  out~append("      n = n + 1")
  out~append("      label = (t ""(""n"")"")~strip")
  out~append("    end")
  out~append("    r[""OBJECTS""]~append(o)")
  out~append("    r[""LABELS""]~append(label)")
  out~append("  end")
  out~append("  return r")
  out~append("")
  out~append("::routine oodLabelOf")
  out~append("  -- the label of the object a one-part holds ("""" for none)")
  out~append("  use strict arg r, obj")
  out~append("  if obj == .nil then return """"")
  out~append("  i = r[""OBJECTS""]~index(obj)")
  out~append("  if i == .nil then return """"")
  out~append("  return r[""LABELS""][i + 1]")
  out~append("")
  out~append("::routine oodChosen")
  out~append("  -- the object of a label (.nil for none)")
  out~append("  use strict arg r, label")
  out~append("  i = r[""LABELS""]~index(label)")
  out~append("  if i == .nil then return .nil")
  out~append("  if i = 1 then return .nil")
  out~append("  return r[""OBJECTS""][i - 1]")
  out~append("")
  out~append("::routine oodRow")
  out~append("  -- row i of a list view from its object: one attribute a column")
  out~append("  use strict arg lv, i, obj, attrs")
  out~append("  a = attrs~makeArray("","")")
  out~append("  do c = 1 to a~items")
  out~append("    lv~modify(i, c - 1, oodValueOf(obj, a[c]))")
  out~append("  end")
  out~append("  return 0")
  out~append("")
  out~append("::routine oodFromText")
  out~append("  -- an entry field's text for the object: empty is no value (NULL)")
  out~append("  use strict arg t")
  out~append("  if t == """" then return .nil")
  out~append("  return t")
  out~append("")
  return

-- the controls on the pages of tab strip t, in creation order
::method pageMembers
  expose controls
  use strict arg t
  members = .array~new
  do o over controls
    if o~prop("page")~caselessPos(t~name":") = 1 then members~append(o)
  end
  return members

-- The menu bar: menu items, in creation order, grouped by the menu (popup)
-- each is in; an item whose text is - is a separator.  Attached in
-- initDialog; upstream keeps it as self~menuBar.
-- a text in the program: self~nls(key) with languages, else the literal
::method textExpr
  use strict arg owner, prop, text
  if \self~isNls then return oodRx(text)
  if owner~isA(.String) then return "self~nls("oodRx(owner"."prop)")"
  return "self~nls("oodRx(owner~name"."prop)")"

::method generateMenu
  expose controls events
  use strict arg out
  popups = .array~new
  items = .directory~new
  do c over controls
    if c~type \== "MENUITEM" then iterate
    p = c~prop("popup")
    if \items~hasIndex(p) then do
      popups~append(p)
      items[p] = .array~new
    end
    items[p]~append(c)
  end
  if popups~items = 0 then return
  out~append("  menu = .UserMenuBar~new(9000, , , .false)")
  pn = 0
  do p over popups
    pn = pn + 1
    flags = ""
    if pn = popups~items then flags = "END"
    out~append("  menu~addPopup("9000 + pn"," self~textExpr(items[p][1], "popup", p)"," oodRx(flags)")")
    list = items[p]
    do i = 1 to list~items
      c = list[i]
      flags = ""
      if c~prop("checked") == "1" then flags = flags "CHECKED"
      if c~prop("grayed") == "1" then flags = flags "GRAYED"
      if i = list~items then flags = flags "END"
      flags = flags~strip
      if c~prop("text") == "-" then out~append("  menu~addSeparator("c~id"," oodRx(flags)")")
      else do
        line = "  menu~addItem("c~id"," self~textExpr(c, "text", c~prop("text"))"," oodRx(flags)
        if events~hasIndex((c~name".CLICKED")~upper) then line = line"," oodRx(self~methodName(c~name, "CLICKED"))
        out~append(line")")
      end
    end
  end
  out~append("  menu~complete")
  out~append("  menu~attachTo(self)")
  return

-- the lines the generator puts round the user's code (the reader removes them)
::method replyLine class
  return "  reply 0  -- background: the dialog carries on while this runs"
::method superLine class
  return "  forward class (super)  -- return before this line to keep the dialog open"

/* ---- checks ---------------------------------------------------------------- */

-- Problems a designer should show but need not refuse: one per line.
-- the dialog edits an object (form OBJECT set)
::method isBound
  expose form
  return oodAt(form, "OBJECT") \== ""

-- a control's bind, checked: "attr" or "a.b" (static text only: read only);
-- a list view's "part:attr,attr" (one attribute a column); a combo box's
-- "part:attr" (a one-part: the objects it may hold, shown by attr); a push
-- button's "add:list" or "remove:list"; an entry field's "@list.attr" (the
-- attribute of the item selected in the bound list view)
::method checkBind
  use strict arg c, value
  value = value~strip
  if value == "" then return ""
  if c~type == "COMBOBOX" then do
    parse var value part ":" show
    if \oodIsSymbol(part) | \oodIsPath(show~strip) then raise syntax 93.900 array(oodT("err.bind.combo", value))
    return part":"show~strip
  end
  if c~type == "PUSHBUTTON" then do
    parse var value verb ":" list
    if wordpos(verb~strip~lower, "add remove") = 0 | \oodIsSymbol(list~strip) then raise syntax 93.900 array(oodT("err.bind.button", value))
    return verb~strip~lower":"list~strip
  end
  if c~type == "EDIT", value~left(1) == "@" then do
    parse var value "@" list "." attr
    if \oodIsSymbol(list) | \oodIsSymbol(attr) then raise syntax 93.900 array(oodT("err.bind.detail", value))
    return "@"list"."attr
  end
  if c~type == "LISTVIEW" then do
    parse var value part ":" attrs
    if \oodIsSymbol(part) | attrs~strip == "" then raise syntax 93.900 array(oodT("err.bind.list", value))
    do a over attrs~makeArray(",")
      if \oodIsPath(a~strip) then raise syntax 93.900 array(oodT("err.bind.list", value))
    end
    return part":"attrs~space(0)
  end
  if \oodIsPath(value) then raise syntax 93.900 array(oodT("err.bind.attr", value))
  if value~pos(".") > 0, c~type \== "STATIC" then raise syntax 93.900 array(oodT("err.bind.path", c~name, value))
  return value

::method problems
  expose form controls
  out = .array~new
  hasClose = .false
  do c over controls
    if c~prop("role") \== "" then hasClose = .true
    if c~kind~nonvisual then iterate
    if c~x + c~w > form["W"] | c~y + c~h > form["H"] then out~append(c~name "is outside the form")
  end
  if \hasClose then out~append("No button has role OK or CANCEL: the dialog closes only with its X")
  bound = .false
  do c over controls
    if c~prop("bind") \== "" then bound = .true
  end
  if bound, \self~isBound then out~append(oodT("err.bind.noObject"))
  if self~isBound, oodAt(form, "DATABASES") == "" then out~append(oodT("err.bind.noDatabases"))
  do c over controls
    b = c~prop("bind")
    if b == "" then iterate
    if c~type == "LISTVIEW" then do
      parse var b . ":" attrs
      if attrs~makeArray(",")~items \= c~prop("columns")~makeArray("|")~items then out~append(oodT("err.bind.columns", c~name))
      if c~prop("rows") \== "" then out~append(oodT("err.bind.fixed", c~name))
      if self~listHelpers(c~name)~items > 0, c~prop("opts")~wordpos("SINGLESEL") = 0 then out~append(oodT("err.bind.single", c~name))
      adds = .false; details = .false
      do h over self~listHelpers(c~name)
        if h~type == "EDIT" then details = .true
        if h~prop("bind")~left(4) == "add:" then adds = .true
      end
      if adds, \details then out~append(oodT("err.bind.noDetail", c~name))
    end
    if c~type == "COMBOBOX", c~prop("items") \== "" then out~append(oodT("err.bind.fixed", c~name))
    if c~type == "PUSHBUTTON", c~prop("role") \== "" then out~append(oodT("err.bind.role", c~name))
    list = self~boundList(c)
    if list \== "" then do
      t = .nil
      do o over controls
        if o~name~caselessEquals(list) then t = o
      end
      if t == .nil then out~append(oodT("err.bind.target", c~name, list))
      else if t~type \== "LISTVIEW" | t~prop("bind") == "" then out~append(oodT("err.bind.target", c~name, list))
    end
  end
  return out~makeString("L", "0a"x)

-- the list view a push button or a detail field works on ("" for none)
::method boundList
  use strict arg c
  b = c~prop("bind")
  if c~type == "PUSHBUTTON", b \== "" then return b~substr(b~pos(":") + 1)
  if c~type == "EDIT", b~left(1) == "@" then do
    parse var b "@" list "." .
    return list
  end
  return ""

-- the controls that work on list view lv: its buttons and detail fields
::method listHelpers
  expose controls
  use strict arg lv
  out = .array~new
  do c over controls
    if self~boundList(c)~caselessEquals(lv) then out~append(c)
  end
  return out


/* ---- routines ------------------------------------------------------------ */

-- A design line: a keyword, then key=value pairs; a value with a blank, a
-- quote or = in it is in double quotes, a quote in it doubled.
::routine oodFields public
  use strict arg line
  f = .directory~new
  parse var line kw rest
  f["*"] = kw
  rest = rest~strip
  do while rest \== ""
    eq = rest~pos("=")
    if eq = 0 then raise syntax 93.900 array(oodT("err.read.keyValue", line))
    key = rest~left(eq - 1)~strip~upper
    rest = rest~substr(eq + 1)
    if rest~left(1) == '"' then do
      val = ""
      p = 2
      closed = .false
      do while \closed
        q = rest~pos('"', p)
        if q = 0 then raise syntax 93.900 array(oodT("err.read.quote", line))
        val = val || rest~substr(p, q - p)
        if rest~substr(q + 1, 1) == '"' then do
          val = val || '"'
          p = q + 2
        end
        else do
          rest = rest~substr(q + 1)
          closed = .true
        end
      end
    end
    else parse var rest val rest
    f[key] = val
    rest = rest~strip
  end
  return f

-- a field of a directory, "" when it is not there
-- a Rexx symbol (a name of a class, an attribute, a schema)
::routine oodIsSymbol public
  use strict arg s
  if s == "" then return .false
  if s~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_!?") > 0 then return .false
  return \datatype(s~left(1), "W")

-- attribute names joined with dots: "name", "employer.name"
::routine oodIsPath public
  use strict arg s
  if s == "" | s~left(1) == "." | s~right(1) == "." then return .false
  do w over s~makeArray(".")
    if \oodIsSymbol(w) then return .false
  end
  return .true

::routine oodAt public
  use strict arg f, key
  v = f~at(key)
  if v == .nil then return ""
  return v

::routine oodQ public
  use strict arg v
  v = v~string
  if v == "" then return '""'
  if v~verify(' "=' || "09"x, "M") > 0 then return '"' || v~changeStr('"', '""') || '"'
  return v

-- a Rexx string literal
-- a language's table lines, or none
::routine oodTableOr public
  use strict arg tables, lang
  t = tables[lang~lower]
  if t == .nil then return .array~new
  return t

::routine oodRx public
  use strict arg v
  return '"' || v~string~changeStr('"', '""') || '"'

::routine oodNum public
  use strict arg v
  if v == "1" then return 1
  return 0

::routine oodBool public
  use strict arg v
  if v == "1" then return ".true"
  return ".false"

-- self~old -> self~new where old is a whole symbol (any case)
::routine oodRenameRef public
  use strict arg code, old, new
  find = "self~"old
  out = ""
  p = 1
  do forever
    q = code~caselessPos(find, p)
    if q = 0 then leave
    nextCh = code~substr(q + length(find), 1)
    out = out || code~substr(p, q - p)
    if nextCh \== "" & nextCh~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789") = 0 then
      out = out || find
    else out = out || "self~"new
    p = q + length(find)
  end
  return out || code~substr(p)

-- Code as typed, less trailing blanks and blank trailing lines.  No line may
-- start with "::": it would end the method.
::routine oodCleanCode public
  use strict arg code
  lines = code~changeStr("0d0a"x, "0a"x)~changeStr("0d"x, "0a"x)~makeArray("0a"x)
  clean = .array~new
  do l over lines
    l = l~strip("T")
    if l~strip~left(2) == "::" then raise syntax 93.900 array(oodT("err.code.directive"))
    clean~append(l)
  end
  do while clean~items > 0
    if clean~lastItem \== "" then leave
    clean~delete(clean~last)
  end
  return clean~makeString("L", "0a"x)

-- The user's code in method m of a generated program, or .nil.
::routine oodMethodBody public
  use strict arg lines, m
  body = .array~new
  found = .false
  do l over lines
    s = l~strip
    if found then do
      if s~left(2) == "::" then leave
      body~append(l)
    end
    else do
      if s~left(9)~caselessEquals("::method ") then do
        if s~word(2)~caselessEquals(m) then found = .true
      end
    end
  end
  if \found then return .nil
  -- the reply line of a background event: first, or after EXPOSE
  do i = 1 to min(2, body~items)
    if body[i] == .OodDesign~replyLine then do
      body~delete(i)
      leave
    end
  end
  do while body~items > 0
    if body~lastItem~strip \== "" then leave
    body~delete(body~last)
  end
  if body~items > 0 then do
    if body~lastItem == .OodDesign~superLine then body~delete(body~last)
  end
  code = .array~new
  do l over body
    if l~left(2) == "  " then code~append(l~substr(3))
    else code~append(l)
  end
  return code~makeString("L", "0a"x)


/* The control catalogue.  kind: a control the palette offers.
   args: what createXxx takes after (id, x, y, cx, cy, opts): text, attr
   (the data attribute name<_data>), both or none.  events: the event
   keywords the connect method takes.  opts: the styles allowed.
   action: a line the code pane inserts when a control is dropped on it
   (types: kinds it applies to, * for every visual kind; %n: the name). */
::resource oodKinds
kind type=PUSHBUTTON label="Push button" prefix=btn create=createPushButton access=newPushButton args=text w=50 h=14 text=Button events=CLICKED connect=connectButtonEvent opts="DEFAULT GROUP NOTAB DISABLED HIDDEN" props="text role bind opts"
kind type=STATIC label=Text prefix=lbl create=createStaticText access=newStatic args=text w=60 h=10 text=Text opts="LEFT RIGHT CENTER GROUP DISABLED HIDDEN" props="text bind opts"
kind type=EDIT label="Entry field" prefix=txt create=createEdit access=newEdit args=attr w=80 h=12 events="CHANGE UPDATE" connect=connectEditEvent opts="READONLY RIGHT CENTER PASSWORD MULTILINE NUMBER UPPER GROUP NOTAB DISABLED HIDDEN" props="text bind opts"
kind type=CHECKBOX label="Check box" prefix=chk create=createCheckBox access=newCheckBox args="text attr" w=60 h=10 text=Check events=CLICKED connect=connectButtonEvent opts="GROUP NOTAB DISABLED HIDDEN" props="text checked bind opts"
kind type=RADIOBUTTON label="Radio button" prefix=opt create=createRadioButton access=newRadioButton args="text attr" w=60 h=10 text=Option events=CLICKED connect=connectButtonEvent opts="GROUP NOTAB DISABLED HIDDEN" props="text checked groupstart opts"
kind type=GROUPBOX label="Group box" prefix=grp create=createGroupBox access=newGroupBox args=text w=100 h=50 text=Group opts="HIDDEN" props="text opts"
kind type=LISTBOX label="List box" prefix=lst create=createListBox access=newListBox args=attr w=80 h=50 events="SELCHANGE DBLCLK" connect=connectListBoxEvent opts="SORT MULTI GROUP NOTAB DISABLED HIDDEN" props="items opts"
kind type=COMBOBOX label="Combo box" prefix=cbo create=createComboBox access=newComboBox args=attr w=80 h=60 events=SELCHANGE connect=connectComboBoxEvent opts="LIST SIMPLE SORT GROUP NOTAB DISABLED HIDDEN" defopts=LIST props="items bind opts"
kind type=PROGRESSBAR label="Progress bar" prefix=prg create=createProgressBar access=newProgressBar args="" w=100 h=10 opts="SMOOTH VERTICAL HIDDEN" props="min max pos opts"
kind type=LISTVIEW label="List view" prefix=lv create=createListView access=newListView args="" w=120 h=60 events="SELECTCHANGED COLUMNCLICK CHECKBOXCHANGED" connect=connectListViewEvent opts="REPORT LIST ICON SMALLICON SINGLESEL SHOWSELALWAYS GROUP NOTAB DISABLED HIDDEN" defopts="REPORT SHOWSELALWAYS" exopts="FULLROWSELECT GRIDLINES CHECKBOXES" props="columns rows bind exstyles opts"
kind type=TAB label="Tab strip" prefix=tab create=createTab access=newTab args="" w=120 h=14 events=SELCHANGE connect=connectTabEvent opts="BUTTONS MULTILINE GROUP NOTAB DISABLED HIDDEN" props="tabs opts"
kind type=TREEVIEW label="Tree view" prefix=tv create=createTreeView access=newTreeView args="" w=100 h=60 events=SELCHANGED connect=connectTreeViewEvent opts="LINES BUTTONS ATROOT SHOWSELALWAYS GROUP NOTAB DISABLED HIDDEN" defopts="LINES BUTTONS ATROOT SHOWSELALWAYS" props="nodes opts"
kind type=TRACKBAR label="Track bar" prefix=trk create=createTrackBar access=newTrackBar args="" w=100 h=16 opts="HORIZONTAL VERTICAL AUTOTICKS NOTICKS BOTH TOP BOTTOM GROUP NOTAB DISABLED HIDDEN" defopts="HORIZONTAL AUTOTICKS" props="min max pos opts"
kind type=DATETIME label="Date picker" prefix=dtp create=createDateTimePicker access=newDateTimePicker args="" w=80 h=12 events=DATETIMECHANGE connect=connectDateTimePickerEvent opts="SHORT LONG TIME SHOWNONE UPDOWN GROUP NOTAB DISABLED HIDDEN" defopts=SHORT props="opts"
kind type=MENUITEM label="Menu item" prefix=mnu nonvisual=1 events=CLICKED props="popup text checked grayed"
kind type=TIMER label="Timer thread" prefix=tmr nonvisual=1 events=TICK props="interval enabled"
form events="INIT OK CANCEL SAVED"
evargs type=LISTVIEW event=SELECTCHANGED args="id, item, state, list"
evargs type=LISTVIEW event=COLUMNCLICK args="id, column, list"
evargs type=LISTVIEW event=CHECKBOXCHANGED args="id, item, state, list"
evargs type=TAB event=SELCHANGE args="id, hwnd, tab"
evargs type=MENUITEM event=CLICKED args="info"
evargs type=TREEVIEW event=SELCHANGED args="id, old, oldData, new, newData, action, tree"
evargs type=DATETIME event=DATETIMECHANGE args="dt, valid, id, hwnd, code, dtp"
action types=* label="Set its text" code="self~%n~setText(""text"")"
action types=* label="Get its text" code="text = self~%n~getText"
action types=* label="Disable it" code="self~%n~disable"
action types=* label="Enable it" code="self~%n~enable"
action types=* label="Hide it" code="self~%n~hide"
action types=* label="Show it" code="self~%n~show"
action types=* label="Give it the focus" code="self~%n~assignFocus"
action types="LISTBOX COMBOBOX" label="Add an item" code="self~%n~add(""item"")"
action types="LISTBOX COMBOBOX" label="The selected item" code="item = self~%n~selected"
action types="LISTBOX COMBOBOX" label="Remove all items" code="self~%n~deleteAll"
action types="LISTBOX COMBOBOX" label="Count the items" code="n = self~%n~items"
action types="CHECKBOX RADIOBUTTON" label="Is it checked?" code="if self~%n~checked then nop"
action types="CHECKBOX RADIOBUTTON" label="Check it" code="self~%n~check"
action types="CHECKBOX" label="Uncheck it" code="self~%n~uncheck"
action types=PROGRESSBAR label="Set the position" code="self~%n~setPos(50)"
action types=PROGRESSBAR label="Set the range" code="self~%n~setRange(0, 100)"
action types=LISTVIEW label="Add a row" code="self~%n~addRow( , , ""cell 1"", ""cell 2"")"
action types=LISTVIEW label="Text of a cell" code="text = self~%n~itemText(item, 0)"
action types=LISTVIEW label="The selected row" code="item = self~%n~selected"
action types=LISTVIEW label="Count the rows" code="n = self~%n~items"
action types=LISTVIEW label="Remove all rows" code="self~%n~deleteAll"
action types=TAB label="The selected tab's number (1 for the first)" code="page = self~%n~selectedIndex + 1"
action types=TAB label="Its selected tab's text" code="text = self~%n~selected"
action types=TREEVIEW label="The selected node's text" code="text = self~%n~itemText(self~%n~selected)"
action types=TREEVIEW label="Add a top node" code="node = self~%n~add(""text"")"
action types=TREEVIEW label="Add a child to the last node" code="node = self~%n~add( , ""text"")"
action types=TREEVIEW label="Remove all nodes" code="self~%n~deleteAll"
action types=TRACKBAR label="Its position" code="pos = self~%n~pos"
action types=TRACKBAR label="Set its position" code="self~%n~pos = 50"
action types=DATETIME label="Its date and time" code="dt = self~%n~getDateTime"
action types=DATETIME label="Set it to now" code="self~%n~setDateTime(.DateTime~new)"
action types=MENUITEM label="Check it" code="self~menuBar~check(self~%n)"
action types=MENUITEM label="Uncheck it" code="self~menuBar~unCheck(self~%n)"
action types=MENUITEM label="Is it checked?" code="if self~menuBar~isChecked(self~%n) then nop"
action types=MENUITEM label="Gray it" code="self~menuBar~disable(self~%n)"
action types=MENUITEM label="Enable it" code="self~menuBar~enable(self~%n)"
action types=TIMER label="Start the timer" code="self~%n_enabled = .true"
action types=TIMER label="Stop the timer" code="self~%n_enabled = .false"
action types=FORM label="Close the dialog (OK)" code="self~ok"
action types=FORM label="Show a message" code="call infoDialog ""message"""
action types=FORM label="Run a method on a new thread" code="self~start(""methodName"")"
action types=FORM label="Set the title" code="self~setTitle(""title"")"
::END

/* Every method a UserDialog subclass inherits (tools/reserved.rex writes
   this over the upstream ooDialog.cls): no control may take these names. */
::resource oodReserved
reserved <> = == >< absrect2logrect activeptr activeptr= addattribute
reserved addautostartmethod addbitmapbutton addblackframe addblackrect
reserved addbutton addbuttongroup addcheckbox addcheckboxstem addcheckgroup
reserved addcombobox addcomboentry addcomboinput addentryline addetchedframe
reserved addetchedhorizontal addetchedvertical addgrayframe addgrayrect
reserved addgroupbox addicon addiconresource addimage addinput addinputgroup
reserved addinputstem addlistbox addlistcontrol addlistentry addmenuitem
reserved addmenuseparator addnewattribute addnewmethod addokcancelleftbottom
reserved addokcancellefttop addokcancelrightbottom addokcancelrighttop
reserved addpasswordline addpopupmenu addprogressbar addradiobutton
reserved addradiogroup addradiostem addscrollbar addslidercontrol addstatic
reserved addtabcontrol addtext addtreecontrol addusermsg addwhiteframe
reserved addwhiterect adm assignwindow autodetect autodetect= autodetection
reserved automaticmethods automaticmethods= backgroundbitmap backgroundcolor
reserved backgroundsyscolor baseptr baseptr= cancel capturemouse center
reserved changebitmapbutton changecomboentry changelistentry checkfile checkid
reserved checkmenuitem childdialogs childdialogs= childdied
reserved childwindowfrompoint class clear clearbuttonrect clearcontrolrect
reserved clearmessages clearrect clearwindowrect client2screen clientrect
reserved clienttoscreen combineelwithsb comboadddirectory combodrop
reserved connectactivate connectallsbevents connectanimatedbutton
reserved connectbitmapbutton connectbutton connectbuttonevent
reserved connectbuttonnotify connectcheckbox connectcombobox
reserved connectcomboboxevent connectcomboboxnotify connectcommandevents
reserved connectcommonnotify connectcontrol connectdatetimepicker
reserved connectdatetimepickerevent connectdraw connecteachsbevent connectedit
reserved connecteditevent connecteditnotify connectentryline connectfkeypress
reserved connecthelp connectkeypress connectlist connectlistbox
reserved connectlistboxevent connectlistboxnotify connectlistcontrol
reserved connectlistleftdoubleclick connectlistnotify connectlistview
reserved connectlistviewevent connectlistviewnotify connectmenuitem
reserved connectmonthcalendar connectmonthcalendarevent connectmousecapture
reserved connectmove connectmultilistbox connectnotifyevent connectposchanged
reserved connectradiobutton connectrebarevent connectresize connectresizing
reserved connectscrollbar connectscrollbarevent connectscrollbarnotify
reserved connectsizemoveended connectslidercontrol connectslidernotify
reserved connectstaticevent connectstaticnotify connectstatusbarevent
reserved connecttab connecttabcontrol connecttabevent connecttabnotify
reserved connecttoolbarevent connecttooltipevent connecttrackbar
reserved connecttrackbarevent connecttreecontrol connecttreenotify
reserved connecttreeview connecttreeviewevent connectupdown connectupdownevent
reserved constdir constdir= copy create createbitmapbutton createblackframe
reserved createblackrect createbrush createcenter createcheckbox
reserved createcheckboxgroup createcheckboxstem createcombobox
reserved createcomboboxinput createdatetimepicker createedit createeditinput
reserved createeditinputgroup createeditinputstem createetchedframe
reserved createetchedhorizontal createetchedvertical createfont createfontex
reserved creategrayframe creategrayrect creategroupbox createlistbox
reserved createlistview createmenu createmonthcalendar createokcancelleftbottom
reserved createokcancellefttop createokcancelrightbottom createokcancelrighttop
reserved createpasswordedit createpen createprogressbar createpushbutton
reserved createpushbuttongroup createpushbuttonstem createradiobutton
reserved createradiobuttongroup createradiobuttonstem createrbcbgroup
reserved createrbcbstem createrebar createscrollbar createstatic
reserved createstaticframe createstaticimage createstatictext createstatusbar
reserved createtab createtoolbar createtooltip createtrackbar createtreeview
reserved createupdown createwhiteframe createwhiterect cursorpos
reserved cursor_appstarting cursor_arrow cursor_cross cursor_no cursor_wait
reserved dataconnection dataconnection= defaultname definedialog
reserved deflistdraghandler deftreedraghandler deinstall deletecomboentry
reserved deletefont deletelistentry deleteobject determinesbposition
reserved dialogitemcount dialogitemcount= dimbitmap disable disablecontrol
reserved disableitem disablemenuitem disconnectkeypress displacebitmap display
reserved dlgdata dlghandle dlgid dlgid= dlgunit2pixel dm_reposition draw
reserved drawanglearc drawarc drawbitmap drawbutton drawline drawpie drawpixel
reserved dump dumpmessagetable dynamicinit enable enablecontrol enableitem
reserved enablemenuitem endasyncexecution ensurefinished ensurevisible
reserved errorfile execute executeasync factorx factorx= factory factory=
reserved filldrawing fillrect finalstopit findcomboentry findiconinrcfile
reserved findlistentry finished finished= focuscontrol focusitem fontcolor
reserved fontname fontname= fontsize fontsize= fonttodc foregroundwindow
reserved freebuttondc freecontroldc freedc freewindowdc get getarcdirection
reserved getattrib getbitmapposition getbitmapsize getbitmapsizex
reserved getbitmapsizey getbmpdisplacement getbuttoncontrol getbuttondc
reserved getbuttonrect getccctrlstyle getcheckbox getcheckboxdata
reserved getcheckcontrol getclientrect getcombobox getcomboboxdata
reserved getcomboentry getcomboitems getcomboline getcontroldata getcontroldc
reserved getcontrolhandle getcontrolid getcontrolrect getcontroltext
reserved getcurrentcomboindex getcurrentlistindex getdata getdataattribute
reserved getdatastem getdc geteditcontrol geteditdata getentryline
reserved getexstyleraw getfocus getfont getgroupbox getid getitem getlistbox
reserved getlistboxdata getlistcontrol getlistentry getlistitemheight
reserved getlistitemheightpx getlistitems getlistline getlistwidth
reserved getlistwidthpx getmenubar getmenuitemstate getmousecapture
reserved getmultilist getnamedctrlstyle getpixel getpos getprogressbar
reserved getradiobutton getradiobuttondata getradiocontrol getrcstyle
reserved getrealpos getrealsize getrect getresourceid getsbpos getsbrange
reserved getscrollbar getself getsize getslidercontrol getstaticcontrol
reserved getstyleraw getsysbrush getsystemmetrics gettabcontrol gettext
reserved gettextalign gettextextent gettextsize gettextsizedlg gettextsizedu
reserved gettextsizepx gettextsizescreen gettextsizetitlebar gettreecontrol
reserved getvalue getwindowdc getwindowlong getwindowrect getwindowtext
reserved graymenuitem handlemessages hashcode haskeypressconnection hasmenubar
reserved hasmethod help hide hidecontrol hidecontrolfast hidefast hideitem
reserved hideitemfast hidewindow hidewindowfast hscrollpos hwnd idabort
reserved idcancel idclose idcontinue identityhash iderror idhelp idignore idno
reserved idok idretry idtimeout idtryagain idyes init initautodetection
reserved initcode initcode= initdialog initwindowextensions
reserved init_eventnotification init_windowbase insertcomboentry
reserved insertlistentry installanimatedbutton installbitmapbutton
reserved instancemethod instancemethods isa isdialogactive isenabled
reserved isinstanceof islinked islinked= ismaximized isminimized
reserved ismousebuttondown isnil isvisible itemtitle leaving library linkmenu
reserved listadddirectory listdrop load loadbitmap loadframe loaditems loadmenu
reserved logrect2absrect makearray mapwindowpoints maximize menubar menubar=
reserved minimize move movecontrol moveitem moveto movewindow newcheckbox
reserved newcombobox newcontrol newdatetimepicker newedit newgroupbox
reserved newlistbox newlistview newmonthcalendar newprogressbar newpushbutton
reserved newradiobutton newrebar newscrollbar newstatic newstatusbar newtab
reserved newtoolbar newtooltip newtrackbar newtreeview newupdown
reserved noautodetection objectname objectname= objecttodc ok oodpeer oodpeer=
reserved opaquetext ownerdialog ownerdialog= parentdlg parentdlg=
reserved parseincludefile peekdialogmessage pixel2dlgunit pixelcx pixelcy popup
reserved popupaschild processingload processingload= putcontrol
reserved putdlgdatainstem rectangle redraw redrawbutton redrawclient
reserved redrawcontrol redrawrect redrawwindow redrawwindowrect
reserved releasemousecapture removebitmap request resize resizecontrol
reserved resizeitem resizeto resolveiconid resolvenumericid resolvesymbolicid
reserved resourceid restore restorecursorshape run screen2client screentoclient
reserved scroll scrollbitmapfromto scrollbutton scrollinbutton scrollincontrol
reserved scrolltext send sendmessage sendmessagehandle sendmessagetocontrol
reserved sendmessagetocontrolh sendmessagetoitem sendmessagetowindow
reserved sendmessagetowindowh sendwinhandle2msg sendwinhandle2msgh
reserved sendwinhandlemsg sendwinhandlemsgh sendwinintmsg sendwinintmsgh
reserved sendwinuintmsg sendwith setarcdirection setattrib setbitmapposition
reserved setcheckbox setcheckboxdata setcomboboxdata setcomboline
reserved setcontrolcolor setcontroldata setcontrolfont setcontrolsyscolor
reserved setcontroltext setcurrentcomboindex setcurrentlistindex setcursorpos
reserved setdata setdataattribute setdatastem setdlgdatafromstem setdlgfont
reserved seteditdata setentryline setfocus setfocustowindow setfont
reserved setforegroundwindow setgroup sethscrollpos setitemcolor setitemfont
reserved setitemsyscolor setlistboxdata setlistcolumnwidth setlistcolumnwidthpx
reserved setlistitemheight setlistitemheightpx setlistline setlisttabulators
reserved setlistwidth setlistwidthpx setmenu setmenuitemradio setmethod
reserved setmultilist setradiobutton setradiobuttondata setrect setsbpos
reserved setsbrange setstatictext setstatictextattribute setstyleraw settabstop
reserved settext settextalign settitle setvalue setvscrollpos setwindowlong
reserved setwindowpos setwindowrect setwindowtext setwindowtitle show
reserved showcontrol showcontrolfast showfast showitem showitemfast showwindow
reserved showwindowfast sizewindow sizex sizex= sizey sizey= size_maxhide
reserved size_maximized size_maxshow size_minimized size_restored
reserved skipthroughifdefs start startchilddialog startit startparentdialog
reserved startwith static_id stop stopit string tabtonext tabtoprevious test
reserved tiledbackgroundbitmap title title= tothetop transparenttext
reserved uncheckmenuitem uninit unknown unlinkmenu unsetmethod update
reserved updatewindow usestem usestem= validate vscrollpos waitfordialog
reserved windowrect windowtitle wm_nextdlgctl wm_setfont
reserved wm_user_interruptscroll write writedirect writetobutton writetocontrol
reserved writetowindow \= \== ||
::END
