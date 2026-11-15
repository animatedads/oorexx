/* data.rex -- lay out the data a bound design runs with in the page:
   the object layer (MappedObjects.cls and what it requires, followed from
   their ::requires: NoSQLServer and Alchemy Objects), the example classes
   (the .cls files in data/) and the example database ent (made from data/ent.sql with
   NoSQLServer's FILE engine), with files.txt listing them.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   usage: rexx tools/data.rex DESIGNER_ROOT ESTATE_PACKAGES_DIR OUT_DIR
     ESTATE_PACKAGES_DIR: the estate's packages/: oorexx_mapped_objects_v0.1,
     nosqlserver_v0.92-dev1, alchemy_objects_v0.8, oorexx_crypto_v0.1.
   REXX_PATH must reach NoSQLServer.cls (to make the database).
   In OUT_DIR: lib/ (the classes, flat: the page puts them beside the
   program), ent/ (the database), files.txt. */
parse arg root estate dst .
if dst == "" then do
  say "usage: rexx tools/data.rex DESIGNER_ROOT ESTATE_PACKAGES_DIR OUT_DIR"
  return 1
end
dst = .File~new(dst)~absolutePath              -- SysFileTree answers absolute names
stack = .array~of("oorexx_mapped_objects_v0.1/src", "nosqlserver_v0.92-dev1/src", "alchemy_objects_v0.8/src", "oorexx_crypto_v0.1/src")
skip = "JSON.CLS FETCH.CLS CSVSTREAM.CLS YAML.CLS RXREGEXP.CLS"
call makeDirs dst"/lib"
listed = .array~new
-- the closure of MappedObjects.cls, flat
todo = .queue~new
todo~queue(estate"/oorexx_mapped_objects_v0.1/src/MappedObjects.cls")
seen = .set~new
do while todo~items > 0
  file = todo~pull
  name = file~substr(file~lastPos("/") + 1)
  if seen~hasIndex(name~upper) then iterate
  seen~put(name~upper)
  call copy file, dst"/lib/"name
  listed~append("lib/"name)
  do l over requiresOf(file)
    parse var l rq kind
    if kind~caselessEquals("LIBRARY") | skip~wordPos(rq~upper) > 0 then iterate
    if rq~pos("/") > 0 then raise syntax 93.900 array("data: a ::requires with a path (" rq ") cannot be laid out flat, from" file)
    found = ""
    do d over stack while found == ""
      if SysIsFile(estate"/"d"/"rq) then found = estate"/"d"/"rq
    end
    if found == "" then raise syntax 93.900 array("data:" rq "(from" file") is not in the estate")
    todo~queue(found)
  end
end
-- the example classes
call SysFileTree root"/data/*.cls", "cls.", "FO"
do i = 1 to cls.0
  name = cls.i~substr(cls.i~lastPos("/") + 1)
  call copy cls.i, dst"/lib/"name
  listed~append("lib/"name)
end
-- the example database, made again each build
call SysFileTree dst"/ent", "old.", "DO"
if old.0 > 0 then address system 'rm -rf "'dst'/ent"'
call SysMkDir dst"/ent"
engine = .FileDatabaseEngine~new(dst"/ent")
cat = .table~new
cat["name"] = "ent"; cat["formatVersion"] = 1; cat["tables"] = .array~new
engine~writeCatalog(cat)
sql = .NoSQLServerSQL~new(engine)
n = 0
do l over .stream~new(root"/data/ent.sql")~arrayIn
  if l~strip == "" | l~strip~left(2) == "--" then iterate
  r = sql~execute(l)
  if r~status \== .Error~SUCCESS then raise syntax 93.900 array("data: ent.sql refused" r~error r~message "--" l)
  n = n + 1
end
call SysFileTree dst"/ent/*", "db.", "FSO"
do i = 1 to db.0
  if db.i~pos("/querylog/") > 0 then iterate          -- the engine's own log: not data
  listed~append(db.i~substr(length(dst) + 2))
end
out = .stream~new(dst"/files.txt")
out~open("write replace")
out~charOut(listed~makeString("L", "0a"x) || "0a"x)
out~close
say "data:" listed~items "files in" dst"," n "statements for ent"
return 0

requiresOf: procedure
  use arg rqFile
  rqOut = .array~new
  do rqLine over .stream~new(rqFile)~arrayIn
    rqS = rqLine~strip
    if \rqS~left(10)~caselessEquals("::requires") then iterate
    rqRest = rqS~substr(11)~strip
    rqQ = rqRest~left(1)
    if rqQ \== '"' & rqQ \== "'" then iterate
    parse var rqRest (rqQ) rqName (rqQ) rqKind .
    rqOut~append(rqName rqKind)
  end
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

copy: procedure
  use arg cpFrom, cpTo
  inp = .stream~new(cpFrom)
  if inp~query("exists") == "" then raise syntax 93.900 array("data: missing" cpFrom)
  inp~open("read")
  data = inp~charIn(1, inp~chars)
  inp~close
  o = .stream~new(cpTo)
  o~open("write replace")
  o~charOut(data)
  o~close
  return

::requires "NoSQLServer.cls"
