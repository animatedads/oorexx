/* oodialog-wasm sphere: structural check. Every pack and profile JSON parses with
 * ooRexx json.cls; the nine articles are there; each has a title, a summary and
 * evidence; the article named by start_here exists.
 * Architecture: Tom Dyer. Author: Claude (Fable 5.2), 2026-11-15.
 * Use: rexx tests/check_sphere.rex [root]      exit 0 PASS, 1 FAIL */
parse arg root
if root = "" then root = "."
call SysFileTree root"/packs/*.json", "f.", "FSO"
call SysFileTree root"/profiles/*.json", "p.", "FSO"
articles = .directory~new
start = ""
count = 0
do i = 1 to f.0 + p.0
  if i <= f.0 then name = f.i
  else do
    k = i - f.0
    name = p.k
  end
  s = .stream~new(name)
  s~open("read")
  text = s~charin(1, s~chars)
  s~close
  signal on syntax name bad
  doc = .json~fromJson(text)
  signal off syntax
  count = count + 1
  if \doc~isA(.directory) then iterate
  if doc["kind"] == "article" then do
    id = doc["id"]
    articles[id] = doc
    do field over .array~of("title", "summary")
      if doc[field] == .nil then call fail "article" id "has no" field
      if doc[field]~length < 20 then call fail "article" id "has a" field "that is too short"
    end
    if doc["sphere"] \== "oodialog-wasm" then call fail "article" id "names the wrong sphere"
    if doc["provenance"] == .nil then call fail "article" id "has no provenance"
    if doc["provenance"]~items < 1 then call fail "article" id "has no evidence"
  end
  if doc["kind"] == "sphere" then start = doc["start_here"][1]
end
if articles~items \== @ARTICLES@ then call fail "expected @ARTICLES@ articles, found" articles~items
if start == "" then call fail "the sphere names no start_here article"
if \articles~hasIndex(start) then call fail "start_here names" start", which is not an article"
say "PASS oodialog-wasm sphere:" count "JSON documents parse," articles~items "articles with evidence, start_here" start
exit 0
bad:
  say "FAIL JSON does not parse:" name
  exit 1
fail:
  parse arg why
  say "FAIL" why
  exit 1
::requires "json.cls"
