/*----------------------------------------------------------------------------*/
/* OodGraph.cls -- an event method's code as a graph of blocks, and back.     */
/*                                                                            */
/* Architecture: Tom Dyer.  Code: Claude (Opus 5.5).                          */
/* Parsing: Josep Maria Blasco's Rexx Parser (Apache 2.0), METHOD option.     */
/*                                                                            */
/* The code is the truth.  The graph is read from Josep Maria's parser: one   */
/* node per instruction, nested as the language nests them (IF: THEN and      */
/* ELSE; DO and LOOP: their bodies; SELECT: WHEN and OTHERWISE), each with    */
/* the exact line and column range of its text.  An edit made on the graph    */
/* -- insert, move, delete, change a block's text, wrap it in DO...END -- is  */
/* a replacement of exact ranges of the source, so comments and the rest of   */
/* the lines stay as they were; then the code is parsed again.                */
/*                                                                            */
/* For a trace run, probeLines gives the code with a call before every        */
/* statement that sits in a body (not before a THEN or ELSE's single          */
/* instruction, where a call would change what runs): oodTraceStep is told    */
/* the method, the node and the variables, and passes them to the page.       */
/*----------------------------------------------------------------------------*/

/* The graph of one method body. */
::class OodGraph public inherit OodModule
::attribute code            -- the text parsed
::attribute lines           -- .Array of its lines
::attribute nodes           -- .Array of .Directory, in source order (ids are their indexes)
::attribute error           -- "" or the parser's message

::method init
  expose code lines nodes error
  use strict arg code
  lines = code~changeStr("0d0a"x, "0a"x)~makeArray("0a"x)
  if lines~items = 0 then lines~append("")
  nodes = .array~new
  error = ""
  if code~strip == "" then return
  signal on syntax name parseFailed
  p = .Rexx.Parser~new("event", lines, .array~of(.array~of("METHOD", 1)))
  self~walk(p~package~prolog~body~instructions, 0, "body")
  return
parseFailed:
  c = condition("O")
  msg = c~at("MESSAGE")
  if msg == .nil then msg = c~at("ERRORTEXT")
  -- the parser reports the program's error as "Error n running INSTORE line l: ..."
  parse var msg . "Error " detail
  if detail \== "" then msg = "Error" detail
  error = msg~string
  nodes = .array~new
  return

/* ---- reading the parse ------------------------------------------------------ */

::method walk
  expose nodes
  use strict arg list, parent, slot
  do ins over list
    if ins~isA(.Implicit.Exit.Instruction) then iterate
    if ins~class~id~upper == "LABEL.CLAUSE" then iterate
    id = self~addNode(ins, parent, slot)
    select
      when ins~isA(.Do.Instruction) then self~walk(ins~instructions, id, "body")
      when ins~isA(.Loop.Instruction) then self~walk(ins~instructions, id, "body")
      when ins~isA(.If.Instruction) then do
        self~walk(.array~of(ins~thenInstruction), id, "then")
        if ins~elseInstruction \== .nil then self~walk(.array~of(ins~elseInstruction), id, "else")
      end
      when ins~isA(.Select.Instruction) then do
        do wt over ins~whenThenInstructions
          wid = self~addClauseNode("when", wt[1], wt[2], wt[3], id, "when")
          self~walk(.array~of(wt[3]), wid, "then")
        end
        if ins~otherwiseClause \== .nil then do
          last = ins~otherwiseClause
          if ins~otherwiseSequence~items > 0 then last = ins~otherwiseSequence~lastItem
          oid = self~addClauseNode("otherwise", ins~otherwiseClause, ins~otherwiseClause, last, id, "otherwise")
          self~walk(ins~otherwiseSequence, oid, "body")
        end
      end
      otherwise nop
    end
  end
  return

