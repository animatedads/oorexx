/* SscPlugin.cls -- an optional extra for the ooDialog Designer and the ooRexx
   Object Editor: Semantic Source Control.  Architecture: Tom Dyer.
   Code: Claude (Opus 5.5).  German: Claude (Opus 5.5).

   Not git-shaped.  The store (oorexx_semantic_source_store, dev28 and later)
   holds semantic objects, each with its own revisions: a class, each method,
   attribute, constant, routine; a file is a projection of them.  So:
   - open: source.get_package for the root object (the latest accepted
     closure), the file from its files, and the source unit's objects
     (source.objects_in) with the revision each was opened at (the manifest,
     else source.history);
   - commit: the file cut into its directives, as the store cuts it; each
     piece changed since it was opened is one source.propose_edit (object,
     its exact base revision, the piece's new text, the message as reason).
     A proposal is PROPOSED, for review: nothing is accepted from here.  A
     stale base is the store's to settle (a CONFLICT branch keeping both); a
     piece that is new or gone has no object to propose an edition of, and is
     reported, not sent;
   - status: has the source unit a newer revision than the one opened;
   - history: the source unit's revisions; at: a package with the unit pinned.

   The way in: MCP tools/call over HTTP, by ADDRESS FETCH, with the session's
   bearer (Authorization: Bearer <access_token>).  The token is the one
   auth.authenticate gives after the local authenticator signs the challenge
   (the signed-challenge design): the private key stays on that machine, and
   the token, short-lived, goes into this plugin's secret setting (this
   page's memory only, the Secret Broker's lease, a header for one request).
   A reply is read as the estate's MCP service gives it (structuredContent
   ok, code, detail, value) or as SemanticSourceMcpOperations~dispatch
   answers (ok, error, payload).

   Status: written to MCP_COMMANDS.md and SemanticSourceMcpOperations of
   dev29, tested against a stand-in (tests/fixtures/ssc_mock_server.mjs);
   not yet against a live store, whose MCP host wiring dev29 itself reports
   unverified. */

::requires "OodPlugins.cls"
::requires "OodBroker.cls"

::class SscPlugin public subclass OodPlugin
::method module_version class
  return "0.8.0"
::method module_lastChanged class
  return "2026-11-15"
::method module_version
  return "0.8.0"
::method module_lastChanged
  return "2026-11-15"

::method init
  expose opened rpcId
  use strict arg id
  self~init:super(id)
  self~setSetting("endpoint", "")
  self~setSetting("project", "default")
  self~setSetting("root", "")
  self~setSetting("unit", "")
  self~setSetting("session", "SSC.SESSION")
  opened = .directory~new          -- path -> what was opened: text, unit, unitRevision, objects
  rpcId = 0

::method resources
  return .resources

::method provides
  return "scm"

::method settingLines
  out = .array~new
  out~append("endpoint" || "09"x || "text" || "09"x || self~nls("set.endpoint"))
  out~append("root" || "09"x || "text" || "09"x || self~nls("set.root"))
  out~append("unit" || "09"x || "text" || "09"x || self~nls("set.unit"))
  out~append("project" || "09"x || "text" || "09"x || self~nls("set.project"))
  out~append("session" || "09"x || "secret" || "09"x || self~nls("set.session"))
  return out~makeString("L", "0a"x)

::method refuse
  use strict arg key, a1 = "", a2 = ""
  raise syntax 93.900 array(self~nls(key, a1, a2))

/* One MCP tool call.  Answers the payload (a Directory); refused when the
   store says no, with its reason. */
