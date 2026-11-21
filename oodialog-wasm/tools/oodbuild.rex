/* oodbuild.rex -- build dist/ for ooDialog/WASM.
 * Architecture: Tom Dyer.  Code: Claude (Fable 5.2).
 * usage: rexx tools/oodbuild.rex   (from the project directory)
 * Steps, each logged: generate ooDialog.cls from upstream; embed the page
 * runtime and the KDE icons (src/kde, taken by tools/oodkde.rex) into oodWeb.cls;
 * copy ooShapes.cls. */
say "oodbuild: generating ooDialog.cls"
call "tools/oodgen.rex" "upstream/ooDialog src/patches.txt dist"
if result \== 0 then do
  say "oodbuild: generator failed, rc" result
  return 1
end
say "oodbuild: embedding oodialog-web.js into oodWeb.cls"
js = .stream~new("src/oodialog-web.js")~~open("READ")
jsLines = js~arrayIn
js~close
in = .stream~new("src/oodWeb.cls")~~open("READ")
out = .stream~new("dist/oodWeb.cls")~~open("WRITE REPLACE")
do line over in~arrayIn
  if line == "@@OODJS@@" then do jl over jsLines
    out~lineout(jl)
  end
  else if line == "@@KDEICONS@@" then do
    -- one line for each row of src/kde-icons.map: type id symbol name base64(SVG)
    say "oodbuild: embedding the KDE icons of src/kde into oodWeb.cls"
    map = .stream~new("src/kde-icons.map")~~open("READ")
    rows = 0
    do row over map~arrayIn
      row = row~strip
      if row == "" | row~left(1) == "#" then iterate
      parse var row type id symbol file .
      name = filespec("NAME", file)
      svg = .stream~new("src/kde/"name)
      if svg~open("READ") \== "READY:" then do
        say "oodbuild: FAIL src/kde/"name "is missing; run tools/oodkde.rex"
        return 1
      end
      bytes = svg~charIn(1, svg~chars)
      svg~close
      out~lineout(type id symbol name bytes~encodeBase64)
      rows = rows + 1
    end
    map~close
    say "oodbuild:" rows "icon rows"
  end
  else out~lineout(line)
end
in~close
out~close
say "oodbuild: copying ooShapes.cls"
shapes = .stream~new("src/ooShapes.cls")~~open("READ")
copy = .stream~new("dist/ooShapes.cls")~~open("WRITE REPLACE")
copy~arrayOut(shapes~arrayIn)
shapes~close
copy~close
say "oodbuild: copying oodPrint.cls"
printFrom = .stream~new("src/oodPrint.cls")~~open("READ")
printTo = .stream~new("dist/oodPrint.cls")~~open("WRITE REPLACE")
printTo~arrayOut(printFrom~arrayIn)
printFrom~close
printTo~close
say "oodbuild: copying the four .cls files to site/ for the demo page"
do name over .array~of("ooDialog.cls", "oodWeb.cls", "ooShapes.cls", "oodPrint.cls")
  from = .stream~new("dist/"name)~~open("READ")
  to = .stream~new("site/"name)~~open("WRITE REPLACE")
  to~arrayOut(from~arrayIn)
  from~close
  to~close
end
say "oodbuild: done"
return 0
