/* wincheck.rex -- run the designer's three example programs under ooDialog
   and work them from Rexx, checking what happens.  Made for Windows
   ooDialog; it also runs on ooDialog/WASM.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage:  rexx wincheck.rex DIR
     DIR holds Calculator.rex, Threads.rex and Contacts.rex (site/examples).
   Each program is loaded without its main code (Package~loadPackage with
   the source), its dialog made and shown with executeAsync, and its
   buttons pressed with Button~click (BM_CLICK, as a mouse click), so the
   event methods run as they would for a user.  The tab and menu events are
   called directly: Windows sends no SELCHANGE for a tab selected by a
   program, and a menu cannot be clicked from Rexx.
   Output: one line per check, then "wincheck: N of M checks passed".
   Exit 0 when all pass, 1 otherwise.                                        */
parse arg dir
dir = dir~strip
if dir == "" then dir = "."
parse version v
say "wincheck: ooRexx" v "on" .rexxInfo~platform
fails = 0
checks = 0

/* ---- Calculator: the EDM2 DrDialog review's RPN calculator ---- */
dlg = loadForm(dir, "Calculator")
call check "Calculator: dialog made", dlg~initCode = 0
call check "Calculator: dialog shown", dlg~executeAsync(, "SHOWTOP") = 0
call SysSleep 0.5
call check "Calculator: INIT ran", dlg~status~getText == "Ready"
do b over .array~of("b1", "b2", "bEnter", "b3", "b0", "bAdd")
  call press dlg, b
end
call check "Calculator: 12 Enter 30 + = 42", dlg~lcd~getText == "42"
call press dlg, "b6"
call press dlg, "bMul"
call check "Calculator: then 6 * = 252", dlg~lcd~getText == "252"
call press dlg, "b0"
call press dlg, "bDiv"
call check "Calculator: division by zero refused", dlg~status~getText == "Division by zero"
call press dlg, "bClose"
dlg~endAsyncExecution
call check "Calculator: closed by its Cancel button", dlg~finished == .true

/* ---- Threads: a background event and a timer thread ---- */
dlg = loadForm(dir, "Threads")
call check "Threads: dialog made", dlg~initCode = 0
call check "Threads: dialog shown", dlg~executeAsync(, "SHOWTOP") = 0
call SysSleep 1.2
call check "Threads: timer thread ticks", dlg~lblClock~getText~left(4) == "Time"
call press dlg, "btnStart"
call SysSleep 0.4
call press dlg, "btnPing"
call press dlg, "btnPing"
call press dlg, "btnPing"
call check "Threads: dialog answers while the job runs", dlg~lblState~getText~pos("pings: 3") > 0
waited = 0
do while dlg~lblState~getText~pos("Done") = 0 & waited < 100
  call SysSleep 0.1
  waited = waited + 1
end
call check "Threads: job finished on its own thread", dlg~lblState~getText == "Done.  Pings while working: 3"
call press dlg, "btnClose"
dlg~endAsyncExecution
call check "Threads: closed", dlg~finished == .true

/* ---- Contacts: tab strip with pages, list view, menu bar ---- */
dlg = loadForm(dir, "Contacts")
call check "Contacts: dialog made", dlg~initCode = 0
call check "Contacts: dialog shown", dlg~executeAsync(, "SHOWTOP") = 0
call SysSleep 0.5
call check "Contacts: four rows", dlg~lvPeople~items = 4
call check "Contacts: page 1 shown, page 2 hidden", dlg~lvPeople~isVisible & \dlg~txtNotes~isVisible
dlg~lvPeople~select(2)
call SysSleep 0.3
call check "Contacts: list view SELECTCHANGED ran", dlg~lblInfo~getText == "Mark Miesfeld -- ooDialog"
dlg~tabMain~select("Notes")
dlg~tabMain_pageChanged
call check "Contacts: page 2 shown, page 1 hidden", dlg~txtNotes~isVisible & \dlg~lvPeople~isVisible
call check "Contacts: the user's SELCHANGE ran too", dlg~lblInfo~getText == "Page: Notes"
call check "Contacts: menu bar attached", dlg~menuBar \== .nil
dlg~on_mnuAdd_clicked
call check "Contacts: menu item added a row", dlg~lvPeople~items = 5
dlg~on_mnuGrid_clicked
call check "Contacts: menu item unchecked", dlg~menuBar~isChecked(dlg~mnuGrid) == .false
call press dlg, "btnClose"
dlg~endAsyncExecution
call check "Contacts: closed", dlg~finished == .true

say "wincheck:" checks - fails "of" checks "checks passed"
if fails > 0 then return 1
return 0

/* the form class of DIR/name.rex, its main code left out */
loadForm: procedure
  use strict arg lfDir, lfName
  lfFile = lfDir || .File~separator || lfName".rex"
  lfIn = .stream~new(lfFile)
  if lfIn~query("exists") == "" then do
    say "wincheck: missing" lfFile
    exit 2
  end
  lfLines = lfIn~arrayIn
  lfIn~close
  lfSrc = .array~new
  lfMain = .true
  do lfLine over lfLines
    if lfMain then do
      if lfLine~strip~left(10)~caselessEquals("::requires") then lfMain = .false
      else iterate
    end
    lfSrc~append(lfLine)
  end
  lfSrc~insert("return 0", .nil)
  lfPkg = .context~package~loadPackage(lfName"-wincheck", lfSrc)
  lfCls = lfPkg~findClass(lfName)
  if lfCls == .nil then do
    say "wincheck: no class" lfName "in" lfFile
    exit 2
  end
  return lfCls~new

/* a click on a button, as a user's: BM_CLICK, then a moment for the event */
press: procedure
  use strict arg prDlg, prName
  prDlg~send(prName)~click
  call SysSleep 0.15
  return

check: procedure expose fails checks
  use strict arg ckLabel, ckOk
  checks = checks + 1
  if ckOk then say "  PASS" ckLabel
  else do
    say "  FAIL" ckLabel
    fails = fails + 1
  end
  return
