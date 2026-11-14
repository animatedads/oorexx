/* t09: FileNameDialog over the WASM machine's file system: open (into a
   sub-directory, with a type filter), a missing file refused, save with a
   default extension, cancel. */
call SysMkDir "docs"
call charout "docs/notes.txt", "one"
call charout "docs/report.txt", "two"
call charout "docs/picture.bmp", "three"
call stream "docs/notes.txt", "c", "close"
call stream "docs/report.txt", "c", "close"
call stream "docs/picture.bmp", "c", "close"
filter = "Text Files (*.txt)" || "00"~x2c || "*.txt" || "00"~x2c || "All Files (*.*)" || "00"~x2c || "*.*" || "00"~x2c
say "open:" FileNameDialog( , , filter, "LOAD", "Pick a text file")
say "save:" FileNameDialog("docs\", , filter, "SAVE", , "txt")
say "cancel:" FileNameDialog()
::requires "ooDialog.cls"
