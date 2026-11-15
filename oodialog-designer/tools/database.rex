/* Stage the Alchemy Database Lab in the editor's isolated WASM session.
 * This is an explicit, versioned dependency set, not an SQL implementation.
 * The editor's own interpreter is never loaded with DatabaseRow/Error etc.
 *
 * rexx tools/database.rex ESTATE_PACKAGES_DIR OUTPUT_DIRECTORY
 */
parse arg estate destination .
if estate = "" | destination = "" then do
  say "usage: rexx tools/database.rex ESTATE_PACKAGES_DIR OUTPUT_DIRECTORY"
  exit 2
end
lab = estate || "/oorexx_oodialog_database_lab_v0.1/src/OodDatabaseLab.cls"
if stream(lab, "c", "query exists") = "" then do
  say "database: Alchemy oorexx_oodialog_database_lab_v0.1 not yet installed; panel will explain"
  exit 0
end
call SysMkDir destination
manifest = .array~new
source = .array~new
source~append(lab)
source~append(estate || "/nosqlserver_v0.92-dev1/src/NoSQLServer.cls")
source~append(estate || "/alchemy_objects_v0.8/src/AlchemyObject.cls")
source~append(estate || "/alchemy_objects_v0.8/src/AlchemySecurity.cls")
source~append(estate || "/alchemy_objects_v0.8/src/AlchemyLockedMethod.cls")
source~append(estate || "/alchemy_objects_v0.8/src/AlchemyEvidence.cls")
source~append(estate || "/oorexx_crypto_v0.1/src/crypto.cls")
do entry over source
  name = entry~substr(entry~lastPos("/") + 1)
  call copy entry, destination || "/" || name
  manifest~append(name)
end
call write destination || "/manifest.txt", manifest~makeString("L", "0a"x) || "0a"x
say "database: staged" manifest~items "Alchemy library files"
exit 0

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
