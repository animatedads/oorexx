/* t12: an ImageList given to a list-view (kept and counted; icons are not
   drawn yet) and a ToolTip with a tool for a button. */
dlg = .Tips~new
dlg~create(30, 30, 180, 90, "Tips and image lists", "CENTER")
dlg~execute("SHOWTOP")
say "log:" dlg~log
return 0

::requires "ooDialog.cls"

::class Tips subclass UserDialog
::attribute log
::method defineDialog
  self~createListView(101, 8, 8, 164, 50, "REPORT")
  self~createPushButton(IDOK, 122, 68, 50, 14, "DEFAULT", "Close")
::method initDialog
  list = self~newListView(101)
  images = .ImageList~create(.Size~new(16, 16), "COLOR8", 4, 0)
  images~add(.Image~getImage("bmp\cake.bmp"))
  images~add(.Image~getImage("bmp\cake1.bmp"))
  previous = list~setImageList(images, "SMALL")
  list~insertColumnPx(0, "Cake", 120)
  list~addRow( , 0, "Chocolate")
  tip = self~createToolTip(900)
  tip~addTool(self~newPushButton(IDOK), "Closes the dialog")
  self~log = "images" images~getCount "size" images~getImageSize~width "previous nil" (previous == .nil) "same list" (list~getImageList("SMALL") == images)
