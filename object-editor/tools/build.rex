/* build.rex -- put the ooRexx Object Editor site together.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx tools/build.rex RUNTIME_DIR OODIALOG_DIST_DIR DESIGNER_EXAMPLES_DIR
   Run in the object editor's directory.  Writes site/: the runtime, the
   page's model (ObjectEditor.cls), ood/ (ooDialog/WASM, so a ::requires
   "ooDialog.cls" loads), and examples/ (Person.cls, and the ooDialog
   Designer's Calculator.rex).                                              */
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
call SysMkDir "site/examples"
call copy "examples/Person.cls", "site/examples/Person.cls"
call copy designerExamples"/Calculator.rex", "site/examples/Calculator.rex"
say "build: done"
return 0

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