-- a node for an instruction: its kind, its whole range, its header's range
::method addNode
  expose nodes
  use strict arg ins, parent, slot
  n = .directory~new
  n["PARENT"] = parent
  n["SLOT"] = slot
  n["KIND"] = oodKindOf(ins)
  parse value TheElementAfter(ins~begin)~from with l1 c1
  parse value ins~end~from with l2 c2
  n["L1"] = l1
  n["C1"] = c1
  n["L2"] = l2
  n["C2"] = c2
  -- the header: what a block shows on its own line (if ... then, do ..., select)
  hl = l2
  hc = c2
  select
    when ins~isA(.If.Instruction) then parse value ins~ifClause~end~from with hl hc
    when ins~isA(.Do.Instruction) then parse value ins~doClause~end~from with hl hc
    when ins~isA(.Loop.Instruction) then parse value ins~loopClause~end~from with hl hc
    when ins~isA(.Select.Instruction) then parse value ins~selectClause~end~from with hl hc
    otherwise nop
  end
  n["HL"] = hl
  n["HC"] = hc
  nodes~append(n)
  return nodes~items

-- a node for a WHEN (when..then, and its instruction) or OTHERWISE (and its body)
::method addClauseNode
  expose nodes
  use strict arg kind, first, headerLast, last, parent, slot
  n = .directory~new
  n["PARENT"] = parent
  n["SLOT"] = slot
  n["KIND"] = kind
  parse value TheElementAfter(first~begin)~from with l1 c1
  parse value headerLast~end~from with hl hc
  parse value last~end~from with l2 c2
  n["L1"] = l1
  n["C1"] = c1
  n["L2"] = l2
  n["C2"] = c2
  n["HL"] = hl
  n["HC"] = hc
  nodes~append(n)
  return nodes~items

-- the text between two positions (columns are where characters start)
::method textOf
  expose lines
  use strict arg l1, c1, l2, c2
  if l1 = l2 then return lines[l1]~substr(c1, max(0, c2 - c1))
  t = lines[l1]~substr(c1)
  do i = l1 + 1 to l2 - 1
    t = t || "0a"x || lines[i]
  end
  return t || "0a"x || lines[l2]~left(max(0, c2 - 1))

::method nodeText
  expose nodes
  use strict arg id
  n = nodes[id]
  return self~textOf(n["L1"], n["C1"], n["L2"], n["C2"])

::method headerText
  expose nodes
  use strict arg id
  n = nodes[id]
  return self~textOf(n["L1"], n["C1"], n["HL"], n["HC"])

-- "id<tab>parent<tab>slot<tab>kind<tab>l1<tab>c1<tab>l2<tab>c2<tab>label" lines
::method nodeLines
  expose nodes
  out = .array~new
  do id = 1 to nodes~items
    n = nodes[id]
    label = self~headerText(id)~changeStr("0a"x, " ")~space
    out~append(id || "09"x || n["PARENT"] || "09"x || n["SLOT"] || "09"x || n["KIND"] || "09"x || n["L1"] || "09"x || n["C1"] || "09"x || n["L2"] || "09"x || n["C2"] || "09"x || label)
  end
  return out~makeString("L", "0a"x)

::method children
  expose nodes
  use strict arg parent, slot
  out = .array~new
  do id = 1 to nodes~items
    if nodes[id]["PARENT"] = parent then do
      if nodes[id]["SLOT"] == slot then out~append(id)
    end
  end
  return out

/* ---- edits: exact ranges of the source -------------------------------------- */

-- the leading blanks of a line
::method indentOf
  expose lines
  use strict arg l
  t = lines[l]
  return t~left(t~verify(" " || "09"x) - 1)

-- does the node start its line / end its line (only blanks, or a ;, around it)?
::method startsLine
  expose lines nodes
  use strict arg id
  n = nodes[id]
  return lines[n["L1"]]~left(n["C1"] - 1)~strip == ""
::method endsLine
  expose lines nodes
  use strict arg id
  n = nodes[id]
  rest = lines[n["L2"]]~substr(n["C2"])~strip
  return rest == "" | rest == ";"

-- the body a node can take children in: top level, a DO/LOOP, an OTHERWISE
::method isBody
  expose nodes
  use strict arg parent, slot
  if slot \== "body" then return .false
  if parent = 0 then return .true
  return wordpos(nodes[parent]["KIND"], "do loop otherwise") > 0

