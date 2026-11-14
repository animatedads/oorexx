/* t07: a bitmap button and a static image, from upstream's sample bitmaps
   (run with --tree upstream/examples; file names written the Windows way). */
dlg = .Pics~new
dlg~create(30, 30, 200, 100, "Bitmaps", "CENTER")
dlg~execute("SHOWTOP")
say "log:" dlg~log
return 0

::requires "ooDialog.cls"

::class Pics subclass UserDialog
::attribute log
::method defineDialog
  self~log = ""
  self~createBitmapButton(201, 10, 10, 70, 50, "STRETCH FRAME", "Cake", onCake, "bmp\cake.bmp")
  self~createStaticImage(202, 100, 10, 80, 50, "BITMAP CENTERIMAGE SUNKEN")
  self~createPushButton(IDOK, 140, 78, 50, 14, "DEFAULT", "Close")
::method initDialog
  image = .Image~getImage("BMP\CAKE1.BMP")
  self~log = "null" image~isNull "missing" .Image~getImage("bmp\nothere.bmp")~isNull "handle" (self~loadBitmap("bmp\cake2.bmp") \== 0)
  self~newStatic(202)~setImage(image)
::method onCake unguarded
  self~log = self~log "cake"
