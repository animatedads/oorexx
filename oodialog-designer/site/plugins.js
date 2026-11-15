/* plugins.js -- the Plugins panel and the findings strip, for the ooDialog
   Designer and the ooRexx Object Editor.  Architecture: Tom Dyer.
   Code: Claude (Opus 5.5).

   The plugins and what they decide are ooRexx (OodPlugins.cls, in the page's
   session); this file shows them.  A secret setting goes from its field to
   the host's secret store (OodSecrets) and is never shown again.

   await OodPluginsPage.rexxPath()             REXX_PATH for rexx.start's env: the
                                               plugins' paths = entries (ooRexx reads
                                               REXX_PATH only as it starts)
   await OodPluginsPage.setup(sess, { status, rx, onChange })
   OodPluginsPage.open()                       the panel
   await OodPluginsPage.diagnose(text)         [{plugin, rule, line, column, severity, fixId, message}]
   await OodPluginsPage.fix(plugin, text, id)  the text fixed
   OodPluginsPage.show(box, findings, { onFix, onLine })   the strip
   await OodPluginsPage.setLanguage(lang)
   await OodPluginsPage.assistIds()            the enabled plugins that propose code
   OodPluginsPage.ask({ title, code, context, apply })   the Ask panel: code() and
                                               context() give the method body and what
                                               it is in; apply(text) takes a proposal
                                               that passed.  The plugin decides what
                                               passes (OodPlugins.cls, AssistPlugin.cls);
                                               this shows it, and its diff.
   await OodPluginsPage.scmIds()               the enabled plugins that do source control
   OodPluginsPage.source({ name, text, open }) the Source panel: name() the file's
                                               name, text() its text now, open(name,
                                               text) puts a version in the editor.  The
                                               plugin decides (OodPlugins.cls ~scm); this
                                               shows the files, the changes since the
                                               file was opened, commit and history. */
