/* test_windows_names.rex -- WindowsNames.cls against the case oodfiles.js was written for (t16).
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-15.
 *   rexx tests/unit/test_windows_names.rex     (from oodialog-qt6; exit 0 when every check holds) */
here = filespec("location", .context~package~name)
.context~package~loadPackage(here"../../tools/WindowsNames.cls")
root = value("TMPDIR",, "ENVIRONMENT")
if root == "" then root = "/tmp"
root = root"/wn-test-"random(1, 99999)
call SysMkDir root
call SysMkDir root"/Parts"
call put root"/main.rex", 'call "parts\Report.rex" "x"' || "0a"x || '::requires "parts\helper.cls"' || "0a"x
call put root"/Parts/Report.rex", 'say "report"' || "0a"x || '::requires "Inner.cls"' || "0a"x
call put root"/Parts/Helper.cls", '::requires "inner"' || "0a"x
call put root"/Parts/Inner.cls", '::class inner public' || "0a"x
call put root"/plain.rex", '::requires "Parts/Helper.cls"' || "0a"x
call SysMkDir root"/Data"                                 -- data files named in strings (oodfiles.js 0.2.0)
call put root"/Data/Items.TXT", "items"
call put root"/ReadMe.Txt", "readme"
call put root"/data.rex", 'a = "data\items.txt"; b = ''readme.txt''; c = "notthere.txt"; d = "ReadMe.Txt"; e = "no dot"' || "0a"x
checks = 0; bad = 0
added = .WindowsNames~new(root)~apply

call check "names added", added == 6
call check "parts\Report.rex", sysFileExists(root"/parts\Report.rex")
call check "parts\helper.cls", sysFileExists(root"/parts\helper.cls")
call check "Inner.cls followed into the program's directory", sysFileExists(root"/Inner.cls")
call check "inner (no extension, other case) followed", sysFileExists(root"/inner")
call check "content copied", charin(root"/parts\helper.cls", 1, 99) == '::requires "inner"' || "0a"x
call stream root"/parts\helper.cls", "c", "close"
call check "data\items.txt", charin(root"/data\items.txt", 1, 9) == "items"
call stream root"/data\items.txt", "c", "close"
call check "readme.txt", sysFileExists(root"/readme.txt")
call check "a name that resolves to nothing adds nothing", \sysFileExists(root"/notthere.txt")
call check "a plain name adds nothing", \sysFileExists(root"/Parts/Helper.cls\")
call check "second apply adds none", .WindowsNames~new(root)~apply == 0
address system 'rm -r "'root'"'
say checks - bad "of" checks "checks hold"
exit bad > 0

put: procedure
  use arg file, text
  call charout file, text, 1
  call stream file, "c", "close"
  return
check:
  use arg label, ok
  checks += 1
  if \ok then do
    bad += 1
    say "FAIL" label
  end
  return
