// github_mock_server.mjs -- a local stand-in for the parts of GitHub's REST
// API the git plugin uses (contents GET/PUT, commits), for tests/t08_git.rex
// and the browser scenario.  One repository, owner/demo, branch main, held in
// memory; the token must be FAKE-GITHUB-TOKEN-73.  CORS answered.
// Architecture: Tom Dyer.  Code: Claude (Opus 5.5).
// usage: node github_mock_server.mjs PORT
import http from 'node:http';
import crypto from 'node:crypto';
const port = Number(process.argv[2] || 8976);
const TOKEN = 'FAKE-GITHUB-TOKEN-73';
const sha = (t) => crypto.createHash('sha1').update('blob ' + Buffer.byteLength(t) + '\0' + t).digest('hex');
const files = new Map();      // path -> { text, sha }
const commits = [];           // { sha, path, message, date, name, files: snapshot }
const seen = [];
function put(path, text, message) {
  files.set(path, { text, sha: sha(text) });
  const c = { sha: crypto.randomBytes(20).toString('hex'), path, message, date: new Date(Date.UTC(2026, 10, 15, 2, commits.length)).toISOString().replace('.000', ''), name: 'Tom Dyer', snap: new Map([...files].map(([p, f]) => [p, { ...f }])) };
  commits.push(c); return c;
}
put('designs/Hello.rex', 'say "hello"\n', 'First design');
put('designs/README.md', '# designs\n', 'Readme');
const b64 = (t) => Buffer.from(t, 'utf8').toString('base64').replace(/(.{60})/g, '$1\n');
function cors(res) {
  res.setHeader('access-control-allow-origin', '*');
  res.setHeader('access-control-allow-headers', '*');
  res.setHeader('access-control-allow-methods', 'GET, PUT, OPTIONS');
}
http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => { body += c; });
  req.on('end', () => {
    cors(res);
    if (req.method === 'OPTIONS') { res.statusCode = 204; res.end(); return; }
    res.setHeader('content-type', 'application/json');
    const u = new URL(req.url, 'http://x');
    if (u.pathname === '/seen') { res.end(JSON.stringify(seen)); return; }
    if (u.pathname === '/move') {            // the branch moves on: someone else commits
      const p = u.searchParams.get('path'); put(p, files.get(p).text + '-- elsewhere\n', 'Elsewhere'); res.end('{}'); return;
    }
    seen.push({ method: req.method, path: u.pathname, auth: req.headers.authorization || '', version: req.headers['x-github-api-version'] || '' });
    if (req.headers.authorization !== 'Bearer ' + TOKEN) { res.statusCode = 401; res.end(JSON.stringify({ message: 'Bad credentials' })); return; }
    const m = /^\/repos\/owner\/demo\/(contents|commits)(?:\/(.*))?$/.exec(u.pathname);
    if (!m) { res.statusCode = 404; res.end(JSON.stringify({ message: 'Not Found' })); return; }
    const path = decodeURIComponent(m[2] || '');
    const ref = u.searchParams.get('ref') || 'main';
    if (m[1] === 'commits') {
      const p = u.searchParams.get('path');
      res.end(JSON.stringify(commits.filter((c) => c.path === p).reverse().map((c) => ({ sha: c.sha, commit: { message: c.message, author: { name: c.name, date: c.date } } }))));
      return;
    }
    if (req.method === 'GET') {
      let set = files;
      if (ref !== 'main') { const c = commits.find((x) => x.sha === ref); if (!c) { res.statusCode = 404; res.end(JSON.stringify({ message: 'No commit found for the ref ' + ref })); return; } set = c.snap; }
      if (set.has(path)) { const f = set.get(path); res.end(JSON.stringify({ type: 'file', name: path.split('/').pop(), path, sha: f.sha, encoding: 'base64', content: b64(f.text) })); return; }
      const inDir = [...set.keys()].filter((p) => (path === '' ? !p.includes('/') : p.startsWith(path + '/') && !p.slice(path.length + 1).includes('/')));
      if (inDir.length) { res.end(JSON.stringify(inDir.map((p) => ({ type: 'file', name: p.split('/').pop(), path: p, sha: set.get(p).sha })))); return; }
      res.statusCode = 404; res.end(JSON.stringify({ message: 'Not Found' })); return;
    }
    if (req.method === 'PUT') {
      let b = {}; try { b = JSON.parse(body); } catch (e) { /* */ }
      if (typeof b.message !== 'string' || typeof b.content !== 'string') { res.statusCode = 422; res.end(JSON.stringify({ message: 'Invalid request: message and content must be strings' })); return; }
      const cur = files.get(path);
      if (cur && b.sha !== cur.sha) { res.statusCode = 409; res.end(JSON.stringify({ message: path + ' does not match ' + b.sha })); return; }
      if (!cur && b.sha) { res.statusCode = 422; res.end(JSON.stringify({ message: 'sha given for a new file' })); return; }
      const c = put(path, Buffer.from(b.content, 'base64').toString('utf8'), b.message);
      res.statusCode = cur ? 200 : 201;
      res.end(JSON.stringify({ content: { path, sha: files.get(path).sha }, commit: { sha: c.sha, message: c.message } }));
      return;
    }
    res.statusCode = 405; res.end('{}');
  });
}).listen(port, '127.0.0.1');
