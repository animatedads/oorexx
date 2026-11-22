/* Resizer.rex -- an ooDialog program made with the ooDialog Designer 0.20.0
   Design: the ::RESOURCE oodDesign at the end.  The designer writes this
   whole file; what you type is the body of each event method.
   ooDialog Designer -- architecture: Tom Dyer; code: Claude (Opus 5.5). */
dlg = .Resizer~new
if dlg~initCode \= 0 then return dlg~initCode
return dlg~execute("SHOWTOP")

::requires "ooDialog.cls"

::class Resizer subclass UserDialog inherit ResizingAdmin

::attribute first

::method init
  forward class (super) continue
  self~first = .nil
  self~create(0, 0, 200, 120, "My Dialog", "CENTER THICKFRAME")

::method defineDialog
  self~createListBox(100, 6, 6, 120, 80, "", "lstItems_data")
  self~createPushButton(101, 140, 6, 50, 14, "", "Measure")
  self~createPushButton(IDOK, 140, 100, 50, 14, "DEFAULT", "OK")
  self~connectButtonEvent(101, "CLICKED", "on_btnMeasure_clicked")

::method defineSizing
  -- the form is resizable; each control follows the edges it is anchored to
  self~defaultSizing(.array~of("STATIONARY", "LEFT"), .array~of("STATIONARY", "TOP"), .array~of("MYLEFT", "LEFT"), .array~of("MYTOP", "TOP"))
  self~controlSizing(100, .array~of("STATIONARY", "LEFT"), .array~of("STATIONARY", "TOP"), .array~of("STATIONARY", "RIGHT"), .array~of("STATIONARY", "BOTTOM"))   -- lstItems: LEFT TOP RIGHT BOTTOM
  self~controlSizing(101, .array~of("STATIONARY", "RIGHT"), .array~of("STATIONARY", "TOP"), .array~of("MYLEFT", "LEFT"), .array~of("MYTOP", "TOP"))   -- btnMeasure: TOP RIGHT
  self~controlSizing(IDOK, .array~of("STATIONARY", "RIGHT"), .array~of("STATIONARY", "BOTTOM"), .array~of("MYLEFT", "LEFT"), .array~of("MYTOP", "TOP"))   -- btnOK: RIGHT BOTTOM
  return 0

::method initDialog unguarded

::method lstItems unguarded
  return self~newListBox(100)
::method btnMeasure unguarded
  return self~newPushButton(101)
::method btnOK unguarded
  return self~newPushButton(IDOK)

::method on_btnMeasure_clicked unguarded
  s = self~lstItems~getRealSize; p = self~btnOK~windowRect
  now = s~width s~height p~left p~top
  if self~first == .nil then do
    self~first = now
    say "measured"
    return
  end
  f = self~first
  say "list grew" (now~word(1) - f~word(1)) (now~word(2) - f~word(2))
  say "OK moved" (now~word(3) - f~word(3)) (now~word(4) - f~word(4))

::resource oodDesign
designer version=0.20.0
form name=Resizer title="My Dialog" w=200 h=120 style=CENTER resizable=1
var name=first value=.nil
control type=LISTBOX name=lstItems id=100 x=6 y=6 w=120 h=80 items="" opts="" tip="" anchor="LEFT TOP RIGHT BOTTOM"
control type=PUSHBUTTON name=btnMeasure id=101 x=140 y=6 w=50 h=14 text=Measure role="" opts="" tip="" anchor="TOP RIGHT"
control type=PUSHBUTTON name=btnOK id=102 x=140 y=100 w=50 h=14 text=OK role=OK opts="" tip="" anchor="RIGHT BOTTOM"
event control=btnMeasure event=CLICKED thread=ui
::END
