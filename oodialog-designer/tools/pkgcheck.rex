/* pkgcheck.rex -- before a package goes to Autobuild: do its version marks agree?
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
   usage: rexx tools/pkgcheck.rex PACKAGE_DIR

   PACKAGE_DIR ends in oorexx_oodialog_designer_vX.Y.  Checked: integration.json's
   package version is X.Y, its publish path is packages/oorexx_oodialog_designer_vX.Y,
   src/OodDesigner.cls answers module_version X.Y.0, README.md's title says vX.Y.0.
   v0.15 was refused at publication (its publish path still named v0.14): a version
   bump that changes one mark and not the others is what this catches.
   Exit 0 when all agree, 1 with one line per mark that does not. */
parse arg dir
dir = dir~strip
if dir == "" then do
  say "usage: rexx tools/pkgcheck.rex PACKAGE_DIR"
  return 2
end
sep = .File~separator
if dir~right(1) == sep then dir = dir~left(dir~length - 1)
name = filespec("NAME", dir)
parse var name base "_v" ver
if base \== "oorexx_oodialog_designer" | ver == "" then do
  say "pkgcheck: FAIL the folder is not oorexx_oodialog_designer_vX.Y:" name
  return 1
end
bad = 0

json = readAll(dir || sep || "integration.json")
-- the package's own "version" is the first one in the file
parse var json '"version"' ':' '"' jver '"'
if jver \== ver then bad = bad + report("integration.json version is" jver", the folder says" ver)
parse var json '"publish"' . '"path"' ':' '"' jpath '"'
if jpath \== "packages/" || name then bad = bad + report("integration.json publish path is" jpath", it must be packages/" || name)

cls = readAll(dir || sep || "src" || sep || "OodDesigner.cls")
p = cls~pos("::method module_version class")
parse value cls~substr(p) with 'return "' mver '"'
if mver \== ver || ".0" then bad = bad + report("OodDesign module_version is" mver", the folder says" ver || ".0")

readme = readAll(dir || sep || "README.md")
parse var readme "# ooDialog Designer " "— v" rver . "0a"x
if rver \== ver || ".0" then bad = bad + report("README.md title says v" || rver", the folder says v" || ver || ".0")

if bad = 0 then do
  say "pkgcheck: PASS" name": integration.json, its publish path, module_version and README agree on" ver
  return 0
end
return 1

report: procedure
  say "pkgcheck: FAIL" arg(1)
  return 1

readAll: procedure
  use strict arg path
  s = .Stream~new(path)
  if s~query("EXISTS") == "" then do
    say "pkgcheck: FAIL missing" path
    return ""
  end
  text = s~charIn(1, s~chars)
  s~close
  return text