-- Where index-th child goes in parent's slot: "line col before|after|line indent"
-- answers the edit that inserts text there, as [l, c, l, c, replacement-maker]
::method insertEdit
  expose lines nodes
  use strict arg parent, slot, index, text
  if \self~isBody(parent, slot) then
    raise syntax 93.900 array(oodT("err.graph.oneInstruction"))
  kids = self~children(parent, slot)
  if index < 1 then index = 1
  if index > kids~items + 1 then index = kids~items + 1
  -- nothing goes before EXPOSE: it must be the method's first instruction
  if parent = 0 & index = 1 & kids~items > 0 then do
    if nodes[kids[1]]["KIND"] == "expose" then index = 2
  end
  if kids~items = 0 then do
    if parent = 0 then do
      -- an empty body: the text is the code (a blank code has one blank line)
      return .array~of(1, 1, lines~items, lines[lines~items]~length + 1, text)
    end
    p = nodes[parent]
    ind = self~indentOf(p["L1"]) || "  "
    -- before the END line of the DO/LOOP (or after the OTHERWISE header)
    if p["KIND"] == "otherwise" then return .array~of(p["HL"], p["HC"], p["HL"], p["HC"], "0a"x || self~reindent(text, ind))
    return .array~of(p["L2"], 1, p["L2"], 1, self~reindent(text, ind) || "0a"x)
  end
  if index <= kids~items then do
    k = kids[index]
    n = nodes[k]
    if self~startsLine(k) then do
      ind = self~indentOf(n["L1"])
      return .array~of(n["L1"], 1, n["L1"], 1, self~reindent(text, ind) || "0a"x)
    end
    return .array~of(n["L1"], n["C1"], n["L1"], n["C1"], text~changeStr("0a"x, " ") || "; ")
  end
  k = kids[kids~items]
  n = nodes[k]
  if self~endsLine(k) then do
    ind = self~indentOf(n["L1"])
    endCol = lines[n["L2"]]~length + 1
    return .array~of(n["L2"], endCol, n["L2"], endCol, "0a"x || self~reindent(text, ind))
  end
  return .array~of(n["L2"], n["C2"], n["L2"], n["C2"], "; " || text~changeStr("0a"x, " "))

-- text whose first line goes at indent ind, its other lines kept relative
::method reindent
  use strict arg text, ind
  ls = text~makeArray("0a"x)
  if ls~items = 0 then return ind
  base = ""
  if ls~items > 1 then do
    -- the smallest indentation of the lines after the first
    minInd = 999
    do i = 2 to ls~items
      if ls[i]~strip == "" then iterate
      k = ls[i]~verify(" ") - 1
      if k < minInd then minInd = k
    end
    if minInd = 999 then minInd = 0
  end
  out = ind || ls[1]~strip("L")
  do i = 2 to ls~items
    if ls[i]~strip == "" then out = out || "0a"x
    else out = out || "0a"x || ind || "  " || ls[i]~substr(minInd + 1)
  end
  return out

-- the edit that removes a node, its line too when it had the line to itself
::method deleteEdit
  expose lines nodes
  use strict arg id
  n = nodes[id]
  -- a THEN, ELSE or WHEN's instruction cannot just go: the clause needs one
  if \self~isBody(n["PARENT"], n["SLOT"]), n["KIND"] \== "when", n["KIND"] \== "otherwise" then
    return .array~of(n["L1"], n["C1"], n["L2"], n["C2"], "nop")
  if self~startsLine(id) then do
    if self~endsLine(id) then return .array~of(n["L1"], 1, n["L2"] + 1, 1, "")
    -- text after it on the line: remove it and the ; after it
    rest = lines[n["L2"]]~substr(n["C2"])
    k = rest~verify(" ;")
    if k = 0 then k = rest~length + 1
    return .array~of(n["L1"], n["C1"], n["L2"], n["C2"] + k - 1, "")
  end
  -- text before it on the line: remove the ; before it and it
  before = lines[n["L1"]]~left(n["C1"] - 1)
  p = before~strip("T")~length
  if before~strip("T")~right(1) == ";" then p = p - 1
  return .array~of(n["L1"], p + 1, n["L2"], n["C2"], "")

