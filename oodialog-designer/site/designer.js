/* designer.js -- the ooDialog Designer page.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   This file only shows the design and reports what the user does.  The design
   itself is an OodDesign object (OodDesigner.cls) living in an ooRexx/WASM
   session: every change is a message to it (addControl, setGeometry, setProp,
   setEventCode, ...), it refuses what is wrong, and the page redraws from its
   snapshot (the ::RESOURCE oodDesign lines).  JavaScript is used because the
   browser's pointer and drag events are where the user's hand is; no design
   decision is made here. */
(function () {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const D = document;
  const st = {
    rexx: null, sess: null, d: null,            // runtime, session, the OodDesign
    kinds: {}, order: [], formEvents: [],       // from the catalogue
    snap: null,                                 // parsed snapshot
    sel: 'form',                                // selected control name, or 'form'
    cur: null,                                  // {type:'event', ctl, ev} | {type:'method', name}
    fx: 1.5, fy: 1.6,                           // pixels per dialog unit
    oodFiles: null, run: null, saveTimer: null,
    page: {},                                   // tab strip name -> the page shown while designing
  };
  window.oodDesigner = st;                      // for tests

  /* ---- status ------------------------------------------------------------ */
  function status(text, isErr) {
    $('status').textContent = text;
    $('status').classList.toggle('err', !!isErr);
    $('status').title = text;
  }
  function errText(e) {
    let m = (e && (e.message || e.toString())) || String(e);
    const k = m.search(/Error 93\.900:\s*/);
    if (k >= 0) m = m.slice(k).replace(/Error 93\.900:\s*/, '');
    return m.split('\n')[0];
  }
  // Every call to Rexx goes through here: one at a time, errors to the status line.
  let chain = Promise.resolve();
  function rx(fn) {
    const p = chain.then(fn);
    chain = p.catch(() => {});
    return p.catch((e) => { status(errText(e), true); throw e; });
  }

  /* ---- design lines: keyword then key=value, "" quoting (as oodFields) ----- */
  function fields(line) {
    const f = {}; let m = /^\s*(\S+)\s*/.exec(line); f['*'] = m[1];
    let s = line.slice(m[0].length);
    while (s.length) {
      const eq = s.indexOf('='); if (eq < 0) break;
      const key = s.slice(0, eq).trim().toLowerCase(); s = s.slice(eq + 1);
      let v = '';
      if (s[0] === '"') {
        let p = 1;
        for (;;) {
          const q = s.indexOf('"', p); if (q < 0) { v += s.slice(p); s = ''; break; }
          v += s.slice(p, q);
          if (s[q + 1] === '"') { v += '"'; p = q + 2; } else { s = s.slice(q + 1); break; }
        }
      } else { const b = s.search(/\s/); v = b < 0 ? s : s.slice(0, b); s = b < 0 ? '' : s.slice(b); }
      f[key] = v; s = s.replace(/^\s+/, '');
    }
    return f;
  }
  function parseSnapshot(text) {
    const snap = { form: {}, vars: [], controls: [], events: [], methods: [], requires: [], shared: [] };
    for (const line of text.split('\n')) {
      if (!line.trim()) continue;
      const f = fields(line);
      if (f['*'] === 'form') snap.form = f;
      else if (f['*'] === 'var') snap.vars.push(f);
      else if (f['*'] === 'control') snap.controls.push(f);
      else if (f['*'] === 'event') snap.events.push(f);
      else if (f['*'] === 'method') snap.methods.push(f.name);
      else if (f['*'] === 'requires') snap.requires.push(f.file);
      else if (f['*'] === 'shared') snap.shared.push(f);
    }
    return snap;
  }
  const findCtl = (name) => st.snap.controls.find((c) => c.name.toLowerCase() === String(name).toLowerCase());
  const plainText = (t) => String(t || '').replace(/&(.)/g, '$1');

  /* ---- start ------------------------------------------------------------- */
  async function boot() {
    try {
      measure();
      st.rexx = await ooRexx.load();
      const files = {};
      for (const f of ['OodDesigner.cls', 'OodGraph.cls', 'ObjectEditor.cls', 'LibraryProviders.cls']) files['/home/rexx/' + f] = await (await fetch(f)).text();
      // Josep Maria Blasco's Rexx Parser, which OodGraph.cls parses event code with
      for (const rel of (await (await fetch('rexx-parser/manifest.txt')).text()).split('\n').map((l) => l.trim()).filter(Boolean))
        files['/home/rexx/rexx-parser/' + rel] = await (await fetch('rexx-parser/' + rel)).text();
      st.sess = await st.rexx.start({ js: { page: true, worker: true }, files });
      await st.sess.loadPackage('LibraryProviders.cls');   // with OodDesigner.cls and ObjectEditor.cls
      await st.sess.loadPackage('OodGraph.cls');           // with the Rexx Parser
      await OxLibraries.setup(st.sess);
      OxGraph.attach({ sess: st.sess, rx, status, setCode, actionsMenu });
      await loadCatalog();
      await newDesign();
      status('Ready.  Drag a control onto the form.');
    } catch (e) { status('Could not start: ' + errText(e), true); console.error(e); }
  }
  async function loadCatalog() {
    const text = await st.sess.eval('return .OodCatalog~catalogText');
    for (const line of text.split('\n')) {
      if (!line.trim()) continue;
      const f = fields(line);
      if (f['*'] === 'kind') { st.kinds[f.type] = f; st.order.push(f.type); }
      if (f['*'] === 'form') st.formEvents = f.events.split(/\s+/);
    }
    const box = $('kinds'); box.textContent = '';
    for (const t of st.order) {
      const div = D.createElement('div'); div.textContent = st.kinds[t].label; div.draggable = true;
      div.dataset.kind = t; div.title = t;
      div.addEventListener('dragstart', (e) => { e.dataTransfer.setData('text/x-ood-kind', t); e.dataTransfer.effectAllowed = 'copy'; });
      div.addEventListener('click', () => addAt(t, null, null));
      box.appendChild(div);
    }
  }
  async function newDesign(design) {
    st.d = design || await rx(() => st.sess.eval('return .OodDesign~new("MyDialog")'));
    st.sel = 'form'; st.cur = null;
    await refresh();
    showCode();
  }
  // Windows' dialog base units for the dialog font, as the ooDialog/WASM page does
  function measure() {
    const s = D.createElement('span');
    s.style.cssText = 'position:absolute;visibility:hidden;white-space:nowrap;font-family:"Segoe UI",Tahoma,"DejaVu Sans",Arial,sans-serif';
    s.style.fontSize = (Math.round(8 * 96 / 72 * 1.25 * 100) / 100) + 'px';
    s.textContent = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    D.body.appendChild(s); const r = s.getBoundingClientRect(); D.body.removeChild(s);
    st.fx = Math.floor((r.width / 26 + 1) / 2) / 4; st.fy = Math.round(r.height) / 8;
    $('form').style.fontSize = s.style.fontSize;
  }

  /* ---- redraw from the design ------------------------------------------- */
  async function refresh() {
    const text = await rx(() => st.d.snapshot());
    st.snap = parseSnapshot(String(text));
    if (st.sel !== 'form' && !findCtl(st.sel)) st.sel = 'form';
    drawForm(); drawProps(); drawVars(); drawLibs(); drawTree();
    autosave();
  }
  function drawForm() {
    const f = st.snap.form, client = $('client');
    $('formTitle').textContent = f.title;
    client.style.width = Math.round(f.w * st.fx) + 'px';
    client.style.height = Math.round(f.h * st.fy) + 'px';
    client.style.backgroundSize = (4 * st.fx) + 'px ' + (4 * st.fy) + 'px';
    $('form').classList.toggle('sel', st.sel === 'form');
    client.textContent = ''; $('tray').textContent = '';
    drawMenuBar();
    for (const c of st.snap.controls) {
      if (st.kinds[c.type].nonvisual === '1') {
        const chip = D.createElement('span'); chip.className = 'chip' + (st.sel === c.name ? ' sel' : '');
        chip.textContent = c.type === 'TIMER' ? '⏱ ' + c.name + ' (' + c.interval + ' s)'
          : '☰ ' + c.name + ': ' + plainText(c.popup) + ' › ' + (c.text === '-' ? '———' : plainText(c.text));
        chip.dataset.name = c.name;
        chip.addEventListener('click', () => select(c.name));
        $('tray').appendChild(chip); continue;
      }
      if (c.page) {                              // on a tab page: shown while that page is
        const [t, n] = c.page.split(':');
        if (String(st.page[t.toLowerCase()] || 1) !== n) continue;
      }
      client.appendChild(drawControl(c));
    }
  }
  // the menu bar, from the menu items, as Windows puts it under the title
  function drawMenuBar() {
    let bar = $('formMenu');
    const popups = [];
    for (const c of st.snap.controls) if (c.type === 'MENUITEM' && !popups.includes(c.popup)) popups.push(c.popup);
    if (!popups.length) { if (bar) bar.remove(); return; }
    if (!bar) { bar = D.createElement('div'); bar.id = 'formMenu'; $('form').insertBefore(bar, $('client')); }
    bar.textContent = '';
    for (const p of popups) { const b = D.createElement('span'); b.textContent = plainText(p); bar.appendChild(b); }
  }
  function drawControl(c) {
    const el = D.createElement('div');
    const opts = String(c.opts || '').toUpperCase().split(/\s+/);
    el.className = 'dz' + (st.sel === c.name ? ' sel' : '') + (opts.includes('HIDDEN') ? ' hidden-style' : '');
    el.dataset.name = c.name; el.title = c.name + ' (' + c.type + ')';
    place(el, c.x, c.y, c.w, c.h);
    const body = D.createElement('div'); body.style.cssText = 'position:absolute;inset:0';
    const text = plainText(c.text);
    switch (c.type) {
      case 'PUSHBUTTON':
        body.className = 'dz-btn' + (opts.includes('DEFAULT') || c.role === 'OK' ? ' def' : ''); body.textContent = text; break;
      case 'STATIC':
        body.className = 'dz-static' + (opts.includes('RIGHT') ? ' right' : opts.includes('CENTER') ? ' center' : ''); body.textContent = text; break;
      case 'EDIT':
        body.className = 'dz-edit' + (opts.includes('READONLY') ? ' ro' : '') + (opts.includes('MULTILINE') ? ' multi' : '') + (opts.includes('RIGHT') ? ' right' : opts.includes('CENTER') ? ' center' : '');
        body.textContent = opts.includes('PASSWORD') ? '•'.repeat(text.length) : text; break;
      case 'CHECKBOX': case 'RADIOBUTTON': {
        body.className = 'dz-check' + (c.type === 'RADIOBUTTON' ? ' radio' : '');
        const i = D.createElement('i'); if (c.checked === '1') i.className = 'on';
        body.append(i, text); break; }
      case 'GROUPBOX': {
        el.classList.add('dz-wrap-group'); body.className = 'dz-group'; body.style.top = '0';
        const s = D.createElement('span'); s.textContent = text; body.appendChild(s); break; }
      case 'LISTBOX':
        body.className = 'dz-list'; body.textContent = String(c.items || '').split('|').filter(Boolean).join('\n'); break;
      case 'COMBOBOX': {
        body.className = 'dz-combo';
        const top = D.createElement('div'); top.style.height = Math.round(12 * st.fy) + 'px';
        const first = String(c.items || '').split('|')[0] || '';
        top.append(first, Object.assign(D.createElement('span'), { textContent: '▾' }));
        body.appendChild(top); break; }
      case 'PROGRESSBAR': {
        body.className = 'dz-prog';
        const bar = D.createElement('div'); const span = (Number(c.max) - Number(c.min)) || 1;
        bar.style.width = Math.max(0, Math.min(100, (Number(c.pos) - Number(c.min)) * 100 / span)) + '%';
        body.appendChild(bar); break; }
      case 'LISTVIEW': {
        body.className = 'dz-lv';
        const tbl = D.createElement('table'); const hr = tbl.insertRow();
        for (const col of String(c.columns || '').split('|')) {
          const [title, width] = col.split(':'); const th = D.createElement('th');
          th.textContent = title; th.style.width = Math.round((Number(width) || 50) * st.fx) + 'px'; hr.appendChild(th);
        }
        for (const row of String(c.rows || '').split('|').filter(Boolean)) {
          const tr = tbl.insertRow(); for (const cell of row.split(';')) tr.insertCell().textContent = cell;
        }
        if (String(c.exstyles || '').toUpperCase().includes('GRIDLINES')) tbl.className = 'grid';
        body.appendChild(tbl); break; }
      case 'TAB': {
        body.className = 'dz-tab';
        const cur = String(st.page[c.name.toLowerCase()] || 1);
        String(c.tabs || '').split('|').forEach((t, i) => {
          const b = D.createElement('span'); b.textContent = plainText(t); b.dataset.page = String(i + 1);
          if (String(i + 1) === cur) b.className = 'cur';
          b.title = 'Show page ' + (i + 1) + ' while designing';
          body.appendChild(b);
        });
        break; }
      case 'TREEVIEW': {
        body.className = 'dz-tree';
        for (const node of String(c.nodes || '').split('|').filter(Boolean)) {
          const depth = node.length - node.replace(/^\.+/, '').length;
          const r = D.createElement('div'); r.style.paddingLeft = (depth * 1.1 + 0.2) + 'em';
          r.textContent = (depth ? '└ ' : '') + node.slice(depth); body.appendChild(r);
        }
        break; }
      case 'TRACKBAR': {
        body.className = 'dz-track';
        const span = (Number(c.max) - Number(c.min)) || 1;
        const k = D.createElement('i'); k.style.left = 'calc(' + Math.max(0, Math.min(100, (Number(c.pos) - Number(c.min)) * 100 / span)) + '% - 4px)';
        body.appendChild(k); break; }
      case 'DATETIME': {
        body.className = 'dz-edit dz-date';
        const now = new Date();
        body.append(opts.includes('TIME') ? now.toTimeString().slice(0, 8) : now.toLocaleDateString(), Object.assign(D.createElement('span'), { textContent: '▾' }));
        break; }
      default: body.textContent = c.type;
    }
    el.appendChild(body);
    for (const h of ['se', 'e', 's']) { const k = D.createElement('div'); k.className = 'h ' + h; k.dataset.h = h; el.appendChild(k); }
    el.addEventListener('pointerdown', (e) => startDrag(e, c, el));
    return el;
  }
  function place(el, x, y, w, h) {
    el.style.left = Math.round(x * st.fx) + 'px'; el.style.top = Math.round(y * st.fy) + 'px';
    el.style.width = Math.round(w * st.fx) + 'px'; el.style.height = Math.round(h * st.fy) + 'px';
  }

  /* ---- selection, move and resize --------------------------------------- */
  async function select(name) {
    st.sel = name;
    drawForm(); drawProps(); drawTree();
  }
  function startDrag(e, c, el) {
    if (e.button !== 0) return;
    e.preventDefault(); e.stopPropagation();
    $('form').focus();
    const mode = e.target.dataset.h || 'move';
    if (st.sel !== c.name) { st.sel = c.name; drawProps(); drawTree(); D.querySelectorAll('#client .dz.sel').forEach((x) => x.classList.remove('sel')); el.classList.add('sel'); $('form').classList.remove('sel'); }
    const start = { px: e.clientX, py: e.clientY, x: +c.x, y: +c.y, w: +c.w, h: +c.h };
    let g = { ...start }; let moved = false;
    const snap = (v) => Math.round(v / 2) * 2;
    el.setPointerCapture(e.pointerId);
    const onMove = (ev) => {
      const dx = (ev.clientX - start.px) / st.fx, dy = (ev.clientY - start.py) / st.fy;
      if (Math.abs(ev.clientX - start.px) + Math.abs(ev.clientY - start.py) > 2) moved = true;
      g = { ...start };
      if (mode === 'move') { g.x = Math.max(0, snap(start.x + dx)); g.y = Math.max(0, snap(start.y + dy)); }
      if (mode === 'se' || mode === 'e') g.w = Math.max(4, snap(start.w + dx));
      if (mode === 'se' || mode === 's') g.h = Math.max(4, snap(start.h + dy));
      place(el, g.x, g.y, g.w, g.h);
      status(c.name + '  x ' + g.x + '  y ' + g.y + '  w ' + g.w + '  h ' + g.h);
    };
    const onUp = async () => {
      el.removeEventListener('pointermove', onMove); el.removeEventListener('pointerup', onUp);
      if (!moved) {
        if (c.type === 'TAB' && e.target.dataset.page) {
          st.page[c.name.toLowerCase()] = e.target.dataset.page; drawForm();
          status(c.name + ': designing page ' + e.target.dataset.page + '.  A control\'s "page" property puts it on a page.');
        }
        return;
      }
      await rx(() => st.d.setGeometry(c.name, g.x, g.y, g.w, g.h)).catch(() => {});
      await refresh();
    };
    el.addEventListener('pointermove', onMove); el.addEventListener('pointerup', onUp);
  }
  $('client').addEventListener('pointerdown', (e) => { if (e.target === $('client')) select('form'); });
  $('formTitle').addEventListener('pointerdown', () => select('form'));
  $('form').addEventListener('keydown', async (e) => {
    if (st.sel === 'form') return;
    const c = findCtl(st.sel); if (!c) return;
    if (e.key === 'Delete' || e.key === 'Backspace') { e.preventDefault(); await removeSelected(); return; }
    const step = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] }[e.key];
    if (!step) return;
    e.preventDefault();
    let [x, y, w, h] = [+c.x, +c.y, +c.w, +c.h];
    if (e.shiftKey) { w += step[0]; h += step[1]; } else { x += step[0]; y += step[1]; }
    await rx(() => st.d.setGeometry(c.name, x, y, w, h)).catch(() => {});
    await refresh();
  });
  async function removeSelected() {
    const name = st.sel; if (name === 'form') return;
    await rx(() => st.d.removeControl(name)).catch(() => {});
    if (st.cur && st.cur.ctl === name) { st.cur = null; showCode(); }
    st.sel = 'form'; await refresh(); status('Removed ' + name + ' and its events.');
  }

  /* ---- adding: drop from the palette, or click it ------------------------ */
  $('client').addEventListener('dragover', (e) => { if (e.dataTransfer.types.includes('text/x-ood-kind')) { e.preventDefault(); e.dataTransfer.dropEffect = 'copy'; } });
  $('client').addEventListener('drop', (e) => {
    const t = e.dataTransfer.getData('text/x-ood-kind'); if (!t) return;
    e.preventDefault();
    const r = $('client').getBoundingClientRect();
    addAt(t, Math.round((e.clientX - r.left) / st.fx / 2) * 2, Math.round((e.clientY - r.top) / st.fy / 2) * 2);
  });
  let cascade = 0;
  async function addAt(type, x, y) {
    if (x === null) { x = 8 + (cascade % 8) * 6; y = 8 + (cascade % 8) * 6; cascade++; }
    const name = await rx(() => st.d.addControl(type, x, y)).catch(() => null);
    if (!name) return;
    st.sel = String(name); await refresh();
    status('Added ' + name + '.  Rename it in Properties; its events are in the list below.');
  }

  /* ---- properties ---------------------------------------------------------- */
  async function drawProps() {
    const box = $('props'); box.textContent = '';
    const name = st.sel;
    if (name === 'form') {
      $('propTitle').textContent = 'Form';
      const f = st.snap.form;
      for (const k of ['name', 'title', 'w', 'h']) box.appendChild(propInput('form', k, f[k]));
      return;
    }
    const c = findCtl(name); if (!c) return;
    const kind = st.kinds[c.type];
    $('propTitle').textContent = c.name + ' — ' + kind.label;
    const keys = ['name'].concat(kind.nonvisual === '1' ? [] : ['x', 'y', 'w', 'h']).concat(String(kind.props || '').split(/\s+/).filter(Boolean));
    const tabs = st.snap.controls.filter((o) => o.type === 'TAB');
    if (kind.nonvisual !== '1' && c.type !== 'TAB' && tabs.length) keys.push('page');
    for (const k of keys) {
      if (k === 'opts') box.appendChild(optsInput(c, kind, 'opts', kind.opts, 'styles'));
      else if (k === 'exstyles') box.appendChild(optsInput(c, kind, 'exstyles', kind.exopts, 'extended'));
      else if (k === 'page') {
        const vals = [''], labels = ['— (always shown)'];
        for (const t of tabs) String(t.tabs || '').split('|').forEach((p, i) => { vals.push(t.name + ':' + (i + 1)); labels.push(t.name + ' › ' + plainText(p)); });
        box.appendChild(selectInput(c.name, k, c.page, vals, labels));
      }
      else if (k === 'role') box.appendChild(selectInput(c.name, k, c[k], ['', 'OK', 'CANCEL'], ['—', 'OK (IDOK, default)', 'Cancel (IDCANCEL)']));
      else if (['checked', 'enabled', 'groupstart', 'grayed'].includes(k)) box.appendChild(checkInput(c.name, k, c[k]));
      else box.appendChild(propInput(c.name, k, c[k]));
    }
    const del = D.createElement('button'); del.textContent = 'Remove ' + c.name; del.style.marginTop = '8px';
    del.addEventListener('click', removeSelected); box.appendChild(del);
    const id = D.createElement('div'); id.className = 'ro hint'; id.textContent = 'id ' + c.id + (c.role ? ' → ID' + c.role : ''); box.appendChild(id);
  }
  const LABELS = { w: 'width', h: 'height', items: 'items (a|b|c)', groupstart: 'starts group', interval: 'interval (s)',
    columns: 'columns (Title:width|…)', nodes: 'nodes (a|.child|..grandchild)', rows: 'rows (a;b|c;d)', tabs: 'tabs (a|b)', popup: 'menu', text: 'text' };
  function propInput(name, key, value) {
    const l = D.createElement('label'); l.append(LABELS[key] || key);
    const i = D.createElement('input'); i.type = 'text'; i.value = value == null ? '' : value; i.dataset.prop = key;
    i.addEventListener('change', () => setProp(name, key, i.value));
    i.addEventListener('keydown', (e) => { if (e.key === 'Enter') i.blur(); });
    l.appendChild(i); return l;
  }
  function selectInput(name, key, value, vals, labels) {
    const l = D.createElement('label'); l.append(key);
    const s = D.createElement('select'); s.dataset.prop = key;
    vals.forEach((v, i) => s.add(new Option(labels[i], v, false, v === (value || ''))));
    s.addEventListener('change', () => setProp(name, key, s.value));
    l.appendChild(s); return l;
  }
  function checkInput(name, key, value) {
    const l = D.createElement('label'); l.append(LABELS[key] || key);
    const i = D.createElement('input'); i.type = 'checkbox'; i.checked = value === '1'; i.dataset.prop = key;
    i.addEventListener('change', () => setProp(name, key, i.checked ? '1' : '0'));
    const w = D.createElement('span'); w.appendChild(i); l.appendChild(w); return l;
  }
  function optsInput(c, kind, prop, allowed, label) {
    const l = D.createElement('label'); l.append(label);
    const w = D.createElement('div'); w.className = 'opts'; w.dataset.prop = prop;
    const on = String(c[prop] || '').toUpperCase().split(/\s+/);
    for (const o of String(allowed || '').split(/\s+/).filter(Boolean)) {
      const b = D.createElement('label'); const i = D.createElement('input'); i.type = 'checkbox'; i.checked = on.includes(o); i.dataset.opt = o;
      i.addEventListener('change', () => {
        const now = [...w.querySelectorAll('input')].filter((x) => x.checked).map((x) => x.dataset.opt).join(' ');
        setProp(c.name, prop, now);
      });
      b.append(i, o); w.appendChild(b);
    }
    l.appendChild(w); return l;
  }
  async function setProp(name, key, value) {
    const v = await rx(() => st.d.setProp(name, key, value)).catch(() => null);
    if (v !== null && key === 'name' && name !== 'form') {
      if (st.cur && st.cur.ctl === name) st.cur.ctl = String(value);
      st.sel = String(value);
    }
    await refresh();
    if (v !== null) { status(name + ' ' + key + ' = ' + v); if (key === 'name') showCode(); }
  }

  /* ---- variables ------------------------------------------------------------ */
  function drawVars() {
    const box = $('vars'); box.textContent = '';
    for (const v of st.snap.vars) {
      const row = D.createElement('div'); row.className = 'row';
      const n = D.createElement('input'); n.value = v.name; n.readOnly = true; n.title = 'self~' + v.name;
      const val = D.createElement('input'); val.value = v.value; val.placeholder = '""'; val.title = 'First value: a Rexx expression';
      val.addEventListener('change', async () => { await rx(() => st.d.setVar(v.name, val.value)).catch(() => {}); await refresh(); });
      const x = D.createElement('button'); x.textContent = '✕'; x.title = 'Remove';
      x.addEventListener('click', async () => { await rx(() => st.d.removeVar(v.name)); await refresh(); });
      row.append(n, val, x); box.appendChild(row);
    }
    const row = D.createElement('div'); row.className = 'row';
    const n = D.createElement('input'); n.placeholder = 'new variable'; n.id = 'newVarName';
    const val = D.createElement('input'); val.placeholder = 'first value'; val.id = 'newVarValue';
    const add = D.createElement('button'); add.textContent = '+'; add.title = 'Add the variable'; add.id = 'btnAddVar';
    add.addEventListener('click', async () => {
      if (!n.value.trim()) return;
      const ok = await rx(() => st.d.setVar(n.value.trim(), val.value)).then(() => true, () => false);
      if (ok) await refresh();
    });
    row.append(n, val, add); box.appendChild(row);
  }

  /* ---- libraries (::requires) and the shared scope -------------------------- */
  function drawLibs() {
    const rb = $('reqs'); rb.textContent = '';
    for (const r of st.snap.requires) {
      const row = D.createElement('div'); row.className = 'row';
      const n = Object.assign(D.createElement('input'), { value: r, readOnly: true });
      const x = Object.assign(D.createElement('button'), { textContent: '✕', title: 'Remove' });
      x.addEventListener('click', async () => { await rx(() => st.d.removeRequire(r)); await refresh(); });
      row.style.gridTemplateColumns = '1fr 24px'; row.append(n, x); rb.appendChild(row);
    }
    if (!st.snap.requires.length) rb.appendChild(Object.assign(D.createElement('div'), { className: 'hint', textContent: 'Libraries… to add one.' }));
    const sb = $('shared'); sb.textContent = '';
    for (const e of st.snap.shared) {
      const row = D.createElement('div'); row.className = 'row';
      const n = Object.assign(D.createElement('input'), { value: e.name, readOnly: true, title: 'sharedScope["' + e.name + '"]' });
      const v = Object.assign(D.createElement('input'), { value: e.value, title: 'Made once, in init: a Rexx expression' });
      v.addEventListener('change', async () => { await rx(() => st.d.setShared(e.name, v.value)).catch(() => {}); await refresh(); });
      const x = Object.assign(D.createElement('button'), { textContent: '✕', title: 'Remove' });
      x.addEventListener('click', async () => { await rx(() => st.d.removeShared(e.name)); await refresh(); });
      row.append(n, v, x); sb.appendChild(row);
    }
    const row = D.createElement('div'); row.className = 'row';
    const n = Object.assign(D.createElement('input'), { placeholder: 'name', id: 'newSharedName' });
    const v = Object.assign(D.createElement('input'), { placeholder: '.Class~new(...)', id: 'newSharedValue' });
    const add = Object.assign(D.createElement('button'), { textContent: '+', id: 'btnAddShared', title: 'Add to the shared scope' });
    add.addEventListener('click', async () => {
      if (!n.value.trim()) return;
      if (await rx(() => st.d.setShared(n.value.trim(), v.value)).then(() => true, () => false)) {
        await refresh(); status('In any event: expose sharedScope, then sharedScope["' + n.value.trim() + '"].');
      }
    });
    row.append(n, v, add); sb.appendChild(row);
  }
  $('btnLibraries').addEventListener('click', () => OxLibraries.open({
    sess: st.sess, status,
    onUse: async (req) => {
      await rx(() => st.d.addRequire(req)); await refresh();
      D.getElementById('libPanel').hidden = true;
      status('::requires "' + req + '" added.  Put what you make of it in the shared scope; events reach it with expose sharedScope.');
    },
  }));

  /* ---- the event tree (VisPro's events view) -------------------------------- */
  function drawTree() {
    const box = $('tree'); box.textContent = '';
    const has = {};
    for (const e of st.snap.events) has[(e.control + '.' + e.event).toUpperCase()] = e.thread;
    const obj = (name, type, evs) => {
      const o = D.createElement('div'); o.className = 'obj';
      const n = D.createElement('span'); n.className = 'name' + (st.sel === name ? ' sel' : ''); n.textContent = name;
      n.draggable = true; n.dataset.ctl = name;
      n.addEventListener('dragstart', (e) => { e.dataTransfer.setData('text/x-ood-ctl', name); e.dataTransfer.effectAllowed = 'copy'; });
      n.addEventListener('click', () => select(name));
      const t = D.createElement('span'); t.className = 'type'; t.textContent = type; n.appendChild(t);
      o.appendChild(n);
      const row = D.createElement('div'); row.className = 'evs';
      for (const ev of evs) {
        const b = D.createElement('span'); const th = has[(name + '.' + ev).toUpperCase()];
        b.className = 'ev' + (th ? ' has' : '') + (th === 'background' ? ' bg' : '') +
          (st.cur && st.cur.type === 'event' && st.cur.ctl.toLowerCase() === name.toLowerCase() && st.cur.ev === ev ? ' cur' : '');
        b.textContent = ev; b.dataset.ev = name + '.' + ev;
        b.addEventListener('click', () => { st.cur = { type: 'event', ctl: name, ev }; select(name); showCode(); });
        row.appendChild(b);
      }
      if (evs.length) o.appendChild(row);
      box.appendChild(o);
    };
    obj('form', st.snap.form.name, st.formEvents);
    for (const c of st.snap.controls) obj(c.name, c.type, c.role ? [] : String(st.kinds[c.type].events || '').split(/\s+/).filter(Boolean));
    // the form's methods: DrDialog's global procedures
    const o = D.createElement('div'); o.className = 'obj';
    const n = D.createElement('span'); n.className = 'name'; n.textContent = 'methods'; n.style.cursor = 'default';
    const t = D.createElement('span'); t.className = 'type'; t.textContent = 'self~name(...)'; n.appendChild(t); o.appendChild(n);
    const row = D.createElement('div'); row.className = 'evs';
    for (const m of st.snap.methods) {
      const b = D.createElement('span'); b.className = 'ev has' + (st.cur && st.cur.type === 'method' && st.cur.name === m ? ' cur' : '');
      b.textContent = m; b.dataset.method = m;
      b.addEventListener('click', () => { st.cur = { type: 'method', name: m }; drawTree(); showCode(); });
      row.appendChild(b);
    }
    o.appendChild(row);
    const nm = D.createElement('div'); nm.className = 'newm';
    const inp = D.createElement('input'); inp.placeholder = 'new method name'; inp.id = 'newMethodName';
    const add = D.createElement('button'); add.textContent = 'Add'; add.id = 'btnAddMethod';
    const go = () => { const v = inp.value.trim(); if (!v) return; st.cur = { type: 'method', name: v, fresh: true }; drawTree(); showCode(); };
    add.addEventListener('click', go); inp.addEventListener('keydown', (e) => { if (e.key === 'Enter') go(); });
    nm.append(inp, add); o.appendChild(nm);
    box.appendChild(o);
  }

  /* ---- the code pane ---------------------------------------------------------- */
  let codeDirty = false, codeTimer = null;
  async function showCode() {
    await flushCode();
    const code = $('code');
    if (!st.cur) { $('codeTitle').textContent = 'Pick an event or a method'; code.value = ''; code.disabled = true; $('threadBox').hidden = true; OxGraph.show(''); return; }
    if (st.cur.type === 'event') {
      const { ctl, ev } = st.cur;
      const args = String(await rx(() => st.d.eventArgs(ctl, ev)).catch(() => ''));
      $('codeTitle').textContent = ctl + ' · ' + ev + '  →  ' + methodName(ctl, ev) + (args ? '(' + args + ')' : '');
      code.value = String(await rx(() => st.d.getEventCode(ctl, ev)).catch(() => ''));
      if (!code.value && args) code.value = 'use arg ' + args + '\n';
      const th = String(await rx(() => st.d.getEventThread(ctl, ev)).catch(() => ''));
      const canBg = ctl !== 'form' && findCtl(ctl) && findCtl(ctl).type !== 'TIMER';
      $('threadBox').hidden = !canBg; $('thread').value = th === 'background' ? 'background' : 'ui';
    } else {
      $('codeTitle').textContent = 'method ' + st.cur.name + '  →  self~' + st.cur.name + '(...)';
      code.value = st.cur.fresh ? 'use strict arg \n' : String(await rx(() => st.d.getMethod(st.cur.name)).catch(() => ''));
      $('threadBox').hidden = true;
    }
    code.disabled = false; codeDirty = false;
    await OxGraph.show(code.value);
    traceShowStep();
  }
  function methodName(ctl, ev) {
    if (ctl === 'form' && ev === 'OK') return 'ok';
    if (ctl === 'form' && ev === 'CANCEL') return 'cancel';
    return 'on_' + ctl + '_' + ev.toLowerCase();
  }
  async function flushCode() {
    if (!codeDirty || !st.cur) return;
    codeDirty = false; clearTimeout(codeTimer);
    const text = $('code').value, cur = st.cur;
    let ok = true;
    if (cur.type === 'event') ok = await rx(() => st.d.setEventCode(cur.ctl, cur.ev, text)).then(() => true, () => false);
    else {
      ok = await rx(() => st.d.setMethod(cur.name, text)).then(() => true, () => false);
      if (ok) cur.fresh = false;
    }
    if (ok) await refresh();
    if (st.cur === cur) await OxGraph.show(text);
  }
  // a graph edit answers the new code: it becomes the event's code
  async function setCode(text) {
    if (!st.cur) return;
    $('code').value = text; codeDirty = true;
    await flushCode();
  }
  $('code').addEventListener('input', () => { codeDirty = true; clearTimeout(codeTimer); codeTimer = setTimeout(flushCode, 600); });
  $('code').addEventListener('blur', flushCode);
  $('code').addEventListener('keydown', (e) => {
    if (e.key === 'Tab') { e.preventDefault(); insertText('  '); }
  });
  $('thread').addEventListener('change', async () => {
    await flushCode();
    const { ctl, ev } = st.cur;
    await rx(() => st.d.setEventThread(ctl, ev, $('thread').value)).catch(() => {});
    await refresh();
    status($('thread').value === 'background'
      ? ctl + ' ' + ev + ' now replies at once and runs on its own thread: the dialog keeps answering.'
      : ctl + ' ' + ev + ' runs on the dialog\'s thread.');
  });
  function insertText(s) {
    const c = $('code'); const a = c.selectionStart, b = c.selectionEnd;
    c.value = c.value.slice(0, a) + s + c.value.slice(b); c.selectionStart = c.selectionEnd = a + s.length;
    codeDirty = true; clearTimeout(codeTimer); codeTimer = setTimeout(flushCode, 600);
  }
  function insertLine(s) {
    const c = $('code'); const a = c.selectionStart;
    const atLineStart = a === 0 || c.value[a - 1] === '\n';
    insertText((atLineStart ? '' : '\n') + s + '\n');
    c.focus();
  }

  /* ---- VisPro's drag a control onto the code: its actions ------------------- */
  $('code').addEventListener('dragover', (e) => { if (!$('code').disabled && e.dataTransfer.types.includes('text/x-ood-ctl')) { e.preventDefault(); $('code').classList.add('drop'); } });
  $('code').addEventListener('dragleave', () => $('code').classList.remove('drop'));
  $('code').addEventListener('drop', (e) => {
    const name = e.dataTransfer.getData('text/x-ood-ctl'); if (!name) return;
    e.preventDefault(); $('code').classList.remove('drop');
    actionsMenu(name, e.clientX, e.clientY);
  });
  async function actionsMenu(name, x, y, then = insertLine) {
    const text = String(await rx(() => st.d.actionsFor(name)).catch(() => ''));
    const menu = $('menu'); menu.textContent = '';
    const h = D.createElement('div'); h.className = 'mh'; h.textContent = name; menu.appendChild(h);
    for (const line of text.split('\n').filter(Boolean)) {
      const [label, code] = line.split('\t');
      const it = D.createElement('div'); it.dataset.action = label;
      it.append(label, Object.assign(D.createElement('small'), { textContent: code }));
      it.addEventListener('click', () => { menu.hidden = true; then(code); });
      menu.appendChild(it);
    }
    openMenu(x, y);
  }
  function openMenu(x, y) {
    const menu = $('menu'); menu.hidden = false;
    const r = menu.getBoundingClientRect();
    menu.style.left = Math.min(x, innerWidth - r.width - 8) + 'px'; menu.style.top = Math.min(y, innerHeight - r.height - 8) + 'px';
    setTimeout(() => D.addEventListener('pointerdown', function close(e) { if (!menu.contains(e.target)) { menu.hidden = true; D.removeEventListener('pointerdown', close); } }), 0);
  }
  // The same without dragging: pick the control, then the action
  $('btnInsert').addEventListener('click', (e) => {
    if ($('code').disabled) { status('Pick an event or a method first.'); return; }
    const menu = $('menu'); menu.textContent = '';
    const h = D.createElement('div'); h.className = 'mh'; h.textContent = 'Insert an action on…'; menu.appendChild(h);
    for (const n of ['form'].concat(st.snap.controls.map((c) => c.name))) {
      const it = D.createElement('div'); it.textContent = n; it.dataset.ctl = n;
      it.addEventListener('click', (ev) => { ev.stopPropagation(); actionsMenu(n, e.clientX, e.clientY); });
      menu.appendChild(it);
    }
    const r = e.target.getBoundingClientRect(); openMenu(r.left, r.bottom + 2);
  });

  /* ---- program, open, save, examples ----------------------------------------- */
  async function program() { await flushCode(); return String(await rx(() => st.d.generate())); }
  $('btnProgram').addEventListener('click', async () => {
    const src = await program().catch(() => null); if (src === null) return;
    $('programName').textContent = st.snap.form.name + '.rex'; $('programText').textContent = src; $('programView').hidden = false;
  });
  $('btnProgramClose').addEventListener('click', () => { $('programView').hidden = true; });
  $('btnCopy').addEventListener('click', () => navigator.clipboard && navigator.clipboard.writeText($('programText').textContent).then(() => status('Copied.')));
  $('btnSave').addEventListener('click', async () => {
    const src = await program().catch(() => null); if (src === null) return;
    const a = D.createElement('a'); a.href = URL.createObjectURL(new Blob([src], { type: 'text/plain' }));
    a.download = st.snap.form.name + '.rex'; D.body.appendChild(a); a.click(); a.remove();
    status('Saved ' + a.download + ': the program, with its design inside.');
  });
  $('btnOpen').addEventListener('click', () => $('file').click());
  $('file').addEventListener('change', async () => {
    const f = $('file').files[0]; if (!f) return;
    await openSource(await f.text(), f.name); $('file').value = '';
  });
  async function openSource(text, label) {
    await flushCode();
    const d = await rx(() => st.sess.eval('use arg t; return .OodDesign~fromSource(t)', text)).catch(() => null);
    if (!d) return false;
    await newDesign(d);
    status('Opened ' + label + '.');
    return true;
  }
  st.openSource = openSource;
  $('example').addEventListener('change', async () => {
    const v = $('example').value;
    if (!v) { await flushCode(); await newDesign(); status('New dialog.'); return; }
    const text = await (await fetch(v)).text();
    await openSource(text, v.replace(/.*\//, ''));
  });
  function autosave() {
    clearTimeout(st.saveTimer);
    st.saveTimer = setTimeout(async () => {
      try { const src = String(await st.d.generate()); localStorage.setItem('oodDesigner.last', src); } catch (e) { /* storage may be off */ }
    }, 1500);
  }

  /* ---- run it: ooDialog on ooRexx/WASM, in this page ------------------------- */
  $('btnRun').addEventListener('click', async () => {
    const src = await program().catch(() => null); if (src === null) return;
    await runProgram(src, 'Running');
  });
  async function runProgram(src, verb) {
    const name = st.snap.form.name + '.rex';
    $('out').textContent = ''; $('btnRun').disabled = true; $('btnTrace').disabled = true;
    try {
      if (!st.oodFiles) {
        st.oodFiles = {};
        for (const f of ['ooDialog.cls', 'oodWeb.cls', 'ooShapes.cls']) st.oodFiles['/home/rexx/' + f] = await (await fetch('ood/' + f)).text();
      }
      const files = Object.assign({}, st.oodFiles, await OxLibraries.installedFiles(st.sess), { ['/home/rexx/' + name]: src });
      const add = (t) => { $('out').textContent += t; $('out').scrollTop = $('out').scrollHeight; };
      status(verb + ' ' + name + '…');
      st.run = st.rexx.run({ args: [name], files, js: { page: true, worker: true }, onOut: add, onErr: add });
      window.oodDone = null; $('btnStop').disabled = false;
      const r = await st.run.done;
      window.oodDone = { rc: r.rc };
      status(name + ' ended, rc ' + r.rc + '.');
    } catch (e) { status('Run failed: ' + errText(e), true); }
    D.querySelectorAll('.ood-dlg,.ood-back,.ood-menu').forEach((el) => el.remove());
    $('btnRun').disabled = false; $('btnTrace').disabled = false; $('btnStop').disabled = true; st.run = null;
  }
  st.runProgram = runProgram;
  $('btnStop').addEventListener('click', () => { if (st.run) st.run.stop(); });

  /* ---- Code | Graph | Both ------------------------------------------------- */
  D.querySelectorAll('#views button').forEach((b) => b.addEventListener('click', () => {
    D.querySelectorAll('#views button').forEach((x) => x.classList.toggle('on', x === b));
    $('codeBody').className = b.dataset.view;
  }));

  /* ---- the trace run ----------------------------------------------------------
     The program is generated with OodTraceFilter: a probe before each statement
     of every event and form method calls window.oodTrace with the method, the
     block, the thread and the variables.  The steps are kept; the slider walks
     them, showing the method's code and graph with the block lit. */
  const trace = { on: false, steps: [], at: -1, where: {} };
  window.oodTrace = (where, node, thread, vars) => {
    const step = { where: String(where), node: +node, thread: String(thread), vars: String(vars).split('\t').filter(Boolean).map((v) => { const i = v.indexOf('='); return [v.slice(0, i), v.slice(i + 1)]; }) };
    trace.steps.push(step);
    $('tStep').max = trace.steps.length - 1;
    if (trace.follow) { $('tStep').value = trace.steps.length - 1; traceGo(trace.steps.length - 1); }
    else $('tWhere').textContent = 'step ' + (trace.at + 1) + ' of ' + trace.steps.length;
  };
  // the method a step is in -> where it is in the tree
  function traceTarget(where) {
    const w = where.toLowerCase();
    for (const e of st.snap.events) if (methodName(e.control, e.event).toLowerCase() === w) return { type: 'event', ctl: e.control, ev: e.event };
    for (const m of st.snap.methods) if (m.toLowerCase() === w) return { type: 'method', name: m };
    return null;
  }
  const sameCur = (a, b) => a && b && a.type === b.type && (a.type === 'method'
    ? a.name.toLowerCase() === b.name.toLowerCase()
    : a.ctl.toLowerCase() === b.ctl.toLowerCase() && a.ev === b.ev);
  async function traceGo(i) {
    trace.at = i; const step = trace.steps[i]; if (!step) return;
    const target = traceTarget(step.where);
    if (target && !sameCur(target, st.cur)) { st.cur = target; drawTree(); await showCode(); }
    else traceShowStep();
  }
  function traceShowStep() {
    if (!trace.on) return;
    const step = trace.steps[trace.at];
    if (!step) { $('tWhere').textContent = trace.steps.length ? '' : 'waiting for the first step…'; return; }
    $('tWhere').textContent = 'step ' + (trace.at + 1) + ' of ' + trace.steps.length + ':  ' + step.where +
      ', block ' + step.node + (step.thread === 'background' ? '  (its own thread)' : step.thread === 'caller' ? '' : '  (the dialog\'s thread)');
    // only highlight when the code shown is the code that was traced
    if (sameCur(traceTarget(step.where), st.cur) && !codeDirty) OxGraph.highlight(step.node);
    const before = {}; const prev = trace.steps[trace.at - 1];
    if (prev && prev.where === step.where) for (const [n, v] of prev.vars) before[n] = v;
    const body = $('tVars').tBodies[0]; body.textContent = '';
    for (const [n, v] of step.vars) {
      const tr = D.createElement('tr'); if (prev && prev.where === step.where && before[n] !== v) tr.className = 'changed';
      tr.append(Object.assign(D.createElement('td'), { textContent: n }), Object.assign(D.createElement('td'), { textContent: v }));
      body.appendChild(tr);
    }
  }
  $('tStep').addEventListener('input', () => { trace.follow = false; traceGo(+$('tStep').value); });
  $('tPrev').addEventListener('click', () => { trace.follow = false; if (trace.at > 0) { $('tStep').value = trace.at - 1; traceGo(trace.at - 1); } });
  $('tNext').addEventListener('click', () => { trace.follow = false; if (trace.at < trace.steps.length - 1) { $('tStep').value = trace.at + 1; traceGo(trace.at + 1); } });
  $('tClose').addEventListener('click', () => { trace.on = false; $('traceBar').hidden = true; OxGraph.highlight(0); });
  $('btnTrace').addEventListener('click', async () => {
    await flushCode();
    const src = await rx(async () => st.d.generate(await st.sess.eval('return .OodTraceFilter~new'))).then(String).catch(() => null);
    if (src === null) return;
    trace.on = true; trace.steps = []; trace.at = -1; trace.follow = true;
    $('tStep').max = 0; $('tStep').value = 0; $('traceBar').hidden = false; traceShowStep();
    if ($('codeBody').className === 'code') D.querySelector('#views [data-view="both"]').click();
    st.runProgram(src, 'Tracing');
  });

  boot();
})();
