/*----------------------------------------------------------------------------*/
/* ObjectEditor.cls -- the ooRexx Object Editor's model.                      */
/*                                                                            */
/* Architecture: Tom Dyer.  Code: Claude (Opus 5.5).                          */
/*                                                                            */
/* What a class file holds is found by examining the objects, not by reading  */
/* the text: the file is loaded into the running interpreter with             */
/* .Package~new(name, source), and its classes, their superclasses, mixins    */
/* and subclasses, their methods and attributes with their scope (public,     */
/* private, package), guard, class or instance side, abstract, and the        */
/* classes its ::requires bring in, are read back by reflection.              */
/*                                                                            */
/* The text is kept as directive segments (OxSource) only so that an edit     */
/* changes the lines it means to and leaves the rest -- comments, blank lines */
/* -- as they were.  Every structural edit is reloaded at once; one that      */
/* does not compile is undone and refused with ooRexx's own message.          */
/*                                                                            */
/* Completion asks the objects too: self~ lists this class's methods with     */
/* those it inherits, .Name~ the class object's methods, x~ the methods of    */
/* x's class when x = .Name~new... comes before it, and a ::requires adds     */
/* its library's public classes to all of it.                                 */
/*----------------------------------------------------------------------------*/

::class OxModule public mixinclass Object
::method module_version class
  return "0.5.0"
::method module_lastChanged class
  return "2026-11-17"
::method module_version
  return "0.5.0"
::method module_lastChanged
  return "2026-11-17"


/* One directive and the lines under it, or the prolog before the first one. */
::class OxSegment public inherit OxModule
::attribute kind            -- PROLOG REQUIRES CLASS METHOD ATTRIBUTE CONSTANT ROUTINE RESOURCE OPTIONS OTHER
::attribute name            -- as written (a method's name without quotes)
::attribute owner           -- the class a member belongs to, "" otherwise
::attribute scope           -- INSTANCE or CLASS, for members
::attribute header          -- the directive line ("" for the prolog)
::attribute body            -- .Array of the lines under it
::method init
  expose kind name owner scope header body
  use strict arg kind, name = "", owner = "", scope = "INSTANCE", header = ""
  body = .array~new
-- the words after the name, upper case
::method options
  expose header
  parse var header . . rest
  return rest~upper~space
::method key
  expose kind name owner scope
  return (kind owner scope name)~upper


/* A class file as directive segments. */
::class OxSource public inherit OxModule
::attribute segments
::method init
  expose segments
  use strict arg text
  segments = .array~new
  lines = text~changeStr("0d0a"x, "0a"x)~changeStr("0d"x, "0a"x)~makeArray("0a"x)
  cur = .OxSegment~new("PROLOG")
  segments~append(cur)
  owner = ""
  inResource = .false
  do l over lines
    s = l~strip
    if inResource then do
      cur~body~append(l)
      if s~caselessEquals("::END") then inResource = .false
      iterate
    end
    if s~left(2) \== "::" then do
      cur~body~append(l)
      iterate
    end
    kw = s~word(1)~substr(3)~upper
    nm = s~word(2)~strip("B", '"')~strip("B", "'")
    kind = "OTHER"
    if wordpos(kw, "REQUIRES CLASS METHOD ATTRIBUTE CONSTANT ROUTINE RESOURCE OPTIONS") > 0 then kind = kw
    scope = "INSTANCE"
    segOwner = ""
    if wordpos(kind, "METHOD ATTRIBUTE CONSTANT") > 0 then do
      segOwner = owner
      parse var s . . opts
      if wordpos("CLASS", opts~upper) > 0 then scope = "CLASS"
    end
    if kind == "CLASS" then owner = nm
    if kind == "RESOURCE" then inResource = .true
    cur = .OxSegment~new(kind, nm, segOwner, scope, l)
    segments~append(cur)
  end
  -- the split leaves one empty line for the file's last newline: keep it out
  last = segments~lastItem
  if last~body~items > 0 then do
    if last~body~lastItem == "" then last~body~delete(last~body~last)
  end

::method text
  expose segments
  out = .array~new
  do g over segments
    if g~kind \== "PROLOG" then out~append(g~header)
    do l over g~body
      out~append(l)
    end
  end
  return out~makeString("L", "0a"x) || "0a"x

::method lines
  return self~text~makeArray("0a"x)

::method find
  expose segments
  use strict arg kind, owner, name, scope = "INSTANCE"
  want = (kind owner scope name)~upper
  do g over segments
    if g~key == want then return g
  end
  return .nil

-- a member of a class: METHOD, ATTRIBUTE or CONSTANT, on either side
::method findMember
  expose segments
  use strict arg owner, name, scope
  do g over segments
    if wordpos(g~kind, "METHOD ATTRIBUTE CONSTANT") = 0 then iterate
    if \g~owner~caselessEquals(owner) then iterate
    if \g~name~caselessEquals(name) then iterate
    if g~scope \== scope~upper then iterate
    return g
  end
  return .nil

-- insert seg after the class's last member (or the class line itself)
::method addToClass
  expose segments
  use strict arg cls, seg
  at = 0
  do i = 1 to segments~items
    g = segments[i]
    if g~kind == "CLASS" then do
      if g~name~caselessEquals(cls) then at = i
    end
    if at > 0 then do
      if g~owner~caselessEquals(cls) then at = i
    end
  end
  if at = 0 then raise syntax 93.900 array(oxT("ox.err.noClassHere", cls))
  segments~insert(seg, at)
  return seg

-- ::requires go after the last ::requires, or before the first directive
::method addRequires
  expose segments
  use strict arg seg
  at = 1
  do i = 1 to segments~items
    if segments[i]~kind == "REQUIRES" then at = i
  end
  segments~insert(seg, at)
  return seg

::method addAtEnd
  expose segments
  use strict arg seg
  -- before a trailing ::resource, if any, so resources stay last
  at = segments~items
  do i = segments~items to 2 by -1
    if segments[i]~kind == "RESOURCE" then at = i - 1
    else leave
  end
  segments~insert(seg, at)
  return seg

::method remove
  expose segments
  use strict arg seg
  i = segments~index(seg)
  if i \== .nil then segments~delete(i)
  return 0

-- the class's own segments, the class line first
::method classSegments
  expose segments
  use strict arg cls
  out = .array~new
  do g over segments
    if g~kind == "CLASS" then do
      if g~name~caselessEquals(cls) then out~append(g)
    end
    else do
      if g~owner~caselessEquals(cls) then out~append(g)
    end
  end
  return out


/* The editor: a file, the package it compiles to, and what reflection finds. */
::class OxWorkspace public inherit OxModule
::attribute fileName
::attribute source          -- OxSource
::attribute pkg             -- the .Package of the last good load
::attribute lastError       -- "" or ooRexx's message for the last failed load
::attribute caseMap         -- .Directory  upper name -> name as written, per package source

::method init
  expose fileName source pkg lastError caseMap
  use strict arg fileName, text = ""
  if text == "" then text = .OxWorkspace~template(fileName)
  source = .OxSource~new(text)
  pkg = .nil
  lastError = ""
  caseMap = .directory~new
  if \self~load then raise syntax 93.900 array(oxT("ox.err.compile", lastError))

-- a starting data object: two attributes and an init
::method template class
  use strict arg fileName
  parse value fileName~substr(fileName~lastPos("/") + 1) with stem "."
  if stem == "" then stem = "DataObject"
  if stem~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789") > 0 then stem = "DataObject"
  t = .array~new
  t~append("/*" fileName "*/")
  t~append("")
  t~append("::class" stem "public")
  t~append("::attribute name")
  t~append("::attribute created")
  t~append("::method init")
  t~append("  expose name created")
  t~append("  use strict arg name")
  t~append("  created = .DateTime~new")
  return t~makeString("L", "0a"x) || "0a"x

::method text
  expose source
  return source~text

-- Compile the text into a package.  .true when it compiles; otherwise
-- lastError holds ooRexx's message and the last good package stays.
::method load
  expose fileName source pkg lastError caseMap
  signal on syntax name loadFailed
  -- Package~new runs the prolog: a program's main code would run (an
  -- ooDialog program would show its dialog).  Examining must not run it, so
  -- the prolog's lines are given blank; the line numbers stay the same.
  lines = source~lines
  n = source~segments[1]~body~items
  do i = 1 to min(n, lines~items)
    lines[i] = ""
  end
  p = .Package~new(fileName, lines)
  pkg = p
  lastError = ""
  caseMap = .directory~new
  return .true