-- Apply edits ([l1, c1, l2, c2, text], ranges in this parse's coordinates,
-- not overlapping): from the last to the first, so earlier ones stay right.
-- Answers the new code.
::method applyEdits
  expose lines
  use strict arg edits
  work = .array~new
  do l over lines
    work~append(l)
  end
  -- a line past the end, for a deletion that takes the last line
  work~append("")
  sorted = edits~sortWith(.OodEditOrder~new)
  do e over sorted
    l1 = e[1]
    c1 = e[2]
    l2 = e[3]
    c2 = e[4]
    head = work[l1]~left(c1 - 1)
    tail = work[l2]~substr(c2)
    joined = head || e[5] || tail
    -- take lines l1..l2 out, put joined's lines in
    do i = l2 to l1 by -1
      work~delete(i)
    end
    newLines = joined~makeArray("0a"x)
    if joined~right(1) == "0a"x then newLines~append("")
    if joined == "" then newLines = .array~of("")
    do i = newLines~items to 1 by -1
      if l1 = 1 then work~insert(newLines[i], .nil)
      else work~insert(newLines[i], l1 - 1)
    end
  end
  -- drop the line added past the end, and a whole-line deletion's leftover
  out = .array~new
  do i = 1 to work~items
    if i = work~items then do
      if work[i] == "" then leave
    end
    out~append(work[i])
  end
  do while out~items > 0
    if out~lastItem~strip \== "" then leave
    out~delete(out~last)
  end
  return out~makeString("L", "0a"x)

/* ---- the operations the page asks for -------------------------------------- */

::method insertCode
  use strict arg parent, slot, index, text
  if text~strip == "" then raise syntax 93.900 array(oodT("err.graph.nothing"))
  return self~applyEdits(.array~of(self~insertEdit(parent, slot, index, text)))

::method deleteCode
  expose nodes
  use strict arg id
  self~checkId(id)
  if nodes[id]["KIND"] == "when", self~children(nodes[id]["PARENT"], "when")~items = 1 then
    raise syntax 93.900 array(oodT("err.graph.lastWhen"))
  return self~applyEdits(.array~of(self~deleteEdit(id)))

