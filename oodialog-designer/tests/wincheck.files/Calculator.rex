/* Calculator.rex -- an ooDialog program made with the ooDialog Designer 0.6.0
   Design: the ::RESOURCE oodDesign at the end.  The designer writes this
   whole file; what you type is the body of each event method.
   ooDialog Designer -- architecture: Tom Dyer; code: Claude (Opus 5.5). */
dlg = .Calculator~new
if dlg~initCode \= 0 then return dlg~initCode
return dlg~execute("SHOWTOP")

::requires "ooDialog.cls"

::class Calculator subclass UserDialog

::attribute entry
::attribute stack

::method init
  forward class (super) continue
  self~entry = ""
  self~stack = .queue~new
  self~create(0, 0, 132, 132, "RPN Calculator", "CENTER")
  self~lcd_data = "0"

::method defineDialog
  self~createEdit(100, 8, 8, 116, 14, "READONLY RIGHT", "lcd_data")
  self~createPushButton(101, 8, 28, 26, 14, "", "7")
  self~createPushButton(102, 38, 28, 26, 14, "", "8")
  self~createPushButton(103, 68, 28, 26, 14, "", "9")
  self~createPushButton(104, 98, 28, 26, 14, "", "/")
  self~createPushButton(105, 8, 46, 26, 14, "", "4")
  self~createPushButton(106, 38, 46, 26, 14, "", "5")
  self~createPushButton(107, 68, 46, 26, 14, "", "6")
  self~createPushButton(108, 98, 46, 26, 14, "", "*")
  self~createPushButton(109, 8, 64, 26, 14, "", "1")
  self~createPushButton(110, 38, 64, 26, 14, "", "2")
  self~createPushButton(111, 68, 64, 26, 14, "", "3")
  self~createPushButton(112, 98, 64, 26, 14, "", "-")
  self~createPushButton(113, 8, 82, 26, 14, "", "0")
  self~createPushButton(114, 38, 82, 26, 14, "", ".")
  self~createPushButton(115, 68, 82, 26, 14, "", "C")
  self~createPushButton(116, 98, 82, 26, 14, "", "+")
  self~createPushButton(117, 8, 100, 56, 14, "", "Enter")
  self~createPushButton(IDCANCEL, 68, 100, 56, 14, "", "Close")
  self~createStaticText(119, 8, 118, 116, 10, "", "")
  self~connectButtonEvent(101, "CLICKED", "on_b7_clicked")
  self~connectButtonEvent(102, "CLICKED", "on_b8_clicked")
  self~connectButtonEvent(103, "CLICKED", "on_b9_clicked")
  self~connectButtonEvent(104, "CLICKED", "on_bDiv_clicked")
  self~connectButtonEvent(105, "CLICKED", "on_b4_clicked")
  self~connectButtonEvent(106, "CLICKED", "on_b5_clicked")
  self~connectButtonEvent(107, "CLICKED", "on_b6_clicked")
  self~connectButtonEvent(108, "CLICKED", "on_bMul_clicked")
  self~connectButtonEvent(109, "CLICKED", "on_b1_clicked")
  self~connectButtonEvent(110, "CLICKED", "on_b2_clicked")
  self~connectButtonEvent(111, "CLICKED", "on_b3_clicked")
  self~connectButtonEvent(112, "CLICKED", "on_bSub_clicked")
  self~connectButtonEvent(113, "CLICKED", "on_b0_clicked")
  self~connectButtonEvent(114, "CLICKED", "on_bPoint_clicked")
  self~connectButtonEvent(115, "CLICKED", "on_bClear_clicked")
  self~connectButtonEvent(116, "CLICKED", "on_bAdd_clicked")
  self~connectButtonEvent(117, "CLICKED", "on_bEnter_clicked")

::method initDialog unguarded
  self~setData
  self~on_form_init
  self~getData

::method lcd unguarded
  return self~newEdit(100)
::method b7 unguarded
  return self~newPushButton(101)
::method b8 unguarded
  return self~newPushButton(102)
::method b9 unguarded
  return self~newPushButton(103)
::method bDiv unguarded
  return self~newPushButton(104)
::method b4 unguarded
  return self~newPushButton(105)
::method b5 unguarded
  return self~newPushButton(106)
::method b6 unguarded
  return self~newPushButton(107)
::method bMul unguarded
  return self~newPushButton(108)
::method b1 unguarded
  return self~newPushButton(109)
::method b2 unguarded
  return self~newPushButton(110)
::method b3 unguarded
  return self~newPushButton(111)
::method bSub unguarded
  return self~newPushButton(112)
::method b0 unguarded
  return self~newPushButton(113)
::method bPoint unguarded
  return self~newPushButton(114)
::method bClear unguarded
  return self~newPushButton(115)
::method bAdd unguarded
  return self~newPushButton(116)
::method bEnter unguarded
  return self~newPushButton(117)
::method bClose unguarded
  return self~newPushButton(IDCANCEL)
::method status unguarded
  return self~newStatic(119)

::method digit unguarded
  use strict arg key
  if key == ".", self~entry~pos(".") > 0 then return
  self~entry = self~entry || key
  self~lcd~setText(self~entry)

