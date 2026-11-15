/* OodPlugins.cls -- optional extras for the ooDialog Designer and the ooRexx
   Object Editor: plugins, none of them loaded until it is switched on.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   A plugin is an ooRexx class, a subclass of OodPlugin, in its own files.
   plugins/index.txt lists the plugins there are:

     plugin bostoncrab
       class = BostonCrabPlugin
       main = bostoncrab/BostonCrabPlugin.cls
       files = bostoncrab/BostonCrabPlugin.cls bostoncrab/PitfallChecker.cls
       provides = diagnose fix
       title.en = Boston Crab: ooRexx pitfalls
       title.de = Boston Crab: ooRexx-Fallen
       summary.en = ...

   The host reads the index, and on enable(id) reads the plugin's files (from
   a folder, or over http(s) in the browser, where it writes them to
   /home/rexx/plugins/ first), loads the main file and makes the plugin.
   What a plugin can do, by the words in "provides":
     diagnose   diagnose(lines, context) -> an array of OodFinding
     fix        fix(lines, fixId) -> the lines fixed
     assist     (code assistance; see its plugin)
     scm        (source control; see its plugin)
   A plugin's settings (settingLines, setSetting) are shown by the page; a
   setting of kind "secret" is never kept by the plugin or the page: it goes
   to the host's secret store (OodSecrets), which the plugin asks by name.
   A plugin's texts are its own ::RESOURCE strings.<language>, read by OodNls,
   in the designer's language. */

::requires "OodNls.cls"

::class OodPlugin public inherit OodNls
::method module_version class
  return "0.8.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.8.0"
::method module_lastChanged
  return "2026-11-15"

::attribute id get
::attribute host
::attribute settings get

::method init
  expose id settings
  use strict arg id
  settings = .directory~new

-- the plugin's own string tables: a subclass answers its package's
::method resources
  return .resources

::method language
  use strict arg lang = ""
  return self~nlsUse(lang, "en", self~resources)

-- what it does: words of diagnose fix assist scm
::method provides
  return ""

-- its settings, one per line: key TAB kind (text, secret, choice:a|b) TAB label
::method settingLines
  return ""

::method setSetting
  expose settings
  use strict arg key, value
  settings[key~upper] = value
  return value

::method setting
  expose settings
  use strict arg key, default = ""
  v = settings[key~upper]
  if v == .nil then return default
  return v

::method diagnose
  use strict arg lines, context = ""
  return .array~new

::method fix
  use strict arg lines, fixId
  return lines


/* One thing a plugin found: where, what, and the fix it offers ("" for none). */
::class OodFinding public
::attribute plugin
::attribute rule
::attribute line
::attribute column
::attribute severity       -- error, warning, note
::attribute message
::attribute fixId
::method init
  expose plugin rule line column severity message fixId
  use strict arg plugin, rule, line, column, severity, message, fixId = ""
::method asLine
  expose plugin rule line column severity message fixId
  return plugin || "09"x || rule || "09"x || line || "09"x || column || "09"x || severity || "09"x || fixId || "09"x || message
::method module_version class
  return "0.8.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.8.0"
::method module_lastChanged
  return "2026-11-15"


/* The secrets plugins may ask for by name (an API key, a token).  They are
   held in this session's memory only: never written to a file, never sent to
   the page again.  OodSecrets is the session provider for the estate's Secret
   Broker (oorexx_secret_broker): acquire(reference) answers the value to a
   trusted consumer; a server-brokered provider sits behind the same names. */
::class OodSecrets public
::attribute provider class           -- the provider used: this class's own, or another
::method module_version class
  return "0.8.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.8.0"
::method module_lastChanged
  return "2026-11-15"
::method init
  expose values
  values = .directory~new
::method put
  expose values
  use strict arg reference, value
  if value == "" then values~remove(reference~upper)
  else values[reference~upper] = value
  return 0