::method tool
  expose rpcId
  use strict arg name, args
  endpoint = self~setting("endpoint")~strip
  if endpoint == "" then self~refuse("err.noEndpoint")
  if \.local~hasIndex("OODFETCHLOADED") then do
    .context~package~loadPackage("fetch.cls")
    .local~oodFetchLoaded = .true
  end
  rpcId = rpcId + 1
  params = .directory~new
  params["name"] = .JsonString~new(name)
  params["arguments"] = args
  body = .directory~new
  body["jsonrpc"] = .JsonString~new("2.0")
  body["id"] = rpcId
  body["method"] = .JsonString~new("tools/call")
  body["params"] = params
  token = .OodSecretUse~value(self~host, self~setting("session"))
  address fetch
  "TIMEOUT 60"
  "HEADER Accept application/json"
  "HEADER Mcp-Name FROM name"
  if token \== .nil then do
    auth = "Bearer" token
    token = ""
    "HEADER Authorization FROM auth"
    auth = ""
  end
  "POST" endpoint "JSON FROM body INTO text"
  status = rc
  "HEADER Authorization"
  "HEADER Mcp-Name"
  "HEADER Accept"
  if status < 0 then self~refuse("err.network", endpoint)
  reply = .nil
  if text~strip \== "" then do
    signal on syntax name notJson
    "JSON INTO reply"
    signal off syntax
  end
  if status \= 0 then do
    said = ""
    if reply~isA(.Directory) then said = sscSaid(reply)
    if status = 401 | status = 403 then self~refuse("err.auth", status, said)
    self~refuse("err.http", status, said)
  end
  if \reply~isA(.Directory) then self~refuse("err.reply", name)
  if reply["error"] \== .nil then self~refuse("err.store", name, sscSaid(reply))
  result = reply["result"]
  if \result~isA(.Directory) then self~refuse("err.reply", name)
  sc = result["structuredContent"]
  if sc == .nil then do                  -- the text content, as JSON
    do item over result["content"]
      if item["type"] == "text" then do
        signal on syntax name notJson
        sc = .JSON~fromJSON(item["text"])
        signal off syntax
        leave
      end
    end
  end
  if \sc~isA(.Directory) then self~refuse("err.reply", name)
  -- the estate's MCP service: ok, code, detail, value (the dispatch reply)
  if sc~hasIndex("value"), sc~hasIndex("code") then do
    if \sscTrue(sc["ok"]) then self~refuse("err.store", name, sscText(sc["detail"]) sscText(sc["code"]))
    if sc["value"]~isA(.Directory) then sc = sc["value"]
  end
  if sc~hasIndex("ok"), \sscTrue(sc["ok"]) then self~refuse("err.store", name, sscText(sc["error"]))
  return sc
notJson:
  self~refuse("err.reply", name)

::method package private
  use strict arg pins = .nil
  if self~setting("endpoint")~strip == "" then self~refuse("err.noEndpoint")
  root = self~setting("root")~strip
  if root == "" then self~refuse("err.noRoot")
  args = .directory~new
  args["roots"] = .array~of(.JsonString~new(root))
  args["project_id"] = .JsonString~new(self~setting("project", "default"))
  if pins \== .nil then args["pins"] = pins
  return self~tool("source.get_package", args)

::method scmList
  pkg = self~package
  out = .array~new
  files = pkg["files"]
  if files~isA(.Directory) then do path over files~allIndexes~sort
    if wordpos(path~substr(path~lastPos(".") + 1)~lower, "rex cls rexx") = 0 then iterate
    out~append(path || "09"x || self~setting("root"))
  end
  return out~makeString("L", "0a"x)

::method scmOpen
  expose opened
  use strict arg path
  pkg = self~package
  files = pkg["files"]
  text = .nil
  if files~isA(.Directory) then text = files[path]
  if text == .nil then self~refuse("err.noFile", path)
  -- the revision each object was opened at: the manifest's, else its history's last
  revs = .directory~new
  manifest = pkg["manifest"]
  if manifest~isA(.Array) then do e over manifest
    if e~isA(.Directory), e["object_id"] \== .nil then revs[e["object_id"]] = sscText(e["revision_id"])
  end
  unit = self~unitFor(path, manifest)
  objects = .array~new
  if unit \== "" then do
    a = .directory~new
    a["source_unit_object_id"] = .JsonString~new(unit)
    listed = self~tool("source.objects_in", a)["objects"]
    if listed~isA(.Array) then do o over listed
      d = .directory~new
      d["ID"] = sscText(o["object_id"])
      d["KIND"] = sscText(o["object_kind"])~upper
      d["NAME"] = sscText(o["name"])
      d["BASE"] = revs[d["ID"]]
      if d["BASE"] == .nil then d["BASE"] = self~latest(d["ID"])
      objects~append(d)
    end
  end
  o = .directory~new
  o["TEXT"] = text; o["UNIT"] = unit; o["OBJECTS"] = objects
  o["UNITREV"] = ""
  if unit \== "" then o["UNITREV"] = self~latest(unit)
  opened[path] = o
  return "REF" o["UNITREV"] || "0a"x || "TEXT" || "0a"x || text

