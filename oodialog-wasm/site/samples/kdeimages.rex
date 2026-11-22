/* t31: the images of the system are KDE Breeze icons: .Image~getImage and fromIDs of
   IDI_ and OBM_ numbers and symbols, shown in a static control and a button, and the icon
   of a message box */
dlg = .Kde~new
dlg~execute("SHOWTOP")
return 0

::requires "ooDialog.cls"

::class Kde subclass UserDialog
::method init
  forward class (super) continue
  self~create(30, 30, 200, 100, "KDE images")
::method defineDialog
  self~createStaticImage(10, 10, 10, 32, 32, "ICON")
  self~createStaticImage(11, 50, 10, 16, 16, "BITMAP")
  self~createPushButton(12, 80, 10, 50, 20, , "Ask", onAsk)
  self~createStaticText(13, 10, 50, 180, 10, , "")
  self~createPushButton(IDCANCEL, 140, 80, 50, 14, , "Close")
::method initDialog
  hand = .Image~getImage(.OEM~IDI_HAND, .Image~toID("IMAGE_ICON"))
  close = .Image~getImage(.OEM~OBM_CLOSE)
  say "getImage" hand~isNull close~isNull .Image~getImage("IDI_QUESTION", "ICON")~isNull .Image~getImage(12345, 1)~isNull
  icons = .Image~fromIDs(.array~of(.OEM~IDI_APPLICATION, .OEM~IDI_EXCLAMATION, .OEM~IDI_ASTERISK, .OEM~IDI_WINLOGO, 99))
  line = "fromIDs" icons~items
  do icon over icons
    line = line icon~isNull
  end
  say line
  say "same number, other type:" (.Image~getImage(32512, 1)~handle) (.Image~getImage(32512, 0)~isNull)
  self~newStatic(10)~setIcon(hand)
  self~newStatic(11)~setImage(close)
  self~newStatic(13)~setText("set")
::method onAsk unguarded
  answer = MessageDialog("Is this a KDE icon?", self~hwnd, "Question", "YESNO", "QUESTION")
  self~newStatic(13)~setText("answer" answer)