loadFailed:
  c = condition("O")
  msg = "Error" c["CODE"]
  if c~hasIndex("POSITION") then msg = msg "line" c["POSITION"]
  msg = msg":" c["ERRORTEXT"]
  if c["MESSAGE"] \== .nil then msg = msg "--" c["MESSAGE"]
  lastError = msg
  return .false

-- Run an edit on the source; if the result does not compile, put the text
-- back and refuse with ooRexx's message.
::method structural
  expose source
  use strict arg editMessage, editArgs
  before = source~text
  signal on syntax name editRefused
  self~sendWith(editMessage, editArgs)
  signal off syntax
  if self~load then return 0
  err = self~lastError
  source = .OxSource~new(before)
  self~load
  raise syntax 93.900 array(oxT("ox.err.notDone", err))
editRefused:
  source = .OxSource~new(before)
  self~load
  raise propagate

/* ---- reflection ----------------------------------------------------------- */

-- the file's own classes, in the order the file defines them
::method classNames
  expose source pkg
  out = .array~new
  do g over source~segments
    if g~kind == "CLASS" then do
      if pkg~classes~hasIndex(g~name~upper) then out~append(g~name)
    end
  end
  return out~makeString("L", " ")

::method classObject
  expose pkg
  use strict arg name
  name = name~strip("L", ".")
  c = pkg~findClass(name)
  if c == .nil then c = .environment~at(name~upper)
  if c == .nil then raise syntax 93.900 array(oxT("ox.err.unknownClass", name))
  if \c~isA(.Class) then raise syntax 93.900 array(oxT("ox.err.notClass", name))
  return c

