/* graph.js -- the event code as a graph of blocks, beside the code, and the
   trace run's step list.  Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   The code is the truth.  The graph is drawn from an OodGraph (OodGraph.cls,
   in the page's ooRexx/WASM session), which parses the code with Josep Maria
   Blasco's Rexx Parser; every graph edit is an OodGraph operation that
   answers new code, which the page puts back as the event's code.

   OxGraph.attach({ sess, rx, setCode(code), status, actionsMenu(name, x, y, then) })
   OxGraph.show(code)       redraw from the code
   OxGraph.highlight(node)  light a block (a trace step)               */
(function () {
  'use strict';
  const D = document;
  const lines = (t) => String(t || '').split('\n').filter((l) => l !== '');
  let cfg = null, g = null, broken = false, nodes = [], selected = 0, lastCode = null;

  // what each kind of block does, for training: graph.explain.<kind> in the
  // designer's string table (OodUi.cls), in the designer's language
  const T = (key, ...a) => window.OodT(key, ...a);
  const has = (key) => !T(key).startsWith('<');
  const explain = (kind) => has('graph.explain.' + kind) ? T('graph.explain.' + kind) : '';
  const kindName = (kind) => has('graph.kind.' + kind) ? T('graph.kind.' + kind) : kind;
  const PALETTE = [
    ['say', 'say "text"'], ['assign', 'name = value'], ['if', 'if condition then do\n  nop\nend'],
    ['if … else', 'if condition then do\n  nop\nend\nelse do\n  nop\nend'], ['do … to', 'do i = 1 to 10\n  nop\nend'],
    ['do … over', 'do item over collection\n  nop\nend'], ['do while', 'do while condition\n  nop\nend'],
    ['select', 'select\n  when condition then nop\n  otherwise nop\nend'], ['call', 'call routineName'],
    ['self~method', 'self~methodName'], ['return', 'return'], ['leave', 'leave'], ['nop', 'nop'],
  ];

  function attach(c) { cfg = c; buildPalette(); }
  function el(tag, cls, text) { const e = D.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }

  function buildPalette() {
    const box = D.getElementById('gPalette'); box.textContent = '';
    for (const [label, text] of PALETTE) {
      const p = el('span', 'gpal', label); p.draggable = true; p.title = text;
      p.addEventListener('dragstart', (e) => { e.dataTransfer.setData('text/x-ood-new', text); e.dataTransfer.effectAllowed = 'copy'; });
      box.appendChild(p);
    }
  }

  async function show(code) {
    if (!cfg) return;
    lastCode = code;
    const box = D.getElementById('graph'); box.dataset.ready = '0';   // tests wait for '1'
    toolsFor(0);
    if (!code.trim()) { broken = false; D.getElementById('gError').hidden = true; box.classList.remove('stale'); box.textContent = ''; box.appendChild(dropZone(0, 'body', 1, true)); nodes = []; g = null; box.dataset.ready = '1'; return; }
    let gg;
    try { gg = await cfg.rx(() => cfg.sess.eval('use arg c; return .OodGraph~new(c)', code)); }
    catch (e) { return; }
    if (code !== lastCode) return;                   // a newer redraw is on its way
    const err = String(await cfg.rx(() => gg.error()));
    if (err) { g = null; broken = true; D.getElementById('gError').textContent = T('graph.noParse', err); D.getElementById('gError').hidden = false; box.classList.add('stale'); box.dataset.ready = '1'; return; }
    D.getElementById('gError').hidden = true; box.classList.remove('stale');
    g = gg; broken = false;
    nodes = [null];
    for (const l of lines(await cfg.rx(() => g.nodeLines()))) {
      const [id, parent, slot, kind, l1, c1, l2, c2, label] = l.split('\t');
      nodes.push({ id: +id, parent: +parent, slot, kind, l1: +l1, c1: +c1, l2: +l2, c2: +c2, label });
    }
    render();
  }

  function kids(parent, slot) { return nodes.filter((n) => n && n.parent === parent && n.slot === slot); }
  const isBody = (parent, slot) => slot === 'body' && (parent === 0 || ['do', 'loop', 'otherwise'].includes(nodes[parent].kind));

  function render() {
    const box = D.getElementById('graph'); box.textContent = '';
    box.appendChild(renderSlot(0, 'body'));
    if (selected) mark(selected);
    if (flagged.length) flagLines(flagged);
    box.dataset.ready = '1';
  }
  function renderSlot(parent, slot) {
    const s = el('div', 'gslot'); s.dataset.parent = parent; s.dataset.slot = slot;
    const ks = kids(parent, slot); const body = isBody(parent, slot);
    if (body) s.appendChild(dropZone(parent, slot, 1, ks.length === 0));
    ks.forEach((n, i) => { s.appendChild(renderNode(n)); if (body) s.appendChild(dropZone(parent, slot, i + 2, false)); });
    return s;
  }
  function renderNode(n) {
    const b = el('div', 'gb k-' + n.kind); b.dataset.id = n.id; b.draggable = true; b.title = explain(n.kind) || n.kind;
    const head = el('div', 'gh'); head.append(el('span', 'gk', n.kind === 'assign' ? '=' : kindName(n.kind)), el('span', 'gl', n.label));
    b.appendChild(head);
    b.addEventListener('dragstart', (e) => { e.stopPropagation(); e.dataTransfer.setData('text/x-ood-block', String(n.id)); e.dataTransfer.effectAllowed = 'move'; });
    b.addEventListener('click', (e) => { e.stopPropagation(); select(n.id, true); });
    b.addEventListener('dblclick', (e) => { e.stopPropagation(); editLabel(n, head); });
    if (n.kind === 'if') {
      const lanes = el('div', 'glanes');
      const t = el('div', 'glane'); t.append(el('div', 'glt', 'then'), renderSlot(n.id, 'then'));
      lanes.appendChild(t);
      if (kids(n.id, 'else').length) { const e2 = el('div', 'glane'); e2.append(el('div', 'glt', 'else'), renderSlot(n.id, 'else')); lanes.appendChild(e2); }
      b.appendChild(lanes);
    } else if (n.kind === 'select') {
      b.appendChild(renderSlot(n.id, 'when')); b.appendChild(renderSlot(n.id, 'otherwise'));
    } else if (n.kind === 'when') {
      b.appendChild(renderSlot(n.id, 'then'));
    } else if (['do', 'loop', 'otherwise'].includes(n.kind)) {
      b.appendChild(renderSlot(n.id, 'body'));
      if (n.kind !== 'otherwise') b.appendChild(el('div', 'gend', 'end'));
    }
    return b;
  }
  function dropZone(parent, slot, index, empty) {
    const z = el('div', 'gdrop' + (empty ? ' empty' : ''), empty ? T('graph.dropHere') : '');
    z.dataset.parent = parent; z.dataset.slot = slot; z.dataset.index = index;
    z.addEventListener('dragover', (e) => {
      const t = e.dataTransfer.types;
      if (t.includes('text/x-ood-block') || t.includes('text/x-ood-new') || t.includes('text/x-ood-ctl')) { e.preventDefault(); z.classList.add('over'); }
    });
    z.addEventListener('dragleave', () => z.classList.remove('over'));
    z.addEventListener('drop', async (e) => {
      e.preventDefault(); z.classList.remove('over');
      const id = e.dataTransfer.getData('text/x-ood-block'), text = e.dataTransfer.getData('text/x-ood-new'), ctl = e.dataTransfer.getData('text/x-ood-ctl');
      if (id) await edit((gr) => gr.moveCode(+id, parent, slot, index), 'graph.moved');
      else if (text) await edit((gr) => gr.insertCode(parent, slot, index, text), 'graph.inserted');
      else if (ctl) cfg.actionsMenu(ctl, e.clientX, e.clientY, (code) => edit((gr) => gr.insertCode(parent, slot, index, code), 'graph.insertedAction', ctl));
    });
    return z;
  }
  // an edit: OodGraph answers the new code; it becomes the event's code
  async function edit(fn, done, ...doneArgs) {
    if (broken) { cfg.status(T('graph.mendFirst'), true); return; }
    let code;
    if (!g) {                                        // no code yet: an insert is the code
      code = null;
      await fn({ insertCode: (p, sl, i, t) => { code = t + '\n'; } });
      if (code === null) return;
    } else {
      try { code = String(await cfg.rx(() => fn(g))); }
      catch (e) { return; }                          // cfg.rx put the refusal on the status line
    }
    await cfg.setCode(code);
    cfg.status(T(done, ...doneArgs));
  }

  function select(id, toCode) {
    selected = id; mark(id);
    const n = nodes[id]; if (!n) return;
    toolsFor(n);
    if (toCode) {                                   // select its text in the code
      const ta = D.getElementById('code'); const ls = ta.value.split('\n');
      const off = (l, c) => ls.slice(0, l - 1).reduce((a, x) => a + x.length + 1, 0) + c - 1;
      ta.focus(); ta.setSelectionRange(off(n.l1, n.c1), off(n.l2, n.c2));
    }
  }
  // the tools under the palette: always there, so nothing moves under the pointer
  function toolsFor(n) {
    if (!n) selected = 0;
    D.getElementById('gDelete').disabled = !n;
    D.getElementById('gWrap').disabled = !n || !['then', 'else'].includes(n.slot) || n.kind === 'do';
    const ex = D.getElementById('gExplain');
    ex.textContent = n ? explain(n.kind) : T('graph.howTo');
    ex.title = ex.textContent;                       // one line, so the graph never moves under the pointer
  }
  function mark(id) {
    D.querySelectorAll('#graph .gb.sel').forEach((x) => x.classList.remove('sel'));
    const b = D.querySelector('#graph .gb[data-id="' + id + '"]'); if (b) b.classList.add('sel');
  }
  // the code's caret lights the innermost block holding it
  function fromCaret() {
    const ta = D.getElementById('code'); const before = ta.value.slice(0, ta.selectionStart).split('\n');
    const l = before.length, c = before[before.length - 1].length + 1;
    let best = 0;
    for (const n of nodes) {
      if (!n) continue;
      const after = l > n.l1 || (l === n.l1 && c >= n.c1), beforeEnd = l < n.l2 || (l === n.l2 && c <= n.c2);
      if (after && beforeEnd) best = n.id;           // later nodes are inner
    }
    if (best) { selected = best; mark(best); }
  }
  function editLabel(n, head) {
    const input = el('input', 'gedit'); input.value = n.label;
    head.replaceChildren(input); input.focus(); input.select();
    const done = async (save) => {
      if (save && input.value.trim() && input.value !== n.label) await edit((gr) => gr.replaceCode(n.id, input.value), 'graph.changed');
      else render();
    };
    input.addEventListener('keydown', (e) => { if (e.key === 'Enter') done(true); if (e.key === 'Escape') done(false); });
    input.addEventListener('blur', () => done(true));
  }
  function highlight(node) {
    D.querySelectorAll('#graph .gb.run').forEach((x) => x.classList.remove('run'));
    const b = D.querySelector('#graph .gb[data-id="' + node + '"]');
    if (b) { b.classList.add('run'); b.scrollIntoView({ block: 'nearest' }); }
  }

  function wire() {
    D.getElementById('gDelete').addEventListener('click', () => { if (selected) edit((gr) => gr.deleteCode(selected), 'graph.deleted'); });
    D.getElementById('gWrap').addEventListener('click', () => { if (selected) edit((gr) => gr.wrapCode(selected), 'graph.wrapped'); });
    D.getElementById('code').addEventListener('click', fromCaret);
    D.getElementById('code').addEventListener('keyup', fromCaret);
  }
  D.addEventListener('DOMContentLoaded', wire);
  if (D.readyState !== 'loading') wire();
  // the designer's language changed: draw the blocks and tools again
  function relabel() { toolsFor(selected ? nodes[selected] : 0); if (lastCode !== null) show(lastCode); }
  // the blocks of lines a plugin found something on (the innermost block of each)
  let flagged = [];
  function flagLines(ls) {
    flagged = ls;
    D.querySelectorAll('#graph .gb.flag').forEach((x) => x.classList.remove('flag'));
    for (const line of ls) {
      let best = null;
      for (const n of nodes) if (n && n.l1 <= line && line <= n.l2) best = n;      // later nodes are inner
      if (best) { const b = D.querySelector('#graph .gb[data-id="' + best.id + '"]'); if (b) b.classList.add('flag'); }
    }
  }
  window.OxGraph = { attach, show, highlight, relabel, flagLines, nodes: () => nodes };
})();
