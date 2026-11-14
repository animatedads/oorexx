/* build.rex -- put the ooDialog Designer site together.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx tools/build.rex RUNTIME_DIR OODIALOG_DIST_DIR OBJECT_EDITOR_DIR
     RUNTIME_DIR        Josep Maria Blasco's oorexxwasm-web release, unpacked
     OODIALOG_DIST_DIR  ooDialog/WASM's dist/ (ooDialog.cls, oodWeb.cls, ooShapes.cls)
     OBJECT_EDITOR_DIR  the Object Editor (its reflection, library providers, Libraries panel)
   Run in the designer's directory.  Writes site/: the page, the runtime,
   OodDesigner.cls, ood/ (ooDialog/WASM) and examples/ (made by
   tests/calculator.rex, threads.rex, views.rex and gadgets.rex through OodDesign). */
parse arg runtime oodDist objEd
if objEd == "" then do
  say "usage: rexx tools/build.rex RUNTIME_DIR OODIALOG_DIST_DIR OBJECT_EDITOR_DIR"
  return 1
end
sep = "/"
call log "build: runtime" runtime
do f over .array~of("ooRexx.js", "ooRexx-worker.js", "rexx.js", "rexx.wasm", "rexx.data", "js-realm.js", "polygon-clipping.umd.min.js", "serve.mjs", "CPLv1.0.txt", "LICENSE-Apache-2.0.txt")
  call copy runtime || sep || f, "site" || sep || f
end
call log "build: ooDialog/WASM" oodDist
call SysMkDir "site" || sep || "ood"
do f over .array~of("ooDialog.cls", "oodWeb.cls", "ooShapes.cls")
  call copy oodDist || sep || f, "site" || sep || "ood" || sep || f
end
call copy "src" || sep || "OodDesigner.cls", "site" || sep || "OodDesigner.cls"
-- the Libraries panel and what it runs on: the Object Editor's reflection
-- and the library providers, with the Alchemy index
call copy objEd"/src/ObjectEditor.cls", "site/ObjectEditor.cls"
call copy objEd"/src/LibraryProviders.cls", "site/LibraryProviders.cls"
call copy objEd"/site/libraries.js", "site/libraries.js"
call copy objEd"/site/libraries.css", "site/libraries.css"
call SysMkDir "site/catalogue"
call copy objEd"/catalogue/alchemy.idx", "site/catalogue/alchemy.idx"
call SysMkDir "site" || sep || "examples"
call write "site/examples/Calculator.rex", .calcDesign~build~generate
call write "site/examples/Threads.rex", .threadsDesign~build~generate
call write "site/examples/Contacts.rex", .viewsDesign~build~generate
call write "site/examples/Gadgets.rex", .gadgetsDesign~build~generate
call log "build: done"
return 0

log: procedure
  use arg logText
  say logText
  return

copy: procedure
  use arg cpFrom, cpTo
  inp = .stream~new(cpFrom)
  if inp~query("exists") == "" then raise syntax 93.900 array("build: missing" cpFrom)
  inp~open("read")
  data = inp~charIn(1, inp~chars)
  inp~close
  call write cpTo, data
  return

write: procedure
  use arg wrTo, wrData
  out = .stream~new(wrTo)
  out~open("write replace")
  out~charOut(wrData)
  out~close
  say "  wrote" wrTo "("length(wrData) "bytes)"
  return

::requires "OodDesigner.cls"
::requires "calculator.rex"
::requires "threads.rex"
::requires "views.rex"
::requires "gadgets.rex"