-- the source unit object of a file: the setting, or the manifest's
::method unitFor private
  use strict arg path, manifest
  unit = self~setting("unit")~strip
  if unit \== "" then return unit
  if \manifest~isA(.Array) then return ""
  found = .array~new
  do e over manifest
    if \e~isA(.Directory) then iterate
    if sscText(e["object_kind"])~upper == "SOURCE_UNIT" then found~append(e)
  end
  do e over found
    do k over .array~of("origin_member_path", "materialisation_path", "path", "projection_path")
      if sscText(e[k]) == path then return sscText(e["object_id"])
    end
  end
  if found~items = 1 then return sscText(found[1]["object_id"])
  return ""

-- an object's newest revision ("" if it has none)
::method latest private
  use strict arg objectId
  a = .directory~new
  a["object_id"] = .JsonString~new(objectId)
  revs = self~tool("source.history", a)["revisions"]
  if \revs~isA(.Array) then return ""
  if revs~items = 0 then return ""
  return sscText(revs[revs~items]["revision_id"])

::method scmStatus
  expose opened
  use strict arg path, ref
  o = opened[path]
  if o == .nil then self~refuse("err.notOpened", path)
  if o["UNIT"] == "" then return "STATE UNKNOWN" || "0a"x || "NOTE" self~nls("st.noUnit")
  now = self~latest(o["UNIT"])
  if now == ref then return "STATE CURRENT"
  return "STATE MOVED" || "0a"x || "NOTE" self~nls("st.moved")

::method scmCommit
  expose opened
  use strict arg path, text, message, ref
  o = opened[path]
  if o == .nil then self~refuse("err.notOpened", path)
  st = "STATUS"; nl = "0a"x
  if message~strip == "" then return st "refused" || nl || "REF" ref || nl || "NOTE" self~nls("err.noMessage")
  if o["UNIT"] == "" then return st "refused" || nl || "REF" ref || nl || "NOTE" self~nls("st.noUnit")
  old = sscPieces(o["TEXT"]); new = sscPieces(text)
  notes = .array~new; proposed = 0; conflicts = 0; blocked = 0
  -- pieces matched by kind, name and their count among those of that kind and name
  do n over new
    p = sscFind(old, n["KEY"])
    if p == .nil then do
      notes~append(self~nls("cm.new", n["LABEL"])); blocked = blocked + 1
      iterate
    end
    p["SEEN"] = 1
    if p["TEXT"] == n["TEXT"] then iterate
    obj = sscFind(o["OBJECTS"], n["KEY"])
    if obj == .nil then do
      notes~append(self~nls("cm.noObject", n["LABEL"])); blocked = blocked + 1
      iterate
    end
    a = .directory~new
    a["object_id"] = .JsonString~new(obj["ID"])
    a["base_revision_id"] = .JsonString~new(obj["BASE"])
    a["source_text"] = .JsonString~new(n["TEXT"])
    a["reason"] = .JsonString~new(message)
    r = self~tool("source.propose_edit", a)["result"]
    status = ""; rev = ""; branch = ""
    if r~isA(.Directory) then do
      status = sscText(r["status"]); rev = sscText(r["revision_id"]); branch = sscText(r["branch_id"])
    end
    if branch \== "" | status~upper~pos("CONFLICT") > 0 then do
      notes~append(self~nls("cm.conflict", n["LABEL"], branch)); conflicts = conflicts + 1
    end
    else if status~upper == "UNCHANGED" then nop
    else do
      notes~append(self~nls("cm.proposed", n["LABEL"], rev)); proposed = proposed + 1
      obj["BASE"] = rev                    -- a further edit builds on it
    end
  end
  do p over old
    if p["SEEN"] \== 1 then do
      notes~append(self~nls("cm.gone", p["LABEL"])); blocked = blocked + 1
    end
  end
  if proposed + conflicts = 0 then do
    if notes~items = 0 then notes~append(self~nls("cm.nothing"))
    out = st "refused"
  end
  else if conflicts > 0 | blocked > 0 then out = st "refused"
  else out = st "ok"
  if proposed > 0 then do
    o["TEXT"] = text                        -- what is proposed is the new base here
    notes~append(self~nls("cm.review", proposed))
  end
  out = out || nl || "REF" ref
  do t over notes
    out = out || nl || "NOTE" t
  end
  return out

