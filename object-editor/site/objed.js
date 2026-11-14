/* objed.js -- the ooRexx Object Editor page.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   The page shows what an OxWorkspace (ObjectEditor.cls), living in an
   ooRexx/WASM session, finds by reflection, and sends it what the user does.
   No class, member or completion is worked out here. */
(function () {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const D = document;
  const st = { rexx: null, sess: null, w: null, cls: null, side: 'INSTANCE', cur: null, fileName: '', files: {} };
  window.oxEditor = st;

  function status(text, isErr) { $('status').textContent = text; $('status').title = text; $('status').classList.toggle('err', !!isErr); }
  function errText(e) {
    let m = (e && (e.message || e.toString())) || String(e);
    const k = m.search(/Error 93\.900:\s*/);
    if (k >= 0) m = m.slice(k).replace(/Error 93\.900:\s*/, '');
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
      for (const f of ['ObjectEditor.cls', 'OodDesigner.cls', 'LibraryProviders.cls']) files['/home/rexx/' + f] = await (await fetch(f)).text();
      st.sess = await st.rexx.start({ js: { page: true, worker: true }, files });
      await st.sess.loadPackage('LibraryProviders.cls');   // requires ObjectEditor.cls and OodDesigner.cls
      await OxLibraries.setup(st.sess);
      const first = $('example').value;
      if (first) await openUrl(first); else await openText('MyObject.cls', '');
    } catch (e) { status('Could not start: ' + errText(e), true); console.error(e); }
  }
  async function openText(name, text) {
    const w = await rx(() => st.sess.eval('use arg n, t; return .OxWorkspace~new(n, t)', '/home/rexx/' + name, text)).catch(() => null);
    if (!w) return false;
    st.w = w; st.fileName = name; st.cur = null; st.side = 'INSTANCE';
    const names = String(await rx(() => w.classNames())).split(' ').filter(Boolean);
    st.cls = names[0] || null;
    $('fileName').textContent = name;
    await refresh(); showCode();
    status('Opened ' + name + ': ' + names.length + ' classes, found by reflection.');
    return true;
  }
  async function openUrl(url) { return openText(url.replace(/.*\//, ''), await (await fetch(url)).text()); }
  st.openText = openText;

  /* ---- redraw from reflection -------------------------------------------------- */
  async function refresh() {
    const w = st.w;
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
      div.append(n + ' ', Object.assign(D.createElement('small'), { textContent: info[n].isMixin === '1' ? 'mixin' : (info[n].sup ? 'subclass of ' + info[n].sup : '') }));
      div.addEventListener('click', async () => { await flushCode(); st.cls = n; st.cur = null; await refresh(); showCode(); });
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
    if (subs) { const div = D.createElement('div'); div.textContent = 'subclasses: ' + subs; box.appendChild(div); }
  }
  async function drawRequires() {
    const box = $('requires'); box.textContent = '';
    for (const l of lines(await rx(() => st.w.requiresInfo()))) {
      const [file, classes] = fieldsOf(l);
      const div = D.createElement('div'); div.className = 'req';
      const b = D.createElement('b'); b.textContent = file;
      const x = D.createElement('button'); x.textContent = '✕'; x.title = 'Remove this ::requires';
      x.addEventListener('click', () => edit(() => st.w.removeRequires(file), 'Removed ::requires ' + file));
      const c = D.createElement('div'); c.className = 'classes'; c.textContent = classes || '(no public classes)';
      div.append(b, x, c); box.appendChild(div);
    }
  }
  async function drawClassCard(i) {
    const box = $('classCard'); box.textContent = ''; if (!i) return;
    const t = D.createElement('span'); t.className = 'title'; t.textContent = '::class ' + i.name;
    const sup = Object.assign(D.createElement('input'), { value: i.sup, id: 'clsSuper' }); sup.setAttribute('list', 'knownList');
    const mix = Object.assign(D.createElement('input'), { value: i.mixins, id: 'clsMixins', placeholder: 'none' });
    const pub = Object.assign(D.createElement('input'), { type: 'checkbox', checked: i.pub === '1', id: 'clsPublic' });
    const isMix = Object.assign(D.createElement('input'), { type: 'checkbox', checked: i.isMixin === '1', id: 'clsMixin' });
    const lab = (txt, el) => { const l = D.createElement('label'); l.append(txt, el); return l; };
    const apply = D.createElement('button'); apply.textContent = 'Apply'; apply.id = 'btnApplyClass';
    apply.addEventListener('click', () => edit(() => st.w.setClass(i.name, sup.value.trim(), mix.value.trim(), pub.checked ? 1 : 0, isMix.checked ? 1 : 0), 'Class ' + i.name + ' changed.'));
    const del = D.createElement('button'); del.textContent = 'Remove class';
    del.addEventListener('click', () => edit(() => st.w.removeClass(i.name), 'Removed class ' + i.name + '.'));
    box.append(t, lab('subclass of', sup), lab('inherit', mix), lab('public', pub), lab('mixinclass', isMix), apply, del);
  }
  async function drawMembers() {
    const tb = $('members').querySelector('tbody'); tb.textContent = ''; if (!st.cls) return;
    D.querySelectorAll('#sideTabs button').forEach((b) => b.classList.toggle('cur', b.dataset.side === st.side));
    const text = await rx(() => st.w.members(st.cls, st.side, $('showInherited').checked ? 1 : 0));
    for (const l of lines(text)) {
      const [name, kind, vis, guard, abstract, definedIn, own] = fieldsOf(l);
      const tr = D.createElement('tr'); tr.className = own === '1' ? 'own' : 'inh'; tr.dataset.member = name;
      if (st.cur && st.cur.name.toLowerCase() === name.toLowerCase() && own === '1') tr.classList.add('cur');
      const td = (x) => { const c = D.createElement('td'); if (x instanceof Node) c.appendChild(x); else c.textContent = x; tr.appendChild(c); return c; };
      const nm = td(/^[A-Za-z0-9_!?.]+=?$/.test(name) ? name : '"' + name + '"'); nm.className = 'nm';
      td(kind.toLowerCase());
      if (own === '1' && kind !== 'CONSTANT') {
        const sel = (vals, v, cls) => { const s = D.createElement('select'); s.className = cls; vals.forEach((x) => s.add(new Option(x, x, false, x === v))); return s; };
        const sv = sel(['public', 'private', 'package'], vis, 'vis'), sg = sel(['guarded', 'unguarded'], guard, 'guard');
        const ab = Object.assign(D.createElement('input'), { type: 'checkbox', checked: abstract === '1', className: 'abstract' });
        if (kind !== 'METHOD') ab.disabled = true;
        const change = () => edit(() => st.w.setMemberFlags(st.cls, name, st.side, st.side, sv.value, sg.value, ab.checked ? 1 : 0), name + ': ' + sv.value + ' ' + sg.value + (ab.checked ? ' abstract' : ''));
        sv.addEventListener('change', change); sg.addEventListener('change', change); ab.addEventListener('change', change);
        td(sv); td(sg); td(ab);
      } else { td(vis); td(guard); td(abstract === '1' ? 'abstract' : ''); }
      td(definedIn);
      if (own === '1') {
        const x = D.createElement('button'); x.textContent = '✕'; x.title = 'Remove ' + name;
        x.addEventListener('click', () => edit(() => st.w.removeMember(st.cls, name, st.side), 'Removed ' + name + '.'));
        td(x);
        if (kind === 'METHOD') nm.addEventListener('click', async () => { await flushCode(); st.cur = { name }; await drawMembers(); showCode(); });
      } else td('');
      tb.appendChild(tr);
    }
  }
  // a structural edit: the model reloads it and refuses it if it does not compile
  async function edit(fn, done) {
    await flushCode();
    const ok = await rx(fn).then(() => true, () => false);
    await refresh();
    if (ok) status(done + '  (reloaded)');
    return ok;
  }
  st.edit = edit;

  /* ---- adding ---------------------------------------------------------------------- */
  $('btnAddClass').addEventListener('click', async () => {
    const n = $('newClassName').value.trim(); if (!n) return;
    if (await edit(() => st.w.addClass(n, $('newClassSuper').value.trim(), '', 1, 0), 'Added class ' + n + '.')) {
      st.cls = n; $('newClassName').value = ''; $('newClassSuper').value = ''; await refresh();
    }
  });
  $('btnAddRequires').addEventListener('click', async () => {
    const f = $('newRequires').value.trim(); if (!f) return;
    if (await edit(() => st.w.addRequires(f), '::requires ' + f + ' loaded; its classes now complete.')) $('newRequires').value = '';
  });
  $('newMemberKind').addEventListener('change', () => { const c = $('newMemberKind').value === 'CONSTANT'; $('newConstValue').hidden = !c; $('newMemberVis').disabled = c; $('newMemberGuard').disabled = c; });
  $('btnAddMember').addEventListener('click', async () => {
    const n = $('newMemberName').value.trim(); if (!n || !st.cls) return;
    const k = $('newMemberKind').value, v = $('newMemberVis').value, g = $('newMemberGuard').value;
    const fn = k === 'METHOD' ? () => st.w.addMethod(st.cls, n, st.side, v, g, 0)
      : k === 'ATTRIBUTE' ? () => st.w.addAttribute(st.cls, n, st.side, v, g)
        : () => st.w.addConstant(st.cls, n, $('newConstValue').value.trim() || '""');
    if (await edit(fn, 'Added ' + k.toLowerCase() + ' ' + n + '.')) {
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
    if (!st.cur) { $('edTitle').textContent = 'Pick a method'; c.value = ''; c.disabled = true; $('edState').textContent = ''; return; }
    $('edTitle').textContent = st.cls + (st.side === 'CLASS' ? ' class' : '') + ' ~' + st.cur.name;
    c.value = String(await rx(() => st.w.getBody(st.cls, st.cur.name, st.side)).catch(() => ''));
    c.disabled = false; dirty = false; state('', '');
  }
  function state(text, cls) { $('edState').textContent = text; $('edState').className = cls; }
  async function flushCode() {
    if (!dirty || !st.cur) return;
    dirty = false; clearTimeout(timer);
    const cur = st.cur, cls = st.cls, side = st.side, text = $('code').value;
    const err = String(await rx(() => st.w.setBody(cls, cur.name, side, text)).catch((e) => errText(e)));
    if (err) state(err, 'err'); else { state('compiles', 'ok'); await drawMembers(); }
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
    D.body.appendChild(a); a.click(); a.remove(); status('Saved ' + st.fileName + '.');
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
      if (await edit(() => st.w.addRequires(req), '::requires "' + req + '" added; its classes now complete.')) D.getElementById('libPanel').hidden = true;
    },
  }));
  $('btnCopy').addEventListener('click', () => navigator.clipboard && navigator.clipboard.writeText($('sourceText').textContent).then(() => status('Copied.')));

  boot();
})();
