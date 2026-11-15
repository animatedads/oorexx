/* build.rex -- put the ooDialog Designer site together.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx tools/build.rex RUNTIME_DIR OODIALOG_DIST_DIR OBJECT_EDITOR_DIR REXX_PARSER_DIR ESTATE_PACKAGES_DIR
     RUNTIME_DIR        Josep Maria Blasco's oorexxwasm-web release, unpacked
     OODIALOG_DIST_DIR  ooDialog/WASM's dist/ (ooDialog.cls, oodWeb.cls, ooShapes.cls)
     OBJECT_EDITOR_DIR  the Object Editor (its reflection, library providers, Libraries panel)
     REXX_PARSER_DIR    Josep Maria Blasco's Rexx Parser (its bin/ is copied, with a
                        manifest the page reads to put it in the session)
     ESTATE_PACKAGES_DIR  the Alchemy estate's packages/ (or a folder of links to
                        them): Boston Crab v0.24 (PitfallChecker.cls) for the Boston
                        Crab and assist plugins, and for the assist plugin the AI
                        stack: alchemy_objects v0.8, crypto v0.1, secret_broker v0.2,
                        ai_access v0.6, ai_provider_anthropic v0.5,
                        ai_provider_openai_compat v0.6, laid out as in the estate
   Run in the designer's directory.  Writes site/: the page, the runtime,
   OodDesigner.cls, ood/ (ooDialog/WASM) and examples/ (made by
   tests/calculator.rex, threads.rex, views.rex and gadgets.rex through OodDesign). */
parse arg runtime oodDist objEd rexxParser estate
if estate == "" then do
  say "usage: rexx tools/build.rex RUNTIME_DIR OODIALOG_DIST_DIR OBJECT_EDITOR_DIR REXX_PARSER_DIR ESTATE_PACKAGES_DIR"
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
call copy "src/OodGraph.cls", "site/OodGraph.cls"
call copy "src/OodBoundGraph.cls", "site/OodBoundGraph.cls"
call copy "src/OodNls.cls", "site/OodNls.cls"
call copy "src/OodPlugins.cls", "site/OodPlugins.cls"
-- the plugins: optional extras, each in its folder, listed in index.txt,
-- with the estate files they need (tools/plugins.rex, which run_all.rex uses too)
address system 'rexx tools/plugins.rex . "'estate~strip'" site/plugins'
if rc \= 0 then raise syntax 93.900 array("build: tools/plugins.rex failed:" rc)
-- The Database Lab is optional in an older estate, but complete when its
-- Alchemy package exists; unlike the normal editor it gets its own interpreter.
address system 'rexx tools/database.rex "'estate~strip'" site/database-lab'
if rc \= 0 then raise syntax 93.900 array("build: tools/database.rex failed:" rc)
call copy "src/OodUi.cls", "site/OodUi.cls"
-- the Rexx Parser: bin/ and its notices, and a manifest of the files
call SysFileTree rexxParser"/bin/*", "rp.", "FSO"
manifest = .array~new
do i = 1 to rp.0
  rel = rp.i~substr(length(rexxParser) + 2)~changeStr("\", "/")
  dir = "site/rexx-parser/" || rel~left(rel~lastPos("/") - 1)
  call makeDirs dir
  call copy rp.i, "site/rexx-parser/"rel
  manifest~append(rel)
end
do f over .array~of("LICENSE", "NOTICE", "VERSION")
  call copy rexxParser"/"f, "site/rexx-parser/"f
end
-- since 20261115 its NOTICE names files under the CPL 1.0 (ANSI.ErrorText.cls): its LICENSE-CPL with them
if stream(rexxParser"/LICENSE-CPL", "c", "query exists") \= "" then call copy rexxParser"/LICENSE-CPL", "site/rexx-parser/LICENSE-CPL"
call write "site/rexx-parser/manifest.txt", manifest~makeString("L", "0a"x) || "0a"x
-- the Libraries panel and what it runs on: the Object Editor's reflection
-- and the library providers, with the Alchemy index
call copy objEd"/src/ObjectEditor.cls", "site/ObjectEditor.cls"
call copy objEd"/src/LibraryProviders.cls", "site/LibraryProviders.cls"
call copy objEd"/src/OxUi.cls", "site/OxUi.cls"
call copy objEd"/site/libraries.js", "site/libraries.js"
call copy objEd"/site/libraries.css", "site/libraries.css"
call SysMkDir "site/catalogue"
call copy objEd"/catalogue/alchemy.idx", "site/catalogue/alchemy.idx"
call SysMkDir "site" || sep || "examples"
call write "site/examples/Calculator.rex", .calcDesign~build~generate
call write "site/examples/Threads.rex", .threadsDesign~build~generate
call write "site/examples/Contacts.rex", .viewsDesign~build~generate
call write "site/examples/Gadgets.rex", .gadgetsDesign~build~generate
call write "site/examples/ContactsDE.rex", .contactsDeDesign~build~generate
call write "site/examples/People.rex", .peopleDesign~build~generate
-- the data a bound design (People) runs with: the object layer, the example
-- classes and database (tools/data.rex)
address system 'rexx tools/data.rex . "'estate~strip'" site/data'
if rc \= 0 then raise syntax 93.900 array("build: tools/data.rex failed:" rc)
call log "build: done"
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
::requires "languages.rex"
::requires "people.rex"