::method has
  expose values
  use strict arg reference
  return values~hasIndex(reference~upper)
::method acquire
  expose values
  use strict arg reference
  v = values[reference~upper]
  if v == .nil then raise syntax 93.900 array(oodT("plug.err.noSecret", reference))
  return v
-- what the page may see: the names set, never the values
::method referenceLines
  expose values
  return values~allIndexes~sort~makeString("L", "0a"x)


::class OodPluginHost public
::method module_version class
  return "0.8.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.8.0"
::method module_lastChanged
  return "2026-11-15"

::attribute base get
::attribute secrets get
::attribute lang

-- base: the folder or the http(s) address plugins/index.txt is in
::method init
  expose base catalogue order loaded secrets lang
  use strict arg base, lang = "en"
  base = base~strip("T", "/")
  catalogue = .directory~new
  order = .array~new
  loaded = .directory~new
  secrets = .OodSecrets~new
  self~readIndex
  return

::method readIndex
  expose catalogue order
  cur = .nil
  do l over self~readText("index.txt")~changeStr("0d0a"x, "0a"x)~makeArray("0a"x)
    s = l~strip
    if s == "" | s~left(2) == "--" then iterate
    if s~word(1) == "plugin" then do
      cur = .directory~new
      cur["ID"] = s~word(2)
      catalogue[s~word(2)~upper] = cur
      order~append(s~word(2))
      iterate
    end
    if cur == .nil then iterate
    parse var s key "=" value
    cur[key~strip~upper] = value~strip
  end
  return

-- a file of the plugins' folder, as text
::method readText
  expose base
  use strict arg rel
  where = base"/"rel
  if where~left(5)~caselessEquals("http:") | where~left(6)~caselessEquals("https:") then do
    if \.local~hasIndex("OODFETCHLOADED") then do      -- the browser's fetch, only when needed
      call loadFetch
      .local~oodFetchLoaded = .true
    end
    address fetch "TIMEOUT 30"
    address fetch "GET" where "INTO body"
    if rc \= 0 then raise syntax 93.900 array(oodT("plug.err.read", where, rc))
    return body
  end
  s = .stream~new(where)
  if s~query("exists") == "" then raise syntax 93.900 array(oodT("plug.err.read", where, "-"))
  s~open("read")
  t = s~charIn(1, s~chars)
  s~close
  return t

-- each plugin: id TAB title TAB summary TAB provides TAB enabled
::method catalogueLines
  expose catalogue order loaded lang
  out = .array~new
  do id over order
    e = catalogue[id~upper]
    on = 0
    if loaded~hasIndex(id~upper) then on = 1
    out~append(id || "09"x || self~about(e, "TITLE") || "09"x || self~about(e, "SUMMARY") || "09"x || oodAt2(e, "PROVIDES") || "09"x || on)
  end
  return out~makeString("L", "0a"x)

-- title.<lang> or title.en
::method about
  expose lang
  use strict arg e, what
  v = e[what"."lang~left(2)~upper]
  if v == .nil then v = e[what".EN"]
  if v == .nil then v = ""
  return v

::method enable
  expose catalogue loaded base lang
  use strict arg id
  e = catalogue[id~upper]
  if e == .nil then raise syntax 93.900 array(oodT("plug.err.none", id))
  if loaded~hasIndex(id~upper) then return loaded[id~upper]
  main = oodAt2(e, "MAIN")
  files = oodAt2(e, "FILES")
  if files == "" then files = main
  if base~left(4)~caselessEquals("http") then do
    -- over http(s): its files written beside each other, then loaded
    local = "/home/rexx/plugins"
    do f over files~space~makeArray(" ")
      text = self~readText(f)
      call writeFile local"/"f, text
    end
    path = local"/"main
  end
  else path = base"/"main
  pkg = .context~package~loadPackage(path)
  cls = pkg~findClass(oodAt2(e, "CLASS"))
  if cls == .nil then raise syntax 93.900 array(oodT("plug.err.class", oodAt2(e, "CLASS"), main))
  p = cls~new(id)
  p~host = self
  p~language(lang)
  loaded[id~upper] = p
  return p

