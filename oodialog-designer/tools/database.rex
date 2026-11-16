/* Stage the Alchemy Database Lab in the editor's isolated WASM session.
 * Architecture: Tom Dyer. Code: ChatGPT (GPT-6).
 * This is a dependency closure, not an SQL implementation.
 * The editor's own interpreter is never loaded with DatabaseRow/Error etc.
 *
 * rexx tools/database.rex ESTATE_PACKAGES_DIR OUTPUT_DIRECTORY
 */
parse arg estate destination .
if estate = "" | destination = "" then do
  say "usage: rexx tools/database.rex ESTATE_PACKAGES_DIR OUTPUT_DIRECTORY"
  exit 2
end
lab = estate || "/oorexx_oodialog_database_lab_v0.1.3/src/OodDatabaseLab.cls"
if stream(lab, "c", "query exists") = "" then lab = estate || "/oorexx_oodialog_database_lab_v0.1.2/src/OodDatabaseLab.cls"
if stream(lab, "c", "query exists") = "" then lab = estate || "/oorexx_oodialog_database_lab_v0.1/src/OodDatabaseLab.cls"
if stream(lab, "c", "query exists") = "" then do
  say "database: Alchemy oorexx_oodialog_database_lab_v0.1 not yet installed; panel will explain"
  exit 0
end
call SysMkDir destination
manifest = .array~new
-- Package locations pin the supported versions; files come entirely from
-- transitive ::requires, not a hand-maintained dependency file list.
roots = .array~of( -
  estate || "/oorexx_oodialog_database_lab_v0.1.3/src", -
  estate || "/oorexx_oodialog_database_lab_v0.1.2/src", -
  estate || "/oorexx_oodialog_database_lab_v0.1/src", -
  estate || "/nosqlserver_v0.92-dev1/src", -
  estate || "/alchemy_objects_v0.8/src", -
  estate || "/oorexx_crypto_v0.1/src", -
  estate || "/oorexx_oodialog_designer_v0.8/src")
todo = .queue~new
todo~queue(lab)
seen = .directory~new
do while todo~items > 0
  entry = todo~pull
  name = entry~substr(entry~lastPos("/") + 1)
  if seen~hasIndex(name~upper) then do
    if seen[name~upper] \== entry then raise syntax 93.900 array("database: dependency collision" name)
    iterate
  end
  seen[name~upper] = entry
  call copy entry, destination || "/" || name
  manifest~append(name)
  do req over requiresOf(entry)
    parse var req reqName reqKind
    if reqKind~caselessEquals("LIBRARY") | wordpos(reqName~upper, "JSON.CLS CSVSTREAM.CLS YAML.CLS") > 0 then iterate
    from = ""
    do root over roots while from == ""
      if SysIsFile(root || "/" || reqName) then from = root || "/" || reqName
    end
    if from == "" then raise syntax 93.900 array("database: missing dependency" reqName "from" entry)
    todo~queue(from)
  end
end
call write destination || "/manifest.txt", manifest~sort~makeString("L", "0a"x) || "0a"x
say "database: staged" manifest~items "Alchemy library files"
exit 0

requiresOf: procedure
  use arg file
  rqOut = .array~new
  sourceFile = .stream~new(file)
  if sourceFile~query("exists") == "" then raise syntax 93.900 array("database: missing source" file)
  do line over sourceFile~arrayIn
    line = line~strip
    if \line~left(10)~caselessEquals("::requires") then iterate
    rest = line~substr(11)~strip
    quote = rest~left(1)
    if quote \== '"' & quote \== "'" then iterate
    parse var rest (quote) reqName (quote) reqKind .
    rqOut~append(reqName reqKind)
  end
  sourceFile~close
  return rqOut

copy: procedure
  use arg from, to
  inp = .stream~new(from)
  if inp~query("exists") = "" then raise syntax 93.900 array("database: missing Alchemy dependency" from)
  inp~open("read")
  contents = inp~charIn(1, inp~chars)
  inp~close
  call write to, contents
  return

write: procedure
  use arg to, contents
  out = .stream~new(to)
  out~open("write replace")
  out~charOut(contents)
  out~close
  return
