/* t02_graph.rex -- event code as a graph and back, without a browser.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
   usage: rexx t02_graph.rex   (OodGraph.cls, OodDesigner.cls and the Rexx Parser on REXX_PATH) */
fails = 0
checks = 0
nl = "0a"x
code = 'expose sharedScope' || nl || -
       'use arg id' || nl || -
       '-- the entry so far' || nl || -
       'if self~entry == "" then return' || nl || -
       'if x > 1 then do' || nl || -
       '  say "big"; self~lcd~setText(x)' || nl || -
       'end' || nl || -
       'else say "small"' || nl || -
       'do i = 1 to 3' || nl || -
       '  call SysSleep 0.1' || nl || -
       'end' || nl || -
       'select' || nl || -
       '  when a = 1 then nop' || nl || -
       '  otherwise' || nl || -
       '    x = 2' || nl || -
       'end'
g = .OodGraph~new(code)
call check "parses", g~error == ""
k = kinds(g)
call check "kinds in order", k == "expose use if return if do say message say do call select when nop otherwise assign"
call check "nesting: say inside the THEN's do", nodeField(g, 7, 2) = 6 & nodeField(g, 6, 3) == "then"
call check "labels: header of the IF", nodeField(g, 5, 9) == "if x > 1"
call check "labels: a do loop", nodeField(g, 10, 9) == "do i = 1 to 3"
call check "labels: when", nodeField(g, 13, 9)~left(10) == "when a = 1"

-- insert: at the top level, inside a DO, at the end
c2 = g~insertCode(0, "body", 3, 'say "inserted"')
call check "insert at top level keeps the comment", c2~pos('-- the entry so far' || nl || 'say "inserted"' || nl || 'if self~entry') > 0 | c2~pos('say "inserted"' || nl || '-- the entry so far') > 0
c3 = g~insertCode(10, "body", 2, 'say i')
call check "append inside a DO, indented like its sibling", c3~pos('  call SysSleep 0.1' || nl || '  say i' || nl || 'end') > 0
c4 = g~insertCode(15, "body", 1, 'y = 3')
call check "insert inside OTHERWISE", c4~pos('    y = 3' || nl || '    x = 2') > 0
call refuses "insert into a THEN's single instruction", "g~insertCode(3, 'then', 1, 'nop')"

-- delete: a whole line, a clause sharing its line
d1 = .OodGraph~new(code)~deleteCode(11)
call check "delete a whole-line statement", d1~pos("SysSleep") = 0 & d1~pos("do i = 1 to 3" || nl || "end") > 0
d2 = .OodGraph~new(code)~deleteCode(8)
call check "delete the second clause of a line", d2~pos('  say "big"' || nl) > 0 & d2~pos("setText") = 0
d3 = .OodGraph~new(code)~deleteCode(7)
call check "delete the first clause of a line", d3~pos('  self~lcd~setText(x)' || nl) > 0 & d3~pos('"big"') = 0

-- move: a statement out of a DO to the top, and back
m1 = .OodGraph~new(code)~moveCode(11, 0, "body", 1)
call check "move out of a loop to the top, after EXPOSE", m1~pos("expose sharedScope" || nl || "call SysSleep 0.1") = 1
mg = .OodGraph~new(m1)
call check "  still parses", mg~error == ""
m2 = .OodGraph~new(code)~moveCode(3, 0, "body", 5)
call check "move down in its own slot: before the place's block (the do loop)", m2~pos('else say "small"' || nl || 'if self~entry == "" then return' || nl || 'do i = 1 to 3') > 0
call refuses "a block into itself", ".OodGraph~new(code)~moveCode(10, 10, 'body', 1)"
-- the code stays valid Rexx: a clause keeps an instruction, a SELECT keeps its clauses
d4 = .OodGraph~new(code)~deleteCode(4)
call check "deleting a THEN's one instruction leaves NOP", d4~makeArray(nl)[4] == 'if self~entry == "" then nop' & .OodGraph~new(d4)~error == ""
m4 = .OodGraph~new(code)~moveCode(9, 0, "body", 7)
call check "moving the ELSE's instruction out leaves NOP and it parses", m4~pos('else nop') > 0 & .OodGraph~new(m4)~error == ""
call refuses "moving a WHEN out of its SELECT", ".OodGraph~new(code)~moveCode(13, 0, 'body', 1)"
call refuses "moving an OTHERWISE out of its SELECT", ".OodGraph~new(code)~moveCode(15, 0, 'body', 1)"
call refuses "deleting a SELECT's only WHEN", ".OodGraph~new(code)~deleteCode(13)"
d5 = .OodGraph~new(code)~deleteCode(15)
call check "deleting the OTHERWISE parses", d5~pos("otherwise") = 0 & .OodGraph~new(d5)~error == ""