::method scmHistory
  expose opened
  use strict arg path
  o = opened[path]
  if o == .nil then self~refuse("err.notOpened", path)
  if o["UNIT"] == "" then return ""
  a = .directory~new
  a["object_id"] = .JsonString~new(o["UNIT"])
  revs = self~tool("source.history", a)["revisions"]
  out = .array~new
  if revs~isA(.Array) then do i = revs~items to 1 by -1
    r = revs[i]
    out~append(sscText(r["revision_id"]) || "09"x || sscText(r["changed_at"]) || "09"x || sscText(r["changed_by"]) || "09"x || -
      sscText(r["status"]) "#" || sscText(r["revision_no"]))
  end
  return out~makeString("L", "0a"x)

::method scmAt
  expose opened
  use strict arg path, ref
  o = opened[path]
  if o == .nil then self~refuse("err.notOpened", path)
  pins = .directory~new
  pins[o["UNIT"]] = .JsonString~new(ref)
  files = self~package(pins)["files"]
  if files~isA(.Directory), files~hasIndex(path) then return files[path]
  self~refuse("err.noFile", path)


/* The file cut into its directives: before the first, the executable
   section; each :: directive with the lines up to the next.  A piece: KIND,
   NAME, KEY (kind, the class for a method, name, and its count among the
   same), LABEL, TEXT (trailing blank lines left out). */
::routine sscPieces
  use strict arg text
  out = .array~new
  lines = text~changeStr("0d0a"x, "0a"x)~makeArray("0a"x)
  cur = .nil; cls = ""; counts = .directory~new
  cur = sscPiece("EXECUTABLE", "", "", counts)
  do l over lines
    s = l~strip("L")
    if s~left(2) == "::" then do
      out~append(cur)
      parse var s "::" kind name rest
      kind = kind~upper
      name = name~strip("B", '"')~strip("B", "'")
      if kind == "CLASS" then cls = name
      owner = ""
      if wordpos(kind, "METHOD ATTRIBUTE CONSTANT") > 0 then do
        owner = cls
        if wordpos("CLASS", rest~upper) > 0 then owner = cls "class"    -- a class method is not the instance method
      end
      if wordpos(kind, "REQUIRES OPTIONS") > 0 then name = ""
      cur = sscPiece(kind, name, owner, counts)
      cur["TEXT"] = l
    end
    else if cur["TEXT"] == .nil then cur["TEXT"] = l
    else cur["TEXT"] = cur["TEXT"] || "0a"x || l
  end
  out~append(cur)
  keep = .array~new
  do p over out
    t = p["TEXT"]
    if t == .nil then t = ""
    ls = t~makeArray("0a"x)
    do while ls~items > 0
      if ls[ls~items]~strip \== "" then leave
      ls~delete(ls~items)
    end
    t = ls~makeString("L", "0a"x)
    p["TEXT"] = t
    if p["KIND"] == "EXECUTABLE" & t~strip == "" then iterate
    keep~append(p)
  end
  return keep

::routine sscPiece
  use strict arg kind, name, owner, counts
  p = .directory~new
  p["KIND"] = kind; p["NAME"] = name
  k = kind || "|" || owner~upper || "|" || name~upper
  if counts[k] == .nil then counts[k] = 0
  counts[k] = counts[k] + 1
  p["KEY"] = k || "|" || counts[k]
  label = kind~lower name
  if owner \== "" then label = kind~lower owner"~"name
  p["LABEL"] = label~strip
  return p

