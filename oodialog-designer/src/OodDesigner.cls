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

::class OodModule public mixinclass Object
::method module_version class
  return "0.5.0"
::method module_lastChanged class
  return "2026-11-14"
::method module_version
  return "0.5.0"
::method module_lastChanged
  return "2026-11-14"


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
      otherwise raise syntax 93.900 array("Unknown catalogue line:" line)
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
  if k == .nil then raise syntax 93.900 array("Unknown control type:" type)
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
::attribute form            -- .Directory  NAME TITLE W H STYLE
::attribute controls        -- .Array of OodControl, in creation (tab) order
::attribute vars            -- .Array of .Directory  NAME VALUE
::attribute events          -- .Directory  "CTL.EVENT" -> .Directory CONTROL EVENT THREAD CODE
::attribute methods         -- .Array of .Directory  NAME CODE: the form's own methods
::attribute requires        -- .Array of file names: the form's ::requires besides ooDialog.cls
::attribute shared          -- .Array of .Directory  NAME VALUE: the entries of self~sharedScope

::method init
  expose form controls vars events methods requires shared
  use strict arg name = "MyDialog"
  form = .directory~new
  form["NAME"] = name
  form["TITLE"] = "My Dialog"
  form["W"] = 200
  form["H"] = 120
  form["STYLE"] = "CENTER"
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
  if name == "" then raise syntax 93.900 array("A name is needed")
  if name~left(1)~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_") > 0 then
    raise syntax 93.900 array("Name" name "must start with a letter or _")
  if name~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789") > 0 then
    raise syntax 93.900 array("Name" name "may only use letters, digits and _")
  if .OodCatalog~isReserved(name) then
    raise syntax 93.900 array("Name" name "is already a method of UserDialog")
  if .OodCatalog~isReserved(name"_data") then
    raise syntax 93.900 array("Name" name"_data would be a method of UserDialog")
  do c over controls
    if c \== forCtl then do
      if c~name~caselessEquals(name) then raise syntax 93.900 array("Name" name "is in use")
      if (c~name"_data")~caselessEquals(name) then raise syntax 93.900 array("Name" name "is in use by" c~name)
      if (c~name"_enabled")~caselessEquals(name) then raise syntax 93.900 array("Name" name "is in use by" c~name)
    end
  end
  do v over vars
    if v["NAME"]~caselessEquals(name) then raise syntax 93.900 array("Name" name "is a variable")
  end
  do m over methods
    if m["NAME"]~caselessEquals(name) then raise syntax 93.900 array("Name" name "is a method of the form")
  end
  if name~caselessEquals("sharedScope") then raise syntax 93.900 array("sharedScope is the form's shared scope")
  if name~left(3)~caselessEquals("on_") then raise syntax 93.900 array("Names starting on_ are the event methods'")
  if name~left(6)~caselessEquals("timer_") then raise syntax 93.900 array("Names starting timer_ are the timers'")
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
  raise syntax 93.900 array("No control named" name)

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
  return 0