-- The ooRexxDoc of a class and its members (OxDocs~docsOf), "" when its
-- package has no source.  OxDocs.cls, with the Rexx Parser, is loaded the
-- first time docs are asked for, not with the editor.
::method docsOf
  expose oxDocs source pkg
  use strict arg name
  if \var("OXDOCS") then oxDocs = .nil
  if oxDocs == .nil then oxDocs = .context~package~loadPackage("OxDocs.cls")~findClass("OxDocs")~new
  c = self~classObject(name)
  if c~package == pkg then return oxDocs~docsOf(c, source~lines)   -- as written, prolog too
  return oxDocs~docsOf(c)

-- name, super, mixins, ismixin, public, abstract, package (tab separated)
::method classInfo
  expose pkg
  use strict arg name
  c = self~classObject(name)
  sup = c~superClass
  supName = ""
  if sup \== .nil then supName = self~nameOf(sup)
  mixins = ""
  sc = c~superclasses
  do i = 2 to sc~items
    mixins = mixins self~nameOf(sc[i])
  end
  isPublic = 0
  if pkg~publicClasses~hasIndex(c~id~upper) then isPublic = 1
  isAbstract = 0
  if c~isAbstract then isAbstract = 1
  pn = ""
  if c~package \== .nil then pn = c~package~name
  return self~nameOf(c) || "09"x || supName || "09"x || mixins~strip || "09"x || (c~queryMixinClass)~string || "09"x || isPublic || "09"x || isAbstract || "09"x || pn

-- The chain from Object down to the class: depth, name, mixins, package.
::method hierarchy
  use strict arg name
  c = self~classObject(name)
  chain = .array~new
  do while c \== .nil
    chain~insert(c, .nil)
    c = c~superClass
  end
  out = .array~new
  do i = 1 to chain~items
    k = chain[i]
    mixins = ""
    sc = k~superclasses
    do j = 2 to sc~items
      mixins = mixins self~nameOf(sc[j])
    end
    pn = ""
    if k~package \== .nil then pn = k~package~name
    out~append((i - 1) || "09"x || self~nameOf(k) || "09"x || mixins~strip || "09"x || pn)
  end
  return out~makeString("L", "0a"x)

-- the subclasses of a class among this file's classes
::method subclassNames
  expose pkg
  use strict arg name
  c = self~classObject(name)
  out = .array~new
  do s over c~subclasses
    if pkg~classes~hasIndex(s~id~upper) then do
      if pkg~classes[s~id~upper] == s then out~append(self~nameOf(s))
    end
  end
  return out~makeString("L", " ")

-- the classes reflection should look in, in the order a message finds
-- methods: the class, its mixins, then its superclass and so on
::method lookupOrder
  use strict arg c
  order = .array~new
  seen = .identityTable~new
  self~addLookup(c, order, seen)
  return order
::method addLookup
  use strict arg c, order, seen
  if seen~hasIndex(c) then return
  seen[c] = c
  order~append(c)
  sc = c~superclasses
  do i = 2 to sc~items
    self~addMixin(sc[i], order, seen)
  end
  if sc~items > 0 then self~addLookup(sc[1], order, seen)
  return
-- a mixin brings its own methods and its mixins', not its base class's:
-- the base class comes in the main chain
::method addMixin
  use strict arg m, order, seen
  if seen~hasIndex(m) then return
  seen[m] = m
  order~append(m)
  sc = m~superclasses
  do i = 2 to sc~items
    self~addMixin(sc[i], order, seen)
  end
  return

