/* oodkde.rex -- take the KDE Breeze icons that stand for the Windows system images.
 * Architecture: Tom Dyer.  Code: Claude (Fable 5.2).
 * usage: rexx tools/oodkde.rex BREEZE_DIR [COMMIT]     (from the project directory)
 *   BREEZE_DIR: a clone of https://github.com/KDE/breeze-icons
 *   COMMIT: the commit of that clone, written to src/kde/SOURCE.txt
 * Reads src/kde-icons.map.  Writes src/kde/<name>.svg for each icon named there, the
 * licence file src/kde/COPYING-ICONS, and src/kde/SOURCE.txt.  tools/oodbuild.rex then puts
 * the icons into dist/oodWeb.cls.  Each step is logged. */
parse arg breeze commit .
if breeze == "" then do
  say "oodkde: usage: rexx tools/oodkde.rex BREEZE_DIR [COMMIT]"
  return 2
end
map = .stream~new("src/kde-icons.map")
if map~open("READ") \== "READY:" then do
  say "oodkde: FAIL can not read src/kde-icons.map"
  return 1
end
lines = map~arrayIn
map~close
call SysMkDir "src/kde"
done = .set~new
failed = 0
do line over lines
  line = line~strip
  if line == "" | line~left(1) == "#" then iterate
  parse var line type id symbol file .
  name = filespec("NAME", file)
  if done~hasIndex(name) then iterate
  from = .stream~new(breeze"/"file)
  if from~open("READ") \== "READY:" then do
    say "oodkde: FAIL" symbol": can not read" breeze"/"file
    failed = failed + 1
    iterate
  end
  bytes = from~charIn(1, from~chars)
  from~close
  if bytes~pos("<svg") == 0 then do
    say "oodkde: FAIL" symbol":" file "is not an SVG file"
    failed = failed + 1
    iterate
  end
  to = .stream~new("src/kde/"name)
  to~open("WRITE REPLACE")
  to~charOut(bytes)
  to~close
  done~put(name)
  say "oodkde: copied" name "("bytes~length "bytes) for" symbol
end
licence = .stream~new(breeze"/COPYING-ICONS")
if licence~open("READ") \== "READY:" then do
  say "oodkde: FAIL can not read" breeze"/COPYING-ICONS"
  return 1
end
text = licence~charIn(1, licence~chars)
licence~close
out = .stream~new("src/kde/COPYING-ICONS")
out~open("WRITE REPLACE")
out~charOut(text)
out~close
say "oodkde: copied COPYING-ICONS"
source = .stream~new("src/kde/SOURCE.txt")
source~open("WRITE REPLACE")
source~lineout("The SVG files in this directory are from the KDE Breeze icon theme.")
source~lineout("Repository: https://github.com/KDE/breeze-icons")
source~lineout("Commit:" commit)
source~lineout("Licence: GNU LGPL version 3 or later, with the clarification in COPYING-ICONS.")
source~lineout("They are unchanged copies. src/kde-icons.map says which Windows system image each stands for.")
source~lineout("Taken by tools/oodkde.rex on" date("S")".")
source~close
if failed > 0 then do
  say "oodkde: FAIL" failed "icons missing"
  return 1
end
say "oodkde: PASS" done~items "icons in src/kde"
return 0