::method disable
  expose loaded
  use strict arg id
  loaded~remove(id~upper)
  return 0

::method plugin
  expose loaded
  use strict arg id
  p = loaded[id~upper]
  if p == .nil then raise syntax 93.900 array(oodT("plug.err.off", id))
  return p

-- the enabled plugins, in the index's order
::method enabledIds
  expose order loaded
  out = .array~new
  do id over order
    if loaded~hasIndex(id~upper) then out~append(id)
  end
  return out~makeString("L", " ")

::method setLanguage
  expose loaded lang
  use strict arg l
  lang = l
  do p over loaded~allItems
    p~language(l)
  end
  return 0

-- every enabled plugin's findings for the text, one line each (OodFinding~asLine),
-- by line then column
::method diagnose
  expose order loaded
  use strict arg text, context = ""
  lines = text~changeStr("0d0a"x, "0a"x)~makeArray("0a"x)
  all = .array~new
  do id over order
    p = loaded[id~upper]
    if p == .nil then iterate
    if p~provides~wordpos("diagnose") = 0 then iterate
    do f over p~diagnose(lines, context)
      all~append(f)
    end
  end
  return self~findingLines(all)

::method findingLines
  use strict arg all
  out = .array~new
  do f over all~sortWith(.OodFindingOrder~new)
    out~append(f~asLine)
  end
  return out~makeString("L", "0a"x)

-- the text with one finding of one plugin fixed
::method fix
  use strict arg id, text, fixId
  lines = text~changeStr("0d0a"x, "0a"x)~makeArray("0a"x)
  return self~plugin(id)~fix(lines, fixId)~makeString("L", "0a"x)

-- one plugin's settings: key TAB kind TAB label TAB value ("(set)" for a secret
-- that is set: its value never comes back)
::method settingLines
  expose secrets
  use strict arg id
  p = self~plugin(id)
  out = .array~new
  do l over p~settingLines~makeArray("0a"x)
    if l == "" then iterate
    parse var l key "09"x kind "09"x label
    if kind == "secret" then do
      v = ""
      if secrets~has(p~setting(key, key)) then v = "(set)"
    end
    else v = p~setting(key)
    out~append(key || "09"x || kind || "09"x || label || "09"x || v)
  end
  return out~makeString("L", "0a"x)

-- a setting; a secret goes to the secret store under the reference the plugin names
::method setSetting
  expose secrets
  use strict arg id, key, value
  p = self~plugin(id)
  kind = ""
  do l over p~settingLines~makeArray("0a"x)
    if l~left(length(key) + 1)~caselessEquals(key || "09"x) then parse var l . "09"x kind "09"x .
  end
  if kind == "secret" then do
    secrets~put(p~setting(key, key), value)
    return ""
  end
  return p~setSetting(key, value)


::class OodFindingOrder public
::method compare
  use strict arg a, b
  if a~line < b~line then return -1
  if a~line > b~line then return 1
  if a~column < b~column then return -1
  if a~column > b~column then return 1
  return 0

::routine oodAt2
  use strict arg d, key
  v = d[key]
  if v == .nil then return ""
  return v

::routine loadFetch
  .context~package~loadPackage("fetch.cls")      -- ADDRESS FETCH: ooRexx/WASM's
  return

::routine writeFile
  use strict arg path, text
  dir = path~left(path~lastPos("/") - 1)
  call makeDirs dir
  s = .stream~new(path)
  s~open("write replace")
  s~charOut(text)
  s~close
  return

::routine makeDirs
  use strict arg dir
  if dir == "" then return
  if SysIsFileDirectory(dir) then return
  call makeDirs dir~left(dir~lastPos("/") - 1)
  call SysMkDir dir
  return

::requires "OodUi.cls"
