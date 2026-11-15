/*----------------------------------------------------------------------------*/
/* OxDocs.cls -- the ooRexxDoc of a class and its members, for the Object     */
/* Editor's tooltips (the first sentence) and its doc box (the whole text).   */
/*                                                                            */
/* Architecture: Tom Dyer.  Code: Claude (Opus 5.5).                          */
/*                                                                            */
/* Read by Josep Maria Blasco's Rexx Parser (Apache 2.0) with the option      */
/* DocComments All: a doc-comment is a block comment starting with slash-star-star  */
/* or contiguous lines starting with three dashes, and the parser splits it   */
/* into armature, summary (the first sentence), main description, tags, tag   */
/* values and tag descriptions.  A doc-comment belongs to the directive that  */
/* comes next, with nothing but blanks between them.  Kept apart from         */
/* ObjectEditor.cls so the parser loads only when docs are first asked for.   */
/*----------------------------------------------------------------------------*/

::class OxDocs public
::method module_version class
  return "0.3.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.3.0"
::method module_lastChanged
  return "2026-11-15"

::method init
  expose cache
  cache = .identityTable~new           -- package -> its doc entries

-- The docs of class c (a class object) and its members, from the package that
-- defines it.  One line each, tab separated: kind (CLASS, METHOD, ATTRIBUTE,
-- CONSTANT), name in lower case (a class-side member ends " class"), the
-- summary, then the whole text with its lines joined by "0b"x.  A class with
-- no source (.Object, .String ...) has none: "".  lines, when given, are
-- the package's text as written (the Object Editor loads a file with its
-- prolog blanked, so a class's doc-comment there would be lost).
::method docsOf
  use strict arg c, lines = .nil
  if \c~isA(.Class) then return ""
  p = c~package
  if p == .nil then return ""
  out = .array~new
  do e over self~entries(p, lines)
    if e["CLASS"]~caselessEquals(c~id) then
      out~append(e["KIND"] || "09"x || e["NAME"] || "09"x || e["SUMMARY"] || "09"x || e["TEXT"])
  end
  return out~makeString("L", "0a"x)

-- every doc-comment of a package, with the directive it documents
::method entries private
  expose cache
  use strict arg p, lines
  if cache~hasIndex(p) then return cache[p]
  out = .array~new
  cache[p] = out
  src = lines
  if src == .nil then src = p~source
  if src == .nil then return out
  if src~items = 0 then return out
  parser = .Rexx.Parser~new(p~name, src, .array~of(.array~of("DOCCOMMENTS", "All")))
  doc = .nil
  cls = ""
  e = parser~firstElement
  do while e \== .nil
    if self~isDoc(e) then do
      doc = e
      e = e~next
      iterate
    end
    if self~ignorable(e) then do
      e = e~next
      iterate
    end
    if e~value == "::" then e = self~directive(e, doc, out, .array~of(cls))
    else e = e~next
    if out~lastItem \== .nil then cls = out~lastItem["CURRENT"]
    doc = .nil
  end
  return out

-- a directive at e (its "::"): note its doc-comment, answer the element after
-- its name.  Keeps the class it is in, so members go with their class.
::method directive private
  use strict arg e, doc, out, clsBox
  e = self~nextReal(e~next)
  if e == .nil then return .nil
  kw = e~value~upper
  e = self~nextReal(e~next)
  if e == .nil then return .nil
  name = e~value
  if name~isA(.Array) then name = name~makeString("L", "")
  name = name~strip("B", '"')~strip("B", "'")
  cls = clsBox[1]
  if \.array~of("CLASS", "METHOD", "ATTRIBUTE", "CONSTANT", "ROUTINE")~hasItem(kw) then return e~next
  if kw == "CLASS" then cls = name
  if kw == "ROUTINE" then cls = ""
  side = ""
  if wordpos(kw, "METHOD ATTRIBUTE CONSTANT") > 0 then side = self~classSide(e~next)
  r = .directory~new
  r["KIND"] = kw
  r["NAME"] = name~lower || side
  r["CLASS"] = cls
  r["CURRENT"] = cls
  r["SUMMARY"] = ""
  r["TEXT"] = ""
  if doc \== .nil then do
    r["SUMMARY"] = self~summaryOf(doc)
    r["TEXT"] = self~textOf(doc)
  end
  if doc \== .nil | kw == "CLASS" | kw == "ROUTINE" then out~append(r)
  return e~next

-- " class" when the rest of the directive's clause has the CLASS option
::method classSide private
  use strict arg e
  do while e \== .nil
    if e~value == ";" | e~class~id~caselessEquals("INSERTED.SEMICOLON") then return ""
    v = e~value
    if \v~isA(.Array) then if v~caselessEquals("CLASS") then return " class"
    e = e~next
  end
  return ""

::method nextReal private
  use strict arg e
  do while e \== .nil
    if \self~ignorable(e) then return e
    e = e~next
  end
  return .nil

-- blanks, comments that are not doc-comments, and what the parser inserts
::method ignorable private
  use strict arg e
  id = e~class~id~upper
  if id~left(9) == "INSERTED." then return .true
  if id == "WHITESPACE.ELEMENT" then return .true
  if e~isA(.Standard.Comment) | e~isA(.Line.Comment) then return \self~isDoc(e)
  return .false

::method isDoc private
  use strict arg e
  if \(e~isA(.Standard.Comment) | e~isA(.Line.Comment)) then return .false
  return e~category == .EL.DOC_COMMENT | e~category == .EL.DOC_COMMENT_MARKDOWN

-- the first sentence, as the parser found it
::method summaryOf private
  use strict arg doc
  s = ""
  do q over doc~parts
    if q[2] == .EL.DOC_COMMENT_SUMMARY then s = s || q[3]
  end
  return s~strip~changeStr("09"x, " ")

-- the whole text without its armature, a line each (joined with "0b"x);
-- a closing "/" left on the last line is armature, not text
::method textOf private
  use strict arg doc
  lines = .array~new
  last = doc~parts~lastItem[1]
  do q over doc~parts
    n = q[1]
    if q[2] == .EL.DOC_COMMENT_ARMATURE then iterate
    t = q[3]
    if n == last & t~strip == "/" then iterate
    k = n - doc~parts[1][1] + 1
    do while lines~items < k
      lines~append("")
    end
    lines[k] = lines[k] || t
  end
  out = .array~new
  do l over lines
    out~append(l~strip("T")~changeStr("09"x, " "))
  end
  do while out~items > 0
    if out[1]~strip \== "" then leave
    out~delete(1)
  end
  do while out~items > 0
    if out~lastItem~strip \== "" then leave
    out~delete(out~items)
  end
  return out~makeString("L", "0b"x)

::requires "rexx-parser/bin/Rexx.Parser.cls"   -- Josep Maria Blasco's Rexx Parser (Apache 2.0)