(function () {
  'use strict';
  const D = document;
  const T = (key, ...a) => window.OodT(key, ...a);
  const KEY = 'oodDesigner.plugins';
  let cfg = null, panel = null;
  const lines = (t) => String(t || '').split('\n').filter((l) => l !== '');
  const el = (tag, props, ...kids) => { const e = Object.assign(D.createElement(tag), props || {}); e.append(...kids); return e; };
  async function call(code, ...args) { return cfg.rx(() => cfg.sess.eval(code, ...args)); }

  function saved() { try { return JSON.parse(localStorage.getItem(KEY) || '[]'); } catch (e) { return []; } }
  function save(ids) { try { localStorage.setItem(KEY, JSON.stringify(ids)); } catch (e) { /* storage may be off */ } }

  async function rexxPath() {
    const r = await fetch('plugins/index.txt').catch(() => null);
    if (!r || !r.ok) return '';
    const out = [];
    for (const l of (await r.text()).split('\n')) {
      const m = /^\s*paths\s*=\s*(.*)$/.exec(l);
      if (m) for (const p of m[1].split(/\s+/).filter(Boolean)) if (!out.includes('/home/rexx/plugins/' + p)) out.push('/home/rexx/plugins/' + p);
    }
    if (out.length) out.push('/usr/lib/ooRexx');        // the runtime's own REXX_PATH, which env replaces
    return out.join(':');
  }

  async function setup(sess, options) {
    cfg = Object.assign({ status: () => {}, onChange: () => {}, rx: (fn) => fn() }, options, { sess });
    const base = new URL('plugins', location.href).href;
    await call('use arg b, l; .local~oodPluginsHost = .OodPluginHost~new(b, l); return 0', base, window.OodNlsPage.lang || 'en');
    for (const id of saved()) await call('use arg i; .oodPluginsHost~enable(i); return 0', id).catch(() => {});
  }
  async function catalogue() {
    return lines(await call('return .oodPluginsHost~catalogueLines')).map((l) => {
      const [id, title, summary, provides, on] = l.split('\t'); return { id, title, summary, provides, on: on === '1' };
    });
  }
  async function enabled() { return String(await call('return .oodPluginsHost~enabledIds')).split(' ').filter(Boolean); }

  async function open() {
    if (!panel) {
      panel = el('div', { id: 'plugPanel' });
      panel.innerHTML = '<div class="pp-box"><div class="pp-head"><strong data-nls="plug.title"></strong>' +
        '<span class="pp-hint" data-nls="plug.hint"></span><button id="ppClose" data-nls="btn.close"></button></div><div id="ppList"></div></div>';
      D.body.appendChild(panel);
      panel.querySelector('#ppClose').onclick = () => { panel.hidden = true; };
    }
    window.OodNlsPage.apply(panel);
    panel.hidden = false;
    await draw();
  }
  async function draw() {
    const box = panel.querySelector('#ppList'); box.textContent = '';
    for (const p of await catalogue()) {
      const row = el('div', { className: 'pp-plugin' }); row.dataset.plugin = p.id;
      const on = el('input', { type: 'checkbox', checked: p.on, id: 'pp-' + p.id });
      on.addEventListener('change', async () => {
        if (on.checked) await call('use arg i; .oodPluginsHost~enable(i); return 0', p.id).catch(() => { on.checked = false; });
        else await call('use arg i; return .oodPluginsHost~disable(i)', p.id);
        const ids = await enabled(); save(ids);
        cfg.status(T(on.checked ? 'plug.enabled' : 'plug.disabled', p.title));
        await draw(); cfg.onChange();
      });
      row.append(el('label', { className: 'pp-name' }, on, ' ', el('b', { textContent: p.title }), ' ', el('small', { textContent: p.provides })),
        el('div', { className: 'pp-sum', textContent: p.summary }));
      if (p.on) row.appendChild(await settings(p));
      box.appendChild(row);
    }
  }
  // an enabled plugin's settings; a secret's field is always empty, and what is typed goes to the host's store
  async function settings(p) {
    const s = el('div', { className: 'pp-settings' });
    for (const l of lines(await call('use arg i; return .oodPluginsHost~settingLines(i)', p.id))) {
      const [key, kind, label, value] = l.split('\t');
      const secret = kind === 'secret';
      let inp;
      if (kind.startsWith('choice:')) {                // choice:a|b: one of these
        inp = el('select', {});
        for (const c of kind.slice(7).split('|')) inp.appendChild(el('option', { value: c, textContent: c, selected: c === value }));
      } else inp = el('input', { type: secret ? 'password' : 'text', value: secret ? '' : value, autocomplete: 'off' });
      inp.dataset.setting = key;
      if (secret) { inp.placeholder = value ? T('plug.secret.set') : ''; inp.title = T('plug.secret.tip'); }
      inp.addEventListener('change', async () => {
        const ok = await call('use arg i, k, v; return .oodPluginsHost~setSetting(i, k, v)', p.id, key, inp.value).then(() => true, () => false);
        if (secret) inp.value = '';                    // the page keeps no copy
        if (ok) { cfg.status(T('plug.saved', label)); await draw(); cfg.onChange(); }
      });
      s.appendChild(el('label', {}, label, inp));
    }
    return s.children.length ? el('div', {}, el('div', { className: 'pp-sub', textContent: T('plug.settings') }), s) : el('span');
  }

  async function diagnose(text) {
    if (!cfg) return [];
    const out = String(await call('use arg t; return .oodPluginsHost~diagnose(t)', text).catch(() => ''));
    return lines(out).map((l) => {
      const [plugin, rule, line, column, severity, fixId, ...m] = l.split('\t');
      return { plugin, rule, line: +line, column: +column, severity, fixId, message: m.join('\t') };
    });
  }
  async function fix(plugin, text, fixId) {
    return String(await call('use arg p, t, f; return .oodPluginsHost~fix(p, t, f)', plugin, text, fixId));
  }
  function show(box, findings, handlers) {
    box.textContent = ''; box.hidden = !findings.length;
    if (!findings.length) return;
    box.appendChild(el('div', { className: 'dg-head', textContent: T('plug.findings', findings.length) }));
    for (const f of findings) {
      const row = el('div', { className: 'dg ' + f.severity });
      row.dataset.rule = f.rule; row.dataset.line = f.line;
      const where = el('a', { href: '#', textContent: T('plug.line', f.line), className: 'dg-line' });
      where.onclick = (e) => { e.preventDefault(); handlers.onLine(f); };
      row.append('⚑ ', where, ' ', el('span', { textContent: f.message }));
      if (f.fixId) {
        const b = el('button', { textContent: T('plug.fix'), className: 'dg-fix' });
        b.onclick = () => handlers.onFix(f);
        row.append(' ', b);
      }
      box.appendChild(row);
    }
  }
  async function setLanguage(lang) {
    if (!cfg) return;
    await call('use arg l; return .oodPluginsHost~setLanguage(l)', lang);
    if (panel && !panel.hidden) { window.OodNlsPage.apply(panel); await draw(); }
    if (ask) window.OodNlsPage.apply(ask);
    if (src) window.OodNlsPage.apply(src);
  }

  /* ---- the Ask panel: a proposal from an assist plugin, beside the code ---- */
  async function assistIds() { return cfg ? String(await call('return .oodPluginsHost~enabledFor("assist")')).split(' ').filter(Boolean) : []; }
  let ask = null, askOpts = null, proposal = null, lastAsked = '';
  async function openAsk(opts) {
    askOpts = opts;
    if (!ask) {
      ask = el('div', { id: 'askPanel', hidden: true });     // shown once it is filled in
      ask.innerHTML = '<div class="ak-box"><div class="ak-head"><strong data-nls="ask.title"></strong><span id="akWhat"></span>' +
        '<select id="akPlugin"></select><button id="akClose" data-nls="btn.close"></button></div>' +
        '<div class="ak-task"><textarea id="akTask" rows="3" data-nls-placeholder="ask.task.ph"></textarea>' +
        '<button id="akGo" data-nls="ask.propose"></button></div>' +
        '<div id="akInfo"></div><ul id="akNotes"></ul>' +
        '<div class="ak-views" role="group"><button data-akview="code" class="on" data-nls="view.code"></button>' +
        '<button data-akview="graph" data-nls="view.graph"></button></div>' +
        '<div class="ak-cols"><div><div class="ak-sub" data-nls="ask.now"></div><pre id="akOld"></pre></div>' +
        '<div><div class="ak-sub" data-nls="ask.proposal"></div><pre id="akNew"></pre></div></div>' +
        '<div class="ak-foot"><span class="ak-hint" data-nls="ask.hint"></span><button id="akApply" data-nls="ask.apply" disabled></button></div></div>';
      D.body.appendChild(ask);
      ask.querySelector('#akClose').onclick = () => { ask.hidden = true; };
      ask.querySelector('#akGo').onclick = propose;
      // the proposal as code (a line diff) or as graphs (OxGraph, where the page has it)
      ask.querySelectorAll('[data-akview]').forEach((b) => b.addEventListener('click', () => {
        ask.dataset.view = b.dataset.akview;
        ask.querySelectorAll('[data-akview]').forEach((x) => x.classList.toggle('on', x === b));
        showProposal(lastAsked, proposal);
      }));
      ask.querySelector('#akApply').onclick = async () => {
        if (!proposal || proposal.status !== 'ok') return;
        await askOpts.apply(proposal.code);
        cfg.status(T('ask.applied'));
        ask.hidden = true;
      };
    }
    window.OodNlsPage.apply(ask);
    const sel = ask.querySelector('#akPlugin'); sel.textContent = '';
    const titles = Object.fromEntries((await catalogue()).map((p) => [p.id, p.title]));
    for (const id of await assistIds()) sel.appendChild(el('option', { value: id, textContent: titles[id] || id }));
    sel.hidden = sel.options.length < 2;
    ask.querySelector('#akWhat').textContent = opts.title || '';
    ask.querySelector('.ak-views').hidden = !window.OxGraph;
    if (!window.OxGraph) ask.dataset.view = 'code';
    proposal = null; lastAsked = opts.code(); showProposal(lastAsked, null);
    ask.hidden = false;
    ask.querySelector('#akTask').focus();
  }
  async function propose() {
    const id = ask.querySelector('#akPlugin').value, task = ask.querySelector('#akTask').value;
    const code = askOpts.code(), go = ask.querySelector('#akGo');
    lastAsked = code;
    go.disabled = true; ask.querySelector('#akInfo').textContent = T('ask.asking');
    ask.querySelector('#akApply').disabled = true;
    const out = await call('use arg i, t, c, x; return .oodPluginsHost~assist(i, t, c, x)', id, task, code, askOpts.context())
      .then(String, (e) => 'STATUS failed\nMODEL\nCOST\nNOTE ' + (e && e.message || e) + '\nCODE\n');
    go.disabled = false;
    proposal = parse(out);
    await showProposal(code, proposal);
  }
  function parse(text) {
    const r = { status: 'failed', model: '', cost: '', notes: [], code: '' };
    const ls = text.split('\n');
    for (let i = 0; i < ls.length; i++) {
      const w = ls[i].split(' ')[0], rest = ls[i].slice(w.length + 1);
      if (w === 'CODE') { r.code = ls.slice(i + 1).join('\n'); break; }
      if (w === 'STATUS') r.status = rest; else if (w === 'MODEL') r.model = rest;
      else if (w === 'COST') r.cost = rest; else if (w === 'NOTE') r.notes.push(rest);
    }
    return r;
  }
  async function showProposal(code, p) {
    const info = ask.querySelector('#akInfo'), notes = ask.querySelector('#akNotes');
    const oldBox = ask.querySelector('#akOld'), newBox = ask.querySelector('#akNew');
    notes.textContent = ''; oldBox.textContent = ''; newBox.textContent = '';
    ask.dataset.status = p ? p.status : '';
    if (!p) {
      info.textContent = '';
      if (ask.dataset.view === 'graph' && window.OxGraph) await window.OxGraph.preview(code, oldBox); else oldBox.textContent = code;
      return;
    }
    info.textContent = [T('ask.status.' + p.status), p.model && T('ask.model', p.model), p.cost && T('ask.cost', p.cost)].filter(Boolean).join('  ·  ');
    for (const n of p.notes) notes.appendChild(el('li', { textContent: n }));
    ask.querySelector('#akApply').disabled = p.status !== 'ok' || p.code === code;
    const d = diff(code.split('\n'), p.code ? p.code.split('\n') : []);
    if (ask.dataset.view === 'graph' && window.OxGraph) {
      // each side as blocks; a block holding a changed line is marked
      ask.dataset.graphReady = '0';
      const gone = new Set(), added = new Set(); let lo = 0, ln = 0;
      for (const [k] of d) { if (k !== '+') lo++; if (k !== '-') ln++; if (k === '-') gone.add(lo); if (k === '+') added.add(ln); }
      await window.OxGraph.preview(code, oldBox); markBlocks(oldBox, gone, 'ak-del');
      await window.OxGraph.preview(p.code || '', newBox); markBlocks(newBox, added, 'ak-add');
      ask.dataset.graphReady = '1';
      return;
    }
    for (const [k, l] of d) {
      if (k !== '+') oldBox.appendChild(el('div', { className: k === '-' ? 'ak-del' : '', textContent: l || ' ' }));
      if (k !== '-') newBox.appendChild(el('div', { className: k === '+' ? 'ak-add' : '', textContent: l || ' ' }));
    }
  }
  // the innermost blocks whose lines hold a changed line
  function markBlocks(box, changed, cls) {
    const bs = [...box.querySelectorAll('.gb')];
    for (const b of bs) {
      const l1 = +b.dataset.l1, l2 = +b.dataset.l2;
      const inner = [...b.querySelectorAll('.gb')];
      const own = [...changed].some((l) => l >= l1 && l <= l2 && !inner.some((c) => l >= +c.dataset.l1 && l <= +c.dataset.l2));
      if (own) b.classList.add(cls);
    }
  }
  // a line diff (longest common subsequence): [' ', line] kept, ['-', line] gone, ['+', line] new
  function diff(a, b) {
    const n = a.length, m = b.length, t = Array.from({ length: n + 1 }, () => new Array(m + 1).fill(0));
    for (let i = n - 1; i >= 0; i--) for (let j = m - 1; j >= 0; j--) t[i][j] = a[i] === b[j] ? t[i + 1][j + 1] + 1 : Math.max(t[i + 1][j], t[i][j + 1]);
    const out = []; let i = 0, j = 0;
    while (i < n && j < m) {
      if (a[i] === b[j]) { out.push([' ', a[i]]); i++; j++; }
      else if (t[i + 1][j] >= t[i][j + 1]) out.push(['-', a[i++]]);
      else out.push(['+', b[j++]]);
    }
    while (i < n) out.push(['-', a[i++]]);
    while (j < m) out.push(['+', b[j++]]);
    return out;
  }

  /* ---- the Source panel: a source control plugin's files, commit, history ---- */
  async function scmIds() { return cfg ? String(await call('return .oodPluginsHost~enabledFor("scm")')).split(' ').filter(Boolean) : []; }
  let src = null, srcOpts = null, cur = null;      // cur: { id, path, ref, base } as opened
  const scm = (id, op, ...a) => call('use arg i, o, a1, a2, a3, a4; return .oodPluginsHost~scm(i, o, a1, a2, a3, a4)', id, op, ...[...a, '', '', '', ''].slice(0, 4)).then(String);
  const short = (r) => (r || '').length > 12 ? r.slice(0, 10) + '…' : (r || '');
  async function openSource(opts) {
    srcOpts = opts;
    if (!src) {
      src = el('div', { id: 'srcPanel', hidden: true });
      src.innerHTML = '<div class="sc-box"><div class="sc-head"><strong data-nls="scm.title"></strong><select id="scPlugin"></select>' +
        '<span id="scWhere"></span><button id="scClose" data-nls="btn.close"></button></div>' +
        '<div class="sc-body"><div class="sc-left"><div class="sc-sub"><span data-nls="scm.files"></span> <button id="scList" data-nls="scm.refresh"></button></div>' +
        '<ul id="scFiles"></ul></div><div class="sc-right">' +
        '<div class="sc-row"><label><span data-nls="scm.path"></span> <input id="scPath" size="34"></label><button id="scCheck" data-nls="scm.check"></button><span id="scState"></span></div>' +
        '<div class="sc-sub" data-nls="scm.changes"></div><pre id="scDiff"></pre>' +
        '<div class="sc-row"><input id="scMsg" data-nls-placeholder="scm.message.ph"><button id="scCommit" data-nls="scm.commit"></button></div>' +
        '<ul id="scNotes"></ul>' +
        '<div class="sc-sub"><span data-nls="scm.history"></span> <button id="scHist" data-nls="scm.refresh"></button></div><ul id="scHistory"></ul>' +
        '<div id="scVersion" hidden><div class="sc-row"><span id="scVerWhat"></span><button id="scVerOpen" data-nls="scm.openVersion"></button></div><pre id="scVerText"></pre></div>' +
        '</div></div></div>';
      D.body.appendChild(src);
      const q = (id) => src.querySelector('#' + id);
      q('scClose').onclick = () => { src.hidden = true; };
      q('scList').onclick = () => guard(listFiles);
      q('scCheck').onclick = () => guard(check);
      q('scCommit').onclick = () => guard(commit);
      q('scHist').onclick = () => guard(history);
      q('scPlugin').onchange = () => { cur = null; guard(listFiles); };
    }
    window.OodNlsPage.apply(src);
    const sel = src.querySelector('#scPlugin'); sel.textContent = '';
    const titles = Object.fromEntries((await catalogue()).map((p) => [p.id, p.title]));
    for (const id of await scmIds()) sel.appendChild(el('option', { value: id, textContent: titles[id] || id, selected: cur && cur.id === id }));
    const path = src.querySelector('#scPath');
    if (!cur || cur.id !== sel.value) path.value = opts.name();
    src.hidden = false;
    await guard(async () => { await listFiles(); await changes(); });
  }
  // a refusal from the plugin goes to the notes, in its words
  async function guard(fn) {
    try { await fn(); } catch (e) { note([String(e && e.message || e).replace(/^.*?Incorrect call to method\.\s*/s, '').replace(/^\(?|\)$/g, '')], 'err'); }
  }
  function note(lines, cls) {
    const n = src.querySelector('#scNotes'); n.textContent = ''; n.className = cls || '';
    for (const l of lines) n.appendChild(el('li', { textContent: l }));
  }
  const pid = () => src.querySelector('#scPlugin').value;
  async function listFiles() {
    const box = src.querySelector('#scFiles'); box.textContent = '';
    const ls = lines(await scm(pid(), 'LIST'));
    if (!ls.length) box.appendChild(el('li', { className: 'sc-none', textContent: T('scm.none') }));
    for (const l of ls) {
      const [path] = l.split('\t');
      const b = el('button', { textContent: T('scm.open') });
      b.onclick = () => guard(() => openFile(path));
      const li = el('li', {}, el('span', { className: 'sc-file', textContent: path }), ' ', b);
      li.dataset.path = path;
      box.appendChild(li);
    }
  }
  async function openFile(path, ref) {
    const out = ref ? 'REF ' + ref + '\nTEXT\n' + await scm(pid(), 'AT', path, ref) : await scm(pid(), 'OPEN', path);
    const m = /^REF ?([^\n]*)\nTEXT\n([\s\S]*)$/.exec(out);
    if (!m) throw new Error(out);
    if (!await srcOpts.open(path.replace(/.*\//, ''), m[2])) { note([T('scm.notOpened', path)], 'err'); return; }
    if (!ref) cur = { id: pid(), path, ref: m[1], base: m[2] };
    src.querySelector('#scPath').value = path;
    note([T('scm.opened', path, short(ref || m[1]))]);
    await changes(); await check();
  }
  async function check() {
    const path = src.querySelector('#scPath').value.trim(), state = src.querySelector('#scState');
    if (!cur || cur.path !== path) { state.textContent = T('scm.state.NEW'); state.dataset.state = 'NEW'; return; }
    const r = lines(await scm(pid(), 'STATUS', path, cur.ref));
    const st = (r.find((l) => l.startsWith('STATE ')) || 'STATE UNKNOWN').slice(6);
    state.dataset.state = st;
    state.textContent = T('scm.state.' + st) + r.filter((l) => l.startsWith('NOTE ')).map((l) => '  ' + l.slice(5)).join('');
  }
  async function changes() {
    const box = src.querySelector('#scDiff'); box.textContent = '';
    const now = await srcOpts.text(), base = cur && cur.path === src.querySelector('#scPath').value.trim() ? cur.base : '';
    const d = diff(base.split('\n'), now.split('\n'));
    const changed = d.filter(([k]) => k !== ' ').length;
    if (!changed) { box.appendChild(el('div', { className: 'sc-same', textContent: T('scm.noChanges') })); return 0; }
    // the changed lines, with two lines either side
    const keep = d.map(([k], i) => d.slice(Math.max(0, i - 2), i + 3).some(([k2]) => k2 !== ' '));
    let gap = false;
    d.forEach(([k, l], i) => {
      if (!keep[i]) { if (!gap) box.appendChild(el('div', { className: 'sc-gap', textContent: '⋯' })); gap = true; return; }
      gap = false;
      box.appendChild(el('div', { className: k === '-' ? 'ak-del' : k === '+' ? 'ak-add' : '', textContent: (k === ' ' ? '  ' : k + ' ') + l }));
    });
    return changed;
  }
  async function commit() {
    const path = src.querySelector('#scPath').value.trim(), msg = src.querySelector('#scMsg').value;
    const text = await srcOpts.text();
    const ref = cur && cur.path === path ? cur.ref : '';
    src.querySelector('#scCommit').disabled = true;
    try {
      const r = lines(await scm(pid(), 'COMMIT', path, text, msg, ref));
      const status = (r.find((l) => l.startsWith('STATUS ')) || 'STATUS failed').slice(7);
      const newRef = (r.find((l) => l.startsWith('REF ')) || 'REF ').slice(4);
      note([T('scm.status.' + status)].concat(r.filter((l) => l.startsWith('NOTE ')).map((l) => l.slice(5))), status);
      src.dataset.committed = status;
      if (status === 'ok') {
        cur = { id: pid(), path, ref: newRef || ref, base: text };
        src.querySelector('#scMsg').value = '';
        await changes(); await check(); await history();
      }
    } finally { src.querySelector('#scCommit').disabled = false; }
  }
  async function history() {
    const box = src.querySelector('#scHistory'); box.textContent = '';
    const path = src.querySelector('#scPath').value.trim();
    for (const l of lines(await scm(pid(), 'HISTORY', path))) {
      const [ref, when, who, ...m] = l.split('\t');
      const b = el('button', { textContent: T('scm.view') });
      b.onclick = () => guard(async () => {
        src.querySelector('#scVerText').textContent = await scm(pid(), 'AT', path, ref);
        src.querySelector('#scVerWhat').textContent = short(ref) + '  ' + when + '  ' + who;
        src.querySelector('#scVerOpen').onclick = () => guard(() => openFile(path, ref));
        src.querySelector('#scVersion').hidden = false;
      });
      const li = el('li', {}, el('code', { textContent: short(ref) }), ' ', el('span', { textContent: when.replace('T', ' ').replace(/(:\d\d)(\.\d+)?Z?$/, '$1') + '  ' + who + '  ' + m.join('\t') }), ' ', b);
      li.dataset.ref = ref;
      box.appendChild(li);
    }
  }

  window.OodPluginsPage = { rexxPath, setup, open, diagnose, fix, show, setLanguage, enabled, assistIds, ask: openAsk, scmIds, source: openSource };
})();
