/* libraries.js -- the Libraries panel, shared by the Object Editor and the
   ooDialog Designer.  Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   The panel shows the shelf (.oxShelf, an OxLibraryShelf in the page's
   ooRexx/WASM session): its providers, their catalogues, a library's details,
   and what an installed file offers (found by loading and examining it).
   "Use" hands each installed path and its ::requires name to the page
   (one call of onUse per file ticked: v0.5).
   No catalogue, install or discovery is done here.

   OxLibraries.setup(sess) -> creates the shelf with the Alchemy and Local providers
   OxLibraries.open({ sess, onUse(requiresName, path), status(text, isErr) }) */
(function () {
  'use strict';
  const T = (key, ...a) => window.OodT(key, ...a);   // the page's texts (oodnls.js)
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
    catch (e) {
      // a refusal: the provider's own message, not ooRexx's "Incorrect call to method. (...)" round it
      let m = String(e.message || e).replace(/^[\s\S]*Error 93\.900:\s*/, '').split('\n')[0];
      const r = /^[^(]*\((.*)\.\)$/.exec(m); if (r) m = r[1];
      say(m, true); throw e;
    }
  }

  function build() {
    panel = el('div', { id: 'libPanel' });
    panel.innerHTML = `
<div class="lp-box"><div class="lp-head"><strong data-nls="libs.title"></strong>
  <select id="lpProvider"></select><button id="lpRefresh" data-nls="libs.refresh" data-nls-title="libs.refresh.tip"></button>
  <span class="lp-sep"></span>
  <input id="lpOwner" data-nls-placeholder="libs.owner" size="10"><input id="lpRepo" data-nls-placeholder="libs.repo" size="10"><input id="lpBranch" placeholder="main" size="6"><button id="lpConnect" data-nls="libs.connect"></button>
  <span class="lp-sep"></span>
  <label class="lp-up"><span data-nls="libs.upload"></span><input id="lpFiles" type="file" multiple accept=".cls,.rex" hidden></label>
  <button id="lpClose" data-nls="libs.close"></button></div>
<div class="lp-body"><div class="lp-left"><input id="lpFilter" data-nls-placeholder="libs.filter"><div id="lpList"></div></div>
<div class="lp-right" id="lpDetail"><p class="lp-hint" data-nls="libs.pick"></p></div></div>
<pre id="lpNotes"></pre></div>`;
    D.body.appendChild(panel);
    window.OodNlsPage.apply(panel);              // its texts, in the page's language
    const $ = (id) => panel.querySelector('#' + id);
    $('lpClose').onclick = () => { panel.hidden = true; };
    $('lpProvider').onchange = () => list();
    let t = null; $('lpFilter').oninput = () => { clearTimeout(t); t = setTimeout(list, 250); };
    $('lpRefresh').onclick = async () => {
      say(T('libs.reading', $('lpProvider').value));
      const n = await call('use arg p; return .oxShelf~provider(p)~refreshFromGitHub', $('lpProvider').value).catch(() => null);
      if (n !== null) { say(T('libs.fromGitHub', n)); list(); }
    };
    $('lpConnect').onclick = async () => {
      const o = $('lpOwner').value.trim(), r = $('lpRepo').value.trim(), b = $('lpBranch').value.trim() || 'main';
      if (!o || !r) return;
      const id = (o + '-' + r).toLowerCase();
      const ok = await call('use arg id, o, r, b; return .oxShelf~register(.OxGitHubProvider~new(id, o"/"r, o, r, b))', id, o, r, b).then(() => true, () => false);
      if (ok) { await providers(id); say(T('libs.connected', o + '/' + r + '@' + b)); }
    };
    $('lpFiles').onchange = async () => {
      const fs = [...$('lpFiles').files];
      for (const f of fs) await call('use arg p, t; return .oxShelf~provider("local")~addFile(p, t)', f.webkitRelativePath || ('uploaded/' + f.name), await f.text()).catch(() => {});
      $('lpFiles').value = '';
      await providers('local'); say(T('libs.uploaded', fs.length));
    };
  }

  async function providers(select) {
    const sel = panel.querySelector('#lpProvider'); sel.textContent = '';
    for (const l of lines(await call('return .oxShelf~providerLines'))) {
      const [id, kind, title] = tabs(l);
      const shown = window.OodNlsPage.has('libs.provider.' + id) ? T('libs.provider.' + id) : title;   // a provider the page knows
      sel.add(new Option(shown + '  (' + kind + ')', id, false, id === select));
    }
    await list();
  }
  async function list() {
    const $ = (id) => panel.querySelector('#' + id);
    const box = $('lpList'); box.textContent = T('libs.readingCatalogue');
    const text = await call('use arg p, f; return .oxShelf~catalogueLines(p, f)', $('lpProvider').value, $('lpFilter').value.trim()).catch(() => '');
    box.textContent = '';
    for (const l of lines(text)) {
      const [id, name, version, files, description] = tabs(l);
      const d = el('div', { className: 'lp-lib' + (cur === id ? ' sel' : '') });
      d.dataset.lib = id;
      d.append(el('b', { textContent: name }), ' ', el('small', { textContent: (version ? 'v' + version + ' · ' : '') + T(files === '1' ? 'libs.file' : 'libs.files', files) }), el('div', { className: 'lp-desc', textContent: description }));
      d.onclick = () => detail(id);
      box.appendChild(d);
    }
    if (!box.children.length) box.textContent = T('libs.none');
  }
  async function detail(id) {
    cur = id;
    panel.querySelectorAll('.lp-lib').forEach((x) => x.classList.toggle('sel', x.dataset.lib === id));
    const box = panel.querySelector('#lpDetail'); box.textContent = T('libs.readingOne');
    const info = {}; const files = [];
    for (const l of lines(await call('use arg i; return .oxShelf~details(i)', id))) { const [k, v] = tabs(l); if (k === 'file') files.push(v); else info[k] = v; }
    box.textContent = '';
    box.append(el('h3', { textContent: info.name + (info.version ? '  v' + info.version : '') }), el('p', { textContent: info.description || '' }));
    // a library's files as checkboxes (v0.5; a radio group before): tick any
    // number, its main file ticked at first; Install installs each ticked
    // file, with what it requires, and Use adds a ::requires for each
    const fl = el('div', { className: 'lp-files' });
    for (const f of files) {
      const r = el('label', {}, el('input', { type: 'checkbox', name: 'lpFile', value: f, checked: f === info.main }), ' ' + f.replace(info.dir + '/', ''));
      fl.appendChild(r);
    }
    const go = el('button', { textContent: T('libs.install'), id: 'lpInstall' });
    const use = el('button', { textContent: T('libs.use'), id: 'lpUse', disabled: true });
    const goodies = el('div', { className: 'lp-goodies', id: 'lpGoodies' });
    const ticked = () => [...fl.querySelectorAll('input[name=lpFile]:checked')].map((x) => x.value);
    let installed = [];
    // a tick changed after an install: what Use would add is no longer what is ticked
    fl.onchange = () => { go.disabled = !ticked().length; use.disabled = true; installed = []; };
    go.disabled = !ticked().length;
    go.onclick = async () => {
      const want = ticked();
      if (!want.length) return;
      use.disabled = true; installed = []; goodies.textContent = '';
      say(T('libs.installing', want.map((f) => f.replace(/.*\//, '')).join(', ')));
      const notes = [];
      for (const f of want) {
        const path = await call('use arg i, f; return .oxShelf~install(i, f)', id, f).catch(() => null);
        notes.push(String(await call('return .oxShelf~notesText').catch(() => '')));
        if (path) installed.push(String(path));
      }
      panel.querySelector('#lpNotes').textContent = notes.filter((n) => n).join('\n');
      if (!installed.length) return;
      say(T('libs.installed', installed.join(', ')));
      let classes = 0;
      for (const path of installed) {
        const g = await call('use arg p; return .oxShelf~goodies(p)', path).catch(() => '');
        if (installed.length > 1) goodies.appendChild(el('div', { className: 'lp-file', textContent: path.replace(/.*\//, '') }));
        let cls = null;
        for (const l of lines(g)) {
          const t = tabs(l);
          // ooRexxDoc: the first sentence on hover, the whole comment on click
          if (t[0] === 'class') {
            const sm = el('summary', { textContent: '.' + t[1] + (t[2] ? '  ' + T('libs.subclassOf', t[2]) : '') });
            cls = el('details', {}, sm); goodies.appendChild(cls); classes++;
            if (t[3] || t[4]) { sm.title = t[3] || T('libs.doc.noSummary'); sm.classList.add('lp-hasdoc'); cls.appendChild(docBlock(t[4] || t[3], true)); }
          } else if (cls) {
            const m = el('div', { className: 'lp-m', textContent: (t[4] === 'class' ? '.' + t[1] + '~' : '~') + t[2] + '   ' + t[3] });
            cls.appendChild(m);
            if (t[5] || t[6]) {
              const full = docBlock(t[6] || t[5], false);
              m.title = t[5] || T('libs.doc.noSummary'); m.classList.add('lp-hasdoc');
              m.onclick = () => { full.hidden = !full.hidden; };
              cls.appendChild(full);
            }
          }
        }
      }
      use.disabled = false;
      say(T('libs.ready', classes));
    };
    use.onclick = async () => {
      // one ::requires for each installed file, in the order they were ticked
      for (const path of installed) {
        const req = String(await call('use arg p; return .oxShelf~requiresName(p, "/home/rexx")', path));
        await cfg.onUse(req, path);
      }
    };
    box.append(fl, el('div', { className: 'lp-actions' }, go, use), goodies);
  }

  function docBlock(text, shown) { return el('pre', { className: 'lp-doc', hidden: !shown, textContent: String(text).replace(/\x0b/g, '\n') }); }

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
