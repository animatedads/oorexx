/* plugins.rex -- lay the designer's plugins out for a page or a test run:
   index.txt, each plugin's folder, plugins/common/, and the estate files the
   plugins that call out need, followed from their ::requires and laid out
   under OUT_DIR/estate/ as the estate lays them out (their ::requires
   "../inspector/..." need that); index.txt's paths = entries put estate/...
   and common on REXX_PATH.  Each plugin's files.txt lists its files.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx tools/plugins.rex DESIGNER_ROOT ESTATE_PACKAGES_DIR OUT_DIR
     ESTATE_PACKAGES_DIR: the estate's packages/ (Alchemy's repository has
     them all), or a folder of links to: oorexx_slam_bostoncrab_v0.24,
     alchemy_objects_v0.8, oorexx_crypto_v0.1, oorexx_secret_broker_v0.2,
     oorexx_ai_access_v0.6, oorexx_ai_provider_anthropic_v0.5,
     oorexx_ai_provider_openai_compat_v0.6.
   Used by tools/build.rex (OUT_DIR site/plugins) and tests/run_all.rex. */
parse arg root estate dst .
if dst == "" then do
  say "usage: rexx tools/plugins.rex DESIGNER_ROOT ESTATE_PACKAGES_DIR OUT_DIR"
  return 1
end
src = root"/plugins"
call makeDirs dst
call SysMkDir dst"/bostoncrab"
call copy src"/index.txt", dst"/index.txt"
call copy src"/bostoncrab/BostonCrabPlugin.cls", dst"/bostoncrab/BostonCrabPlugin.cls"
call copy estate"/oorexx_slam_bostoncrab_v0.24/tests/PitfallChecker.cls", dst"/bostoncrab/PitfallChecker.cls"
call SysMkDir dst"/common"
call copy estate"/oorexx_slam_bostoncrab_v0.24/tests/PitfallChecker.cls", dst"/common/PitfallChecker.cls"
call SysFileTree src"/common/*.cls", "cm.", "FO"
do i = 1 to cm.0
  call copy cm.i, dst"/common/"cm.i~substr(cm.i~lastPos("/") + 1)
end
do id over .array~of("assist", "git", "ssc")
  call layoutPlugin id, estate
end
call log "plugins: laid out in" dst
return 0

-- one plugin that calls out: its folder's files, and the closure of its
-- main file's ::requires (beside the requiring file, then plugins/common,
-- then the estate's folders), as files.txt
layoutPlugin: procedure expose src dst
  use arg bpId, estate
  call SysMkDir dst"/"bpId
  listed = .array~new
  call SysFileTree src"/"bpId"/*.cls", "own.", "FO"
  do i = 1 to own.0
    name = own.i~substr(own.i~lastPos("/") + 1)
    call copy own.i, dst"/"bpId"/"name
    listed~append(bpId"/"name)
  end
  main = src"/"bpId"/"bpId~left(1)~upper || bpId~substr(2)"Plugin.cls"
  if bpId == "ssc" then main = src"/ssc/SscPlugin.cls"
  if \SysIsFile(main) then return                          -- not written yet
  stack = .array~of("alchemy_objects_v0.8/src", "oorexx_crypto_v0.1/src", "oorexx_secret_broker_v0.2/src", -
    "oorexx_ai_access_v0.6/src", "oorexx_ai_provider_anthropic_v0.5/src", "oorexx_ai_provider_openai_compat_v0.6/src")
  skip = "OODPLUGINS.CLS JSON.CLS FETCH.CLS"
  todo = .queue~new
  todo~queue(.array~of(src"/"bpId, main))
  seen = .set~new
  do while todo~items > 0
    parse value todo~pull~makeString("L", "09"x) with fromDir "09"x fromFile
    do l over requiresOf(fromFile)
      parse var l name kind
      if kind~caselessEquals("LIBRARY") | skip~wordPos(name~upper) > 0 then iterate
      found = ""; rel = ""
      if fromDir == src"/"bpId then do
        if SysIsFile(fromDir"/"name) then iterate              -- its own, copied
      end
      else if fromDir~left(length(estate)) == estate then do  -- beside an estate file
        if SysIsFile(fromDir"/"name) then do; found = fromDir"/"name; rel = "estate/"found~substr(length(estate) + 2); end
      end
      if found == "" then if SysIsFile(dst"/common/"name) then do; found = dst"/common/"name; rel = "common/"name; end
      do d over stack while found == ""
        if SysIsFile(estate"/"d"/"name) then do; found = estate"/"d"/"name; rel = "estate/"d"/"name; end
      end
      if found == "" then raise syntax 93.900 array("build:" bpId "needs" name "(from" fromFile"), not in the estate")
      if seen~hasIndex(rel) then iterate
      seen~put(rel)
      if rel~left(7) == "estate/" then do
        call makeDirs dst"/"rel~left(rel~lastPos("/") - 1)
        call copy found, dst"/"rel
      end
      listed~append(rel)
      todo~queue(.array~of(found~left(found~lastPos("/") - 1), found))
    end
  end
  call write dst"/"bpId"/files.txt", listed~makeString("L", "0a"x) || "0a"x
  call log "plugins:" bpId"," listed~items "files"
  return

-- the ::requires of a file: name [LIBRARY], one an item
requiresOf: procedure
  use arg rqFile
  rqOut = .array~new
  rqIn = .stream~new(rqFile)
  if rqIn~query("exists") == "" then raise syntax 93.900 array("build: missing" rqFile)
  do rqLine over rqIn~arrayIn
    rqS = rqLine~strip
    if \rqS~left(10)~caselessEquals("::requires") then iterate
    rqRest = rqS~substr(11)~strip
    rqQ = rqRest~left(1)
    if rqQ \== '"' & rqQ \== "'" then iterate
    parse var rqRest (rqQ) rqName (rqQ) rqKind .
    rqOut~append(rqName rqKind)
  end
  rqIn~close
  return rqOut

makeDirs: procedure
  use arg mdPath
  mdSoFar = ""
  if mdPath~left(1) == "/" then mdSoFar = "/"
  do mdPart over mdPath~makeArray("/")
    if mdPart == "" then iterate
    if mdSoFar == "" | mdSoFar == "/" then mdSoFar = mdSoFar || mdPart
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