-- Geometry is in dialog units, whole numbers, inside the form.
::method toUnit
  use strict arg v
  if \datatype(v, "N") then raise syntax 93.900 array("Not a number:" v)
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
  if name~caselessEquals("form") then return "name title w h"
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
  if t == .nil then raise syntax 93.900 array("page is tabName:n; there is no control" tabName)
  if t~type \== "TAB" then raise syntax 93.900 array(tabName "is not a tab strip")
  count = t~prop("tabs")~makeArray("|")~items
  if \datatype(n, "W") then raise syntax 93.900 array("page is tabName:n with n a tab number")
  if n < 1 | n > count then raise syntax 93.900 array(tabName "has tabs 1 to" count)
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
      when key == "w" | key == "h" then do
        value = self~toUnit(value)
        if value < 20 then value = 20
        form[key~upper] = value
      end
      otherwise raise syntax 93.900 array("The form has no property" key)
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
      if \self~onPageAllowed(c) then raise syntax 93.900 array(c~name "cannot sit on a tab page")
      c~setProp(key, self~checkPage(value))
    end
    when c~kind~props~wordpos(key) = 0 then
      raise syntax 93.900 array(c~type "has no property" key)
    when key == "opts" then do
      allowed = c~kind~opts
      value = value~upper~space
      do o over value~makeArray(" ")
        if wordpos(o, allowed) = 0 then
          raise syntax 93.900 array(o "is not a style of" c~type"; it takes" allowed)
      end
      c~setProp(key, value)
    end
    when key == "exstyles" then do
      allowed = c~kind~exopts
      value = value~upper~space
      do o over value~makeArray(" ")
        if wordpos(o, allowed) = 0 then
          raise syntax 93.900 array(o "is not an extended style of" c~type"; it takes" allowed)
      end
      c~setProp(key, value)
    end
    when key == "columns" then do
      do col over value~makeArray("|")
        parse var col title ":" width
        if title~strip == "" then raise syntax 93.900 array("columns is Title:width|Title:width, width in dialog units")
        if width \== "" then do
          if \datatype(width, "W") then raise syntax 93.900 array("column" title"'s width is a whole number of dialog units")
        end
      end
      c~setProp(key, value)
    end
    when key == "tabs" then do
      if value == "" then raise syntax 93.900 array("A tab strip needs at least one tab")
      c~setProp(key, value)
    end
    when key == "popup" then do
      if value~strip == "" then raise syntax 93.900 array("A menu item needs the menu (popup) it is in")
      c~setProp(key, value)
    end
    when key == "checked" | key == "enabled" | key == "groupstart" | key == "grayed" then do
      if value \== "0" & value \== "1" then raise syntax 93.900 array(key "is 0 or 1")
      c~setProp(key, value)
    end
    when key == "role" then do
      value = value~upper
      if wordpos(value, "OK CANCEL") = 0 & value \== "" then
        raise syntax 93.900 array("role is OK, CANCEL or empty")
      if value \== "" then do
        if self~eventSummary(c~name)~pos(":1") > 0 then
          raise syntax 93.900 array(c~name "has event code: an" value "button's code goes in the form's" value "event")
        do o over controls
          if o \== c then do
            if o~prop("role")~upper == value then raise syntax 93.900 array(o~name "already has role" value)
          end
        end
      end
      c~setProp(key, value)
    end
    when wordpos(key, "min max pos") > 0 then do
      if \datatype(value, "W") then raise syntax 93.900 array(key "is a whole number")
      c~setProp(key, value)
    end
    when key == "interval" then do
      if \datatype(value, "N") then raise syntax 93.900 array("interval is a number of seconds")
      if value <= 0 then raise syntax 93.900 array("interval must be more than 0")
      c~setProp(key, value)
    end
    when key == "nodes" then do
      do node over value~makeArray("|")
        depth = node~verify(".") - 1
        if depth < 0 then raise syntax 93.900 array("A node needs text after its dots:" node)
        if node~substr(depth + 1)~strip == "" then raise syntax 93.900 array("A node needs text after its dots:" node)
      end
      if value~left(1) == "." then raise syntax 93.900 array("The first node is a top node (no dots)")
      c~setProp(key, value)
    end
    when key == "text" | key == "items" | key == "rows" then do
      if value~pos("0a"x) > 0 | value~pos("0d"x) > 0 then raise syntax 93.900 array(key "is one line")
      c~setProp(key, value)
    end
    otherwise c~setProp(key, value)
  end
  return self~getProp(c~name, key)

