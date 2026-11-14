/* t15: the shell dialog classes over the WASM machine's file system:
   OpenFileDialog (file types, type index, labels), SaveFileDialog (an event
   handler that refuses a file once, an item filter that hides .bak files),
   OpenFileDialog with PICKFOLDERS, BrowseForFolder, and cancel. */
call SysMkDir "work"
do name over .array~of("a.rex", "b.cls", "c.txt", "old.bak")
  call charout "work/"name, "x"
  call stream "work/"name, "c", "close"
end

ofd = .OpenFileDialog~new
say "options:" ofd~options
ofd~setFileTypes(.array~of("Rexx Program File", "*.rex", "Rexx Class File", "*.cls"))
ofd~setFileTypeIndex(2)
ofd~setTitle("Shell open")
ofd~setOkButtonLabel("Finished")
ofd~setFileNameLabel("Name here:")
ofd~setFolder("work")
ret = ofd~show
say "open:" ret ofd~getResult "type" ofd~getFileTypeIndex
ofd~release

sfd = .SaveFileDialog~new
sfd~setTitle("Shell save")
sfd~setFolder("work")
sfd~setDefaultExtension("txt")
sfd~advise(.Refuser~new)
sfd~setFilter(.NoBak~new)
ret = sfd~show
say "save:" ret sfd~getResult
sfd~release

ofd = .OpenFileDialog~new
ofd~options = ofd~options "PICKFOLDERS"
ofd~setTitle("Shell folder")
ret = ofd~show
say "folder:" ret ofd~getResult

bff = .BrowseForFolder~new("Shell browse", "banner", "hint", "work")
say "browse:" bff~getFolder

ofd = .OpenFileDialog~new
ofd~setTitle("Shell cancel")
ret = ofd~show
if ret == ofd~canceled then say "cancel: canceled" (ofd~getResult == .nil)
return 0

::requires "ooDialog.cls"

::class Refuser subclass CommonDialogEvents
::method onFileOk unguarded
  use arg cfd, hwnd
  if filespec("NAME", cfd~getResult) == "bad.txt" then return self~S_FALSE
  return self~S_OK

::class NoBak subclass ShellItemFilter
::method includeItem unguarded
  use arg cfd, hwnd, item
  if item~right(4) == ".bak" then return self~S_FALSE
  return self~S_OK
