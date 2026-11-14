/* gadgets.rex -- the "Tree view, track bar, date picker" example.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx gadgets.rex [out.rex]                                        */
parse arg outFile
d = .gadgetsDesign~build
if outFile \= "" then do
  st = .stream~new(outFile~strip)
  st~open("write replace")
  st~charOut(d~generate)
  st~close
  say "gadgets: wrote" outFile~strip
end
return d

::requires "OodDesigner.cls"

::class gadgetsDesign public
::method build class
  d = .OodDesign~new("Gadgets")
  d~setProp("form", "title", "Tree view, track bar, date picker")
  d~setProp("form", "w", 220)
  d~setProp("form", "h", 120)
  n = d~addControl("TREEVIEW", 8, 8)
  d~setProp(n, "name", "tvRexx")
  d~setGeometry("tvRexx", 8, 8, 96, 86)
  d~setProp("tvRexx", "nodes", "ooRexx|.Interpreter|.Extensions|..ooDialog|..RxSock|..BSF4ooRexx|Classic Rexx|.Regina")
  n = d~addControl("TRACKBAR", 112, 8)
  d~setProp(n, "name", "trkLevel")
  d~setGeometry("trkLevel", 112, 8, 100, 16)
  d~setProp("trkLevel", "max", 50)
  d~setProp("trkLevel", "pos", 30)
  n = d~addControl("PUSHBUTTON", 112, 28)
  d~setProp(n, "name", "btnRead")
  d~setGeometry("btnRead", 112, 28, 100, 14)
  d~setProp("btnRead", "text", "&Read the level")
  n = d~addControl("DATETIME", 112, 50)
  d~setProp(n, "name", "dtpWhen")
  d~setGeometry("dtpWhen", 112, 50, 100, 12)
  n = d~addControl("STATIC", 112, 70)
  d~setProp(n, "name", "lblOut")
  d~setGeometry("lblOut", 112, 70, 100, 24)
  d~setProp("lblOut", "text", "")
  n = d~addControl("PUSHBUTTON", 156, 100)
  d~setProp(n, "name", "btnClose")
  d~setGeometry("btnClose", 156, 100, 56, 14)
  d~setProp("btnClose", "text", "Close")
  d~setProp("btnClose", "role", "CANCEL")
  d~setEventCode("tvRexx", "SELCHANGED", -
    'use arg id, old, oldData, new, newData, action, tree'   || "0a"x || -
    'self~lblOut~setText("Node:" tree~itemText(new))')
  d~setEventCode("btnRead", "CLICKED", 'self~lblOut~setText("Level:" self~trkLevel~pos)')
  d~setEventCode("dtpWhen", "DATETIMECHANGE", -
    'use arg dt'                                              || "0a"x || -
    'self~lblOut~setText("Date:" dt~isoDate~left(10))')
  return d
