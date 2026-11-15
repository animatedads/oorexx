/* build.rex -- put the ooRexx Object Editor site together.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx tools/build.rex RUNTIME_DIR OODIALOG_DIST_DIR DESIGNER_EXAMPLES_DIR
   Run in the object editor's directory.  Writes site/: the runtime, the
   page's model (ObjectEditor.cls), ood/ (ooDialog/WASM, so a ::requires
   "ooDialog.cls" loads), and examples/ (Person.cls, and the ooDialog
   Designer's Calculator.rex), LibraryProviders.cls with OodDesigner.cls
   (whose design-line reader it shares) and catalogue/alchemy.idx.                                              */
parse arg runtime oodDist designerExamples
if designerExamples == "" then do
  say "usage: rexx tools/build.rex RUNTIME_DIR OODIALOG_DIST_DIR DESIGNER_EXAMPLES_DIR"
  return 1
end
say "build: runtime" runtime
do f over .array~of("ooRexx.js", "ooRexx-worker.js", "rexx.js", "rexx.wasm", "rexx.data", "js-realm.js", "polygon-clipping.umd.min.js", "serve.mjs", "CPLv1.0.txt", "LICENSE-Apache-2.0.txt")
  call copy runtime"/"f, "site/"f
end
call SysMkDir "site/ood"
do f over .array~of("ooDialog.cls", "oodWeb.cls", "ooShapes.cls")
  call copy oodDist"/"f, "site/ood/"f
end
call copy "src/ObjectEditor.cls", "site/ObjectEditor.cls"
call copy "src/LibraryProviders.cls", "site/LibraryProviders.cls"
call copy designerExamples"/../../src/OodDesigner.cls", "site/OodDesigner.cls"
call copy "src/OxUi.cls", "site/OxUi.cls"
-- from the ooDialog Designer: its texts and the language support, shared
call copy designerExamples"/../../src/OodNls.cls", "site/OodNls.cls"
call copy designerExamples"/../../src/OodUi.cls", "site/OodUi.cls"
call copy designerExamples"/../oodnls.js", "site/oodnls.js"
-- the plugins (optional extras), as the designer's site has them
call copy designerExamples"/../OodPlugins.cls", "site/OodPlugins.cls"
call copy designerExamples"/../plugins.js", "site/plugins.js"
call copy designerExamples"/../plugins.css", "site/plugins.css"
-- every plugin's files, the assist plugin's estate files with them
plugFrom = designerExamples"/../plugins"
call SysFileTree plugFrom"/*", "pf.", "FSO"
do i = 1 to pf.0
  rel = pf.i~substr(pf.i~pos("/plugins/") + 9)
  call makeDirs "site/plugins/"rel~left(max(rel~lastPos("/") - 1, 0))
  call copy pf.i, "site/plugins/"rel
end
say "build: plugins," pf.0 "files"
call SysMkDir "site/catalogue"
call copy "catalogue/alchemy.idx", "site/catalogue/alchemy.idx"
call SysMkDir "site/examples"
call copy "examples/Person.cls", "site/examples/Person.cls"
call copy designerExamples"/Calculator.rex", "site/examples/Calculator.rex"
say "build: done"
return 0

makeDirs: procedure
  use arg mdPath
  mdSoFar = ""
  do mdPart over mdPath~makeArray("/")
    if mdSoFar == "" then mdSoFar = mdPart
    else mdSoFar = mdSoFar"/"mdPart
    call SysMkDir mdSoFar
  end
  return

copy: procedure
  use arg cpFrom, cpTo
  inp = .stream~new(cpFrom)
  if inp~query("exists") == "" then raise syntax 93.900 array("build: missing" cpFrom)
  inp~open("read")
  data = inp~charIn(1, inp~chars)
  inp~close
  out = .stream~new(cpTo)
  out~open("write replace")
  out~charOut(data)
  out~close
  say "  wrote" cpTo "("length(data) "bytes)"
  return