-- replace and wrap
r1 = .OodGraph~new(code)~replaceCode(5, "if x > 10")
call check "replace a block's header keeps its body", r1~pos("if x > 10 then do") > 0 & r1~pos('say "big"') > 0
w1 = .OodGraph~new(code)~wrapCode(4)
call check "wrap a THEN's instruction in do...end", .OodGraph~new(w1)~error == "" & w1~pos("then do") > 0
wg = .OodGraph~new(w1)
call check "  then it takes a second statement", .OodGraph~new(wg~insertCode(wg~children(3, "then")[1], "body", 2, "nop"))~error == ""

-- the trace probes
p = .OodGraph~new(code)~probeCode("on_b1_clicked")
pg = .OodGraph~new(p)
call check "probed code parses", pg~error == ""
call check "no probe before EXPOSE", p~left(18) == "expose sharedScope"
call check "probe before a top-level statement", p~pos('call oodTraceStep "on_b1_clicked", 2, "ui", .context~variables; use arg id') > 0
call check "probe inside a DO", p~pos('call oodTraceStep "on_b1_clicked", 11, "ui", .context~variables; call SysSleep') > 0
call check "no probe before a THEN's single instruction", p~pos('then call oodTraceStep') = 0
-- a whole program with probes, from a design
d = .calcDesign~build
d~setEventThread("bEnter", "CLICKED", "background")
t = d~generate(.OodTraceFilter~new)
call check "traced program: probes in events", t~pos('call oodTraceStep "on_b7_clicked", 1, "ui", .context~variables; self~digit(7)') > 0
call check "traced program: probes in form methods", t~pos('"operate", 1, "caller"') > 0
call check "traced program: background events marked", t~pos('"on_bEnter_clicked", 1, "background"') > 0
call check "traced program: the probe routine", t~pos("::routine oodTraceStep public") > 0
call check "a saved program has no probes", d~generate~pos("oodTraceStep") = 0
call check "a bad parse is reported", .OodGraph~new("if then")~error \== ""

say "t02_graph:" checks - fails "of" checks "checks passed"
if fails > 0 then return 1
return 0

kinds: procedure
  use arg kGraph
  kOut = ""
  do kLine over kGraph~nodeLines~makeArray("0a"x)
    kOut = kOut kLine~changeStr("09"x, "|")~makeArray("|")[4]
  end
  return kOut~strip

nodeField: procedure
  use arg nfGraph, nfId, nfField
  return nfGraph~nodeLines~makeArray("0a"x)[nfId]~makeArray("09"x)[nfField]

check: procedure expose fails checks
  use arg ckLabel, ckOk
  checks = checks + 1
  if ckOk then say "  ok  " ckLabel
  else do
    say "  FAIL" ckLabel
    fails = fails + 1
  end
  return

refuses: procedure expose fails checks g code
  use arg rfLabel, rfCode
  checks = checks + 1
  signal on syntax name rfRefused
  interpret rfCode
  say "  FAIL not refused:" rfLabel
  fails = fails + 1
  return
rfRefused:
  -- the designer's own refusal: Error 93.900 with its message, not any error
  if condition("O")~at("CODE") \== "93.900" | condition("O")~at("ADDITIONAL")~isA(.Array) = .false then do
    say "  FAIL refused, but not by the designer:" rfLabel "--" condition("O")~at("MESSAGE")
    fails = fails + 1
    return
  end
  say "  ok   refuses" rfLabel "--" condition("O")~at("ADDITIONAL")[1]~left(90)
  return

::requires "OodGraph.cls"
::requires "calculator.rex"
