// ssc_mock_server.mjs -- a local stand-in for a Semantic Source Control
// store's MCP endpoint (oorexx_semantic_source_store dev29: source.get_package,
// source.objects_in, source.history, source.propose_edit), for
// tests/t09_ssc.rex and the browser scenario.  JSON-RPC tools/call over
// HTTP; the bearer must be FAKE-SSC-SESSION-84.  Replies are wrapped as the
// estate's MCP service wraps a dispatch reply (structuredContent ok, code,
// detail, value), except source.history, which comes as text content only.
// One source unit, src/Greeter.cls: a class and two methods.
// Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
// usage: node ssc_mock_server.mjs PORT
import http from 'node:http';
const port = Number(process.argv[2] || 8977);
const SESSION = 'FAKE-SSC-SESSION-84';
let n = 0;
const rid = () => 'ssr_' + String(++n).padStart(4, '0');
const objects = [
  { id: 'sso_class', kind: 'CLASS', name: 'Greeter', text: '::class Greeter public' },
  { id: 'sso_init', kind: 'METHOD', name: 'init', text: '::method init\n  expose name\n  use arg name' },
  { id: 'sso_greet', kind: 'METHOD', name: 'greet', text: '::method greet\n  expose name\n  return "Hello," name' },
];
const revs = {};      // object id -> [{revision_id, revision_no, status, changed_at, changed_by, text}]
const current = {};   // object id -> current revision id
function addRev(id, text, status, by) {
  const r = { revision_id: rid(), revision_no: (revs[id] || []).length + 1, status, changed_at: '2026-11-15T02:' + String(n).padStart(2, '0') + ':00Z', changed_by: by, text };
  (revs[id] = revs[id] || []).push(r); return r;
}
for (const o of objects) current[o.id] = addRev(o.id, o.text, 'ACCEPTED', 'tom').revision_id;
const UNIT = 'ssu_greeter', PATH = 'src/Greeter.cls';
const unitSnap = {};  // unit revision -> file text
function fileText() { return objects.map((o) => revs[o.id].find((r) => r.revision_id === accepted(o.id)).text).join('\n') + '\n'; }
function accepted(id) { return [...revs[id]].reverse().find((r) => r.status === 'ACCEPTED').revision_id; }
function unitRev() { const r = addRev(UNIT, '', 'ACCEPTED', 'tom'); unitSnap[r.revision_id] = fileText(); return r; }
unitRev();
const seen = [];
function ok(op, payload) { return { ok: true, code: 'OK', detail: '', value: Object.assign({ ok: 1, operation: op }, payload) }; }
function refuse(op, error) { return { ok: true, code: 'OK', detail: '', value: { ok: 0, operation: op, error } }; }
function call(op, a) {
  if (op === 'source.get_package') {
    if (!a.roots || a.roots[0] !== 'oorexx://demo/Greeter') return refuse(op, 'unknown root: ' + (a.roots || [])[0]);
    const pin = a.pins && a.pins[UNIT];
    if (pin && !unitSnap[pin]) return refuse(op, 'pinned revision ' + pin + ' does not belong to ' + UNIT);
    const text = pin ? unitSnap[pin] : fileText();
    const manifest = [{ object_id: UNIT, object_kind: 'SOURCE_UNIT', revision_id: revs[UNIT][revs[UNIT].length - 1].revision_id, origin_member_path: PATH, resolution: pin ? 'pinned' : 'latest-accepted' }]
      .concat(objects.map((o) => ({ object_id: o.id, object_kind: o.kind, revision_id: accepted(o.id), resolution: 'latest-accepted' })));
    return ok(op, { files: { [PATH]: text, 'README.md': '# Greeter\n' }, manifest, resolution_policy: 'pin-or-latest-accepted' });
  }
  if (op === 'source.objects_in') {
    if (a.source_unit_object_id !== UNIT) return ok(op, { objects: [] });
    return ok(op, { objects: objects.map((o, i) => ({ ordinal: String(i + 1), object_id: o.id, object_kind: o.kind, name: o.name })) });
  }
  if (op === 'source.history') {
    const rs = revs[a.object_id];
    if (!rs) return refuse(op, 'unknown semantic object: ' + a.object_id);
    return { text: { ok: 1, operation: op, revisions: rs.map(({ text, ...r }) => r) } };
  }
  if (op === 'source.propose_edit') {
    const id = a.object_id, rs = revs[id];
    if (!rs) return refuse(op, 'unknown semantic object: ' + id);
    if (!rs.some((r) => r.revision_id === a.base_revision_id)) return refuse(op, 'unknown base revision: ' + a.base_revision_id);
    if (typeof a.source_text !== 'string') return refuse(op, 'source_text is required');
    const r = addRev(id, a.source_text, 'PROPOSED', 'session-principal');
    const conflict = current[id] !== a.base_revision_id;
    const result = { object_id: id, base_revision_id: a.base_revision_id, revision_id: r.revision_id, current_revision_id: current[id], conflict: conflict ? 1 : 0, status: conflict ? 'BRANCH_CONFLICT' : 'PROPOSED', reason: a.reason };
    if (conflict) { result.branch_id = 'br_conflict_' + r.revision_id.slice(4); result.branch_classification = 'CONFLICT'; }
    else current[id] = r.revision_id;
    return ok(op, { result });
  }
  return null;
}
function cors(res) {
  res.setHeader('access-control-allow-origin', '*');
  res.setHeader('access-control-allow-headers', '*');
  res.setHeader('access-control-allow-methods', 'POST, GET, OPTIONS');
}
http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => { body += c; });
  req.on('end', () => {
    cors(res);
    if (req.method === 'OPTIONS') { res.statusCode = 204; res.end(); return; }
    res.setHeader('content-type', 'application/json');
    if (req.url === '/seen') { res.end(JSON.stringify(seen)); return; }
    if (req.url === '/accept-and-move') {     // someone else's edit accepted: the unit moves on
      const o = objects[2]; addRev(o.id, o.text + '\n  -- reviewed', 'ACCEPTED', 'reviewer'); current[o.id] = accepted(o.id); unitRev(); res.end('{}'); return;
    }
    let rpc = {}; try { rpc = JSON.parse(body); } catch (e) { /* */ }
    const name = rpc.params && rpc.params.name;
    seen.push({ auth: req.headers.authorization || '', mcpName: req.headers['mcp-name'] || '', name });
    if (req.headers.authorization !== 'Bearer ' + SESSION) {
      res.statusCode = 401; res.end(JSON.stringify({ jsonrpc: '2.0', id: rpc.id, error: { code: -32001, message: 'AUTHENTICATED_PRINCIPAL_REQUIRED' } })); return;
    }
    if (rpc.method !== 'tools/call') { res.end(JSON.stringify({ jsonrpc: '2.0', id: rpc.id, error: { code: -32601, message: 'Method not found: ' + rpc.method } })); return; }
    const r = call(name, (rpc.params && rpc.params.arguments) || {});
    if (!r) { res.end(JSON.stringify({ jsonrpc: '2.0', id: rpc.id, error: { code: -32602, message: 'Unknown tool: ' + name } })); return; }
    const result = r.text ? { content: [{ type: 'text', text: JSON.stringify(r.text) }] } : { isError: r.value.ok ? false : true, structuredContent: r, content: [{ type: 'text', text: 'OK' }] };
    res.end(JSON.stringify({ jsonrpc: '2.0', id: rpc.id, result }));
  });
}).listen(port, '127.0.0.1');
