/* libraries.js -- the Libraries panel, shared by the Object Editor and the
   ooDialog Designer.  Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   The panel shows the shelf (.oxShelf, an OxLibraryShelf in the page's
   ooRexx/WASM session): its providers, their catalogues, a library's details,
   and what an installed file offers (found by loading and examining it).
   "Use" hands the installed path and its ::requires name to the page.
   No catalogue, install or discovery is done here.

   OxLibraries.setup(sess) -> creates the shelf with the Alchemy and Local providers
   OxLibraries.open({ sess, onUse(requiresName, path), status(text, isErr) }) */
(function () {
  'use strict';
  const D = document;
  const lines = (t) => String(t || '').split('\n').filter((l) => l !== '');
  const tabs = (l) => l.split('\t');
  const esc = (s) => String(s).replace(/"/g, '""');
  let cfg = null, cur = null, panel = null;

  async function setup(sess) {
    const index = new URL('catalogue/alchemy.idx', location.href).href;
    await sess.eval('use arg idx; .local~oxShelf = .OxLibraryShelf~new("/home/rexx/lib");' +
      ' .oxShelf~register(.OxAlchemyProvider~new(idx));' +
      ' .oxShelf~register(.OxLocalProvider~new("local", "Files from this computer", "/home/rexx/local")); return 0', index);
  }

  function el(tag, props, ...kids) { const e = Object.assign(D.createElement(tag), props || {}); kids.forEach((k) => e.append(k)); return e; }
  function say(t, err) { if (cfg && cfg.status) cfg.status(t, err); }
  async function call(code, ...args) {
    try { return await cfg.sess.eval(code, ...args); }
    catch (e) { const m = String(e.message || e).replace(/^[\s\S]*Error 93\.900:\s*/, '').split('\n')[0]; say(m, true); throw e; }
  }

  function build() {
    panel = el('div', { id: 'libPanel' });
    panel.innerHTML = `
<div class="lp-box"><div class="lp-head"><strong>Libraries</strong>
  <select id="lpProvider"></select><button id="lpRefresh" title="Read the repository's tree from GitHub">Refresh from GitHub</button>
  <span class="lp-sep"></span>
  <input id="lpOwner" placeholder="owner" size="10"><input id="lpRepo" placeholder="repo" size="10"><input id="lpBranch" placeholder="main" size="6"><button id="lpConnect">Connect GitHub repo</button>
  <span class="lp-sep"></span>
  <label class="lp-up">Upload files…<input id="lpFiles" type="file" multiple accept=".cls,.rex" hidden></label>
  <button id="lpClose">Close</button></div>
<div class="lp-body"><div class="lp-left"><input id="lpFilter" placeholder="filter: logging, maths, …"><div id="lpList"></div></div>
<div class="lp-right" id="lpDetail"><p class="lp-hint">Pick a library.</p></div></div>
<pre id="lpNotes"></pre></div>`;
    D.body.appendChild(panel);
    const $ = (id) => panel.querySelector('#' + id);
    $('lpClose').onclick = () => { panel.hidden = true; };
    $('lpProvider').onchange = () => list();
    let t = null; $('lpFilter').oninput = () => { clearTimeout(t); t = setTimeout(list, 250); };
    $('lpRefresh').onclick = async () => {
      say('Reading ' + $('lpProvider').value + ' from GitHub…');
      const n = await call('use arg p; return .oxShelf~provider(p)~refreshFromGitHub', $('lpProvider').value).catch(() => null);
      if (n !== null) { say(n + ' libraries, from GitHub.'); list(); }
    };
    $('lpConnect').onclick = async () => {
      const o = $('lpOwner').value.trim(), r = $('lpRepo').value.trim(), b = $('lpBranch').value.trim() || 'main';
      if (!o || !r) return;
      const id = (o + '-' + r).toLowerCase();
      const ok = await call('use arg id, o, r, b; return .oxShelf~register(.OxGitHubProvider~new(id, o"/"r, o, r, b))', id, o, r, b).then(() => true, () => false);
      if (ok) { await providers(id); say('Connected ' + o + '/' + r + '@' + b + '.'); }
    };
    $('lpFiles').onchange = async () => {
      const fs = [...$('lpFiles').files];
      for (const f of fs) await call('use arg p, t; return .oxShelf~provider("local")~addFile(p, t)', f.webkitRelativePath || ('uploaded/' + f.name), await f.text()).catch(() => {});
      $('lpFiles').value = '';
      await providers('local'); say(fs.length + ' file(s) added to the local provider.');
    };
  }

  async function providers(select) {
    const sel = panel.querySelector('#lpProvider'); sel.textContent = '';
    for (const l of lines(await call('return .oxShelf~providerLines'))) {
      const [id, kind, title] = tabs(l); sel.add(new Option(title + '  (' + kind + ')', id, false, id === select));
    }
    await list();
  }
  async function list() {
    const $ = (id) => panel.querySelector('#' + id);
    const box = $('lpList'); box.textContent = 'Reading the catalogue…';
    const text = await call('use arg p, f; return .oxShelf~catalogueLines(p, f)', $('lpProvider').value, $('lpFilter').value.trim()).catch(() => '');
    box.textContent = '';
    for (const l of lines(text)) {
      const [id, name, version, files, description] = tabs(l);
      const d = el('div', { className: 'lp-lib' + (cur === id ? ' sel' : '') });
      d.dataset.lib = id;
      d.append(el('b', { textContent: name }), ' ', el('small', { textContent: (version ? 'v' + version + ' · ' : '') + files + ' file' + (files === '1' ? '' : 's') }), el('div', { className: 'lp-desc', textContent: description }));
      d.onclick = () => detail(id);
      box.appendChild(d);
    }
    if (!box.children.length) box.textContent = 'Nothing matches.';
  }
  async function detail(id) {
    cur = id;
    panel.querySelectorAll('.lp-lib').forEach((x) => x.classList.toggle('sel', x.dataset.lib === id));
    const box = panel.querySelector('#lpDetail'); box.textContent = 'Reading…';
    const info = {}; const files = [];
    for (const l of lines(await call('use arg i; return .oxShelf~details(i)', id))) { const [k, v] = tabs(l); if (k === 'file') files.push(v); else info[k] = v; }
    box.textContent = '';
    box.append(el('h3', { textContent: info.name + (info.version ? '  v' + info.version : '') }), el('p', { textContent: info.description || '' }));
    const fl = el('div', { className: 'lp-files' });
    for (const f of files) {
      const r = el('label', {}, el('input', { type: 'radio', name: 'lpFile', value: f, checked: f === info.main }), ' ' + f.replace(info.dir + '/', ''));
      fl.appendChild(r);
    }
    const go = el('button', { textContent: 'Install and show what it offers', id: 'lpInstall' });
    const use = el('button', { textContent: 'Use it here', id: 'lpUse', disabled: true });
    const goodies = el('div', { className: 'lp-goodies', id: 'lpGoodies' });
    let installed = null;
    go.onclick = async () => {
      const f = (panel.querySelector('input[name=lpFile]:checked') || {}).value || '';
      say('Installing ' + f.replace(/.*\//, '') + ' and what it requires…');
      const path = await call('use arg i, f; return .oxShelf~install(i, f)', id, f).catch(() => null);
      panel.querySelector('#lpNotes').textContent = String(await call('return .oxShelf~notesText').catch(() => ''));
      if (!path) return;
      installed = String(path);
      say('Installed ' + installed + '.  Loading it to see what it offers…');
      const g = await call('use arg p; return .oxShelf~goodies(p)', installed).catch(() => '');
      goodies.textContent = '';
      let cls = null;
      for (const l of lines(g)) {
        const t = tabs(l);
        if (t[0] === 'class') { cls = el('details', {}, el('summary', { textContent: '.' + t[1] + (t[2] ? '  (subclass of ' + t[2] + ')' : '') })); goodies.appendChild(cls); }
        else if (cls) cls.appendChild(el('div', { className: 'lp-m', textContent: (t[4] === 'class' ? '.' + t[1] + '~' : '~') + t[2] + '   ' + t[3] }));
      }
      use.disabled = false;
      say('Ready: ' + goodies.children.length + ' public classes.  "Use it here" adds the ::requires.');
    };
    use.onclick = async () => {
      if (!installed) return;
      const req = String(await call('use arg p; return .oxShelf~requiresName(p, "/home/rexx")', installed));
      await cfg.onUse(req, installed);
    };
    box.append(fl, el('div', { className: 'lp-actions' }, go, use), goodies);
  }

  async function open(c) {
    cfg = c;
    if (!panel) build();
    panel.hidden = false;
    await providers(panel.querySelector('#lpProvider').value || 'alchemy');
  }
  // the installed files, for a run to carry: {path: text}
  async function installedFiles(sess) {
    const out = {};
    const paths = lines(await sess.eval('if .local~hasIndex("OXSHELF") then return .oxShelf~installedLines; return ""'));
    for (const p of paths) out[p] = String(await sess.eval('use arg p; return .oxShelf~fileText(p)', p));
    return out;
  }
  window.OxLibraries = { setup, open, installedFiles };
})();
