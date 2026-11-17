/* objed.js -- the ooRexx Object Editor page.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   The page shows what an OxWorkspace (ObjectEditor.cls), living in an
   ooRexx/WASM session, finds by reflection, and sends it what the user does.
   No class, member or completion is worked out here. */
(function () {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const D = document;
  const st = { rexx: null, sess: null, w: null, cls: null, side: 'INSTANCE', cur: null, fileName: '', files: {}, docs: {}, groups: new Map() };
  window.oxEditor = st;
  // the editor's texts: ::RESOURCE strings.<language> of OxUi.cls, through OodNls (oodnls.js)
  const T = window.OodT, NLS = window.OodNlsPage;

  function status(text, isErr) { $('status').textContent = text; $('status').title = text; $('status').classList.toggle('err', !!isErr); }
  function errText(e) {
    let m = (e && (e.message || e.toString())) || String(e);
    const k = m.search(/Error 93\.900:\s*/);
    if (k >= 0) {
      // a refusal: the editor's own message, not ooRexx's "Incorrect call to method. (...)" round it
      m = m.slice(k).replace(/Error 93\.900:\s*/, '').split('\n')[0];
      const r = /^[^(]*\((.*)\.\)$/.exec(m);
      return r ? r[1] : m;
    }
    return m.split('\n')[0];
  }
  let chain = Promise.resolve();
  function rx(fn) {                                   // one Rexx call at a time; errors to the status line
    const p = chain.then(fn);
    chain = p.catch(() => {});
    return p.catch((e) => { status(errText(e), true); throw e; });
  }
  const lines = (t) => String(t || '').split('\n').filter((l) => l !== '');
  const fieldsOf = (l) => l.split('\t');

  /* ---- start ---------------------------------------------------------------- */
  async function boot() {
    try {
      st.rexx = await ooRexx.load();
      const files = {};
      for (const f of ['ooDialog.cls', 'oodWeb.cls', 'ooShapes.cls']) {
        const r = await fetch('ood/' + f); if (r.ok) files['/home/rexx/' + f] = await r.text();
      }
      for (const f of ['OodNls.cls', 'OxUi.cls', 'OodUi.cls', 'OodPlugins.cls', 'ObjectEditor.cls', 'OodDesigner.cls', 'LibraryProviders.cls', 'OxDocs.cls']) files['/home/rexx/' + f] = await (await fetch(f)).text();
      // Josep Maria Blasco's Rexx Parser, which OxDocs.cls reads ooRexxDoc with (loaded on first use)
      for (const rel of (await (await fetch('rexx-parser/manifest.txt')).text()).split('\n').map((l) => l.trim()).filter(Boolean))
        files['/home/rexx/rexx-parser/' + rel] = await (await fetch('rexx-parser/' + rel)).text();
      const rexxPath = await OodPluginsPage.rexxPath();     // where plugins' estate files go, before it starts
      st.sess = await st.rexx.start({ js: { page: true, worker: true }, files, env: rexxPath ? { REXX_PATH: rexxPath } : {} });
      await st.sess.loadPackage('LibraryProviders.cls');   // requires ObjectEditor.cls and OodDesigner.cls
      await st.sess.loadPackage('OodPlugins.cls');         // the optional extras' host
      let chosen = ''; try { chosen = localStorage.getItem('oodDesigner.ui') || ''; } catch (e) { /* storage may be off */ }
      await loadUi(chosen || navigator.language || '');   // the designer's choice is the editor's too
      OodDatabaseLabPage.setup(st.rexx);
      await OxLibraries.setup(st.sess);
      await OodPluginsPage.setup(st.sess, { status, rx, onChange: () => { diagnoseSoon(0); askButton(); sourceButton(); } });
      await sourceButton();
      const first = $('example').value;
      if (first) await openUrl(first); else await openText('MyObject.cls', '');
      st.ready = true;                                  // (tests wait for st.ready)
    } catch (e) { status((NLS.has('ox.noStart') ? T('ox.noStart') : 'Could not start:') + ' ' + errText(e), true); console.error(e); }
  }
  async function loadUi(lang) {
    await NLS.load(st.sess, ['OxUi', 'OodUi'], lang);       // OodUi: the Plugins panel's texts
    const sel = $('uiLang'); sel.textContent = '';
    for (const l of NLS.languages) sel.appendChild(Object.assign(D.createElement('option'), { value: l, textContent: l }));
    sel.value = NLS.lang;
    NLS.apply(); D.title = T('ox.name');
    const panel = D.getElementById('libPanel'); if (panel) NLS.apply(panel);
  }
  $('uiLang').addEventListener('change', async () => {
    await flushCode();
    try { localStorage.setItem('oodDesigner.ui', $('uiLang').value); } catch (e) { /* storage may be off */ }
    await rx(() => loadUi($('uiLang').value));
    await OodPluginsPage.setLanguage(NLS.lang);
    await refresh(); await showCode();
    status(T('ox.lang.now', NLS.lang));
  });
  async function openText(name, text) {
    const w = await rx(() => st.sess.eval('use arg n, t; return .OxWorkspace~new(n, t)', '/home/rexx/' + name, text)).catch(() => null);
    if (!w) return false;
    st.w = w; st.fileName = name; st.cur = null; st.side = 'INSTANCE';
    const names = String(await rx(() => w.classNames())).split(' ').filter(Boolean);
    st.cls = names[0] || null;
    $('fileName').textContent = name;
    await refresh(); showCode();
    status(T('ox.opened', name, names.length));
    return true;
  }
  async function openUrl(url) { return openText(url.replace(/.*\//, ''), await (await fetch(url)).text()); }
  st.openText = openText;

  /* ---- redraw from reflection -------------------------------------------------- */
  async function refresh() {
    const w = st.w;
    st.docs = {};                                       // an edit may change them
    const names = String(await rx(() => w.classNames())).split(' ').filter(Boolean);
    if (st.cls && !names.some((n) => n.toLowerCase() === st.cls.toLowerCase())) st.cls = names[0] || null;
    // classes, indented under their superclass where it is in this file
    const info = {};
    for (const n of names) { const f = fieldsOf(String(await rx(() => w.classInfo(n)))); info[n] = { name: f[0], sup: f[1], mixins: f[2], isMixin: f[3], pub: f[4], abs: f[5] }; }
    const box = $('classes'); box.textContent = '';
    const depthOf = (n, d = 0) => { const s = info[n] && info[n].sup; const p = names.find((x) => x.toLowerCase() === String(s).toLowerCase()); return p && d < 20 ? depthOf(p, d + 1) : d; };
    for (const n of names) {
      const div = D.createElement('div'); div.className = 'cls' + (st.cls === n ? ' sel' : ''); div.dataset.cls = n;
      div.style.paddingLeft = (6 + depthOf(n) * 14) + 'px';
      div.append(n + ' ', Object.assign(D.createElement('small'), { textContent: info[n].isMixin === '1' ? 'mixin' : (info[n].sup ? T('ox.subclassOfX', info[n].sup) : '') }));
      div.addEventListener('click', async () => { await flushCode(); st.cls = n; st.cur = null; $('docBox').hidden = true; await refresh(); showCode(); });
      docsOfClass(n).then((m) => { const d = Object.values(m).find((x) => x.kind === 'CLASS'); if (d && d.summary) div.title = d.summary; });
      box.appendChild(div);
    }
    await drawHierarchy(); await drawRequires(); await drawClassCard(info[st.cls]); await drawMembers();
    const known = String(await rx(() => w.knownClassNames())).split(' ');
    $('knownList').textContent = ''; for (const k of known) $('knownList').appendChild(Object.assign(D.createElement('option'), { value: k }));
  }
  async function drawHierarchy() {
    const box = $('hierarchy'); box.textContent = ''; if (!st.cls) return;
    for (const l of lines(await rx(() => st.w.hierarchy(st.cls)))) {
      const [depth, name, mixins, pkg] = fieldsOf(l);
      const div = D.createElement('div'); const own = pkg && pkg.endsWith(st.fileName);
      div.className = name.toLowerCase() === st.cls.toLowerCase() ? 'me' : (own ? '' : 'lib');
      div.textContent = '  '.repeat(Number(depth)) + (Number(depth) ? '└ ' : '') + name + (mixins ? '  + ' + mixins : '') + (own ? '' : '  (' + pkg.replace(/.*\//, '') + ')');
      box.appendChild(div);
    }
    const subs = String(await rx(() => st.w.subclassNames(st.cls))).trim();
    if (subs) { const div = D.createElement('div'); div.textContent = T('ox.subclasses', subs); box.appendChild(div); }
  }
  async function drawRequires() {
    const box = $('requires'); box.textContent = '';
    for (const l of lines(await rx(() => st.w.requiresInfo()))) {
      const [file, classes] = fieldsOf(l);
      const div = D.createElement('div'); div.className = 'req';
      const b = D.createElement('b'); b.textContent = file;
      const x = D.createElement('button'); x.textContent = '✕'; x.title = T('ox.requires.remove.tip');
      x.addEventListener('click', () => edit(() => st.w.removeRequires(file), 'ox.requires.removed', file));
      const c = D.createElement('div'); c.className = 'classes'; c.textContent = classes || T('ox.requires.noClasses');
      div.append(b, x, c); box.appendChild(div);
    }
  }
  async function drawClassCard(i) {
    const box = $('classCard'); box.textContent = ''; if (!i) return;
    const t = D.createElement('span'); t.className = 'title'; t.textContent = '::class ' + i.name;
    const sup = Object.assign(D.createElement('input'), { value: i.sup, id: 'clsSuper' }); sup.setAttribute('list', 'knownList');
    const mix = Object.assign(D.createElement('input'), { value: i.mixins, id: 'clsMixins', placeholder: T('ox.none') });
    const pub = Object.assign(D.createElement('input'), { type: 'checkbox', checked: i.pub === '1', id: 'clsPublic' });
    const isMix = Object.assign(D.createElement('input'), { type: 'checkbox', checked: i.isMixin === '1', id: 'clsMixin' });
    const lab = (txt, el) => { const l = D.createElement('label'); l.append(txt, el); return l; };
    const apply = D.createElement('button'); apply.textContent = T('ox.apply'); apply.id = 'btnApplyClass';
    apply.addEventListener('click', () => edit(() => st.w.setClass(i.name, sup.value.trim(), mix.value.trim(), pub.checked ? 1 : 0, isMix.checked ? 1 : 0), 'ox.classChanged', i.name));
    const del = D.createElement('button'); del.textContent = T('ox.removeClass');
    del.addEventListener('click', () => edit(() => st.w.removeClass(i.name), 'ox.classRemoved', i.name));
    const doc = D.createElement('button'); doc.id = 'btnDocClass'; doc.textContent = T('ox.doc.cls.btn'); doc.title = T('ox.doc.cls.tip');
    doc.hidden = true; OodPluginsPage.assistIds().then((ids) => { doc.hidden = !ids.length; }, () => {});
    doc.addEventListener('click', () => documentMember(i.name, '', 'INSTANCE'));
    // the directive words (inherit, public, mixinclass) are ooRexx's, as written in the file
    box.append(t, lab(T('ox.subclassOf'), sup), lab('inherit', mix), lab('public', pub), lab('mixinclass', isMix), apply, del, doc);
  }
  /* ---- ooRexxDoc: the first sentence as a member's tooltip, the whole text in
     the doc box when it is clicked (OxDocs, read by the Rexx Parser) */
  async function docsOfClass(cls) {
    const key = cls.toLowerCase();
    if (!(key in st.docs)) {
      const m = {};
      for (const l of lines(await rx(() => st.w.docsOf(cls)).catch(() => ''))) {
        const [kind, name, summary, full] = fieldsOf(l);
        m[kind + ' ' + name] = { kind, name, summary, text: String(full || '').replace(/\x0b/g, '\n') };
      }
      st.docs[key] = m;
    }
    return st.docs[key];
  }
  async function docFor(cls, name, kind) {
    const m = await docsOfClass(cls), side = st.side === 'CLASS' ? ' class' : '';
    const k = kind === 'ATTRIBUTE' ? 'ATTRIBUTE ' + name.toLowerCase().replace(/=$/, '') + side : kind + ' ' + name.toLowerCase() + side;
    const d = m[k] || (kind === 'ATTRIBUTE' ? m['METHOD ' + name.toLowerCase() + side] : null);
    return d && (d.summary || d.text) ? d : null;
  }
  function showDoc(cls, name, doc) {
    const box = $('docBox'); box.textContent = '';
    const h = D.createElement('b'); h.textContent = cls + '~' + (name === '' ? '""' : name === ' ' ? '" "' : name);
    const p = D.createElement('pre'); p.textContent = doc ? doc.text : T('ox.doc.none');
    box.append(h, p); box.hidden = false;
  }
  async function drawMembers() {
    const tb = $('members').querySelector('tbody'); tb.textContent = ''; if (!st.cls) return;
    D.querySelectorAll('#sideTabs button').forEach((b) => b.classList.toggle('cur', b.dataset.side === st.side));
    const text = await rx(() => st.w.members(st.cls, st.side, $('showInherited').checked ? 1 : 0));
    // inherited members under the class that defines them; Object's and
    // Class's closed at first, so the class's own members stand out
    const rows = lines(text).map(fieldsOf);
    const counts = {};
    for (const r of rows) if (r[6] !== '1') counts[r[5]] = (counts[r[5]] || 0) + 1;
    let group = null;
    for (const [name, kind, vis, guard, abstract, definedIn, own] of rows) {
      if (own !== '1' && definedIn !== group) {
        group = definedIn;
        const g = definedIn.toLowerCase(), open = st.groups.has(g) ? st.groups.get(g) : !['object', 'class'].includes(g);
        const hr = D.createElement('tr'); hr.className = 'grp'; hr.dataset.grp = definedIn;
        const c = D.createElement('td'); c.colSpan = 7; c.textContent = (open ? '▾ ' : '▸ ') + T('ox.inheritedFrom', definedIn, counts[definedIn]);
        c.title = T(open ? 'ox.group.close.tip' : 'ox.group.open.tip');
        hr.addEventListener('click', () => { st.groups.set(g, !open); drawMembers(); });
        hr.appendChild(c); tb.appendChild(hr);
      }
      if (own !== '1' && !(st.groups.has(group.toLowerCase()) ? st.groups.get(group.toLowerCase()) : !['object', 'class'].includes(group.toLowerCase()))) continue;
      const tr = D.createElement('tr'); tr.className = own === '1' ? 'own' : 'inh'; tr.dataset.member = name;
      if (st.cur && st.cur.name.toLowerCase() === name.toLowerCase() && own === '1') tr.classList.add('cur');
      const td = (x) => { const c = D.createElement('td'); if (x instanceof Node) c.appendChild(x); else c.textContent = x; tr.appendChild(c); return c; };
      // operators' names in quotes; the two that look empty say what they are
      const shown = /^[A-Za-z0-9_!?.]+=?$/.test(name) ? name : '"' + name + '"' + (name === '' ? ' ' + T('ox.op.abuttal') : name === ' ' ? ' ' + T('ox.op.blank') : '');
      const nm = td(shown); nm.className = 'nm';
      const doc = await docFor(definedIn, name, kind);
      if (doc) { nm.title = doc.summary || T('ox.doc.noSummary'); nm.classList.add('hasdoc'); }
      nm.addEventListener('click', () => showDoc(definedIn, name, doc));
      td(kind.toLowerCase());                    // method, attribute, constant: ooRexx's own words
      if (own === '1' && kind !== 'CONSTANT') {
        const sel = (vals, v, cls) => { const s = D.createElement('select'); s.className = cls; vals.forEach((x) => s.add(new Option(x, x, false, x === v))); return s; };
        const sv = sel(['public', 'private', 'package'], vis, 'vis'), sg = sel(['guarded', 'unguarded'], guard, 'guard');
        const ab = Object.assign(D.createElement('input'), { type: 'checkbox', checked: abstract === '1', className: 'abstract' });
        if (kind !== 'METHOD') ab.disabled = true;
        const change = () => edit(() => st.w.setMemberFlags(st.cls, name, st.side, st.side, sv.value, sg.value, ab.checked ? 1 : 0), 'ox.flags', name, sv.value + ' ' + sg.value + (ab.checked ? ' abstract' : ''));
        sv.addEventListener('change', change); sg.addEventListener('change', change); ab.addEventListener('change', change);
        td(sv); td(sg); td(ab);
      } else { td(vis); td(guard); td(abstract === '1' ? 'abstract' : ''); }
      td(definedIn);
      if (own === '1') {
        const x = D.createElement('button'); x.textContent = '✕'; x.title = T('ox.remove.tip', name);
        x.addEventListener('click', () => edit(() => st.w.removeMember(st.cls, name, st.side), 'ox.memberRemoved', name));
        td(x);
        if (kind === 'METHOD') nm.addEventListener('click', async () => { await flushCode(); st.cur = { name }; await drawMembers(); showCode(); });
      } else td('');
      tb.appendChild(tr);
    }
  }
  // a structural edit: the model reloads it and refuses it if it does not compile
  // done: the key of the status text, then its arguments
  async function edit(fn, done, ...args) {
    await flushCode();
    const ok = await rx(fn).then(() => true, () => false);
    await refresh();
    if (ok) status(T(done, ...args) + '  ' + T('ox.reloaded'));
    return ok;
  }
  st.edit = edit;

  /* ---- adding ---------------------------------------------------------------------- */
  $('btnAddClass').addEventListener('click', async () => {
    const n = $('newClassName').value.trim(); if (!n) return;
    if (await edit(() => st.w.addClass(n, $('newClassSuper').value.trim(), '', 1, 0), 'ox.classAdded', n)) {
      st.cls = n; $('newClassName').value = ''; $('newClassSuper').value = ''; await refresh();
    }
  });
  $('btnAddRequires').addEventListener('click', async () => {
    const f = $('newRequires').value.trim(); if (!f) return;
    if (await edit(() => st.w.addRequires(f), 'ox.requires.added', f)) $('newRequires').value = '';
  });
  $('newMemberKind').addEventListener('change', () => { const c = $('newMemberKind').value === 'CONSTANT'; $('newConstValue').hidden = !c; $('newMemberVis').disabled = c; $('newMemberGuard').disabled = c; });
  $('btnAddMember').addEventListener('click', async () => {
    const n = $('newMemberName').value.trim(); if (!n || !st.cls) return;
    const k = $('newMemberKind').value, v = $('newMemberVis').value, g = $('newMemberGuard').value;
    const fn = k === 'METHOD' ? () => st.w.addMethod(st.cls, n, st.side, v, g, 0)
      : k === 'ATTRIBUTE' ? () => st.w.addAttribute(st.cls, n, st.side, v, g)
        : () => st.w.addConstant(st.cls, n, $('newConstValue').value.trim() || '""');
    if (await edit(fn, 'ox.memberAdded', k.toLowerCase(), n)) {
      $('newMemberName').value = '';
      if (k === 'METHOD') { st.cur = { name: n }; await drawMembers(); showCode(); }
    }
  });
  D.querySelectorAll('#sideTabs button').forEach((b) => b.addEventListener('click', async () => { await flushCode(); st.side = b.dataset.side; st.cur = null; await drawMembers(); showCode(); }));
  $('showInherited').addEventListener('change', drawMembers);

  /* ---- the method pane ----------------------------------------------------------- */
  let dirty = false, timer = null;
  async function showCode() {
    const c = $('code');
    if (!st.cur) { $('edTitle').textContent = T('ox.pickMethod'); c.value = ''; c.disabled = true; $('edState').textContent = ''; askButton(); return; }
    $('edTitle').textContent = st.cls + (st.side === 'CLASS' ? ' class' : '') + ' ~' + st.cur.name;
    c.value = String(await rx(() => st.w.getBody(st.cls, st.cur.name, st.side)).catch(() => ''));
    c.disabled = false; dirty = false; state('', '');
    diagnoseSoon(0); askButton();
  }
  function state(text, cls) { $('edState').textContent = text; $('edState').className = cls; }
  async function flushCode() {
    if (!dirty || !st.cur) return;
    dirty = false; clearTimeout(timer);
    const cur = st.cur, cls = st.cls, side = st.side, text = $('code').value;
    const err = String(await rx(() => st.w.setBody(cls, cur.name, side, text)).catch((e) => errText(e)));
    if (err) state(err, 'err'); else { state(T('ox.compiles'), 'ok'); await drawMembers(); }
    diagnoseSoon(0);
  }
  $('code').addEventListener('input', () => { dirty = true; clearTimeout(timer); timer = setTimeout(flushCode, 700); popupUpdate(); });
  $('code').addEventListener('blur', () => setTimeout(() => { if (!popOpen()) flushCode(); }, 150));

  /* ---- completion: asked of the objects ------------------------------------------- */
  const SYM = /[A-Za-z0-9_!?]/;
  let all = [], items = [], sel = 0, pending = false;
  const popOpen = () => !$('pop').hidden;
  function closePop() { $('pop').hidden = true; items = []; all = []; }
  // the model answers for the text before the caret; while the user types
  // on, its answer is narrowed here to the symbol now before the caret
  async function complete() {
    const c = $('code'); const before = c.value.slice(0, c.selectionStart);
    pending = true;
    const text = String(await rx(() => st.w.complete(st.cls, st.side, before)).catch(() => ''));
    pending = false;
    all = lines(text).map((l) => { const [label, kind, detail] = fieldsOf(l); return { label, kind, detail }; });
    sel = 0; drawPop();
  }
  function typedPrefix() {
    const c = $('code'); let a = c.selectionStart;
    while (a > 0 && SYM.test(c.value[a - 1])) a--;
    return c.value.slice(a, c.selectionStart).toLowerCase();
  }
  st.complete = complete;
  function drawPop() {
    const pop = $('pop'); pop.textContent = '';
    const pre = typedPrefix();
    items = all.filter((it) => it.label.toLowerCase().startsWith(pre));
    if (sel >= items.length) sel = 0;
    if (!items.length) { pop.hidden = true; return; }
    items.slice(0, 200).forEach((it, i) => {
      const d = D.createElement('div'); if (i === sel) d.className = 'cur';
      d.dataset.label = it.label;
      d.append(it.label, Object.assign(D.createElement('small'), { textContent: it.kind + (it.detail ? '  ' + it.detail : '') }));
      d.addEventListener('mousedown', (e) => { e.preventDefault(); sel = i; accept(); });
      pop.appendChild(d);
    });
    const c = $('code'); const r = c.getBoundingClientRect();
    const before = c.value.slice(0, c.selectionStart); const row = before.split('\n').length - 1; const col = before.length - before.lastIndexOf('\n') - 1;
    const lh = parseFloat(getComputedStyle(c).lineHeight) || 19; const cw = 7.8;
    pop.style.left = Math.min(r.left + 12 + col * cw - c.scrollLeft, innerWidth - 280) + 'px';
    pop.style.top = Math.min(r.top + 8 + (row + 1) * lh - c.scrollTop, innerHeight - 250) + 'px';
    pop.hidden = false;
    const cur = pop.children[sel]; if (cur) cur.scrollIntoView({ block: 'nearest' });
  }
  function accept() {
    const it = items[sel]; if (!it) return;
    const c = $('code'); let a = c.selectionStart;
    while (a > 0 && SYM.test(c.value[a - 1])) a--;
    c.value = c.value.slice(0, a) + it.label + c.value.slice(c.selectionStart);
    c.selectionStart = c.selectionEnd = a + it.label.length;
    closePop(); dirty = true; clearTimeout(timer); timer = setTimeout(flushCode, 700); c.focus();
  }
  function popupUpdate() {
    const c = $('code'); const ch = c.value[c.selectionStart - 1];
    if (ch === '~' || ch === '.') { complete(); return; }
    if (popOpen() || pending) { if (ch && SYM.test(ch)) drawPop(); else closePop(); }
  }
  $('code').addEventListener('keydown', (e) => {
    if (e.key === ' ' && e.ctrlKey) { e.preventDefault(); complete(); return; }
    if (e.key === 'Tab' && !popOpen()) { e.preventDefault(); const c = $('code'); const a = c.selectionStart; c.value = c.value.slice(0, a) + '  ' + c.value.slice(c.selectionEnd); c.selectionStart = c.selectionEnd = a + 2; dirty = true; return; }
    if (!popOpen()) return;
    if (e.key === 'ArrowDown') { e.preventDefault(); sel = Math.min(sel + 1, items.length - 1); drawPop(); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); sel = Math.max(sel - 1, 0); drawPop(); }
    else if (e.key === 'Enter' || e.key === 'Tab') { e.preventDefault(); accept(); }
    else if (e.key === 'Escape') { e.preventDefault(); closePop(); }
  });

  /* ---- files ---------------------------------------------------------------------- */
  $('example').addEventListener('change', async () => { await flushCode(); const v = $('example').value; if (v) await openUrl(v); else await openText('MyObject.cls', ''); });
  $('btnOpen').addEventListener('click', () => $('file').click());
  $('file').addEventListener('change', async () => { const f = $('file').files[0]; if (!f) return; await flushCode(); await openText(f.name, await f.text()); $('file').value = ''; });
  $('btnSave').addEventListener('click', async () => {
    await flushCode();
    const text = String(await rx(() => st.w.text()));
    const a = D.createElement('a'); a.href = URL.createObjectURL(new Blob([text], { type: 'text/plain' })); a.download = st.fileName;
    D.body.appendChild(a); a.click(); a.remove(); status(T('ox.saved', st.fileName));
  });
  $('btnSource').addEventListener('click', async () => {
    await flushCode();
    $('sourceName').textContent = st.fileName; $('sourceText').textContent = String(await rx(() => st.w.text())); $('sourceView').hidden = false;
  });
  $('btnSourceClose').addEventListener('click', () => { $('sourceView').hidden = true; });
  // Libraries: connect to a provider, install, and use: a ::requires in this file
  $('btnLibraries').addEventListener('click', () => OxLibraries.open({
    sess: st.sess, status,
    onUse: async (req) => {
      if (await edit(() => st.w.addRequires(req), 'ox.requires.added', req)) D.getElementById('libPanel').hidden = true;
    },
  }));
  $('btnCopy').addEventListener('click', () => navigator.clipboard && navigator.clipboard.writeText($('sourceText').textContent).then(() => status(T('ox.copied'))));

  /* ---- plugins: optional extras; what they find in the method, and their fixes -- */
  $('btnPlugins').addEventListener('click', () => OodPluginsPage.open());
  let diagTimer = null;
  function diagnoseSoon(ms) { clearTimeout(diagTimer); diagTimer = setTimeout(diagnoseNow, ms == null ? 500 : ms); }
  async function diagnoseNow() {
    const c = $('code');
    if (c.disabled) { OodPluginsPage.show($('diag'), [], {}); return; }
    const text = c.value;
    const found = await OodPluginsPage.diagnose(text);
    if (c.value !== text) return;
    OodPluginsPage.show($('diag'), found, {
      onLine: (f) => {
        const ls = c.value.split('\n'); const a = ls.slice(0, f.line - 1).reduce((n, l) => n + l.length + 1, 0);
        c.focus(); c.setSelectionRange(a, a + (ls[f.line - 1] || '').length);
      },
      onFix: async (f) => {
        const fixed = await OodPluginsPage.fix(f.plugin, c.value, f.fixId).catch(() => null);
        if (fixed === null) return;
        c.value = fixed; dirty = true; await flushCode();
        status(T('plug.fixed', f.rule, f.line));
      },
    });
  }
  st.diagnoseNow = diagnoseNow;

  // Repository…: shown when a source control plugin is on; the file is the class file
  async function sourceButton() { $('btnScm').hidden = !(await OodPluginsPage.scmIds()).length; }
  $('btnScm').addEventListener('click', () => OodPluginsPage.source({
    name: () => st.fileName,
    text: async () => { await flushCode(); return String(await rx(() => st.w.text())); },
    open: async (name, text) => { await flushCode(); return openText(name, text); } }));

  // Ask…: shown when a code assistance plugin is on and a method is open
  async function askButton() {
    const on = (await OodPluginsPage.assistIds()).length > 0;
    $('btnAsk').hidden = !st.cur || !on; $('btnDoc').hidden = !st.cur || !on;
    const c = $('btnDocClass'); if (c) c.hidden = !on;
  }
  $('btnAsk').addEventListener('click', async () => {
    if (!st.cur) return;
    await flushCode();
    const cls = st.cls, cur = st.cur, side = st.side;
    const own = String(await rx(() => st.w.members(cls, side, 0)).catch(() => ''))
      .split('\n').filter(Boolean).map((l) => l.split('\t')).map((f) => f[0] + ' (' + f[1].toLowerCase() + ')');
    const context = () => ['An ooRexx class ' + cls + ', in ' + st.fileName + '.',
      'Its ' + (side === 'CLASS' ? 'class' : 'instance') + ' members: ' + (own.join(', ') || '(none)'),
      'The code is the ' + (side === 'CLASS' ? 'class ' : '') + 'method ' + cur.name + ' of ' + cls + '.'].join('\n');
    OodPluginsPage.ask({ title: $('edTitle').textContent, code: () => $('code').value, context,
      apply: async (text) => { if (st.cur !== cur) return; $('code').value = text; dirty = true; await flushCode(); } });
  });
  // Document…: an ooRexxDoc comment proposed from the member's code (the
  // assist plugins' DOC kind); applied before the member's directive (setDoc)
  async function documentMember(cls, name, side, title) {
    await flushCode();
    const label = name === '' ? cls : cls + (side === 'CLASS' ? ' class' : '') + ' ~' + name;
    const member = String(await rx(() => st.w.memberText(cls, name, side)).catch(() => ''));
    let now = String(await rx(() => st.w.getDoc(cls, name, side)).catch(() => ''));
    OodPluginsPage.ask({ kind: 'DOC', title: title || T('ox.doc.title', label), code: () => now,
      context: () => 'In ' + st.fileName + ', class ' + cls + '.\n' + member,
      apply: async (text) => {
        if (await edit(() => st.w.setDoc(cls, name, side, text), 'ox.doc.applied', label)) now = text;
        if (name !== '' && st.cur && st.cur.name.toLowerCase() === name.toLowerCase()) showCode();
      } });
  }
  st.documentMember = documentMember;
  $('btnDoc').addEventListener('click', () => { if (st.cur) documentMember(st.cls, st.cur.name, st.side); });
  $('code').addEventListener('input', () => diagnoseSoon());

  boot();
})();
