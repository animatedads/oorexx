/* t19: the standby printer.  A list-view is printed as a PDF table, then a text, then a
   report the program builds itself.  Needs the PDF kit (tools/oodpdfkit.rex) as --tree. */
dlg = .Main~new
dlg~create(30, 30, 240, 130, "Print", "CENTER")
dlg~execute("SHOWTOP")
say "ended"
return 0

::requires "ooDialog.cls"
::requires "oodPrint.cls"

::class Main subclass UserDialog
::method defineDialog
  self~createListView(100, 5, 5, 230, 90, "REPORT")
  self~createPushButton(201, 5, 105, 50, 14, , "Print list", onList)
  self~createPushButton(202, 60, 105, 50, 14, , "Print text", onText)
  self~createPushButton(203, 115, 105, 55, 14, , "Print report", onReport)
  self~createPushButton(1, 185, 105, 50, 14, "DEFAULT", "Close")
::method initDialog
  list = self~newListView(100)
  list~insertColumn(0, "Part", 60)
  list~insertColumn(1, "Description", 110)
  list~insertColumn(2, "Stock", 40)
  list~addRow( , , "P-100", "Left-handed widget (blue)", "12")
  list~addRow( , , "P-205", "Bracket, 40 mm", "340")
  list~addRow( , , "P-333", "Cable (5 m) \ spare", "7")
::method onList unguarded
  say "list" (.OodPrint~listView(self~newListView(100), "Parts in stock", "parts.pdf") > 500)
::method onText unguarded
  say "text" (.OodPrint~text("First paragraph, line one." || .endOfLine || "Line two." || .endOfLine~copies(2) || "Second paragraph.", "A note", "note.pdf") > 300)
::method onReport unguarded
  report = .PdfFlowReport~new
  report~title = "Built by the program"
  report~addField("Owner", "Tom Dyer")
  report~addParagraph("One paragraph.")
  say "report" (.OodPrint~report(report) > 300)
  say "missing" .OodPrint~file("/tmp/no-such-file.pdf")
