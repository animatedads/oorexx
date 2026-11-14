/* FileNameDialog over the WASM machine's file system. */
call SysMkDir "docs"
call charout "docs/notes.txt", "Some notes."
call stream "docs/notes.txt", "c", "close"
filter = "Text Files (*.txt)" || "00"~x2c || "*.txt" || "00"~x2c || "Rexx (*.rex;*.cls)" || "00"~x2c || "*.rex;*.cls" || "00"~x2c || "All Files (*.*)" || "00"~x2c || "*.*" || "00"~x2c
file = FileNameDialog( , , filter, "LOAD", "Open a file of the WASM machine")
if file == 0 then say "Cancelled."
else say "You chose" file "(" || stream(file, "c", "query size") "bytes)"
::requires "ooDialog.cls"
