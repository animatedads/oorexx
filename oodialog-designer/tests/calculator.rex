/* calculator.rex -- builds the RPN calculator of the EDM2 DrDialog review
   (Paul Floyd, "Dr. Dialog Review") through OodDesign, as the designer page
   does, and writes the generated program.  Shared by t01_model.rex and by
   the page test, which types the same thing into the designer.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx calculator.rex [out.rex]                                      */
parse arg outFile
d = .calcDesign~build
src = d~generate
if outFile \= "" then do
  st = .stream~new(outFile~strip)
  st~open("write replace")
  st~charOut(src)
  st~close
  say "calculator: wrote" outFile~strip
end
return d

::requires "OodDesigner.cls"

::class calcDesign public
::method build class
  d = .OodDesign~new("Calculator")
  d~setProp("form", "title", "RPN Calculator")
  d~setProp("form", "w", 132)
  d~setProp("form", "h", 132)
  d~setVar("entry", "")
  d~setVar("stack", ".queue~new")
  disp = d~addControl("EDIT", 8, 8)
  d~setProp(disp, "name", "lcd")
  d~setGeometry("lcd", 8, 8, 116, 14)
  d~setProp("lcd", "opts", "READONLY RIGHT")
  d~setProp("lcd", "text", "0")
  -- the keys: digits, point, the four operators, Enter and Clear
  keys = .array~of("7", "8", "9", "/", "4", "5", "6", "*", "1", "2", "3", "-", "0", ".", "C", "+")
  names = .array~of("b7", "b8", "b9", "bDiv", "b4", "b5", "b6", "bMul", "b1", "b2", "b3", "bSub", "b0", "bPoint", "bClear", "bAdd")
  do i = 1 to keys~items
    row = (i - 1) % 4
    col = (i - 1) // 4
    n = d~addControl("PUSHBUTTON", 8 + col * 30, 28 + row * 18)
    d~setProp(n, "name", names[i])
    d~setGeometry(names[i], 8 + col * 30, 28 + row * 18, 26, 14)
    d~setProp(names[i], "text", keys[i])
  end
  n = d~addControl("PUSHBUTTON", 8, 100)
  d~setProp(n, "name", "bEnter")
  d~setGeometry("bEnter", 8, 100, 56, 14)
  d~setProp("bEnter", "text", "Enter")
  n = d~addControl("PUSHBUTTON", 68, 100)
  d~setProp(n, "name", "bClose")
  d~setGeometry("bClose", 68, 100, 56, 14)
  d~setProp("bClose", "text", "Close")
  d~setProp("bClose", "role", "CANCEL")
  n = d~addControl("STATIC", 8, 118)
  d~setProp(n, "name", "status")
  d~setGeometry("status", 8, 118, 116, 10)
  d~setProp("status", "text", "")

  -- the form's methods: DrDialog's global procedures, as methods
  d~setMethod("digit", -
    'use strict arg key'                                    || "0a"x || -
    'if key == ".", self~entry~pos(".") > 0 then return'   || "0a"x || -
    'self~entry = self~entry || key'                        || "0a"x || -
    'self~lcd~setText(self~entry)')
  d~setMethod("operate", -
    'use strict arg op'                                     || "0a"x || -
    'if self~entry \== "" then self~enter'                  || "0a"x || -
    'if self~stack~items < 2 then do'                       || "0a"x || -
    '  self~status~setText("Two numbers are needed")'       || "0a"x || -
    '  return'                                              || "0a"x || -
    'end'                                                   || "0a"x || -
    'b = self~stack~pull'                                   || "0a"x || -
    'a = self~stack~pull'                                   || "0a"x || -
    'if op == "/", b = 0 then do'                           || "0a"x || -
    '  self~stack~push(a)'                                  || "0a"x || -
    '  self~stack~push(b)'                                  || "0a"x || -
    '  self~status~setText("Division by zero")'             || "0a"x || -
    '  return'                                              || "0a"x || -
    'end'                                                   || "0a"x || -
    'select'                                                || "0a"x || -
    '  when op == "+" then answer = a + b'                  || "0a"x || -
    '  when op == "-" then answer = a - b'                  || "0a"x || -
    '  when op == "*" then answer = a * b'                  || "0a"x || -
    '  otherwise answer = a / b'                            || "0a"x || -
    'end'                                                   || "0a"x || -
    'self~stack~push(answer)'                               || "0a"x || -
    'self~lcd~setText(answer)'                          || "0a"x || -
    'self~status~setText(a op b "=" answer)')
  d~setMethod("enter", -
    'if self~entry == "" then return'                       || "0a"x || -
    'self~stack~push(self~entry)'                           || "0a"x || -
    'self~entry = ""'                                       || "0a"x || -
    'self~status~setText(self~stack~items "on the stack")')

  -- the events: a line each
  digits = "b0 b1 b2 b3 b4 b5 b6 b7 b8 b9"
  do w over digits~makeArray(" ")
    d~setEventCode(w, "CLICKED", "self~digit(" || w~substr(2) || ")")
  end
  d~setEventCode("bPoint", "CLICKED", 'self~digit(".")')
  d~setEventCode("bAdd", "CLICKED", 'self~operate("+")')
  d~setEventCode("bSub", "CLICKED", 'self~operate("-")')
  d~setEventCode("bMul", "CLICKED", 'self~operate("*")')
  d~setEventCode("bDiv", "CLICKED", 'self~operate("/")')
  d~setEventCode("bEnter", "CLICKED", "self~enter")
  d~setEventCode("bClear", "CLICKED", -
    'self~entry = ""'                                       || "0a"x || -
    'self~stack~empty'                                      || "0a"x || -
    'self~lcd~setText("0")'                             || "0a"x || -
    'self~status~setText("")')
  d~setEventCode("form", "INIT", 'self~status~setText("Ready")')
  return d