-- Renaming moves the control's events to the new name and rewrites
-- self~old in all the event and method code, where it is a whole symbol.
::method renameControl
  expose events methods controls
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
  if file == "" then raise syntax 93.900 array("Which file?")
  if file~caselessEquals("ooDialog.cls") then raise syntax 93.900 array("ooDialog.cls is always required")
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
  if name == "" then raise syntax 93.900 array("A name is needed")
  if value~strip == "" then raise syntax 93.900 array("A value (a Rexx expression) is needed")
  if value~pos("0a"x) > 0 then raise syntax 93.900 array("The value is one line")
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
    raise syntax 93.900 array(name "has no event" event)
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
  if e == .nil then raise syntax 93.900 array("Type the event's code first")
  if self~isTimer(name) then return "timer"
  if name~caselessEquals("form") then do
    if thread \== "ui" then raise syntax 93.900 array("The form's events run on the dialog's thread")
  end
  if wordpos(thread, "ui background") = 0 then raise syntax 93.900 array("thread is ui or background")
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

/* ---- the design as text (::RESOURCE oodDesign) ---------------------------- */

::method resourceLines
  expose form controls vars events methods requires shared
  out = .array~new
  out~append("designer version="self~module_version)
  out~append("form name="oodQ(form["NAME"]) "title="oodQ(form["TITLE"]) "w="form["W"] "h="form["H"] "style="oodQ(form["STYLE"]))
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
      if p \== "" then line = line p"="oodQ(c~prop(p))
    end
    if c~prop("page") \== "" then line = line "page="c~prop("page")
    out~append(line)
  end
  do m over methods
    out~append("method name="m["NAME"])
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
  inRes = .false
  do l over lines
    s = l~strip
    if inRes then do
      if s~caselessEquals("::END") then inRes = .false
      else res~append(l)
    end
    else do
      if s~upper~space == "::RESOURCE OODDESIGN" then inRes = .true
    end
  end
  if res~items = 0 then raise syntax 93.900 array("No ::RESOURCE oodDesign in this program")
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
      when f["*"] == "requires" then d~addRequire(f["FILE"])
      when f["*"] == "shared" then d~setShared(f["NAME"], oodAt(f, "VALUE"))
      when f["*"] == "control" then d~readControl(f)
      when f["*"] == "event" then evs~append(f)
      when f["*"] == "method" then do
        code = oodMethodBody(lines, f["NAME"])
        if code == .nil then raise syntax 93.900 array("Method" f["NAME"] "is missing")
        d~setMethod(f["NAME"], code)
      end
      otherwise raise syntax 93.900 array("Unknown design line:" l)
    end
  end
  -- event code: the body of each event's method, less what the generator adds
  do f over evs
    m = d~methodName(f["CONTROL"], f["EVENT"])
    code = oodMethodBody(lines, m)
    if code == .nil then raise syntax 93.900 array("Method" m "of event" f["CONTROL"] f["EVENT"] "is missing")
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
  expose form controls vars events methods requires shared
  use strict arg filter = .nil
  nm = form["NAME"]
  out = .array~new
  out~append("/*" nm".rex -- an ooDialog program made with the ooDialog Designer" self~module_version)
  out~append("   Design: the ::RESOURCE oodDesign at the end.  The designer writes this")
  out~append("   whole file; what you type is the body of each event method.")
  out~append("   ooDialog Designer -- architecture: Tom Dyer; code: Claude (Opus 5.5). */")
  out~append("dlg = ."nm"~new")
  out~append("if dlg~initCode \= 0 then return dlg~initCode")
  out~append("return dlg~execute(""SHOWTOP"")")
  out~append("")
  out~append("::requires ""ooDialog.cls""")
  do r over requires
    out~append("::requires" oodRx(r))
  end
  out~append("")
  out~append("::class" nm "subclass UserDialog")
  out~append("")
  if shared~items > 0 then out~append("::attribute sharedScope        -- reach it in any method with: expose sharedScope")
  do v over vars
    out~append("::attribute" v["NAME"])
  end
  do c over controls
    if c~type == "TIMER" then out~append("::attribute" c~name"_enabled")
  end
  out~append("")
  -- init: variables, the dialog template, data attributes' first values
  out~append("::method init")
  out~append("  forward class (super) continue")
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
  out~append("  self~create(0, 0," form["W"]"," form["H"]"," oodRx(form["TITLE"])"," oodRx(form["STYLE"])")")
  do c over controls
    if c~kind~args~wordpos("attr") = 0 then iterate
    if c~type == "EDIT" then out~append("  self~"c~name"_data =" oodRx(c~prop("text")))
    if c~type == "CHECKBOX" | c~type == "RADIOBUTTON" then out~append("  self~"c~name"_data =" oodNum(c~prop("checked")))
  end
  out~append("")
  -- defineDialog: the controls and their events
  out~append("::method defineDialog")
  do c over controls
    k = c~kind
    if k~nonvisual then iterate
    line = "  self~"k~create"("c~dlgId"," c~x"," c~y"," c~w"," c~h"," oodRx(c~opts)
    do a over k~args~makeArray(" ")
      if a == "text" then line = line"," oodRx(c~prop("text"))
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
    out~append("  self~"c~kind~connect"("c~dlgId"," oodRx(e["EVENT"])"," oodRx(self~methodName(c~name, e["EVENT"]))")")
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
    if c~type == "LISTBOX" | c~type == "COMBOBOX" then do
      if c~prop("items") \== "" then do
        do item over c~prop("items")~makeArray("|")
          out~append("  self~"c~name"~add("oodRx(item)")")
        end
      end
    end
    if c~type == "PROGRESSBAR" then do
      out~append("  self~"c~name"~setRange("c~prop("min")"," c~prop("max")")")
      out~append("  self~"c~name"~setPos("c~prop("pos")")")
    end
    if c~type == "LISTVIEW" then do
      if c~prop("exstyles") \== "" then out~append("  self~"c~name"~addExtendedStyle("oodRx(c~prop("exstyles"))")")
      i = 0
      do col over c~prop("columns")~makeArray("|")
        parse var col title ":" width
        if width == "" then width = 50
        out~append("  self~"c~name"~insertColumn("i"," oodRx(title)"," width")")
        i = i + 1
      end
      if c~prop("rows") \== "" then do
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
      out~append("  self~"c~name"~addSequence("line")")
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
  out~append("::resource oodDesign")
  do l over self~resourceLines
    out~append(l)
  end
  out~append("::END")
  return out~makeString("L", "0a"x) || "0a"x

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
    out~append("  menu~addPopup("9000 + pn"," oodRx(p)"," oodRx(flags)")")
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
        line = "  menu~addItem("c~id"," oodRx(c~prop("text"))"," oodRx(flags)
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
  return out~makeString("L", "0a"x)


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
    if eq = 0 then raise syntax 93.900 array("Expected key=value in:" line)
    key = rest~left(eq - 1)~strip~upper
    rest = rest~substr(eq + 1)
    if rest~left(1) == '"' then do
      val = ""
      p = 2
      closed = .false
      do while \closed
        q = rest~pos('"', p)
        if q = 0 then raise syntax 93.900 array("Unclosed quote in:" line)
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
    if l~strip~left(2) == "::" then raise syntax 93.900 array("A line of code cannot start with ::")
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
kind type=PUSHBUTTON label="Push button" prefix=btn create=createPushButton access=newPushButton args=text w=50 h=14 text=Button events=CLICKED connect=connectButtonEvent opts="DEFAULT GROUP NOTAB DISABLED HIDDEN" props="text role opts"
kind type=STATIC label=Text prefix=lbl create=createStaticText access=newStatic args=text w=60 h=10 text=Text opts="LEFT RIGHT CENTER GROUP DISABLED HIDDEN" props="text opts"
kind type=EDIT label="Entry field" prefix=txt create=createEdit access=newEdit args=attr w=80 h=12 events="CHANGE UPDATE" connect=connectEditEvent opts="READONLY RIGHT CENTER PASSWORD MULTILINE NUMBER UPPER GROUP NOTAB DISABLED HIDDEN" props="text opts"
kind type=CHECKBOX label="Check box" prefix=chk create=createCheckBox access=newCheckBox args="text attr" w=60 h=10 text=Check events=CLICKED connect=connectButtonEvent opts="GROUP NOTAB DISABLED HIDDEN" props="text checked opts"
kind type=RADIOBUTTON label="Radio button" prefix=opt create=createRadioButton access=newRadioButton args="text attr" w=60 h=10 text=Option events=CLICKED connect=connectButtonEvent opts="GROUP NOTAB DISABLED HIDDEN" props="text checked groupstart opts"
kind type=GROUPBOX label="Group box" prefix=grp create=createGroupBox access=newGroupBox args=text w=100 h=50 text=Group opts="HIDDEN" props="text opts"
kind type=LISTBOX label="List box" prefix=lst create=createListBox access=newListBox args=attr w=80 h=50 events="SELCHANGE DBLCLK" connect=connectListBoxEvent opts="SORT MULTI GROUP NOTAB DISABLED HIDDEN" props="items opts"
kind type=COMBOBOX label="Combo box" prefix=cbo create=createComboBox access=newComboBox args=attr w=80 h=60 events=SELCHANGE connect=connectComboBoxEvent opts="LIST SIMPLE SORT GROUP NOTAB DISABLED HIDDEN" defopts=LIST props="items opts"
kind type=PROGRESSBAR label="Progress bar" prefix=prg create=createProgressBar access=newProgressBar args="" w=100 h=10 opts="SMOOTH VERTICAL HIDDEN" props="min max pos opts"
kind type=LISTVIEW label="List view" prefix=lv create=createListView access=newListView args="" w=120 h=60 events="SELECTCHANGED COLUMNCLICK CHECKBOXCHANGED" connect=connectListViewEvent opts="REPORT LIST ICON SMALLICON SINGLESEL SHOWSELALWAYS GROUP NOTAB DISABLED HIDDEN" defopts="REPORT SHOWSELALWAYS" exopts="FULLROWSELECT GRIDLINES CHECKBOXES" props="columns rows exstyles opts"
kind type=TAB label="Tab strip" prefix=tab create=createTab access=newTab args="" w=120 h=14 events=SELCHANGE connect=connectTabEvent opts="BUTTONS MULTILINE GROUP NOTAB DISABLED HIDDEN" props="tabs opts"
kind type=TREEVIEW label="Tree view" prefix=tv create=createTreeView access=newTreeView args="" w=100 h=60 events=SELCHANGED connect=connectTreeViewEvent opts="LINES BUTTONS ATROOT SHOWSELALWAYS GROUP NOTAB DISABLED HIDDEN" defopts="LINES BUTTONS ATROOT SHOWSELALWAYS" props="nodes opts"
kind type=TRACKBAR label="Track bar" prefix=trk create=createTrackBar access=newTrackBar args="" w=100 h=16 opts="HORIZONTAL VERTICAL AUTOTICKS NOTICKS BOTH TOP BOTTOM GROUP NOTAB DISABLED HIDDEN" defopts="HORIZONTAL AUTOTICKS" props="min max pos opts"
kind type=DATETIME label="Date picker" prefix=dtp create=createDateTimePicker access=newDateTimePicker args="" w=80 h=12 events=DATETIMECHANGE connect=connectDateTimePickerEvent opts="SHORT LONG TIME SHOWNONE UPDOWN GROUP NOTAB DISABLED HIDDEN" defopts=SHORT props="opts"
kind type=MENUITEM label="Menu item" prefix=mnu nonvisual=1 events=CLICKED props="popup text checked grayed"
kind type=TIMER label="Timer thread" prefix=tmr nonvisual=1 events=TICK props="interval enabled"
form events="INIT OK CANCEL"
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
action types=TAB label="The selected tab (1 = first)" code="page = self~%n~selectedIndex + 1"
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
