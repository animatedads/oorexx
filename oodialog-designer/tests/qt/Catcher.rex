/* Catcher.rex -- an ooDialog program made with the ooDialog Designer 0.22.0
   Design: the ::RESOURCE oodDesign at the end.  The designer writes this
   whole file; what you type is the body of each event method.
   ooDialog Designer -- architecture: Tom Dyer; code: Claude (Opus 5.5). */
-- does this ooRexx know CATCH?  One that does refuses a lone CATCH clause; one that
-- does not would run it as a command
signal on syntax name oodKnowsCATCH
oodProbe = .Routine~new("oodProbe", "catch syntax")
call errorDialog "This program uses CATCH, which this ooRexx does not know: it would run it as a command."
return 1
oodKnowsCATCH:
-- does this ooRexx know FINALLY?  One that does refuses a lone FINALLY clause; one that
-- does not would run it as a command
signal on syntax name oodKnowsFINALLY
oodProbe = .Routine~new("oodProbe", "finally")
call errorDialog "This program uses FINALLY, which this ooRexx does not know: it would run it as a command."
return 1
oodKnowsFINALLY:
dlg = .Catcher~new
if dlg~initCode \= 0 then return dlg~initCode
return dlg~execute("SHOWTOP")

::requires "ooDialog.cls"

::class Catcher subclass UserDialog


::method init
  forward class (super) continue
  self~create(0, 0, 200, 120, "My Dialog", "CENTER")

::method defineDialog
  self~createPushButton(100, 10, 10, 50, 14, "", "Go")
  self~createPushButton(IDOK, 60, 10, 50, 14, "DEFAULT", "OK")
  self~connectButtonEvent(100, "CLICKED", "on_btnGo_clicked")

::method initDialog unguarded

::method btnGo unguarded
  return self~newPushButton(100)
::method btn1 unguarded
  return self~newPushButton(IDOK)

::method on_btnGo_clicked unguarded
  do
    x = 1 + "a"
    say "not here"
  catch co = syntax
    say "caught" co~code
  finally
    say "finally"
  end

::resource oodDesign
designer version=0.22.0
form name=Catcher title="My Dialog" w=200 h=120 style=CENTER
control type=PUSHBUTTON name=btnGo id=100 x=10 y=10 w=50 h=14 text=Go role="" opts="" tip="" anchor="LEFT TOP"
control type=PUSHBUTTON name=btn1 id=101 x=60 y=10 w=50 h=14 text=OK role=OK opts="" tip="" anchor="LEFT TOP"
event control=btnGo event=CLICKED thread=ui
::END