-- the item with this key (pieces: KEY; the store's objects: KIND and NAME,
-- matched in their order, the owning class not known to the store's list)
::routine sscFind
  use strict arg items, key
  parse var key kind "|" owner "|" name "|" nth
  if items~items = 0 then return .nil
  if items[1]~hasIndex("KEY") then do
    do p over items
      if p["KEY"] == key then return p
    end
    return .nil
  end
  -- the store's objects: the nth of that kind and name, counting all classes
  seen = 0
  do o over items
    if o["KIND"] \== kind then iterate
    if \o["NAME"]~caselessEquals(name) then iterate
    seen = seen + 1
    if seen = nth then return o
  end
  return .nil

-- a JSON true (1, "1", "true", json.cls's JSONBoolean true)
::routine sscTrue
  use strict arg v
  if v == .nil then return .false
  if v~isA(.String) then return v == 1 | v~caselessEquals("true")
  if v~hasMethod("VALUE") then return v~value == 1        -- json.cls's JSONBoolean
  return .false

::routine sscText
  use strict arg v
  if v == .nil then return ""
  return v~string

-- what a JSON-RPC or MCP reply says went wrong
::routine sscSaid
  use strict arg reply
  if reply["error"]~isA(.Directory) then return sscText(reply["error"]["message"])
  if reply["error"] \== .nil then return sscText(reply["error"])
  if reply["message"] \== .nil then return sscText(reply["message"])
  return ""

::resource strings.en
set.endpoint = The store's MCP address
set.root = The object to open (its id, as source.get_package takes it)
set.unit = Its source unit (empty: from the package's manifest)
set.project = Project
set.session = Session token (from auth.authenticate: your local authenticator signs the challenge)
err.noEndpoint = Give the store's MCP address in the SSC plugin's settings.
err.noRoot = Give the object to open in the SSC plugin's settings.
err.network = No answer from %1 (the network, or the address).
err.auth = The store refused the session (%1): %2.  Sign a new challenge and give the new token.
err.http = The store answered %1: %2
err.reply = The store's answer to %1 could not be read.
err.store = The store refused %1: %2
err.noFile = %1 is not in the package.
err.notOpened = Open %1 from the store first.
err.noMessage = Say what the change is for: it is the proposal's reason.
st.noUnit = The file's source unit is not known: give it in the settings.
st.moved = The source unit has a newer revision than the one opened.
cm.new = %1 is new: the store takes new objects by import, not as an edit; not sent.
cm.gone = %1 is gone: the store takes removals by review, not as an edit; not sent.
cm.noObject = %1 changed, but the store lists no such object; not sent.
cm.proposed = %1: proposed as %2.
cm.conflict = %1: the store kept both editions on conflict branch %2.
cm.nothing = Nothing changed.
cm.review = %1 proposed for review: nothing is accepted until it is reviewed.
::END

::resource strings.de
-- Deutsch: übersetzt von Claude (Opus 5.5); bitte von einem Muttersprachler prüfen
set.endpoint = Die MCP-Adresse des Speichers
set.root = Das zu öffnende Objekt (seine Kennung, wie source.get_package sie nimmt)
set.unit = Seine Quelleinheit (leer: aus dem Manifest des Pakets)
set.project = Projekt
set.session = Sitzungs-Token (von auth.authenticate: Ihr lokaler Authentifikator signiert die Herausforderung)
err.noEndpoint = Die MCP-Adresse des Speichers in den Einstellungen des SSC-Plugins angeben.
err.noRoot = Das zu öffnende Objekt in den Einstellungen des SSC-Plugins angeben.
err.network = Keine Antwort von %1 (das Netz oder die Adresse).
err.auth = Der Speicher wies die Sitzung zurück (%1): %2.  Eine neue Herausforderung signieren und das neue Token angeben.
err.http = Der Speicher antwortete %1: %2
err.reply = Die Antwort des Speichers auf %1 ist nicht lesbar.
err.store = Der Speicher wies %1 zurück: %2
err.noFile = %1 ist nicht im Paket.
err.notOpened = %1 zuerst aus dem Speicher öffnen.
err.noMessage = Sagen, wozu die Änderung dient: es ist die Begründung des Vorschlags.
st.noUnit = Die Quelleinheit der Datei ist nicht bekannt: in den Einstellungen angeben.
st.moved = Die Quelleinheit hat eine neuere Revision als die geöffnete.
cm.new = %1 ist neu: der Speicher nimmt neue Objekte durch Import, nicht als Bearbeitung; nicht gesendet.
cm.gone = %1 ist entfernt: der Speicher nimmt Entfernungen durch Prüfung, nicht als Bearbeitung; nicht gesendet.
cm.noObject = %1 geändert, aber der Speicher führt kein solches Objekt; nicht gesendet.
cm.proposed = %1: vorgeschlagen als %2.
cm.conflict = %1: der Speicher behielt beide Fassungen im Konfliktzweig %2.
cm.nothing = Nichts geändert.
cm.review = %1 zur Prüfung vorgeschlagen: nichts wird angenommen, bevor es geprüft ist.
::END