-- Members as the object has them, tab separated (a method may be named ||):
-- name, kind, visibility, guard, abstract, definedIn, own
-- kind METHOD, ATTRIBUTE (both its methods as one), CONSTANT; scope INSTANCE
-- or CLASS (the class object's methods).  Own members first, in file order.
::method members
  use strict arg name, scope = "INSTANCE", withInherited = .true
  c = self~classObject(name)
  scope = scope~upper
  out = .array~new
  seen = .set~new
  sources = self~lookupOrder(c)
  -- the class object finds its own class methods and its superclasses',
  -- then those of .Class, then those of .Object
  if scope == "CLASS" then do
    sources~removeItem(.Object)
    sources = sources~makeArray
    sources~append(.Class)
    sources~append(.Object)
  end
  do k over sources
    if k \== c then do
      if \withInherited then leave
    end
    if scope == "CLASS" then sup = c~instanceMethods(k)
    else sup = k~methods(k)
    found = .array~new
    do while sup~available
      found~append(.array~of(sup~index, sup~item))
      sup~next
    end
    found = self~fileOrder(k, scope, found)
    do pair over found
      mname = pair[1]
      m = pair[2]
      base = mname
      kind = "METHOD"
      if m~isAttribute then do
        kind = "ATTRIBUTE"
        if base~right(1) == "=" then base = base~left(base~length - 1)
      end
      if m~isConstant then kind = "CONSTANT"
      if seen~hasIndex(base) then iterate
      seen~put(base)
      vis = "public"
      if m~isPrivate then vis = "private"
      if m~isPackage then vis = "package"
      guard = "guarded"
      if \m~isGuarded then guard = "unguarded"
      abstract = 0
      if m~isAbstract then abstract = 1
      own = 0
      if k == c then own = 1
      out~append(self~caseOf(k, base) || "09"x || kind || "09"x || vis || "09"x || guard || "09"x || abstract || "09"x || self~nameOf(k) || "09"x || own)
    end
  end
  return out~makeString("L", "0a"x)

-- reflection gives no order: use the order of the defining package's text
::method fileOrder
  use strict arg k, scope, found
  pk = k~package
  if pk == .nil then return self~sortPairs(found)
  src = pk~source
  if src == .nil then return self~sortPairs(found)
  pos = .directory~new
  n = 0
  inClass = .false
  do l over src
    s = l~strip
    if s~left(2) \== "::" then iterate
    kw = s~word(1)~upper
    if kw == "::CLASS" then inClass = s~word(2)~strip("B", '"')~caselessEquals(k~id)
    if \inClass then iterate
    if wordpos(kw, "::METHOD ::ATTRIBUTE ::CONSTANT") = 0 then iterate
    nm = s~word(2)~strip("B", '"')~strip("B", "'")~upper
    n = n + 1
    if \pos~hasIndex(nm) then pos[nm] = n
    if kw == "::ATTRIBUTE" then do
      if \pos~hasIndex(nm"=") then pos[nm"="] = n
    end
  end
  ranked = .array~new
  rest = .array~new
  do pair over found
    if pos~hasIndex(pair[1]) then ranked~append(pair)
    else rest~append(pair)
  end
  ranked = ranked~sortWith(.OxPairOrder~new(pos))
  do pair over self~sortPairs(rest)
    ranked~append(pair)
  end
  return ranked

::method sortPairs
  use strict arg found
  return found~sortWith(.OxPairOrder~new(.directory~new))

-- the name as the defining package writes it, from that package's source
::method caseOf
  expose caseMap
  use strict arg k, upperName
  pk = k~package
  if pk == .nil then return upperName~lower
  key = pk~name
  map = caseMap~at(key)
  if map == .nil then do
    map = .directory~new
    src = pk~source
    if src \== .nil then do
      do l over src
        s = l~strip
        if s~left(2) \== "::" then iterate
        if wordpos(s~word(1)~upper, "::METHOD ::ATTRIBUTE ::CONSTANT ::CLASS ::ROUTINE") = 0 then iterate
        nm = s~word(2)~strip("B", '"')~strip("B", "'")
        if \map~hasIndex(nm~upper) then map[nm~upper] = nm
      end
    end
    caseMap[key] = map
  end
  v = map~at(upperName)
  if v == .nil then return upperName~lower
  return v

::method nameOf
  use strict arg c
  -- built-in classes keep their case in their id (StringTable); a program's
  -- are upper case there, so their case comes from their package's text
  if c~id \== c~id~upper then return c~id
  return self~caseOf(c, c~id~upper)

-- what the ::requires brought in: file, then its public classes
::method requiresInfo
  expose pkg source
  out = .array~new
  do g over source~segments
    if g~kind \== "REQUIRES" then iterate
    classes = ""
    do ip over pkg~importedPackages
      if self~sameFile(ip~name, g~name) then do
        do n over ip~publicClasses~allIndexes~sort
          classes = classes self~nameOf(ip~publicClasses[n])
        end
      end
    end
    out~append(g~name || "09"x || classes~strip)
  end
  return out~makeString("L", "0a"x)

::method sameFile
  use strict arg full, short
  full = full~changeStr("\", "/")
  short = short~changeStr("\", "/")
  if full~caselessEquals(short) then return .true
  tail = "/" || short
  return full~right(tail~length)~caselessEquals(tail)

-- every class a program in this file can name: its own, those its
-- ::requires make public, and the environment's (.String, .Array, ...)
::method knownClasses
  expose pkg
  out = .directory~new
  do n over .environment~allIndexes
    v = .environment[n]
    if v~isA(.Class) then out[n] = v
  end
  do n over pkg~importedClasses~allIndexes
    out[n] = pkg~importedClasses[n]
  end
  do n over pkg~classes~allIndexes
    out[n] = pkg~classes[n]
  end
  return out

::method knownClassNames
  known = self~knownClasses
  out = .array~new
  do n over known~allIndexes~sortWith(.CaselessComparator~new)
    out~append(self~nameOf(known[n]))
  end
  return out~makeString("L", " ")

/* ---- edits ------------------------------------------------------------------ */

::method checkSymbol
  use strict arg name, what
  if name == "" then raise syntax 93.900 array(oxT("ox.err.name.needed", what))
  if name~left(1)~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_!?") > 0 then
    raise syntax 93.900 array(oxT("ox.err.name.start", what, name))
  if name~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_!?0123456789.") > 0 then
    raise syntax 93.900 array(oxT("ox.err.name.chars", what, name))
  return name

-- the directive words for a member's options
::method memberWords
  use strict arg scope, vis, guard, abstract = 0
  w = ""
  if scope~upper == "CLASS" then w = w "class"
  vis = vis~lower
  if wordpos(vis, "public private package") = 0 then raise syntax 93.900 array(oxT("ox.err.visibility"))
  if vis \== "public" then w = w vis
  guard = guard~lower
  if wordpos(guard, "guarded unguarded") = 0 then raise syntax 93.900 array(oxT("ox.err.guard"))
  if guard == "unguarded" then w = w "unguarded"
  if abstract == 1 then w = w "abstract"
  return w

::method addClass
  use strict arg name, super = "", mixins = "", isPublic = 1, isMixin = 0
  self~checkSymbol(name, "class")
  if self~classNames~caselessPos(name) > 0 then do
    do n over self~classNames~makeArray(" ")
      if n~caselessEquals(name) then raise syntax 93.900 array(oxT("ox.err.classExists", name))
    end
  end
  return self~structural("doAddClass", .array~of(name, super, mixins, isPublic, isMixin))
::method doAddClass
  expose source
  use strict arg name, super, mixins, isPublic, isMixin
  source~addAtEnd(.OxSegment~new("CLASS", name, "", "INSTANCE", self~classHeader(name, super, mixins, isPublic, isMixin)))
  return 0

::method classHeader
  use strict arg name, super, mixins, isPublic, isMixin
  h = "::class" name
  if isPublic == 1 then h = h "public"
  if isMixin == 1 then h = h "mixinclass" self~orObject(super)
  else do
    if super \== "" then do
      if \super~caselessEquals("Object") then h = h "subclass" super
    end
  end
  if mixins~strip \== "" then h = h "inherit" mixins~space
  return h
::method orObject
  use strict arg super
  if super == "" then return "Object"
  return super

-- change a class's superclass, mixins, public and mixinclass
::method setClass
  use strict arg name, super, mixins, isPublic, isMixin
  return self~structural("doSetClass", .array~of(name, super, mixins, isPublic, isMixin))
::method doSetClass
  expose source
  use strict arg name, super, mixins, isPublic, isMixin
  g = source~find("CLASS", "", name)
  if g == .nil then raise syntax 93.900 array(oxT("ox.err.noClassHere2", name))
  g~header = self~classHeader(g~name, super, mixins, isPublic, isMixin)
  return 0

::method addAttribute
  use strict arg cls, name, scope = "INSTANCE", vis = "public", guard = "guarded"
  self~checkSymbol(name, "attribute")
  self~refuseTaken(cls, name, scope)
  return self~structural("doAddMember", .array~of(cls, "ATTRIBUTE", name, scope, vis, guard, 0, ""))

::method addMethod
  use strict arg cls, name, scope = "INSTANCE", vis = "public", guard = "guarded", abstract = 0
  self~checkSymbol(name, "method")
  self~refuseTaken(cls, name, scope)
  body = "  return"
  if abstract == 1 then body = ""
  return self~structural("doAddMember", .array~of(cls, "METHOD", name, scope, vis, guard, abstract, body))

::method addConstant
  use strict arg cls, name, value
  self~checkSymbol(name, "constant")
  self~refuseTaken(cls, name, "INSTANCE")
  return self~structural("doAddConstant", .array~of(cls, name, value))
::method doAddConstant
  expose source
  use strict arg cls, name, value
  source~addToClass(cls, .OxSegment~new("CONSTANT", name, cls, "INSTANCE", "::constant" name value))
  return 0

::method refuseTaken
  expose source
  use strict arg cls, name, scope
  if source~findMember(cls, name, scope) \== .nil then raise syntax 93.900 array(oxT("ox.err.memberExists", cls, name))
  return 0

::method doAddMember
  expose source
  use strict arg cls, kind, name, scope, vis, guard, abstract, body
  h = "::"kind~lower name self~memberWords(scope, vis, guard, abstract)
  g = .OxSegment~new(kind, name, cls, scope~upper, h~strip("T"))
  if body \== "" then do
    do l over body~makeArray("0a"x)
      g~body~append(l)
    end
  end
  source~addToClass(cls, g)
  return 0

-- Change a member's visibility, guard, side or abstract, keeping its other
-- options (get, set, external, ...).
::method setMemberFlags
  use strict arg cls, name, scope, newScope, vis, guard, abstract = 0
  return self~structural("doSetFlags", .array~of(cls, name, scope, newScope, vis, guard, abstract))
::method doSetFlags
  expose source
  use strict arg cls, name, scope, newScope, vis, guard, abstract
  g = source~findMember(cls, name, scope)
  if g == .nil then raise syntax 93.900 array(oxT("ox.err.noOwnSide", cls, name, scope~lower))
  if g~kind == "CONSTANT" then raise syntax 93.900 array(oxT("ox.err.constant"))
  parse value g~header with dir nm rest
  keep = ""
  do w over rest~makeArray(" ")
    if w == "" then iterate
    if wordpos(w~upper, "CLASS PUBLIC PRIVATE PACKAGE GUARDED UNGUARDED ABSTRACT") > 0 then iterate
    keep = keep w
  end
  g~header = (dir nm self~memberWords(newScope, vis, guard, abstract) keep)~space
  g~scope = newScope~upper
  if abstract == 1 then do
    if g~kind == "METHOD" then g~body = .array~new
  end
  return 0

::method removeMember
  use strict arg cls, name, scope
  return self~structural("doRemoveMember", .array~of(cls, name, scope))
::method doRemoveMember
  expose source
  use strict arg cls, name, scope
  g = source~findMember(cls, name, scope)
  if g == .nil then raise syntax 93.900 array(oxT("ox.err.noOwn", cls, name))
  source~remove(g)
  return 0

::method removeClass
  use strict arg name
  return self~structural("doRemoveClass", .array~of(name))
::method doRemoveClass
  expose source
  use strict arg name
  do g over source~classSegments(name)
    source~remove(g)
  end
  return 0

-- the body of an own method as the file has it
::method getBody
  expose source
  use strict arg cls, name, scope
  g = source~findMember(cls, name, scope)
  if g == .nil then raise syntax 93.900 array(oxT("ox.err.noOwn", cls, name))
  body = .array~new
  do l over g~body
    body~append(l)
  end
  do while body~items > 0
    if body~lastItem~strip \== "" then leave
    body~delete(body~last)
  end
  return body~makeString("L", "0a"x)

-- Typing a body is not refused: the text is kept as typed.  The answer is
-- "" when it compiles, else ooRexx's message (reflection keeps the last good load).
::method setBody
  expose source
  use strict arg cls, name, scope, code
  g = source~findMember(cls, name, scope)
  if g == .nil then raise syntax 93.900 array(oxT("ox.err.noOwn", cls, name))
  if g~kind \== "METHOD" then raise syntax 93.900 array(oxT("ox.err.notMethod", name))
  lines = code~changeStr("0d0a"x, "0a"x)~makeArray("0a"x)
  body = .array~new
  do l over lines
    if l~strip~left(2) == "::" then raise syntax 93.900 array(oxT("ox.err.directive"))
    body~append(l~strip("T"))
  end
  do while body~items > 0
    if body~lastItem \== "" then leave
    body~delete(body~last)
  end
  body~append("")
  g~body = body
  if self~load then return ""
  return self~lastError

/* ---- ooRexxDoc written in the editor ----------------------------------------
   A doc-comment sits right before its directive, so it is held at the end of
   the segment before it.  getDoc answers it as written ("" for none); setDoc
   puts text there, replacing the one that is there, or takes it away ("").
   The text must be one doc-comment: a block from slash-star-star to star-slash
   with no star-slash inside, or lines that all start with three dashes.
   (Code assistance proposes one; the person applies it.) */
::method getDoc
  use strict arg cls, name = "", scope = "INSTANCE"
  parse value self~docPlace(cls, name, scope) with i first last
  if first = 0 then return ""
  prev = self~source~segments[i]
  out = .array~new
  do n = first to last
    out~append(prev~body[n])
  end
  return out~makeString("L", "0a"x)

-- a member's directive and body (name "": the class's directive), as the
-- file has them: what a doc-comment is written from
::method memberText
  use strict arg cls, name = "", scope = "INSTANCE"
  if name == "" then g = self~source~find("CLASS", "", cls)
  else g = self~source~findMember(cls, name, scope)
  if g == .nil then raise syntax 93.900 array(oxT("ox.err.noOwn", cls, name))
  out = .array~of(g~header)
  do l over g~body
    out~append(l)
  end
  do while out~items > 1
    if out~lastItem~strip \== "" then leave
    out~delete(out~last)
  end
  return out~makeString("L", "0a"x)

::method setDoc
  use strict arg cls, name, scope, text
  lines = .array~new
  do l over text~changeStr("0d0a"x, "0a"x)~makeArray("0a"x)
    lines~append(l~strip("T"))
  end
  do while lines~items > 0
    if lines[1]~strip \== "" then leave
    lines~delete(1)
  end
  do while lines~items > 0
    if lines~lastItem~strip \== "" then leave
    lines~delete(lines~last)
  end
  if lines~items > 0 then do
    if \self~isDocComment(lines) then raise syntax 93.900 array(oxT("ox.err.notDoc"))
  end
  parse value self~docPlace(cls, name, scope) with i first last
  prev = self~source~segments[i]
  body = prev~body
  if first > 0 then do                                     -- the one there goes
    do n = last to first by -1
      body~delete(n)
    end
  end
  -- right before the directive; blank lines above it stay above it, and a new
  -- one is kept off the code before it by one blank line
  if first > 0 then at = first
  else do
    if body~items > 0, lines~items > 0 then do
      if body~lastItem~strip \== "" then body~append("")
    end
    at = body~items + 1
  end
  out = .array~new
  do n = 1 to at - 1
    out~append(body[n])
  end
  do l over lines
    out~append(l)
  end
  do n = at to body~items
    out~append(body[n])
  end
  prev~body = out
  if self~load then return ""
  return self~lastError

-- where the doc-comment of a class (name "") or member goes: the index of the
-- segment before its directive, then the first and last line of the
-- doc-comment there (0 0 when there is none)
::method docPlace private
  use strict arg cls, name, scope
  segs = self~source~segments
  if name == "" then g = self~source~find("CLASS", "", cls)
  else g = self~source~findMember(cls, name, scope)
  if g == .nil then raise syntax 93.900 array(oxT("ox.err.noOwn", cls, name))
  i = segs~index(g) - 1
  body = segs[i]~body
  last = body~items
  do while last > 0
    if body[last]~strip \== "" then leave
    last = last - 1
  end
  if last = 0 then return i 0 0
  t = body[last]~strip
  if t~left(3) == "---" then do                            -- --- lines
    first = last
    do while first > 1
      if body[first - 1]~strip~left(3) \== "---" then leave
      first = first - 1
    end
    return i first last
  end
  if t~right(2) \== "*/" then return i 0 0
  first = last
  do while first > 0
    if body[first]~strip~left(2) == "/*" then leave
    first = first - 1
  end
  if first = 0 then return i 0 0
  if body[first]~strip~left(3) \== "/**" | body[first]~strip~left(4) == "/**/" then return i 0 0   -- an ordinary comment stays
  return i first last

-- one doc-comment: /** ... */ with no */ before its end, or --- lines only
::method isDocComment private
  use strict arg lines
  if lines[1]~strip~left(3) == "---" then do
    do l over lines
      if l~strip~left(3) \== "---" then return .false
    end
    return .true
  end
  all = lines~makeString("L", "0a"x)~strip
  if all~left(3) \== "/**" | all~right(2) \== "*/" | all~length < 5 then return .false
  return all~substr(3, all~length - 4)~pos("*/") = 0

-- ::requires: refused unless it loads, so its library is really there
::method addRequires
  use strict arg file
  file = file~strip~strip("B", '"')~strip("B", "'")
  if file == "" then raise syntax 93.900 array(oxT("ox.err.whichFile"))
  do g over self~source~segments
    if g~kind == "REQUIRES" then do
      if g~name~caselessEquals(file) then raise syntax 93.900 array(oxT("ox.err.requiresAlready", file))
    end
  end
  return self~structural("doAddRequires", .array~of(file))
::method doAddRequires
  expose source
  use strict arg file
  source~addRequires(.OxSegment~new("REQUIRES", file, "", "INSTANCE", '::requires "'file'"'))
  return 0

::method removeRequires
  use strict arg file
  return self~structural("doRemoveRequires", .array~of(file))
::method doRemoveRequires
  expose source
  use strict arg file
  g = source~find("REQUIRES", "", file)
  if g == .nil then raise syntax 93.900 array(oxT("ox.err.requiresNot", file))
  source~remove(g)
  return 0

/* ---- completion --------------------------------------------------------------- */

-- What may follow the text before the caret, in method member of class cls
-- (scope: the side it is on).  label, kind, detail: tab separated lines.
::method complete
  use strict arg cls, scope, before
  lines = before~changeStr("0d0a"x, "0a"x)~makeArray("0a"x)
  if lines~items = 0 then line = ""
  else line = lines~lastItem
  symChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_!?"
  p = line~length
  do while p > 0
    if symChars~pos(line~substr(p, 1)) = 0 then leave
    p = p - 1
  end
  prefix = line~substr(p + 1)
  lead = line~left(p)
  out = .array~new
  select
    when lead~right(1) == "~" then do
      recv = lead~left(lead~length - 1)
      if recv~right(1) == "~" then recv = recv~left(recv~length - 1)   -- ~~ cascade
      self~completeMessage(cls, scope, recv, before, prefix, out)
    end
    when lead~right(1) == "." then do
      ch = lead~right(2)~left(1)
      if lead~length == 1 | symChars~pos(ch) = 0 then do
        known = self~knownClasses
        do n over known~allIndexes~sortWith(.CaselessComparator~new)
          out~append(self~nameOf(known[n]) || "09"x || "class" || "09"x || self~packageOf(known[n]))
        end
      end
    end
    when lead~strip~word(1)~caselessEquals("expose") then do
      do m over self~members(cls, "INSTANCE", .false)~makeArray("0a"x)
        parse var m nm "09"x kind "09"x
        if kind == "ATTRIBUTE" then out~append(nm || "09"x || "attribute" || "09"x || cls)
      end
    end
    otherwise do
      do v over self~variablesIn(before)
        out~append(v || "09"x || "variable" || "09"x)
      end
      do k over "address arg call do drop else end exit expose forward guard if interpret iterate leave loop nop numeric otherwise parse procedure pull push queue raise reply return say select signal then trace use when"~makeArray(" ")
        out~append(k || "09"x || "keyword" || "09"x)
      end
    end
  end
  return self~filterSorted(out, prefix)

-- the members a receiver answers
::method completeMessage
  use strict arg cls, scope, recv, before, prefix, out
  recv = oxLastTerm(recv)
  recvU = recv~strip~upper
  -- self: everything this class has, private too; on the class side, the class object's
  if recvU~right(4) == "SELF" then do
    if recvU == "SELF" then do
      self~addMembers(out, cls, scope, .true)
      return
    end
  end
  -- .Name~new... -> an instance of Name
  t = self~typeOfExpression(recv~strip, before)
  if t \== "" then do
    parse var t side ":" cname
    self~addMembers(out, cname, side, .false)
    return
  end
  return

-- "INSTANCE:Name" or "CLASS:Name" for an expression, "" when not known
::method typeOfExpression
  use strict arg expr, before
  e = expr~strip
  if e == "" then return ""
  -- a string literal
  if e~right(1) == '"' | e~right(1) == "'" then return "INSTANCE:String"
  -- strip one trailing (...) group
  if e~right(1) == ")" then do
    depth = 0
    do i = e~length to 1 by -1
      ch = e~substr(i, 1)
      if ch == ")" then depth = depth + 1
      if ch == "(" then depth = depth - 1
      if depth = 0 then leave
    end
    e = e~left(i - 1)
  end
  if e~left(1) == "." then do
    parse var e "." cname "~" rest
    if \self~isKnownClass(cname) then return ""
    if rest == "" then return "CLASS:" || cname
    if rest~caselessEquals("new") | rest~caselessEquals("of") then return "INSTANCE:" || cname
    return ""
  end
  if e~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_!?") = 0 then
    return self~typeOfVariable(e, before)
  return ""

-- the last "var = .Name~new..." (or ~of) before the caret gives var's class
::method typeOfVariable
  use strict arg var, before
  lines = before~changeStr("0d0a"x, "0a"x)~makeArray("0a"x)
  do i = lines~items to 1 by -1
    l = lines[i]~strip
    parse var l lhs "=" rhs
    if \lhs~strip~caselessEquals(var) then iterate
    rhs = rhs~strip
    if rhs~left(1) \== "." then return ""
    parse var rhs "." cname "~" call
    call = call~strip
    parse var call mname "("
    if \self~isKnownClass(cname) then return ""
    if mname~caselessEquals("new") | mname~caselessEquals("of") then return "INSTANCE:" || cname
    return ""
  end
  return ""

::method isKnownClass
  use strict arg cname
  if cname == "" then return .false
  return self~knownClasses~hasIndex(cname~upper)

::method addMembers
  use strict arg out, cname, side, withPrivate
  do m over self~members(cname, side, .true)~makeArray("0a"x)
    parse var m nm "09"x kind "09"x vis "09"x guard "09"x abstract "09"x definedIn "09"x own
    if vis == "private" & \withPrivate then iterate
    if nm~right(1) == "=" then iterate
    -- operators ("||", "==", " ") are sent as expressions, not after ~
    if nm == "" then iterate
    if nm~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_!?.") > 0 then iterate
    detail = definedIn
    if vis \== "public" then detail = detail vis
    out~append(nm || "09"x || kind~lower || "09"x || detail)
  end
  return

-- variables seen before the caret: assigned, or named by use arg, expose, parse
::method variablesIn
  use strict arg before
  vars = .array~new
  seen = .set~new
  do l over before~changeStr("0d0a"x, "0a"x)~makeArray("0a"x)
    s = l~strip
    names = .array~new
    w1 = s~word(1)~upper
    if w1 == "USE" | w1 == "EXPOSE" then do
      parse var s . rest
      if w1 == "USE" then do
        parse var rest w rest
        if w~upper == "STRICT" then parse var rest . rest
      end
      rest = rest~changeStr(",", " ")
      do n over rest~makeArray(" ")
        parse var n n "="
        if n \== "" then names~append(n)
      end
    end
    else do
      eq = s~pos("=")
      if eq > 1 then do
        lhs = s~left(eq - 1)~strip
        if s~substr(eq + 1, 1) \== "=" then do
          if lhs~verify("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_!?") = 0 then names~append(lhs)
        end
      end
    end
    do n over names
      if n~left(1)~verify("0123456789") = 0 then iterate
      if \seen~hasIndex(n~upper) then do
        seen~put(n~upper)
        vars~append(n)
      end
    end
  end
  return vars

::method packageOf
  use strict arg c
  if c~package == .nil then return "built in"
  n = c~package~name
  return n~substr(n~lastPos("/") + 1)

-- keep those starting with prefix (any case); own and inherited order kept
-- for members, sorted otherwise; one per label
::method filterSorted
  use strict arg items, prefix
  out = .array~new
  seen = .set~new
  do it over items
    parse var it label "09"x
    if prefix \== "" then do
      if \label~left(prefix~length)~caselessEquals(prefix) then iterate
    end
    if seen~hasIndex(label~upper) then iterate
    seen~put(label~upper)
    out~append(it)
  end
  return out~makeString("L", "0a"x)


/* orders [name, method] pairs by their position in the file, then by name */
::class OxPairOrder public inherit OxModule
::method init
  expose pos
  use strict arg pos
::method compare
  expose pos
  use strict arg a, b
  pa = pos~at(a[1])
  pb = pos~at(b[1])
  if pa \== .nil then do
    if pb \== .nil then do
      if pa < pb then return -1
      if pa > pb then return 1
    end
    else return -1
  end
  else do
    if pb \== .nil then return 1
  end
  return a[1]~compareTo(b[1])

-- The last term of an expression: what a ~ at its end is sent to.
-- "x = .Person~new(a, b)" -> ".Person~new(a, b)"; "say 'abc'" -> "'abc'"
::routine oxLastTerm public
  use strict arg text
  t = text~strip("T")
  i = t~length
  depth = 0
  do while i > 0
    ch = t~substr(i, 1)
    if depth > 0 then do
      if ch == ")" | ch == "]" then depth = depth + 1
      if ch == "(" | ch == "[" then depth = depth - 1
      i = i - 1
      iterate
    end
    if ch == ")" | ch == "]" then do
      depth = 1
      i = i - 1
      iterate
    end
    if ch == '"' | ch == "'" then do
      q = t~left(i - 1)~lastPos(ch)
      if q = 0 then leave
      i = q - 1
      iterate
    end
    if "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_!?.~"~pos(ch) = 0 then leave
    i = i - 1
  end
  return t~substr(i + 1)

::requires "OxUi.cls"   -- the editor's texts (and OodNls)