::method operate unguarded
  use strict arg op
  if self~entry \== "" then self~enter
  if self~stack~items < 2 then do
    self~status~setText("Two numbers are needed")
    return
  end
  b = self~stack~pull
  a = self~stack~pull
  if op == "/", b = 0 then do
    self~stack~push(a)
    self~stack~push(b)
    self~status~setText("Division by zero")
    return
  end
  select
    when op == "+" then answer = a + b
    when op == "-" then answer = a - b
    when op == "*" then answer = a * b
    otherwise answer = a / b
  end
  self~stack~push(answer)
  self~lcd~setText(answer)
  self~status~setText(a op b "=" answer)

::method enter unguarded
  if self~entry == "" then return
  self~stack~push(self~entry)
  self~entry = ""
  self~status~setText(self~stack~items "on the stack")

::method on_form_init unguarded
  self~status~setText("Ready")

::method on_b7_clicked unguarded
  self~digit(7)

::method on_b8_clicked unguarded
  self~digit(8)

::method on_b9_clicked unguarded
  self~digit(9)

::method on_bDiv_clicked unguarded
  self~operate("/")

::method on_b4_clicked unguarded
  self~digit(4)

::method on_b5_clicked unguarded
  self~digit(5)

::method on_b6_clicked unguarded
  self~digit(6)

::method on_bMul_clicked unguarded
  self~operate("*")

::method on_b1_clicked unguarded
  self~digit(1)

::method on_b2_clicked unguarded
  self~digit(2)

::method on_b3_clicked unguarded
  self~digit(3)

::method on_bSub_clicked unguarded
  self~operate("-")

::method on_b0_clicked unguarded
  self~digit(0)

::method on_bPoint_clicked unguarded
  self~digit(".")

::method on_bClear_clicked unguarded
  self~entry = ""
  self~stack~empty
  self~lcd~setText("0")
  self~status~setText("")

::method on_bAdd_clicked unguarded
  self~operate("+")

::method on_bEnter_clicked unguarded
  self~enter

::resource oodDesign
designer version=0.6.0
form name=Calculator title="RPN Calculator" w=132 h=132 style=CENTER
var name=entry value=""
var name=stack value=.queue~new
control type=EDIT name=lcd id=100 x=8 y=8 w=116 h=14 text=0 opts="READONLY RIGHT"
control type=PUSHBUTTON name=b7 id=101 x=8 y=28 w=26 h=14 text=7 role="" opts=""
control type=PUSHBUTTON name=b8 id=102 x=38 y=28 w=26 h=14 text=8 role="" opts=""
control type=PUSHBUTTON name=b9 id=103 x=68 y=28 w=26 h=14 text=9 role="" opts=""
control type=PUSHBUTTON name=bDiv id=104 x=98 y=28 w=26 h=14 text=/ role="" opts=""
control type=PUSHBUTTON name=b4 id=105 x=8 y=46 w=26 h=14 text=4 role="" opts=""
control type=PUSHBUTTON name=b5 id=106 x=38 y=46 w=26 h=14 text=5 role="" opts=""
control type=PUSHBUTTON name=b6 id=107 x=68 y=46 w=26 h=14 text=6 role="" opts=""
control type=PUSHBUTTON name=bMul id=108 x=98 y=46 w=26 h=14 text=* role="" opts=""
control type=PUSHBUTTON name=b1 id=109 x=8 y=64 w=26 h=14 text=1 role="" opts=""
control type=PUSHBUTTON name=b2 id=110 x=38 y=64 w=26 h=14 text=2 role="" opts=""
control type=PUSHBUTTON name=b3 id=111 x=68 y=64 w=26 h=14 text=3 role="" opts=""
control type=PUSHBUTTON name=bSub id=112 x=98 y=64 w=26 h=14 text=- role="" opts=""
control type=PUSHBUTTON name=b0 id=113 x=8 y=82 w=26 h=14 text=0 role="" opts=""
control type=PUSHBUTTON name=bPoint id=114 x=38 y=82 w=26 h=14 text=. role="" opts=""
control type=PUSHBUTTON name=bClear id=115 x=68 y=82 w=26 h=14 text=C role="" opts=""
control type=PUSHBUTTON name=bAdd id=116 x=98 y=82 w=26 h=14 text=+ role="" opts=""
control type=PUSHBUTTON name=bEnter id=117 x=8 y=100 w=56 h=14 text=Enter role="" opts=""
control type=PUSHBUTTON name=bClose id=118 x=68 y=100 w=56 h=14 text=Close role=CANCEL opts=""
control type=STATIC name=status id=119 x=8 y=118 w=116 h=10 text="" opts=""
method name=digit
method name=operate
method name=enter
event control=form event=INIT thread=ui
event control=b7 event=CLICKED thread=ui
event control=b8 event=CLICKED thread=ui
event control=b9 event=CLICKED thread=ui
event control=bDiv event=CLICKED thread=ui
event control=b4 event=CLICKED thread=ui
event control=b5 event=CLICKED thread=ui
event control=b6 event=CLICKED thread=ui
event control=bMul event=CLICKED thread=ui
event control=b1 event=CLICKED thread=ui
event control=b2 event=CLICKED thread=ui
event control=b3 event=CLICKED thread=ui
event control=bSub event=CLICKED thread=ui
event control=b0 event=CLICKED thread=ui
event control=bPoint event=CLICKED thread=ui
event control=bClear event=CLICKED thread=ui
event control=bAdd event=CLICKED thread=ui
event control=bEnter event=CLICKED thread=ui
::END
