/* oodbuild.rex -- build dist/ for ooDialog/WASM.
 * Architecture: Tom Dyer.  Code: Claude (Fable 5.2).
 * usage: rexx tools/oodbuild.rex   (from the project directory)
 * Steps, each logged: generate ooDialog.cls from upstream; embed the page
 * runtime into oodWeb.cls; copy ooShapes.cls. */
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
say "oodbuild: done"
return 0