-- move node id to index in parent's slot: one deletion and one insertion,
-- made together in the original coordinates
::method moveCode
  expose nodes
  use strict arg id, parent, slot, index
  self~checkId(id)
  if nodes[id]["KIND"] == "when" | nodes[id]["KIND"] == "otherwise" then
    raise syntax 93.900 array(oodT("err.graph.clause", nodes[id]["KIND"]~upper))
  -- not into itself
  p = parent
  do while p > 0
    if p = id then raise syntax 93.900 array(oodT("err.graph.itself"))
    p = nodes[p]["PARENT"]
  end
  text = self~nodeText(id)
  -- index is a place in the slot as it is now, with the moved node still in
  -- it (the page's drop zones): the edits are made in this parse's coordinates
  ins = self~insertEdit(parent, slot, index, text)
  del = self~deleteEdit(id)
  if self~overlaps(ins, del) then return self~code
  return self~applyEdits(.array~of(ins, del))

::method overlaps
  use strict arg a, b
  -- a is an insertion (a point); it overlaps b when inside b's range
  if a[1] < b[1] then return .false
  if a[1] > b[3] then return .false
  if a[1] = b[1] & a[2] <= b[2] then return .false
  if a[1] = b[3] & a[2] >= b[4] then return .false
  return .true

-- a new text for a simple block, or for a block's header (if ..., do ..., when ...)
::method replaceCode
  expose nodes
  use strict arg id, text
  self~checkId(id)
  n = nodes[id]
  if text~strip == "" then raise syntax 93.900 array(oodT("err.graph.empty"))
  -- keep the blanks the header ended with (before THEN, say)
  old = self~headerText(id)
  trail = old~substr(old~strip("T")~length + 1)
  return self~applyEdits(.array~of(.array~of(n["L1"], n["C1"], n["HL"], n["HC"], text~strip("T") || trail)))

-- a THEN, ELSE or WHEN's single instruction made a DO...END block
::method wrapCode
  expose nodes
  use strict arg id
  self~checkId(id)
  n = nodes[id]
  ind = self~indentOf(n["L1"])
  body = self~reindent(self~nodeText(id), ind || "  ")
  return self~applyEdits(.array~of(.array~of(n["L1"], n["C1"], n["L2"], n["C2"], "do" || "0a"x || body || "0a"x || ind || "end")))

::method checkId
  expose nodes
  use strict arg id
  if \datatype(id, "W") then raise syntax 93.900 array(oodT("err.graph.noBlock", id))
  if id < 1 | id > nodes~items then raise syntax 93.900 array(oodT("err.graph.noBlock", id))
  return 0

/* ---- the trace run ------------------------------------------------------------ */

-- The code with "call oodTraceStep where, node, .context~variables;" before
-- each statement in a body (top level, DO, LOOP, OTHERWISE).  Not before
-- EXPOSE (it must come first), nor before a THEN, ELSE or WHEN's single
-- instruction (the call would become that instruction).
::method probeCode
  expose nodes error code
  use strict arg where, thread = "ui"
  if error \== "" then return code
  edits = .array~new
  do id = 1 to nodes~items
    n = nodes[id]
    if \self~isBody(n["PARENT"], n["SLOT"]) then iterate
    if n["KIND"] == "expose" then iterate
    probe = "call oodTraceStep" oodRx(where)"," id"," oodRx(thread)", .context~variables; "
    edits~append(.array~of(n["L1"], n["C1"], n["L1"], n["C1"], probe))
  end
  if edits~items = 0 then return code
  return self~applyEdits(edits)


/* A trace run: OodDesign~generate(.OodTraceFilter~new) writes the program
   with probes in every event and form method, and the routine they call,
   which hands each step to the page (window.oodTrace). */
::class OodTraceFilter public inherit OodModule
::method filter
  use strict arg methodName, code, thread
  return .OodGraph~new(code)~probeCode(methodName, thread)
::method extraLines
  t = .array~new
  t~append("-- the trace run's probe: each step, its variables, to the page")
  t~append("::routine oodTraceStep public")
  t~append("  use arg where, node, thread, vars")
  t~append("  text = """"")
  t~append("  do n over vars~allIndexes~sort")
  t~append("    v = vars[n]")
  t~append("    if v~isA(.String) then s = v")
  t~append("    else s = v~objectName")
  t~append("    if s~length > 60 then s = s~left(57)""...""")
  t~append("    text = text || n""="" || s || ""09""x")
  t~append("  end")
  t~append("  .js~page~js.invokeStrict(""oodTrace"", where, node, thread, text)")
  t~append("  return")
  t~append("")
  return t

/* orders edits last first */
::class OodEditOrder public
::method module_version class
  return "0.10.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.10.0"
::method module_lastChanged
  return "2026-11-15"
::method compare
  use strict arg a, b
  if a[1] > b[1] then return -1
  if a[1] < b[1] then return 1
  if a[2] > b[2] then return -1
  if a[2] < b[2] then return 1
  return 0

-- the kind of block an instruction is
::routine oodKindOf public
  use strict arg ins
  id = ins~class~id~upper
  select
    when ins~isA(.If.Instruction) then return "if"
    when ins~isA(.Do.Instruction) then return "do"
    when ins~isA(.Loop.Instruction) then return "loop"
    when ins~isA(.Select.Instruction) then return "select"
    when id == "ASSIGNMENT.INSTRUCTION" then return "assign"
    when id == "MESSAGE.INSTRUCTION" then return "message"
    when id == "MESSAGE.ASSIGNMENT.INSTRUCTION" then return "assign"
    when id == "COMMAND.INSTRUCTION" then return "command"
    otherwise do
      -- keyword instructions: SAY.INSTRUCTION -> say, USE.ARG.INSTRUCTION -> use
      return id~left(id~pos(".") - 1)~lower
    end
  end

::requires "rexx-parser/bin/Rexx.Parser.cls"   -- Josep Maria Blasco's Rexx Parser (Apache 2.0)
::requires "OodDesigner.cls"
::requires "OodUi.cls"
