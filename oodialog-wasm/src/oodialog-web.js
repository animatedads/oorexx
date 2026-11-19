/* oodialog-web.js -- the page side of ooDialog for ooRexx/WASM.
 * Architecture: Tom Dyer.  Code: Claude (Fable 5.2).
 *
 * Runs in the page's realm (window.__ood).  It stands where user32/comctl32
 * stand for the Windows DLL: it owns the dialogs and controls (DOM elements),
 * answers a subset of the Win32 control messages (msg), and posts WM_COMMAND
 * style events to Rexx through one queued handler.
 */
(function (W) {
  'use strict';
  if (W.__ood) return;
  const D = W.document;
  const ood = W.__ood = { version: '0.1.0', dialogs: new Map(), handler: null, z: 5000, scale: 1.25, log: [] };

  const CSS = `
.ood-back{position:fixed;inset:0;background:rgba(0,0,0,.18)}
.ood-dlg{position:fixed;background:#f0f0f0;color:#000;border:1px solid #6b6b6b;box-shadow:0 6px 24px rgba(0,0,0,.35);
  font-family:"Segoe UI",Tahoma,"DejaVu Sans",Arial,sans-serif;line-height:normal;user-select:none;-webkit-user-select:none}
.ood-dlg *{box-sizing:border-box;font:inherit}
.ood-dlg.ood-child{position:absolute;border:0;box-shadow:none;background:transparent}
.ood-title{display:flex;align-items:center;height:1.9em;background:#fff;border-bottom:1px solid #d0d0d0;cursor:move;padding-left:.5em;touch-action:none}
.ood-dlg.ood-inactive .ood-title{color:#777}
.ood-title span{flex:1;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}
.ood-x{width:2.6em;height:100%;border:0;background:transparent;cursor:pointer;font-size:1em}
.ood-x:hover{background:#e81123;color:#fff}
.ood-client{position:relative;overflow:hidden}
.ood-c{position:absolute;margin:0}
.ood-c[hidden]{display:none}
button.ood-c{padding:0;border:1px solid #adadad;background:#e1e1e1;border-radius:0;cursor:default;white-space:nowrap;overflow:hidden;color:#000}
button.ood-c:hover{border-color:#0078d7;background:#e5f1fb}
button.ood-c.ood-def{border:2px solid #0078d7}
button.ood-c:disabled{color:#838383;border-color:#bfbfbf;background:#ccc}
.ood-static{overflow:hidden;white-space:pre-wrap}
.ood-static.ood-oneline{white-space:pre}
.ood-edit{border:1px solid #7a7a7a;background:#fff;color:#000;padding:0 2px;user-select:text;-webkit-user-select:text;border-radius:0;outline:none;resize:none}
.ood-edit:focus{border-color:#0078d7}
.ood-edit:disabled,.ood-edit[readonly]{background:#f0f0f0}
.ood-check{display:flex;align-items:center;gap:.3em;white-space:nowrap;overflow:hidden}
.ood-check input{margin:0}
fieldset.ood-c{border:1px solid #d5d5d5;padding:0;pointer-events:none;min-width:0}
fieldset.ood-c legend{padding:0 .2em;margin-left:.5em;line-height:1}
select.ood-c{border:1px solid #7a7a7a;background:#fff;color:#000;border-radius:0;padding:0}
.ood-progress{border:1px solid #bcbcbc;background:#e6e6e6;overflow:hidden}
.ood-progress div{height:100%;width:0;background:#06b025}
.ood-frame{pointer-events:none}
.ood-todo{border:1px dashed #a33;color:#a33;font-size:.85em;overflow:hidden;padding:2px}
.ood-u{text-decoration:underline}
.ood-deliver{position:fixed;inset:4vh 4vw;display:flex;flex-direction:column;background:#fff;border:1px solid #555;box-shadow:0 6px 24px rgba(0,0,0,.4);font:13px 'Segoe UI',Tahoma,sans-serif;color:#222}
.ood-deliverbar{display:flex;flex-wrap:wrap;gap:.6em;align-items:center;padding:.5em .7em;background:#1f3f66;color:#fff}
.ood-deliverbar span{flex:1 1 12em;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.ood-deliveract{color:#1f3f66;background:#fff;border-radius:3px;padding:.25em .8em;text-decoration:none}
.ood-deliverview{flex:1;border:0;width:100%;background:#888}
.ood-tb{position:absolute;display:flex;flex-wrap:wrap;align-items:center;gap:2px;box-sizing:border-box;padding:2px 3px;background:#f0f0f0;border-bottom:1px solid #d0d0d0}
.ood-tbbtn{font:12px 'Segoe UI',Tahoma,sans-serif;padding:2px 8px;border:1px solid transparent;border-radius:2px;background:transparent;color:#222}
.ood-tbbtn:hover:not(:disabled){border-color:#7a9ac0;background:#e5f1fb}
.ood-tbbtn:disabled{color:#999}
.ood-tbsep{width:1px;align-self:stretch;margin:2px 3px;background:#bbb}
.ood-stb{position:absolute;display:flex;box-sizing:border-box;background:#f0f0f0;border-top:1px solid #d0d0d0;font:12px 'Segoe UI',Tahoma,sans-serif;color:#222}
.ood-stbpart{box-sizing:border-box;padding:3px 6px;border-right:1px solid #c8c8c8;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ood-stbpart:last-child{border-right:0}
.ood-pushed{border-style:inset;background:#cce4f7}
.ood-tip{position:fixed;z-index:100000;background:#fff;color:#333;border:1px solid #767676;border-radius:3px;padding:3px 7px;font:12px 'Segoe UI',Tahoma,sans-serif;box-shadow:2px 2px 4px rgba(0,0,0,.25);pointer-events:none}
.ood-tip b{display:block;margin-bottom:2px}
.ood-mc{background:#fff;border:1px solid #7a7a7a;box-sizing:border-box;padding:4px 6px;cursor:default;outline:none;user-select:none;overflow:hidden}
.ood-mc-head{display:flex;align-items:center;justify-content:space-between;padding:2px 0 4px}
.ood-mc-head button{border:0;background:none;font:inherit;font-size:15px;line-height:1;padding:0 6px;cursor:pointer}
.ood-mc-head button:hover{color:#0078d7}
.ood-mc-grid{display:grid;grid-template-columns:repeat(7,minmax(22px,1fr));text-align:center}
.ood-mc-wd{color:#555;border-bottom:1px solid #d0d0d0;padding:1px 0;margin-bottom:2px}
.ood-mc-day{padding:1px 2px;border:1px solid transparent}
.ood-mc-day:hover{background:#e5f1fb}
.ood-mc-other{color:#9a9a9a}
.ood-mc-off{color:#c8c8c8;text-decoration:line-through}
.ood-mc-off:hover{background:none}
.ood-mc-bold{font-weight:bold}
.ood-mc-today{border-color:#0078d7}
.ood-mc-sel{background:#0078d7;color:#fff}
.ood-mc-sel:hover{background:#0078d7}
.ood-mc-foot{padding-top:4px;white-space:nowrap}
.ood-mc-foot:hover{color:#0078d7}
.ood-lv,.ood-tv{border:1px solid #7a7a7a;background:#fff;overflow:auto;outline:none;cursor:default}
.ood-lv table{border-collapse:collapse;table-layout:fixed}
.ood-lv th{position:sticky;top:0;background:#fff;border-right:1px solid #e5e5e5;border-bottom:1px solid #e5e5e5;font-weight:normal;padding:2px 6px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ood-lv th:hover{background:#d9ebf9}
.ood-lv td{padding:1px 6px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ood-lv table.ood-grid td{border:1px solid #f0f0f0}
.ood-lv tr.ood-sel td,.ood-tv .ood-tvrow.ood-sel{background:#cce8ff}
.ood-lv:focus tr.ood-sel td,.ood-tv:focus .ood-tvrow.ood-sel{background:#0078d7;color:#fff}
.ood-lvchk{margin:0 .4em 0 0;vertical-align:middle}
.ood-tvrow{white-space:nowrap;padding:1px 4px}
.ood-tvtw{display:inline-block;width:1.1em;text-align:center;color:#555}
.ood-menubar{display:flex;background:#fff;border-bottom:1px solid #e5e5e5;padding:0 2px}
.ood-menubar button{border:0;background:transparent;padding:.15em .6em;cursor:default;color:#000}
.ood-menubar button:hover,.ood-menubar button.ood-mopen{background:#cce8ff}
.ood-menubar button:disabled{color:#999}
.ood-menu{position:fixed;background:#f2f2f2;border:1px solid #ccc;box-shadow:2px 2px 6px rgba(0,0,0,.3);padding:2px;font:13px "Segoe UI",Tahoma,"DejaVu Sans",Arial,sans-serif;color:#000;min-width:8em;user-select:none}
.ood-menu hr{border:0;border-top:1px solid #d7d7d7;margin:3px 0}
.ood-mi{display:flex;padding:.2em .4em;white-space:nowrap;cursor:default}
.ood-mi:hover{background:#91c9f7}
.ood-mi.ood-off{color:#999}
.ood-mi.ood-off:hover{background:transparent}
.ood-mark{width:1.3em;text-align:center}
.ood-mtext{flex:1}
.ood-macc{margin-left:2em;color:#555}
.ood-image{overflow:hidden}
.ood-image.ood-imgcenter{display:flex;align-items:center;justify-content:center}
.ood-image img{display:block;image-rendering:auto}
button.ood-c.ood-bmp:hover{background-color:transparent}
.ood-track{margin:0;padding:0}
.ood-ud{display:flex;flex-direction:column}
.ood-ud button{flex:1;min-height:0;padding:0;border:1px solid #adadad;background:#e1e1e1;font-size:.6em;line-height:1;color:#000;cursor:default}
.ood-ud button:hover{background:#e5f1fb;border-color:#0078d7}
.ood-tab{pointer-events:none}
.ood-tabstrip{display:flex;pointer-events:auto;height:1.75em;align-items:flex-end;padding-left:2px}
.ood-tabbtn{flex:none;white-space:nowrap;border:1px solid #d9d9d9;border-bottom:0;background:#f0f0f0;padding:0 .7em;height:1.5em;margin-right:-1px;cursor:default;color:#000}
.ood-tabbtn.ood-cur{background:#fff;height:1.75em;position:relative;top:1px}
.ood-tabpage{position:absolute;left:0;right:0;top:1.75em;bottom:0;border:1px solid #d9d9d9;background:#fff}
`;

  function boot() {
    if (ood.booted) return;
    const st = D.createElement('style');
    st.textContent = CSS;
    D.head.appendChild(st);
    ood.booted = true;
  }

  function fire(key, kind, id, code, extra) {
    if (ood.handler) ood.handler(String(key), kind, String(id), String(code), extra == null ? '' : String(extra));
  }
  const has = (opts, word) => opts.indexOf(word) >= 0;       // as StrStrI in the DLL
  function label(el, text) {                                  // & marks the accelerator
    el.textContent = '';
    const p = text.search(/&[^&]/);
    if (p < 0) { el.textContent = text.replace(/&&/g, '&'); return; }
    el.append(text.slice(0, p).replace(/&&/g, '&'));
    const u = D.createElement('span'); u.className = 'ood-u'; u.textContent = text[p + 1];
    el.append(u, text.slice(p + 2).replace(/&&/g, '&'));
  }
  const plain = (text) => text.replace(/&(.)/g, '$1');

  /* ---- dialogs ---------------------------------------------------------- */
  ood.create = function (spec, ctrls) {
    boot();
    const key = Number(spec.key);
    const opts = String(spec.opts || '').toUpperCase();
    const dlg = { key, opts, ctrls: new Map(), all: [], subs: new Set(), group: 0, defId: 1, modal: !spec.modeless, prevFocus: D.activeElement };
    const px = Math.round(Number(spec.fontSize || 8) * 96 / 72 * ood.scale * 100) / 100;
    const el = dlg.el = D.createElement('div');
    el.className = 'ood-dlg'; el.tabIndex = -1; el.style.outline = 'none';
    el.style.fontSize = px + 'px';
    if (spec.fontName && !/^MS Shell Dlg|^MS Sans Serif|^System$/i.test(spec.fontName))
      el.style.fontFamily = '"' + spec.fontName + '",' + '"Segoe UI",Tahoma,sans-serif';
    el.style.visibility = 'hidden';
    const host = spec.parent != null && spec.parent !== '' ? ood.dialogs.get(Number(spec.parent)) : null;
    dlg.child = !!host;
    if (host) { dlg.modal = false; el.classList.add('ood-child'); }
    const title = dlg.titleEl = D.createElement('div'); title.className = 'ood-title';
    const cap = dlg.capEl = D.createElement('span'); cap.textContent = spec.title || '';
    title.appendChild(cap);
    if (!has(opts, 'NOMENU')) {
      const x = D.createElement('button'); x.className = 'ood-x'; x.textContent = '✕'; x.tabIndex = -1;
      x.addEventListener('click', () => fire(key, 'CMD', 2, 0));
      title.appendChild(x);
    }
    const client = dlg.client = D.createElement('div'); client.className = 'ood-client';
    if (host) el.append(client); else el.append(title, client);
    if (dlg.modal) { dlg.back = D.createElement('div'); dlg.back.className = 'ood-back'; dlg.back.style.zIndex = ++ood.z; D.body.appendChild(dlg.back); dlg.back.hidden = true; }
    if (host) host.client.appendChild(el); else { el.style.zIndex = ++ood.z; D.body.appendChild(el); }

    // dialog base units, as Windows computes them from the dialog font
    const s = D.createElement('span');
    s.style.cssText = 'position:absolute;visibility:hidden;white-space:nowrap';
    s.textContent = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    client.appendChild(s);
    const r = s.getBoundingClientRect();
    client.removeChild(s);
    dlg.fx = Math.floor((r.width / 26 + 1) / 2) / 4;
    dlg.fy = Math.round(r.height) / 8;
    dlg.cx = Number(spec.cx); dlg.cy = Number(spec.cy);
    client.style.width = Math.round(dlg.cx * dlg.fx) + 'px';
    client.style.height = Math.round(dlg.cy * dlg.fy) + 'px';
    const rect = el.getBoundingClientRect();
    let left = Math.round(Number(spec.x) * dlg.fx), top = Math.round(Number(spec.y) * dlg.fy);
    if (has(opts, 'CENTER')) { left = Math.max(0, (W.innerWidth - rect.width) / 2); top = Math.max(0, (W.innerHeight - rect.height) / 2); }
    if (host) { left = Number(spec.px || 0); top = Number(spec.py || 0); }
    el.style.left = Math.round(left) + 'px'; el.style.top = Math.round(top) + 'px';
    ood.dialogs.set(key, dlg);
    for (const c of ctrls || []) addControl(dlg, c);
    if (!host) wireDialog(dlg);
    if (!host && has(opts, 'THICKFRAME')) {                  // a sizing border: the client area can be dragged larger or smaller
      client.style.resize = 'both'; client.style.minWidth = '60px'; client.style.minHeight = '30px';
    }
    if (!host && W.ResizeObserver) {
      let first = true, timer = null;
      new W.ResizeObserver(() => {
        if (first) { first = false; return; }
        if (!ood.dialogs.has(key)) return;
        if (dlg.ra) raLayout(dlg);                             // ResizingAdmin: the controls follow the dialog
        if (dlg.subs.has('0.RESIZE')) fire(key, 'WM', 0, 'RESIZE', client.clientWidth + SEP + client.clientHeight);
        clearTimeout(timer);
        timer = setTimeout(() => {
          if (!ood.dialogs.has(key)) return;
          if (dlg.subs.has('0.SIZEMOVEENDED')) fire(key, 'WM', 0, 'SIZEMOVEENDED', '');
          if (dlg.ra && dlg.ra.ended) fire(key, 'WM', 0, 'RASIZEENDED', '');
        }, 250);
      }).observe(client);
    }
    return dlg.fx + ' ' + dlg.fy + ' ' + Math.round(rect.width) + ' ' + Math.round(rect.height);
  };

  /* ---- ResizingAdmin (oodResizableDialog.cpp) ----
     Each edge of each control is pinned to an edge of the dialog or of another control:
       [pinType, pinToEdge, pinToID]   pinType S stationary, P proportional, ML my left, MT my top
     ra = { def: [left, top, right, bottom], ctrls: [[id, left, top, right, bottom], ...], min, max, ended }
     The controls named by the program come first, in its order; then the others as created. */
  function raRect(el) { return { left: el.offsetLeft, top: el.offsetTop, right: el.offsetLeft + el.offsetWidth, bottom: el.offsetTop + el.offsetHeight }; }
  function raInit(dlg, spec) {
    const ra = JSON.parse(spec), cl = dlg.client;
    ra.orig = { left: 0, top: 0, right: cl.clientWidth, bottom: cl.clientHeight };
    ra.items = [];
    const seen = new Set();
    const add = (id, edges) => { const c = dlg.ctrls.get(id); if (!c || seen.has(id)) return; seen.add(id);
      ra.items.push({ id, c, edges, orig: raRect(c.el), cur: raRect(c.el) }); };
    for (const row of ra.ctrls) add(row[0], row.slice(1));
    for (const [id, c] of dlg.ctrls) if (!c.parentCtl) add(id, ra.def);
    dlg.ra = ra;
    cl.style.resize = 'both';
    raLimits(dlg, ra.min, ra.max);
    return '1';
  }
  function raLimits(dlg, min, max) {                           // "initial": the size the dialog has now; null: none
    const ra = dlg.ra, cl = dlg.client; ra.min = min; ra.max = max;
    const m = min === 'initial' ? [ra.orig.right, ra.orig.bottom] : min;
    cl.style.minWidth = m ? m[0] + 'px' : '60px'; cl.style.minHeight = m ? m[1] + 'px' : '30px';
    cl.style.maxWidth = max ? max[0] + 'px' : ''; cl.style.maxHeight = max ? max[1] + 'px' : '';
  }
  function raLayout(dlg) {
    const ra = dlg.ra, cl = dlg.client;
    const cur = { left: 0, top: 0, right: cl.clientWidth, bottom: cl.clientHeight };
    const rects = (id) => { if (id) { const it = ra.items.find((x) => x.id === id); if (it) return [it.orig, it.cur]; } return [ra.orig, cur]; };
    const coord = (edge, r) => ({ LEFT: r.left, TOP: r.top, RIGHT: r.right, BOTTOM: r.bottom, XCENTER: (r.left + r.right) / 2, YCENTER: (r.top + r.bottom) / 2 }[edge]);
    const span = (side, r) => (side === 'left' || side === 'right' ? r.right - r.left : r.bottom - r.top);
    const edge = (it, side, e) => {
      const [pi, pc] = rects(e[2]);
      if (e[0] === 'S') return it.orig[side] - coord(e[1], pi) + coord(e[1], pc);
      if (e[0] === 'ML') return it.cur.left + (it.orig.right - it.orig.left);
      if (e[0] === 'MT') return it.cur.top + (it.orig.bottom - it.orig.top);
      const was = span(side, pi) || 1;                         // proportional: the same edge of the window pinned to
      return pc[side] + (it.orig[side] - pi[side]) * (span(side, pc) / was);
    };
    for (const it of ra.items) {
      it.cur = { left: 0, top: 0, right: 0, bottom: 0 };
      it.cur.left = Math.trunc(edge(it, 'left', it.edges[0])); it.cur.top = Math.trunc(edge(it, 'top', it.edges[1]));
      it.cur.right = Math.trunc(edge(it, 'right', it.edges[2])); it.cur.bottom = Math.trunc(edge(it, 'bottom', it.edges[3]));
      const s = it.c.el.style;
      s.left = it.cur.left + 'px'; s.top = it.cur.top + 'px';
      s.width = Math.max(0, it.cur.right - it.cur.left) + 'px'; s.height = Math.max(0, it.cur.bottom - it.cur.top) + 'px';
    }
    raPages(dlg);
  }
  /* pagedTab: op(key, tabId, 'ra.page', childKey) names an embedded dialog as a page of that tab
     control.  After each layout every page takes the tab's display area (handleChildDialogs of
     oodResizableDialog.cpp); a page that has its own ResizingAdmin definition is laid out too. */
  function raPages(dlg) {
    for (const c of dlg.ctrls.values()) {
      if (!c.raPages || !c.page) continue;
      const o = dlg.client.getBoundingClientRect(), r = c.page.getBoundingClientRect();
      const l = Math.round(r.left - o.left + 2), t = Math.round(r.top - o.top + 2), w = Math.round(r.width - 4), h = Math.round(r.height - 4);
      for (const k of c.raPages) {
        const page = ood.dialogs.get(k); if (!page) continue;
        page.el.style.left = l + 'px'; page.el.style.top = t + 'px';
        page.client.style.width = Math.max(0, w) + 'px'; page.client.style.height = Math.max(0, h) + 'px';
        if (page.ra) raLayout(page);
      }
    }
  }

  function wireDialog(dlg) {
    const el = dlg.el;
    let drag = null;
    dlg.titleEl.addEventListener('pointerdown', (e) => {
      if (e.target.closest('.ood-x')) return;
      drag = { x: e.clientX - el.offsetLeft, y: e.clientY - el.offsetTop };
      dlg.titleEl.setPointerCapture(e.pointerId);
    });
    dlg.titleEl.addEventListener('pointermove', (e) => {
      if (!drag) return;
      el.style.left = (e.clientX - drag.x) + 'px'; el.style.top = Math.max(0, e.clientY - drag.y) + 'px';
      if (dlg.subs.has('0.MOVE')) fire(dlg.key, 'WM', 0, 'MOVE', el.offsetLeft + SEP + el.offsetTop);
    });
    dlg.titleEl.addEventListener('pointerup', () => { if (drag && dlg.subs.has('0.SIZEMOVEENDED')) fire(dlg.key, 'WM', 0, 'SIZEMOVEENDED', ''); drag = null; });
    el.addEventListener('pointerdown', () => { if (el.style.zIndex != ood.z && !dlg.modal) el.style.zIndex = ++ood.z; }, true);
    el.addEventListener('contextmenu', (e) => {
      if (!dlg.subs.has('0.CTX')) return;
      e.preventDefault();
      const c = dlg.all.find((x) => x.el.contains(e.target));
      fire(dlg.key, 'CTX', c && c.id > 0 ? c.id : 0, Math.round(e.clientX), Math.round(e.clientY));
    });
    el.addEventListener('keydown', (e) => {
      if (dlg.subs.has('0.KEY')) { const fc = dlg.all.find((x) => x.id > 0 && x.el.contains(D.activeElement));   // extra: the control that has the focus
        fire(dlg.key, 'KEY', e.keyCode, (e.shiftKey ? 'S' : '') + (e.ctrlKey ? 'C' : '') + (e.altKey ? 'A' : ''), fc ? fc.id : 0); }
    }, true);
    el.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') { e.preventDefault(); if (!dlg.noClose) fire(dlg.key, 'CMD', 2, 0); return; }
      if (e.key === 'F1') { e.preventDefault(); fire(dlg.key, 'CMD', 9, 0); return; }
      if (e.key === 'Enter') {
        const t = e.target;
        if (t.tagName === 'TEXTAREA' && !t.dataset.noreturn) return;
        if (t.tagName === 'BUTTON') return;                 // the button's own click
        e.preventDefault();
        const def = dlg.ctrls.get(dlg.defId);
        if (def && def.kind === 'BUTTON') { if (!def.main.disabled) def.main.click(); }
        else fire(dlg.key, 'CMD', 1, 0);
      }
    });
  }

  function fit(dlg) {                                         // a dialog larger than the window is scaled down to it
    const el = dlg.el, w = el.offsetWidth, h = el.offsetHeight;
    const k = Math.min(1, (W.innerWidth - 8) / w, (W.innerHeight - 8) / h);
    if (k >= 1) return;
    el.style.transformOrigin = '0 0'; el.style.transform = 'scale(' + k + ')';
    el.style.left = Math.max(0, Math.round((W.innerWidth - w * k) / 2)) + 'px';
    el.style.top = Math.max(0, Math.round((W.innerHeight - h * k) / 2)) + 'px';
  }
  ood.show = function (key, how) {
    const dlg = ood.dialogs.get(Number(key)); if (!dlg) return '0';
    how = String(how || '').toUpperCase();
    const hide = has(how, 'HIDE');
    if (!hide && !dlg.shown && !dlg.child) fit(dlg);
    dlg.el.style.visibility = hide ? 'hidden' : 'visible';
    if (dlg.back) dlg.back.hidden = hide;
    if (!hide && !dlg.shown) {
      dlg.shown = true;
      const first = dlg.all.find((c) => c.main && c.main.tabIndex >= 0 && !c.main.disabled && c.focusable);
      if (first) first.main.focus(); else dlg.el.focus();
    }
    return '1';
  };

  ood.destroy = function (key) {
    const dlg = ood.dialogs.get(Number(key)); if (!dlg) return '0';
    if (tipBox.dlg === dlg) tipHide(true);
    dlg.el.remove(); if (dlg.back) dlg.back.remove();
    ood.dialogs.delete(Number(key));
    if (dlg.prevFocus && dlg.prevFocus.isConnected) dlg.prevFocus.focus();   // as Windows activates the owner again
    return '1';
  };

  ood.sub = function (key, id, code) {
    const dlg = ood.dialogs.get(Number(key)); if (dlg) dlg.subs.add(id + '.' + code);
    return '1';
  };
  function cmd(dlg, c, code, always) {
    if (always || dlg.subs.has(c.id + '.' + code) || dlg.subs.has(c.id + '.*') || dlg.subs.has('*.' + code))
      fire(dlg.key, 'CMD', c.id, code);
  }

  /* ---- controls --------------------------------------------------------- */
  function place(dlg, el, c) {
    el.classList.add('ood-c');
    el.style.left = Math.round(c.x * dlg.fx) + 'px'; el.style.top = Math.round(c.y * dlg.fy) + 'px';
    el.style.width = Math.round(c.cx * dlg.fx) + 'px'; el.style.height = Math.round(c.cy * dlg.fy) + 'px';
  }

  function addControl(dlg, spec) {
    const o = String(spec.opts || '').toUpperCase();
    const c = { id: Number(spec.id), kind: spec.kind, opts: o, x: +spec.x, y: +spec.y, cx: +spec.cx, cy: +spec.cy, focusable: true };
    const text = spec.text == null ? '' : String(spec.text);
    if (has(o, 'GROUP')) dlg.group++;
    let el, main;
    switch (spec.kind) {
      case 'BUTTON':
        el = main = D.createElement('button'); main.type = 'button'; label(main, text);
        if (has(o, 'DEFAULT')) { main.classList.add('ood-def'); dlg.defId = c.id; }
        main.addEventListener('click', () => cmd(dlg, c, 0, true));
        main.addEventListener('dblclick', () => cmd(dlg, c, 5));
        main.addEventListener('focus', () => { paintButton(c); cmd(dlg, c, 6); });
        main.addEventListener('blur', () => { c.down = false; paintButton(c); cmd(dlg, c, 7); });
        main.addEventListener('pointerdown', () => { c.down = true; paintButton(c); });
        main.addEventListener('pointerup', () => { c.down = false; paintButton(c); });
        main.addEventListener('pointerleave', () => { if (c.down) { c.down = false; paintButton(c); } });
        break;
      case 'CHECK': case 'RADIO': {
        el = D.createElement('label'); el.className = 'ood-check';
        main = D.createElement('input'); main.type = spec.kind === 'RADIO' ? 'radio' : 'checkbox';
        if (spec.kind === 'RADIO') main.name = 'oodg' + dlg.key + '_' + dlg.group;
        c.tri = has(o, '3STATE');
        const sp = D.createElement('span'); label(sp, text); c.textEl = sp;
        if (has(o, 'LTEXT')) el.append(sp, main); else el.append(main, sp);
        main.addEventListener('click', () => {
          if (c.tri) {                                      // unchecked -> checked -> indeterminate
            c.state = ((c.state || 0) + 1) % 3;
            main.checked = c.state === 1; main.indeterminate = c.state === 2;
          }
          cmd(dlg, c, 0, true);
        });
        break; }
      case 'GROUP': {
        el = main = D.createElement('fieldset'); const lg = D.createElement('legend'); label(lg, text);
        if (text !== '') el.appendChild(lg); c.textEl = lg; c.focusable = false;
        break; }
      case 'STATIC':
        el = main = D.createElement('div'); el.className = 'ood-static'; label(el, text); c.focusable = false;
        if (c.cy <= 12) el.classList.add('ood-oneline');
        if (has(o, 'CENTER')) el.style.textAlign = 'center'; else if (has(o, 'RIGHT')) el.style.textAlign = 'right';
        if (has(o, 'BORDER')) el.style.border = '1px solid #7a7a7a';
        if (has(o, 'NOTIFY')) { el.addEventListener('click', () => cmd(dlg, c, 0, true)); el.addEventListener('dblclick', () => cmd(dlg, c, 1, true)); }
        break;
      case 'IMAGE':                                         // createStaticImage: a bitmap or icon
        el = main = D.createElement('div'); el.className = 'ood-image'; c.focusable = false;
        c.img = D.createElement('img'); c.img.alt = ''; c.img.hidden = true; el.appendChild(c.img);
        if (has(o, 'CENTERIMAGE')) el.classList.add('ood-imgcenter');
        if (has(o, 'SUNKEN') || has(o, 'BORDER')) el.style.border = '1px solid #a0a0a0';
        break;
      case 'FRAME': {                                       // createBlackRect, createGrayFrame ...
        el = main = D.createElement('div'); el.className = 'ood-frame'; c.focusable = false;
        const col = has(o, 'WHITE') ? '#fff' : has(o, 'GRAY') ? '#a0a0a0' : has(o, 'ETCHED') ? '#d5d5d5' : '#000';
        if (has(o, 'RECT')) el.style.background = col; else el.style.border = '1px solid ' + col;
        break; }
      case 'EDIT':
        if (has(o, 'MULTILINE')) {
          el = main = D.createElement('textarea'); main.wrap = has(o, 'HSCROLL') || has(o, 'AUTOSCROLLH') ? 'off' : 'soft';
          if (has(o, 'NOWANTRETURN')) main.dataset.noreturn = '1';
        } else {
          el = main = D.createElement('input'); main.type = has(o, 'PASSWORD') ? 'password' : 'text';
          if (has(o, 'NUMBER')) main.inputMode = 'numeric';
        }
        el.className = 'ood-edit'; main.value = text; main.spellcheck = false; main.autocomplete = 'off';
        if (has(o, 'READONLY')) main.readOnly = true;
        if (has(o, 'CENTER')) main.style.textAlign = 'center'; else if (has(o, 'RIGHT')) main.style.textAlign = 'right';
        if (has(o, 'NOBORDER')) main.style.border = '0';
        main.addEventListener('input', () => {
          if (has(o, 'NUMBER')) main.value = main.value.replace(/\D/g, '');
          if (has(o, 'UPPER')) main.value = main.value.toUpperCase();
          if (has(o, 'LOWER')) main.value = main.value.toLowerCase();
          c.modified = true; cmd(dlg, c, 0x400); cmd(dlg, c, 0x300);
        });
        main.addEventListener('focus', () => cmd(dlg, c, 0x100));
        main.addEventListener('blur', () => cmd(dlg, c, 0x200));
        break;
      case 'LIST':
        el = main = D.createElement('select'); main.size = 2; main.multiple = has(o, 'MULTI');
        c.sort = has(o, 'SORT');
        main.addEventListener('change', () => cmd(dlg, c, 1));
        main.addEventListener('dblclick', () => cmd(dlg, c, 2));
        main.addEventListener('focus', () => cmd(dlg, c, 4));
        main.addEventListener('blur', () => cmd(dlg, c, 5));
        break;
      case 'COMBO':                                         // LIST -> drop-down list; else editable
        c.sort = has(o, 'SORT');
        if (has(o, 'LIST') && !has(o, 'SIMPLE')) {
          el = main = D.createElement('select'); c.droplist = true;
          main.addEventListener('change', () => { cmd(dlg, c, 9); cmd(dlg, c, 1); });
        } else {
          el = D.createElement('div'); main = D.createElement('input'); main.className = 'ood-edit';
          main.style.cssText = 'width:100%;height:100%'; main.autocomplete = 'off';
          const dl = D.createElement('datalist'); dl.id = 'oodl' + dlg.key + '_' + c.id; main.setAttribute('list', dl.id);
          el.append(main, dl); c.items = dl;
          main.addEventListener('input', () => { cmd(dlg, c, 6); cmd(dlg, c, 5); });
          main.addEventListener('change', () => { cmd(dlg, c, 9); cmd(dlg, c, 1); });
        }
        main.addEventListener('focus', () => cmd(dlg, c, 3));
        main.addEventListener('blur', () => cmd(dlg, c, 4));
        break;
      case 'PROGRESS':
        el = main = D.createElement('div'); el.className = 'ood-progress'; c.bar = D.createElement('div'); el.appendChild(c.bar);
        c.min = 0; c.max = 100; c.pos = 0; c.step = 10; c.focusable = false; c.vertical = has(o, 'VERTICAL');
        if (c.vertical) { el.style.position = 'absolute'; c.bar.style.cssText = 'position:absolute;left:0;bottom:0;width:100%;height:0'; }
        break;
      case 'LISTVIEW':
        el = main = D.createElement('div'); el.className = 'ood-lv'; el.tabIndex = 0;
        c.cols = []; c.rows = []; c.uid = 0; c.focusIdx = -1; c.ex = new Set(); c.single = has(o, 'SINGLESEL');
        c.view = has(o, 'REPORT') ? 'REPORT' : has(o, 'SMALLICON') ? 'SMALLICON' : has(o, 'LIST') ? 'LIST' : 'ICON';
        c.table = D.createElement('table'); c.thead = D.createElement('thead'); c.tbody = D.createElement('tbody');
        c.table.append(c.thead, c.tbody); el.appendChild(c.table); c.el = el; lvWire(dlg, c);
        break;
      case 'TREEVIEW':
        el = main = D.createElement('div'); el.className = 'ood-tv'; el.tabIndex = 0;
        c.nodes = new Map(); c.roots = []; c.nextH = 0; c.selH = 0; c.body = D.createElement('div'); el.appendChild(c.body); c.el = el; tvWire(dlg, c);
        break;
      case 'TAB':
        el = main = D.createElement('div'); el.className = 'ood-tab'; c.tabs = []; c.cur = -1;
        c.strip = D.createElement('div'); c.strip.className = 'ood-tabstrip'; c.page = D.createElement('div'); c.page.className = 'ood-tabpage';
        el.append(c.strip, c.page); tabWire(dlg, c);
        break;
      case 'TRACKBAR':
        el = main = D.createElement('input'); main.type = 'range'; main.min = 0; main.max = 100; main.value = 0; main.className = 'ood-track';
        c.page = 20; c.line = 1;
        if (has(o, 'VERTICAL')) { main.style.writingMode = 'vertical-lr'; main.style.direction = 'rtl'; }
        main.addEventListener('input', () => note(dlg, c, 'TRACK', main.value + SEP + 'DRAG'));
        main.addEventListener('change', () => note(dlg, c, 'TRACK', main.value + SEP + 'ENDTRACK'));
        break;
      case 'MONTHCALENDAR':
        el = main = D.createElement('div'); el.className = 'ood-mc'; el.tabIndex = 0; c.main = main; c.el = el;
        c.mc = { sel: mcDay(new Date()), today: mcDay(new Date()), min: null, max: null, bold: new Map(), firstDay: 0,
                 noToday: has(o, 'NOTODAY'), weekNumbers: has(o, 'WEEKNUMBERS'), dayState: has(o, 'DAYSTATE') };
        c.mc.view = new Date(c.mc.sel.getFullYear(), c.mc.sel.getMonth(), 1);
        mcRender(dlg, c);
        break;
      case 'DATETIMEPICKER':
        el = main = D.createElement('input'); main.className = 'ood-edit';
        main.type = has(o, 'TIME') ? 'time' : 'date'; if (main.type === 'time') main.step = 1;
        main.addEventListener('change', () => note(dlg, c, 'DATETIMECHANGE', dtpGet(c)));
        c.main = main; dtpSet(c, new Date());
        break;
      case 'UPDOWN': {
        el = main = D.createElement('div'); el.className = 'ood-ud'; c.focusable = false;
        c.min = 0; c.max = 100; c.pos = 0; c.buddy = 0;
        const up = D.createElement('button'), dn = D.createElement('button');
        up.type = dn.type = 'button'; up.tabIndex = dn.tabIndex = -1; up.textContent = '\u25B4'; dn.textContent = '\u25BE';
        el.append(up, dn);
        if (has(o, 'AUTOBUDDY') && dlg.all.length) c.buddy = dlg.all[dlg.all.length - 1].id;
        c.setInt = has(o, 'BUDDYINT'); c.wrap = has(o, 'WRAP');
        const step = (d) => {
          let np = c.pos + d;
          if (np > c.max) np = c.wrap ? c.min : c.max; if (np < c.min) np = c.wrap ? c.max : c.min;
          note(dlg, c, 'DELTAPOS', c.pos + SEP + (np - c.pos));
          udSet(dlg, c, np);
        };
        up.addEventListener('click', () => step(1)); dn.addEventListener('click', () => step(-1));
        break; }
      case 'TOOLBAR':                                       // a row of buttons along the top of the dialog
        el = main = D.createElement('div'); el.className = 'ood-tb'; el.setAttribute('role', 'toolbar'); c.focusable = false; c.docked = 'top';
        c.btns = [];
        break;
      case 'STATUSBAR':                                     // a bar along the bottom of the dialog, in parts
        el = main = D.createElement('div'); el.className = 'ood-stb'; c.focusable = false; c.docked = true;
        c.parts = [{ edge: -1, text: '', tip: '' }]; c.simple = false; c.simpleText = '';
        stbRender(c);
        break;
      default:                                              // a control kind not ported yet
        el = main = D.createElement('div'); el.className = 'ood-todo'; el.textContent = spec.kind + ' ' + c.id; c.focusable = false;
    }
    c.el = el; c.main = main;
    place(dlg, el, c);
    if (c.docked === 'top') { el.style.left = '0'; el.style.right = '0'; el.style.top = '0'; el.style.width = ''; el.style.height = ''; el.style.minHeight = '24px'; }   // Windows puts a tool bar at the top
    else if (c.docked) { el.style.left = '0'; el.style.right = '0'; el.style.bottom = '0'; el.style.top = ''; el.style.width = ''; if (!c.h) el.style.height = '22px'; }   // Windows puts a status bar at the bottom, whatever rectangle is given
    if (c.kind === 'COMBO' && c.droplist) el.style.height = Math.round(12 * dlg.fy) + 'px';   // cy is the dropped height
    if (c.kind === 'COMBO' && !c.droplist) el.style.height = Math.round(12 * dlg.fy) + 'px';
    if (c.kind === 'UPDOWN' && c.buddy && (has(o, 'RIGHT') || has(o, 'LEFT'))) {   // sits inside its buddy's edge
      const b = dlg.ctrls.get(c.buddy);
      if (b) {
        const w = Math.round(9 * dlg.fx), bl = parseInt(b.el.style.left), bw = parseInt(b.el.style.width);
        el.style.left = (has(o, 'RIGHT') ? bl + bw - w - 1 : bl + 1) + 'px'; el.style.top = (parseInt(b.el.style.top) + 1) + 'px';
        el.style.width = w + 'px'; el.style.height = (parseInt(b.el.style.height) - 2) + 'px';
      }
    }
    if (has(o, 'HIDDEN')) el.hidden = true;
    if (has(o, 'DISABLED')) main.disabled = true;
    if (has(o, 'NOTAB')) main.tabIndex = -1;
    dlg.client.appendChild(el);
    dlg.all.push(c);
    if (c.id > 0 && !dlg.ctrls.has(c.id)) dlg.ctrls.set(c.id, c);
    return c;
  }
  ood.addControl = function (key, spec) {
    const dlg = ood.dialogs.get(Number(key)); if (!dlg) return '0';
    addControl(dlg, spec); return '1';
  };

  /* ---- list-view, tree-view, tab ----------------------------------------- */
  const SEP = '\x1f';
  function note(dlg, c, ev, extra) {                           // a WM_NOTIFY to Rexx, if connected
    if (dlg.subs.has(c.id + '.' + ev)) fire(dlg.key, 'NOTIFY', c.id, ev, extra);
  }
  /* ---- Custom draw ----
     op(key, id, 'cd.on') : the program wants to colour the rows of this list-view or tree-view.
     After each time the control is drawn, and after it is scrolled, the page sends
     ('CD', id, 'ROWS', what is in view): for a list-view "first last" (row indexes), for a
     tree-view the items in view as "item:level item:level ...".  The program answers with
     op(key, id, 'cd.paint', JSON): for a list-view rows of [uid, [[column or -1 for the whole
     row, text colour, background, font], ...]]; for a tree-view rows of [item, text colour,
     background, font].  '' leaves a value as it is drawn.  A row keeps its paint until the
     next answer for it.  The page sends no second question for a control before the first is
     answered: the program answers every question, with '[]' if it has nothing to say. */
  function cdApply(el, fg, bg, font) { el.style.color = fg || ''; el.style.background = bg || ''; el.style.font = font || ''; }
  function cdPaintLv(c) {
    c.rows.forEach((row, i) => {
      const tr = c.tbody.children[i]; if (!tr || !row.cd) return;
      for (const [col, fg, bg, font] of row.cd) {
        if (col < 0) [...tr.children].forEach((td) => cdApply(td, fg, bg, font));
        else if (tr.children[col]) cdApply(tr.children[col], fg, bg, font);
      }
    });
  }
  function cdPaintTv(c) {
    c.body.querySelectorAll('.ood-tvrow').forEach((row) => { const nd = c.nodes.get(Number(row.dataset.h)); if (nd && nd.cd) cdApply(row.lastElementChild, nd.cd[0], nd.cd[1], nd.cd[2]); });
  }
  function cdAsk(c) {                                          // one question at a time: the next waits for the answer
    if (!c.cdDlg || c.cdTimer) return;
    if (c.cdBusy) { c.cdAgain = true; return; }
    c.cdTimer = setTimeout(() => {
      c.cdTimer = 0;
      const dlg = c.cdDlg; if (!ood.dialogs.has(dlg.key)) return;
      const box = c.el.getBoundingClientRect(), seen = (e) => { const r = e.getBoundingClientRect(); return r.bottom > box.top && r.top < box.bottom; };
      if (c.kind === 'LISTVIEW') {
        const trs = [...c.tbody.children]; let first = trs.findIndex(seen), last = first;
        if (first < 0) return;
        while (last + 1 < trs.length && seen(trs[last + 1])) last++;
        c.cdBusy = true; fire(dlg.key, 'CD', c.id, 'ROWS', first + ' ' + last);
      } else {
        const rows = [...c.body.querySelectorAll('.ood-tvrow')].filter(seen); if (!rows.length) return;
        const level = (h) => { let n = 0, nd = c.nodes.get(h); while (nd && nd.parent) { n++; nd = c.nodes.get(nd.parent); } return n; };
        c.cdBusy = true; fire(dlg.key, 'CD', c.id, 'ROWS', rows.map((r) => r.dataset.h + ':' + level(Number(r.dataset.h))).join(' '));
      }
    }, 30);
  }
  function cdOp(dlg, c, name, a) {
    if (name === 'on') { if (!c.cdDlg) { c.cdDlg = dlg; c.el.addEventListener('scroll', () => cdAsk(c)); } cdAsk(c); return '1'; }
    if (name === 'paint') {                                    // the answer; an empty one ('[]') says "as drawn"
      const rows = JSON.parse(String(a));
      c.cdBusy = false; if (c.cdAgain) { c.cdAgain = false; cdAsk(c); }
      if (c.kind === 'LISTVIEW') { const by = new Map(c.rows.map((r) => [r.uid, r])); for (const [uid, paint] of rows) { const r = by.get(uid); if (r) r.cd = paint; } cdPaintLv(c); }
      else { for (const [h, fg, bg, font] of rows) { const nd = c.nodes.get(h); if (nd) nd.cd = [fg, bg, font]; } cdPaintTv(c); }
      return '1';
    }
    return '';
  }
  /* Drawing a control again is put off to the end of the current call.  A long list that is
     being filled row by row would be drawn, laid out and painted once for each row.  So a
     control of more than 100 rows is drawn when no change has come for 50 ms, and at the
     latest 300 ms after the first change.  An operation that reads the drawing
     (flushRender) draws first. */
  function later(c, fn) {
    const run = () => { if (!c.dirty) return; c.dirty = false; clearTimeout(c.drawTimer); c.drawTimer = 0; fn(c); c.draws = (c.draws || 0) + 1; };
    if (c.rows && c.rows.length > 100) {
      const now = performance.now();
      if (!c.dirty) { c.dirty = true; c.dirtySince = now; }
      c.drawNow = run;
      clearTimeout(c.drawTimer);
      c.drawTimer = setTimeout(run, now - c.dirtySince > 300 ? 0 : 50);
      return;
    }
    if (c.dirty) return; c.dirty = true;
    c.drawNow = run;
    queueMicrotask(run);
  }
  function flushRender(c) { if (c.dirty && c.drawTimer) { clearTimeout(c.drawTimer); c.drawNow(); } }

  function lvRender(c) {
    const report = c.view === 'REPORT';
    c.thead.textContent = ''; c.tbody.textContent = '';
    c.table.classList.toggle('ood-grid', c.ex.has('GRIDLINES'));
    if (report) {
      const tr = D.createElement('tr');
      c.cols.forEach((col) => {
        const th = D.createElement('th'); th.textContent = col.text; th.style.width = col.w < 0 ? 'auto' : col.w + 'px';
        th.style.minWidth = th.style.maxWidth = th.style.width; th.style.textAlign = col.fmt; tr.appendChild(th);
      });
      c.thead.appendChild(tr);
    }
    c.rows.forEach((row, i) => {
      const tr = D.createElement('tr');
      if (row.sel) tr.classList.add('ood-sel');
      if (i === c.focusIdx) tr.classList.add('ood-foc');
      const n = report ? Math.max(1, c.cols.length) : 1;
      for (let k = 0; k < n; k++) {
        const td = D.createElement('td');
        if (k === 0 && c.ex.has('CHECKBOXES')) {
          const cb = D.createElement('input'); cb.type = 'checkbox'; cb.checked = !!row.chk; cb.tabIndex = -1; cb.className = 'ood-lvchk'; td.appendChild(cb);
        }
        td.append(row.cells[k] == null ? '' : row.cells[k]);
        if (report && c.cols[k]) td.style.textAlign = c.cols[k].fmt;
        tr.appendChild(td);
      }
      c.tbody.appendChild(tr);
    });
    if (c.cdDlg) { cdPaintLv(c); cdAsk(c); }
  }
  const LV_DATA_OPS = new Set(['lv.insRow', 'lv.setCell', 'lv.cell', 'lv.uid', 'lv.uids', 'lv.row', 'lv.count', 'lv.colCount', 'lv.find', 'lv.itemState', 'lv.state', 'lv.check', 'lv.isChecked', 'lv.order']);   // these do not read the drawing
  function lvSel(dlg, c, i, on) {
    const row = c.rows[i]; if (!row || !!row.sel === on) return;
    row.sel = on; later(c, lvRender);
    note(dlg, c, 'SEL', i + SEP + (on ? 'SELECTED' : 'UNSELECTED'));
  }
  function lvFocus(dlg, c, i) {
    if (c.focusIdx === i) return;
    const old = c.focusIdx; c.focusIdx = i; later(c, lvRender);
    if (old >= 0 && old < c.rows.length) note(dlg, c, 'FOC', old + SEP + 'UNFOCUSED');
    if (i >= 0) note(dlg, c, 'FOC', i + SEP + 'FOCUSED');
  }
  function lvPick(dlg, c, i, e) {                              // a click or key chooses row i
    const ctrl = e && (e.ctrlKey || e.metaKey), shift = e && e.shiftKey;
    if (i < 0) { c.rows.forEach((r, k) => lvSel(dlg, c, k, false)); return; }
    if (c.single || (!ctrl && !shift)) {
      c.rows.forEach((r, k) => { if (k !== i) lvSel(dlg, c, k, false); });
      lvSel(dlg, c, i, true); c.anchor = i;
    } else if (ctrl) { lvSel(dlg, c, i, !c.rows[i].sel); c.anchor = i; }
    else {
      const a = c.anchor == null ? i : c.anchor, lo = Math.min(a, i), hi = Math.max(a, i);
      c.rows.forEach((r, k) => lvSel(dlg, c, k, k >= lo && k <= hi));
    }
    lvFocus(dlg, c, i);
  }
  const keysOf = (e) => [e.shiftKey ? 'SHIFT' : '', e.ctrlKey ? 'CONTROL' : '', e.altKey ? 'ALT' : ''].filter(Boolean).join(' ') || 'NONE';
  function lvWire(dlg, c) {
    let scrolling = 0, lastX = 0, lastY = 0;                   // LVN_BEGINSCROLL when the view starts to move, LVN_ENDSCROLL when it rests
    c.el.addEventListener('scroll', () => {
      const dx = c.el.scrollLeft - lastX, dy = c.el.scrollTop - lastY; lastX = c.el.scrollLeft; lastY = c.el.scrollTop;
      if (!scrolling) note(dlg, c, 'BEGINSCROLL', dx + SEP + dy);
      clearTimeout(scrolling);
      scrolling = setTimeout(() => { scrolling = 0; note(dlg, c, 'ENDSCROLL', dx + SEP + dy); }, 150);
    }, true);
    const hit = (e) => {
      const tr = e.target.closest('tbody tr'), td = e.target.closest('td');
      return tr ? [tr.sectionRowIndex, td ? td.cellIndex : 0] : [-1, -1];
    };
    c.el.addEventListener('click', (e) => {
      const th = e.target.closest('th');
      if (th) { note(dlg, c, 'COLUMNCLICK', th.cellIndex); return; }
      const [i, sub] = hit(e);
      if (e.target.classList.contains('ood-lvchk')) {
        c.rows[i].chk = e.target.checked; note(dlg, c, 'CHECK', i + SEP + (e.target.checked ? 'CHECKED' : 'UNCHECKED')); if (c.cdDlg) cdAsk(c); return;   // (Windows draws the item again)
      }
      lvPick(dlg, c, i, e);
      note(dlg, c, 'CLICK', i + SEP + sub + SEP + keysOf(e));
    });
    c.el.addEventListener('dblclick', (e) => {
      const [i, sub] = hit(e); if (e.target.closest('th')) return;
      note(dlg, c, 'DBLCLK', i + SEP + sub + SEP + keysOf(e));
      if (i >= 0) note(dlg, c, 'ACTIVATE', i);
    });
    c.el.addEventListener('keydown', (e) => {
      const n = c.rows.length; let i = c.focusIdx;
      if (e.key === 'ArrowDown' && n) { e.preventDefault(); lvPick(dlg, c, Math.min(n - 1, i + 1), e); }
      else if (e.key === 'ArrowUp' && n) { e.preventDefault(); lvPick(dlg, c, Math.max(0, i - 1), e); }
      else if (e.key === 'Enter' && i >= 0) { e.stopPropagation(); note(dlg, c, 'ACTIVATE', i); }
      note(dlg, c, 'KEYDOWN', e.keyCode);
    });
  }
  function lvNext(c, start, flags) {
    const back = has(flags, 'PREV'), n = c.rows.length;
    for (let i = start + (back ? -1 : 1); i >= 0 && i < n; i += back ? -1 : 1) {
      if (has(flags, 'SELECTED') && !c.rows[i].sel) continue;
      if (has(flags, 'FOCUSED') && i !== c.focusIdx) continue;
      return i;
    }
    return -1;
  }

  function tvRender(c) {
    c.body.textContent = '';
    const walk = (list, depth) => list.forEach((h) => {
      const nd = c.nodes.get(h), row = D.createElement('div'); row.className = 'ood-tvrow'; row.dataset.h = h;
      row.style.paddingLeft = (depth * 1.3 + 0.2) + 'em';
      if (h === c.selH) row.classList.add('ood-sel');
      const tw = D.createElement('span'); tw.className = 'ood-tvtw';
      tw.textContent = nd.kids.length ? (nd.open ? '▾' : '▸') : '';
      const tx = D.createElement('span'); tx.textContent = nd.text; if (nd.bold) tx.style.fontWeight = 'bold';
      row.append(tw, tx); c.body.appendChild(row);
      if (nd.open) walk(nd.kids, depth + 1);
    });
    walk(c.roots, 0);
    if (c.cdDlg) { cdPaintTv(c); cdAsk(c); }
  }
  function tvSelect(dlg, c, h, action) {
    if (c.selH === h) return;
    const old = c.selH; c.selH = h; later(c, tvRender);
    note(dlg, c, 'SELCHANGED', old + SEP + h + SEP + action);
  }
  function tvOpen(dlg, c, h, how) {
    const nd = c.nodes.get(h); if (!nd) return false;
    const open = how === 'TOGGLE' ? !nd.open : how === 'EXPAND';
    if (nd.open === open) return true;
    note(dlg, c, 'EXPANDING', h + SEP + (open ? 'EXPANDED' : 'COLLAPSED'));
    nd.open = open; later(c, tvRender);
    note(dlg, c, 'EXPANDED', h + SEP + (open ? 'EXPANDED' : 'COLLAPSED'));
    return true;
  }
  function tvVisible(c) { const out = []; const walk = (l) => l.forEach((h) => { out.push(h); const nd = c.nodes.get(h); if (nd.open) walk(nd.kids); }); walk(c.roots); return out; }
  function tvDrop(c, h) { const nd = c.nodes.get(h); if (!nd) return; nd.kids.slice().forEach((k) => tvDrop(c, k)); c.nodes.delete(h); if (c.selH === h) c.selH = 0; }
  function tvWire(dlg, c) {
    c.el.addEventListener('click', (e) => {
      const row = e.target.closest('.ood-tvrow'); if (!row) return;
      const h = Number(row.dataset.h);
      if (e.target.classList.contains('ood-tvtw')) tvOpen(dlg, c, h, 'TOGGLE'); else tvSelect(dlg, c, h, 'MOUSE');
    });
    c.el.addEventListener('dblclick', (e) => {
      const row = e.target.closest('.ood-tvrow'); if (row && !e.target.classList.contains('ood-tvtw')) tvOpen(dlg, c, Number(row.dataset.h), 'TOGGLE');
    });
    c.el.addEventListener('keydown', (e) => {
      const vis = tvVisible(c), i = vis.indexOf(c.selH), nd = c.nodes.get(c.selH);
      if (e.key === 'ArrowDown' && i < vis.length - 1) { e.preventDefault(); tvSelect(dlg, c, vis[i + 1], 'KEYBOARD'); }
      else if (e.key === 'ArrowUp' && i > 0) { e.preventDefault(); tvSelect(dlg, c, vis[i - 1], 'KEYBOARD'); }
      else if (e.key === 'ArrowRight' && nd) { e.preventDefault(); tvOpen(dlg, c, c.selH, 'EXPAND'); }
      else if (e.key === 'ArrowLeft' && nd) { e.preventDefault(); tvOpen(dlg, c, c.selH, 'COLLAPSE'); }
    });
  }

  const two = (n) => String(n).padStart(2, '0');
  /* ---- Month calendar: one month, Sunday first unless set otherwise ---- */
  const mcDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const mcIso = (d) => d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0') + 'T00:00:00';
  const mcFirstShown = (c) => { const f = new Date(c.mc.view); f.setDate(1 - ((f.getDay() - c.mc.firstDay + 7) % 7)); return f; };
  function mcInRange(c, d) { return (!c.mc.min || d >= c.mc.min) && (!c.mc.max || d <= c.mc.max); }
  function mcRender(dlg, c) {
    const m = c.mc, el = c.el; el.textContent = '';
    const head = D.createElement('div'); head.className = 'ood-mc-head';
    const nav = (text, by, cls) => { const b = D.createElement('button'); b.type = 'button'; b.className = cls; b.textContent = text; b.tabIndex = -1;
      b.addEventListener('click', (e) => { e.stopPropagation(); mcGo(dlg, c, by); }); return b; };
    const title = D.createElement('span'); title.className = 'ood-mc-title';
    title.textContent = m.view.toLocaleString('en-US', { month: 'long' }) + ' ' + m.view.getFullYear();
    head.append(nav('‹', -1, 'ood-mc-prev'), title, nav('›', 1, 'ood-mc-next'));
    const grid = D.createElement('div'); grid.className = 'ood-mc-grid';
    for (let k = 0; k < 7; k++) { const w = D.createElement('span'); w.className = 'ood-mc-wd'; w.textContent = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'][(k + m.firstDay) % 7]; grid.appendChild(w); }
    const first = mcFirstShown(c);
    for (let k = 0; k < 42; k++) {
      const d = new Date(first.getFullYear(), first.getMonth(), first.getDate() + k);
      const cell = D.createElement('span'); cell.className = 'ood-mc-day'; cell.textContent = d.getDate(); cell.dataset.date = mcIso(d).slice(0, 10);
      if (d.getMonth() !== m.view.getMonth()) cell.classList.add('ood-mc-other');
      if (+d === +m.sel) cell.classList.add('ood-mc-sel');
      if (+d === +m.today) cell.classList.add('ood-mc-today');
      const bold = m.bold.get(d.getFullYear() + '-' + d.getMonth()); if (bold && (bold >>> (d.getDate() - 1)) & 1) cell.classList.add('ood-mc-bold');
      if (!mcInRange(c, d)) cell.classList.add('ood-mc-off');
      else cell.addEventListener('click', () => mcPick(dlg, c, d, true));
      grid.appendChild(cell);
    }
    el.append(head, grid);
    if (!m.noToday) { const t = D.createElement('div'); t.className = 'ood-mc-foot'; t.textContent = 'Today: ' + m.today.toLocaleDateString('en-US');
      t.addEventListener('click', () => mcPick(dlg, c, m.today, true)); el.appendChild(t); }
  }
  function mcShow(dlg, c, d, ask) {                           // bring the month of d into view; the program is asked for its bold days
    const m = c.mc, moved = d.getFullYear() !== m.view.getFullYear() || d.getMonth() !== m.view.getMonth();
    if (moved) m.view = new Date(d.getFullYear(), d.getMonth(), 1);
    mcRender(dlg, c);
    if (moved && ask && m.dayState) { const f = mcFirstShown(c); note(dlg, c, 'GETDAYSTATE', mcIso(new Date(f.getFullYear(), f.getMonth(), 1)) + SEP + 3); }
  }
  function mcGo(dlg, c, by) {
    const m = c.mc, to = new Date(m.view.getFullYear(), m.view.getMonth() + by, 1), end = new Date(to.getFullYear(), to.getMonth() + 1, 0);
    if ((m.min && end < m.min) || (m.max && to > m.max)) return;
    mcShow(dlg, c, to, true);
  }
  function mcPick(dlg, c, d, byUser) {
    if (!mcInRange(c, d)) return;
    c.mc.sel = mcDay(d); mcShow(dlg, c, c.mc.sel, byUser);
    if (byUser) { const e = mcIso(c.mc.sel) + SEP + mcIso(c.mc.sel); note(dlg, c, 'SELCHANGE', e); note(dlg, c, 'SELECT', e); }
  }
  function mcOp(dlg, c, name, a, b) {
    const m = c.mc, date = (v) => (v === '' || v === undefined ? null : mcDay(new Date(String(v))));
    switch (name) {
      case 'get': return mcIso(m.sel);
      case 'set': { const d = date(a); if (!d || isNaN(d)) return '0'; m.sel = d; mcShow(dlg, c, d, false); return '1'; }
      case 'today': { if (a !== '' && a !== undefined) { m.today = date(a); mcRender(dlg, c); } return mcIso(m.today); }
      case 'range': m.min = date(a); m.max = date(b);
        if (m.min && m.sel < m.min) m.sel = m.min; if (m.max && m.sel > m.max) m.sel = m.max;
        mcShow(dlg, c, m.sel, false); return '1';
      case 'getRange': return (m.min ? mcIso(m.min) : '') + SEP + (m.max ? mcIso(m.max) : '');
      case 'months': {                                         // what is shown: P with the days of the months before and after, else the whole month
        if (a !== 'P') return mcIso(m.view) + SEP + mcIso(new Date(m.view.getFullYear(), m.view.getMonth() + 1, 0)) + SEP + 1;
        const f = mcFirstShown(c), l = new Date(f.getFullYear(), f.getMonth(), f.getDate() + 41);
        return mcIso(f) + SEP + mcIso(l) + SEP + ((l.getFullYear() - f.getFullYear()) * 12 + l.getMonth() - f.getMonth() + 1); }
      case 'dayState': {                                       // the bold days of the months from the first one shown: one bit mask a month
        const f = mcFirstShown(c);
        String(a).split(' ').filter(Boolean).forEach((v, k) => { const d = new Date(f.getFullYear(), f.getMonth() + k, 1); m.bold.set(d.getFullYear() + '-' + d.getMonth(), Number(v) >>> 0); });
        mcRender(dlg, c); return '1'; }
      case 'dayStateFrom': {                                   // the same, from a month named by the program
        const f = date(a);
        String(b).split(' ').filter(Boolean).forEach((v, k) => { const d = new Date(f.getFullYear(), f.getMonth() + k, 1); m.bold.set(d.getFullYear() + '-' + d.getMonth(), Number(v) >>> 0); });
        mcRender(dlg, c); return '1'; }
      case 'firstDay': { if (a !== '' && a !== undefined) { m.firstDay = (Number(a) + 1) % 7; mcRender(dlg, c); } return String((m.firstDay + 6) % 7); }   // Windows: 0 is Monday
      case 'minRect': {                                        // the size the calendar needs, whatever size it has now
        const w = c.el.style.width, h = c.el.style.height; c.el.style.width = 'max-content'; c.el.style.height = 'max-content';
        const r = Math.ceil(c.el.offsetWidth) + ' ' + Math.ceil(c.el.offsetHeight); c.el.style.width = w; c.el.style.height = h; return r; }
      case 'todayWidth': { const t = c.el.querySelector('.ood-mc-foot'); if (!t) return '0';
        const g = D.createElement('canvas').getContext('2d'); g.font = getComputedStyle(t).font; return String(Math.ceil(g.measureText(t.textContent).width) + 12); }
      case 'hit': {                                            // what is at a point of the client area: "DATE iso" | "TITLE" | "PREV" | "NEXT" | "TODAY" | "NOWHERE"
        const o = c.el.getBoundingClientRect(), t = D.elementFromPoint(o.left + Number(a), o.top + Number(b));
        if (!t || !c.el.contains(t)) return 'NOWHERE';
        if (t.dataset.date) return 'DATE ' + t.dataset.date + 'T00:00:00';
        if (t.classList.contains('ood-mc-prev')) return 'PREV'; if (t.classList.contains('ood-mc-next')) return 'NEXT';
        if (t.classList.contains('ood-mc-foot')) return 'TODAY'; if (t.closest('.ood-mc-head')) return 'TITLE';
        return 'NOWHERE'; }
    }
    return '';
  }

  function dtpSet(c, d) {
    c.date = d;
    c.main.value = c.main.type === 'time' ? two(d.getHours()) + ':' + two(d.getMinutes()) + ':' + two(d.getSeconds())
      : d.getFullYear() + '-' + two(d.getMonth() + 1) + '-' + two(d.getDate());
  }
  function dtpGet(c) {                                        // the part shown is the user's; the rest is kept
    const d = new Date(c.date), v = c.main.value;
    if (v) {
      if (c.main.type === 'time') { const [h, m, sec] = v.split(':').map(Number); d.setHours(h, m, sec || 0); }
      else { const [y, mo, da] = v.split('-').map(Number); d.setFullYear(y, mo - 1, da); }
      c.date = d;
    }
    return d.getFullYear() + '-' + two(d.getMonth() + 1) + '-' + two(d.getDate()) + 'T' + two(d.getHours()) + ':' + two(d.getMinutes()) + ':' + two(d.getSeconds());
  }
  function udSet(dlg, c, pos) {
    c.pos = Math.max(c.min, Math.min(c.max, pos));
    const b = dlg.ctrls.get(c.buddy);
    if (b && c.setInt && b.kind === 'EDIT') { b.main.value = String(c.pos); cmd(dlg, b, 0x400); cmd(dlg, b, 0x300); }
  }
  function tabRender(c) {
    c.strip.textContent = '';
    c.tabs.forEach((t, i) => {
      const b = D.createElement('button'); b.type = 'button'; b.className = 'ood-tabbtn'; b.tabIndex = i === c.cur ? 0 : -1;
      if (c.minTab != null) b.style.minWidth = c.minTab + 'px';
      label(b, t.text); if (i === c.cur) b.classList.add('ood-cur'); c.strip.appendChild(b);
    });
  }
  function tabWire(dlg, c) {
    c.strip.addEventListener('click', (e) => {
      const b = e.target.closest('.ood-tabbtn'); if (!b) return;
      const i = Array.prototype.indexOf.call(c.strip.children, b); if (i === c.cur) return;
      note(dlg, c, 'SELCHANGING', ''); c.cur = i; tabRender(c); note(dlg, c, 'SELCHANGE', '');
    });
  }

  /* list helpers: positions are zero-based here, as in the Win32 messages */
  const optsOf = (c) => (c.items ? c.items : c.main).children;
  /* LB_SETTABSTOPS: an option cannot show a tab, so what it shows (its label) is the
     text with each tab filled out to the next stop; its text stays as the program gave it. */
  function listTabbed(c, text) {
    if (!c.tabStops || text.indexOf('\t') < 0) return null;
    const g = (listTabbed.g = listTabbed.g || D.createElement('canvas').getContext('2d'));
    g.font = getComputedStyle(c.main).font;
    const pad = '\u00a0', padW = g.measureText(pad).width || 3;
    let out = '';
    text.split('\t').forEach((part, k, all) => {
      out += part;
      if (k === all.length - 1) return;
      const last = c.tabStops[c.tabStops.length - 1] || 32, step = c.tabStops.length > 1 ? last - c.tabStops[c.tabStops.length - 2] : last;
      let stop = c.tabStops.find((t) => t > g.measureText(out).width);
      if (stop === undefined) { stop = last; while (stop <= g.measureText(out).width) stop += Math.max(8, step); }
      out += pad.repeat(Math.max(1, Math.round((stop - g.measureText(out).width) / padW)));
    });
    return out;
  }
  function listInsert(c, at, text) {
    const op = D.createElement('option'); op.textContent = text; if (c.items) op.value = text;
    const shown = listTabbed(c, text); if (shown !== null) op.label = shown;
    const kids = optsOf(c), box = c.items || c.main;
    if (c.sort && at < 0) {
      at = 0; while (at < kids.length && kids[at].textContent.localeCompare(text, undefined, { sensitivity: 'base' }) <= 0) at++;
    }
    if (at < 0 || at >= kids.length) { box.appendChild(op); at = kids.length - 1; } else box.insertBefore(op, kids[at]);
    if (c.droplist && kids.length === 1) c.main.selectedIndex = -1;
    return at;
  }
  function listFind(c, text, start, exact) {
    const kids = optsOf(c), n = kids.length, t = text.toLowerCase();
    for (let k = 0; k < n; k++) {
      const i = (start + 1 + k) % n, v = kids[i].textContent.toLowerCase();
      if (exact ? v === t : v.startsWith(t)) return i;
    }
    return -1;
  }
  function curSel(c) {
    if (c.kind === 'COMBO' && !c.droplist) {
      const kids = optsOf(c);
      for (let i = 0; i < kids.length; i++) if (kids[i].textContent === c.main.value) return i;
      return -1;
    }
    return c.main.selectedIndex;
  }
  function setProgress(c) {
    const span = c.max - c.min; c.pos = Math.max(c.min, Math.min(c.max, c.pos));
    const pct = (span > 0 ? (c.pos - c.min) * 100 / span : 0) + '%';
    if (c.vertical) c.bar.style.height = pct; else c.bar.style.width = pct;
  }

  /* ---- Win32 messages (the subset upstream's Rexx code sends) ------------ */
  ood.msg = function (key, id, msg, w, l) {
    const dlg = ood.dialogs.get(Number(key)); if (!dlg) return '0';
    const c = dlg.ctrls.get(Number(id)); if (!c) return '0';
    msg = Number(msg); w = Number(w); l = Number(l);
    const m = c.main;
    switch (c.kind) {
      case 'MONTHCALENDAR':
        switch (msg) {
          case 0x1015: return mcOp(dlg, c, 'todayWidth');                     // MCM_GETMAXTODAYWIDTH
          case 0x1003: return '1';                                            // MCM_GETMAXSELCOUNT: one day
          case 0x1013: return '1';                                            // MCM_GETMONTHDELTA
        }
        return '0';
      case 'BUTTON': case 'CHECK': case 'RADIO':
        switch (msg) {
          case 0xF5: m.click(); return '0';                                   // BM_CLICK
          case 0xF0: return String(c.tri ? (c.state || 0) : (m.checked ? 1 : 0)); // BM_GETCHECK
          case 0xF1: if (c.tri) c.state = w; m.checked = w === 1; m.indeterminate = w === 2; return '0'; // BM_SETCHECK
          case 0xF2: return String((m.checked ? 1 : 0) | (c.pushed ? 4 : 0) | (D.activeElement === m ? 8 : 0)); // BM_GETSTATE
          case 0xF3: c.pushed = (w !== 0); m.classList.toggle('ood-pushed', c.pushed); return '0';   // BM_SETSTATE: drawn pushed or not
        }
        break;
      case 'EDIT':
        switch (msg) {
          case 0xB1: m.setSelectionRange(w, l < 0 ? m.value.length : l); return '1';   // EM_SETSEL
          case 0xB8: return c.modified ? '1' : '0';                                    // EM_GETMODIFY
          case 0xB9: c.modified = w !== 0; return '0';                                 // EM_SETMODIFY
          case 0xBA: return String(m.value.split('\n').length);                        // EM_GETLINECOUNT
          case 0xC5: if (w > 0) m.maxLength = w; else m.removeAttribute('maxlength'); return '0'; // EM_LIMITTEXT
          case 0xC6: return '0';
          case 0xCC: if (m.tagName === 'INPUT') m.type = w === 0 ? 'text' : 'password'; return '0'; // EM_SETPASSWORDCHAR
          case 0xD2: return m.type === 'password' ? '42' : '0';                        // EM_GETPASSWORDCHAR
          case 0xCF: m.readOnly = w !== 0; return '1';                                 // EM_SETREADONLY
          case 0xB5: {                                                                 // EM_SCROLL: line up, line down, page up, page down
            const lh = parseFloat(getComputedStyle(m).lineHeight) || 16, before = m.scrollTop;
            m.scrollTop += [-lh, lh, -m.clientHeight, m.clientHeight][Number(w)] || 0;
            return String(65536 + Math.round((m.scrollTop - before) / lh)); }
          case 0xB7: m.scrollTop = m.scrollHeight; return '0';                         // EM_SCROLLCARET
          case 0x303: m.setRangeText(''); return '0';                                  // WM_CLEAR
        }
        break;
      case 'LIST':
        switch (msg) {
          case 0x182: if (w < 0 || w >= m.options.length) return '-1'; m.remove(w); return String(m.options.length); // LB_DELETESTRING
          case 0x184: m.textContent = ''; return '0';                                  // LB_RESETCONTENT
          case 0x185: if (l < 0) { for (const op of m.options) op.selected = w !== 0; } else if (m.options[l]) m.options[l].selected = w !== 0; return '0'; // LB_SETSEL
          case 0x186: m.selectedIndex = w; return String(m.selectedIndex);             // LB_SETCURSEL
          case 0x187: return m.options[w] && m.options[w].selected ? '1' : '0';        // LB_GETSEL
          case 0x188: return String(m.selectedIndex);                                  // LB_GETCURSEL
          case 0x18B: return String(m.options.length);                                 // LB_GETCOUNT
          case 0x190: return String(m.selectedOptions.length);                         // LB_GETSELCOUNT
          case 0x18E: return '0';                                                      // LB_GETTOPINDEX
          case 0x194: case 0x193: return '0';                                          // LB_SETHORIZONTALEXTENT, LB_GETHORIZONTALEXTENT
          case 0x197: if (m.options[w]) m.options[w].scrollIntoView({ block: 'nearest' }); return '0'; // LB_SETTOPINDEX
        }
        break;
      case 'COMBO': {
        const kids = optsOf(c);
        switch (msg) {
          case 0x144: if (w < 0 || w >= kids.length) return '-1'; kids[w].remove(); return String(kids.length); // CB_DELETESTRING
          case 0x146: return String(kids.length);                                      // CB_GETCOUNT
          case 0x147: return String(curSel(c));                                        // CB_GETCURSEL
          case 0x14B: (c.items || m).textContent = ''; if (!c.droplist) m.value = ''; return '0'; // CB_RESETCONTENT
          case 0x14E:                                                                  // CB_SETCURSEL
            if (c.droplist) { m.selectedIndex = w; return String(m.selectedIndex); }
            if (w >= 0 && w < kids.length) { m.value = kids[w].textContent; return String(w); }
            m.value = ''; return '-1';
          case 0x14F: if (w && m.showPicker) { try { m.showPicker(); } catch (e) { } } return '1'; // CB_SHOWDROPDOWN
          case 0x157: return '0';                                                      // CB_GETDROPPEDSTATE
          case 0x142: if (!c.droplist) m.setSelectionRange(l & 0xFFFF, (l >>> 16) === 0xFFFF ? m.value.length : l >>> 16); return '1'; // CB_SETEDITSEL
        }
        break; }
      case 'PROGRESS':
        switch (msg) {
          case 0x401: c.min = l & 0xFFFF; c.max = l >>> 16; setProgress(c); return '0';  // PBM_SETRANGE
          case 0x406: c.min = w; c.max = l; setProgress(c); return '0';                  // PBM_SETRANGE32
          case 0x407: return String(w ? c.min : c.max);                                  // PBM_GETRANGE
          case 0x402: { const old = c.pos; c.pos = w; setProgress(c); return String(old); } // PBM_SETPOS
          case 0x403: { const old = c.pos; c.pos += w; setProgress(c); return String(old); } // PBM_DELTAPOS
          case 0x404: { const old = c.step; c.step = w; return String(old); }            // PBM_SETSTEP
          case 0x405: { const old = c.pos; c.pos += c.step; if (c.pos > c.max) c.pos = c.min + (c.pos - c.max); setProgress(c); return String(old); } // PBM_STEPIT
          case 0x408: return String(c.pos);                                              // PBM_GETPOS
          case 0x409: c.bar.style.background = bgr(w === 0xFF000000 ? 0x25B006 : l); return '0'; // PBM_SETBARCOLOR
          case 0x2001: c.el.style.background = bgr(l); return '0';                        // PBM_SETBKCOLOR
        }
        break;
    }
    if (c.kind === 'LISTVIEW') switch (msg) {
      case 0x1004: return String(c.rows.length);                                       // LVM_GETITEMCOUNT
      case 0x1032: return String(c.rows.filter((r) => r.sel).length);                  // LVM_GETSELECTEDCOUNT
      case 0x101D: return String(c.cols[w] ? Math.max(0, c.cols[w].w) : 0);            // LVM_GETCOLUMNWIDTH
      case 0x1013: { const tr = c.tbody.children[w]; if (tr) tr.scrollIntoView({ block: 'nearest' }); return '1'; } // LVM_ENSUREVISIBLE
      case 0x102F: case 0x1027: case 0x102A: case 0x1015: return '0';
    }
    if (c.kind === 'TREEVIEW') switch (msg) {
      case 0x1105: return String(c.nodes.size);                                        // TVM_GETCOUNT
      case 0x1114: return '1';                                                         // TVM_ENSUREVISIBLE
    }
    if (c.kind === 'TRACKBAR') switch (msg) {
      case 0x400: return String(m.value);                                              // TBM_GETPOS
      case 0x401: return String(m.min);                                                // TBM_GETRANGEMIN
      case 0x402: return String(m.max);                                                // TBM_GETRANGEMAX
      case 0x405: m.value = l; return '0';                                             // TBM_SETPOS
      case 0x406: m.min = l & 0xFFFF; m.max = l >>> 16; return '0';                    // TBM_SETRANGE
      case 0x407: m.min = l; return '0';                                               // TBM_SETRANGEMIN
      case 0x408: m.max = l; return '0';                                               // TBM_SETRANGEMAX
      case 0x415: { const old = c.page; c.page = l; return String(old); }              // TBM_SETPAGESIZE
      case 0x416: return String(c.page);
      case 0x417: { const old = c.line; c.line = l; m.step = l; return String(old); }  // TBM_SETLINESIZE
      case 0x418: return String(c.line);
      case 0x414: case 0x404: case 0x409: case 0x40A: case 0x40B: case 0x40C: case 0x413: return '0';
      case 0x410: return '2';
    }
    if (c.kind === 'UPDOWN') switch (msg) {
      case 0x471: { const old = c.pos; udSet(dlg, c, l); return String(old); }         // UDM_SETPOS32
      case 0x472: return String(c.pos);                                                // UDM_GETPOS32
      case 0x46F: c.min = Math.min(w, l); c.max = Math.max(w, l); udSet(dlg, c, c.pos); return '0'; // UDM_SETRANGE32
      case 0x46E: return '10';                                                         // UDM_GETBASE
      case 0x46D: return '10';                                                         // UDM_SETBASE
    }
    if (c.kind === 'TAB') switch (msg) {
      case 0x1304: return String(c.tabs.length);                                       // TCM_GETITEMCOUNT
      case 0x130B: return String(c.cur);                                               // TCM_GETCURSEL
      case 0x130C: { const old = c.cur; if (w >= 0 && w < c.tabs.length) { c.cur = w; tabRender(c); } return String(old); } // TCM_SETCURSEL
      case 0x1308: if (w < 0 || w >= c.tabs.length) return '0'; c.tabs.splice(w, 1); if (c.cur >= c.tabs.length) c.cur = c.tabs.length - 1; tabRender(c); return '1'; // TCM_DELETEITEM
      case 0x1309: c.tabs = []; c.cur = -1; tabRender(c); return '1';                  // TCM_DELETEALLITEMS
      case 0x132F: return String(c.cur);                                               // TCM_GETCURFOCUS
      case 0x1330: if (w >= 0 && w < c.tabs.length) { c.cur = w; tabRender(c); } return '0'; // TCM_SETCURFOCUS
      case 0x132C: return '1';                                                         // TCM_GETROWCOUNT
      case 0x1331: { const old = c.minTab == null ? -1 : c.minTab; c.minTab = l < 0 ? null : l; tabRender(c); return String(old); }   // TCM_SETMINTABWIDTH: the width before
    }
    ood.log.push('msg ' + c.kind + ' 0x' + msg.toString(16));
    return '0';
  };
  const bgr = (v) => 'rgb(' + (v & 255) + ',' + ((v >> 8) & 255) + ',' + ((v >> 16) & 255) + ')';

  /* ---- operations that carry text, and window operations ---------------- */
  /* ---- Drawing (GDI) ----
     A device context is a canvas laid over the dialog's client area or over one control.
     It takes no pointer events, so the control under it still works.  Rexx keeps the state
     of a DC (pen, brush, font, colours); every call brings what it needs:
       style = stroke, width, dash, fill, font, textColour, bkMode (O|T), bkColour, align words */
  function gdiCanvas(dlg, c, el) {
    const id = c ? c.id : 0;
    dlg.gdi = dlg.gdi || new Map();
    let cv = dlg.gdi.get(id);
    let left = 0, top = 0, w = dlg.client.clientWidth, h = dlg.client.clientHeight;
    if (c) {
      left = 0; top = 0;
      for (let n = el; n && n !== dlg.client; n = n.offsetParent) { left += n.offsetLeft; top += n.offsetTop; }
      w = el.offsetWidth; h = el.offsetHeight;
    }
    if (!cv) {
      cv = D.createElement('canvas'); cv.className = 'ood-gdi';
      cv.style.cssText = 'position:absolute;pointer-events:none;z-index:5';
      dlg.client.appendChild(cv); dlg.gdi.set(id, cv);
    }
    if (cv.width !== w || cv.height !== h) { cv.width = Math.max(1, w); cv.height = Math.max(1, h); }
    cv.style.left = left + 'px'; cv.style.top = top + 'px';
    return cv;
  }
  function gdiHatch(kind, color) {
    const t = D.createElement('canvas'); t.width = 8; t.height = 8;
    const g = t.getContext('2d'); g.strokeStyle = color; g.lineWidth = 1; g.beginPath();
    const line = (x1, y1, x2, y2) => { g.moveTo(x1, y1); g.lineTo(x2, y2); };
    if (kind === 'HORIZONTAL' || kind === 'CROSS') line(0, 4.5, 8, 4.5);
    if (kind === 'VERTICAL' || kind === 'CROSS') line(4.5, 0, 4.5, 8);
    if (kind === 'UPDIAGONAL' || kind === 'DIAGCROSS') line(0, 8, 8, 0);
    if (kind === 'DOWNDIAGONAL' || kind === 'DIAGCROSS') line(0, 0, 8, 8);
    g.stroke();
    return t;
  }
  function gdiRgb(css) {                                       // a CSS colour as [r, g, b]
    const t = D.createElement('canvas'); t.width = t.height = 1;
    const g = t.getContext('2d'); g.fillStyle = css; g.fillRect(0, 0, 1, 1);
    return g.getImageData(0, 0, 1, 1).data;
  }
  function gdi(dlg, c, el, verb, v, st) {
    const cv = gdiCanvas(dlg, c, el), g = cv.getContext('2d', { willReadFrequently: true });
    const n = (i) => Number(v[i]) || 0;
    const [stroke, width, dash, fill, font, textColor, bkMode, bkColor, align] = st;
    const lw = Math.max(1, Number(width) || 1);
    const pen = () => {
      g.strokeStyle = stroke || '#000'; g.lineWidth = lw; g.lineCap = 'round'; g.lineJoin = 'round';
      const u = lw; g.setLineDash({ DASH: [6 * u, 3 * u], DOT: [u, 2 * u], DASHDOT: [6 * u, 3 * u, u, 3 * u], DASHDOTDOT: [6 * u, 3 * u, u, 3 * u, u, 3 * u] }[dash] || []);
    };
    const brush = () => {
      if (!fill) return false;
      if (fill.startsWith('hatch:')) { const [, kind, color] = fill.split(':'); g.fillStyle = g.createPattern(gdiHatch(kind, color), 'repeat'); }
      else g.fillStyle = fill;
      return true;
    };
    const o = (lw % 2) ? 0.5 : 0;                              // odd widths on the pixel grid
    switch (verb) {
      case 'line': if (dash === 'NULL') return '1'; pen(); g.beginPath(); g.moveTo(n(0) + o, n(1) + o); g.lineTo(n(2) + o, n(3) + o); g.stroke(); return '1';
      case 'rect': {
        const x = Math.min(n(0), n(2)), y = Math.min(n(1), n(3)), w = Math.abs(n(2) - n(0)), h = Math.abs(n(3) - n(1));
        if (v[4] === '1' && brush()) g.fillRect(x, y, w, h);
        if (dash !== 'NULL') { pen(); g.strokeRect(x + o, y + o, w, h); }
        return '1'; }
      case 'arc': {                                            // Arc() and Pie(): counter-clockwise from the start radial to the end radial
        const cx = (n(0) + n(2)) / 2, cy = (n(1) + n(3)) / 2, rx = Math.abs(n(2) - n(0)) / 2, ry = Math.abs(n(3) - n(1)) / 2;
        if (rx <= 0 || ry <= 0) return '0';
        const whole = (n(4) === n(6) && n(5) === n(7));
        const ang = (x, y) => Math.atan2((y - cy) / ry, (x - cx) / rx);
        const a1 = whole ? 0 : ang(n(4), n(5)), a2 = whole ? 2 * Math.PI : ang(n(6), n(7));
        const ccw = !whole && v[9] !== 'CLOCKWISE';
        g.beginPath();
        if (v[8] === '1' && !whole) g.moveTo(cx, cy);
        g.ellipse(cx, cy, rx, ry, 0, a1, a2, ccw);
        if (v[8] === '1') { g.closePath(); if (brush()) g.fill(); }
        if (dash !== 'NULL') { pen(); g.stroke(); }
        return '1'; }
      case 'angleArc': {                                       // x, y, radius, start and sweep in degrees, counter-clockwise; fromX fromY
        const a1 = -n(3) * Math.PI / 180, a2 = -(n(3) + n(4)) * Math.PI / 180;
        pen(); g.beginPath();
        if (v[5] !== '') g.moveTo(n(5), n(6));
        g.arc(n(0), n(1), Math.max(0, n(2)), a1, a2, n(4) > 0); g.stroke();
        return Math.round(n(0) + n(2) * Math.cos(a2)) + ' ' + Math.round(n(1) + n(2) * Math.sin(a2)); }
      case 'pixel': g.fillStyle = v[2]; g.fillRect(n(0), n(1), 1, 1); return '1';
      case 'getPixel': { if (n(0) < 0 || n(1) < 0 || n(0) >= cv.width || n(1) >= cv.height) return '-1';
        const d = g.getImageData(n(0), n(1), 1, 1).data; return d[3] === 0 ? '-1' : String(d[0] + d[1] * 256 + d[2] * 65536); }
      case 'fillRect': if (brush()) g.fillRect(Math.min(n(0), n(2)), Math.min(n(1), n(3)), Math.abs(n(2) - n(0)), Math.abs(n(3) - n(1))); return '1';
      case 'clear': if (v[0] === '') g.clearRect(0, 0, cv.width, cv.height); else g.clearRect(Math.min(n(0), n(2)), Math.min(n(1), n(3)), Math.abs(n(2) - n(0)), Math.abs(n(3) - n(1))); return '1';
      case 'extent': { g.font = font || getComputedStyle(dlg.client).font; const m = g.measureText(v[0]);
        return Math.ceil(m.width) + ' ' + Math.ceil((m.fontBoundingBoxAscent || 10) + (m.fontBoundingBoxDescent || 3)); }
      case 'text': {
        g.font = font || getComputedStyle(dlg.client).font;
        const words = ' ' + (align || '') + ' ';
        g.textAlign = words.includes(' CENTER ') ? 'center' : words.includes(' RIGHT ') ? 'right' : 'left';
        g.textBaseline = words.includes(' BASELINE ') ? 'alphabetic' : words.includes(' BOTTOM ') ? 'bottom' : 'top';
        const lines = String(v[2]).split('\n');
        const m = g.measureText('Mg'), lh = Math.ceil((m.fontBoundingBoxAscent || 10) + (m.fontBoundingBoxDescent || 3));
        lines.forEach((t, i) => {
          const y = n(1) + i * lh;
          if (bkMode === 'O') {
            const w = g.measureText(t).width;
            const x0 = g.textAlign === 'center' ? n(0) - w / 2 : g.textAlign === 'right' ? n(0) - w : n(0);
            const y0 = g.textBaseline === 'alphabetic' ? y - (m.fontBoundingBoxAscent || 10) : g.textBaseline === 'bottom' ? y - lh : y;
            g.fillStyle = bkColor || '#fff'; g.fillRect(x0, y0, w, lh);
          }
          g.fillStyle = textColor || '#000'; g.fillText(t, n(0), y);
        });
        return '1'; }
      case 'flood': {                                          // FloodFill(): from x, y out to the border colour
        const x0 = Math.round(n(0)), y0 = Math.round(n(1)), W = cv.width, H = cv.height;
        if (x0 < 0 || y0 < 0 || x0 >= W || y0 >= H || !fill) return '0';
        const img = g.getImageData(0, 0, W, H), px = img.data;
        const bc = gdiRgb(v[2]), fc = gdiRgb(fill.startsWith('hatch:') ? fill.split(':')[2] : fill);
        const near = (i, col) => px[i + 3] > 40 && Math.abs(px[i] - col[0]) + Math.abs(px[i + 1] - col[1]) + Math.abs(px[i + 2] - col[2]) < 150;
        const seen = new Uint8Array(W * H), stack = [x0 + y0 * W];
        while (stack.length) {
          const p = stack.pop();
          if (seen[p]) continue;
          seen[p] = 1;
          const i = p * 4;
          if (near(i, bc)) continue;                           // the border stops the fill
          px[i] = fc[0]; px[i + 1] = fc[1]; px[i + 2] = fc[2]; px[i + 3] = 255;
          const x = p % W;
          if (x > 0) stack.push(p - 1);
          if (x < W - 1) stack.push(p + 1);
          if (p >= W) stack.push(p - W);
          if (p < W * (H - 1)) stack.push(p + W);
        }
        g.putImageData(img, 0, 0);
        return '1'; }
      case 'ownerDraw': if (c) (c.textEl || c.main || el).style.color = 'transparent'; return '1';   // the program draws it: no text of its own
      case 'image': {                                          // BitBlt(): key, x, y, xSource, ySource, width, height (0: all of it)
        const url = ood.images.get(v[0]); if (!url) return '0';
        ood.imgEls = ood.imgEls || new Map();
        let img = ood.imgEls.get(v[0]);
        if (!img) { img = new Image(); img.src = url; ood.imgEls.set(v[0], img); }
        const put = () => {
          const w = n(5) || img.naturalWidth, h = n(6) || img.naturalHeight;
          const sw = Math.min(w, img.naturalWidth - n(3)), sh = Math.min(h, img.naturalHeight - n(4));
          if (sw > 0 && sh > 0) g.drawImage(img, n(3), n(4), sw, sh, n(1), n(2), sw, sh);
        };
        if (img.complete && img.naturalWidth) put(); else img.addEventListener('load', put, { once: true });   // not decoded yet: drawn when it is
        return '1'; }
      case 'scroll': {                                         // ScrollWindow(): what is drawn moves by dx, dy
        const dx = Math.round(n(0)), dy = Math.round(n(1));    // then left, top, right, bottom of the part that moves (all of it without)
        const l = v[2] === undefined || v[2] === '' ? 0 : Math.max(0, n(2)), t = v[2] === undefined || v[2] === '' ? 0 : Math.max(0, n(3));
        const r = v[2] === undefined || v[2] === '' ? cv.width : Math.min(cv.width, n(4)), b2 = v[2] === undefined || v[2] === '' ? cv.height : Math.min(cv.height, n(5));
        const w = r - l, h = b2 - t;
        if (w <= 0 || h <= 0) return '1';
        const img = g.getImageData(l, t, w, h);
        g.clearRect(l, t, w, h);
        const ax = Math.abs(dx), ay = Math.abs(dy);
        if (ax < w && ay < h) g.putImageData(img, l + dx, t + dy, dx < 0 ? ax : 0, dy < 0 ? ay : 0, w - ax, h - ay);   // what leaves the part is cut off
        return '1'; }
      case 'size': return cv.width + ' ' + cv.height;
    }
    return '';
  }

  /* ---- Tool tips ----
     A ToolTip is not a control of the page: it is a set of tools kept by its dialog under the
     tool tip's ID, and one floating box.  A tool is a control, a rectangle of a window, or a
     whole window; its text is fixed, or asked from the program each time (text null).
       op(key, ttId, 'tip.add', JSON {key, host, rect|null, text|null})
     The page decides when a tip is due (the pointer rests on a tool).  Then:
       fixed text:  the box is shown, and ('TT', ttId, 'SHOW', toolKey) is sent
       asked text:  ('TT', ttId, 'NEEDTEXT', toolKey) is sent; the program answers tip.show
     ('TT', ttId, 'POP', toolKey) is sent when the box goes.  For a tool the program manages
     itself, ('TT', ttId, 'RELAY', toolKey + SEP + x + SEP + y) is sent for each pointer move over a
     window named by op(key, ttId, 'tip.relay', hostId, '1').  tip.pop ends the tip; if the
     pointer is still on the tool, the tip is due again after the delay.
     A tree-view asks for the text of the item under the pointer with its GETINFOTIP notification. */
  const tipBox = { el: null, dlg: null, tt: null, tool: null, shown: false, x: 0, y: 0 };
  function tipEl() {
    if (!tipBox.el) { tipBox.el = D.createElement('div'); tipBox.el.className = 'ood-tip'; tipBox.el.hidden = true; D.body.appendChild(tipBox.el); }
    return tipBox.el;
  }
  function tipSet(dlg, ttId) {
    dlg.tips = dlg.tips || new Map();
    if (!dlg.tips.has(ttId)) dlg.tips.set(ttId, { id: ttId, tools: [], delay: 500, maxWidth: 0, title: '', active: true, events: '', hosts: new Set(), relayHosts: new Set(), rearm: null, rearmHost: -1 });
    return dlg.tips.get(ttId);
  }
  function tipHide(silent) {
    if (tipBox.shown) {
      tipBox.shown = false; tipEl().hidden = true;
      if (!silent && tipBox.tt && tipBox.tt.events.includes('POP') && ood.dialogs.has(tipBox.dlg.key)) fire(tipBox.dlg.key, 'TT', tipBox.tt.id, 'POP', tipBox.tool ? tipBox.tool.key : '');
    }
    tipBox.tool = null;
  }
  function tipDisplay(dlg, tt, tool, text) {
    if (text === '' || !tt.active) return;
    const el = tipEl(); el.textContent = '';
    if (tt.title) { const b = D.createElement('b'); b.textContent = tt.title; el.appendChild(b); }
    const body = D.createElement('div'); body.textContent = text; el.appendChild(body);
    el.style.maxWidth = tt.maxWidth > 0 ? tt.maxWidth + 'px' : '';
    el.style.whiteSpace = tt.maxWidth > 0 || text.includes('\n') ? 'pre-wrap' : 'nowrap';
    el.hidden = false;
    el.style.left = Math.min(tipBox.x + 12, W.innerWidth - el.offsetWidth - 4) + 'px';
    el.style.top = Math.min(tipBox.y + 20, W.innerHeight - el.offsetHeight - 4) + 'px';
    tipBox.shown = true; tipBox.dlg = dlg; tipBox.tt = tt; tipBox.tool = tool;
    if (tt.events.includes('SHOW')) fire(dlg.key, 'TT', tt.id, 'SHOW', tool ? tool.key : '');
  }
  function tipDue(dlg, tt, tool) {
    tipBox.dlg = dlg; tipBox.tt = tt; tipBox.tool = tool;
    if (tool.text !== null) tipDisplay(dlg, tt, tool, tool.text);
    else fire(dlg.key, 'TT', tt.id, 'NEEDTEXT', tool.key);
  }
  function tipHost(dlg, tt, hostId) {                         // watch one window (a control, or 0 the dialog) for this tool tip
    if (tt.hosts.has(hostId)) return;
    tt.hosts.add(hostId);
    const hc = hostId ? dlg.ctrls.get(hostId) : null, host = hc ? hc.el : dlg.client;
    if (!host) return;
    let current = null, timer = 0;                             // (each window has its own timer: a tip of another window is not this one's to end)
    const arm = (tool) => { clearTimeout(timer); timer = setTimeout(() => { timer = 0; if (ood.dialogs.has(dlg.key) && current === tool) tipDue(dlg, tt, tool); }, tt.delay); };
    const leave = () => { clearTimeout(timer); timer = 0; if (current && tipBox.tool === current) tipHide(); current = null; if (tt.rearm && tt.rearmHost === hostId) tt.rearm = null; };
    host.addEventListener('pointermove', (e) => {
      const r = host.getBoundingClientRect(), x = e.clientX - r.left - host.clientLeft, y = e.clientY - r.top - host.clientTop;
      if (!hostId && e.target !== host && e.target.closest('.ood-c')) { leave(); return; }   // over a control: not the dialog's own area
      tipBox.x = e.clientX; tipBox.y = e.clientY;
      const tool = tt.tools.find((t) => t.host === hostId && (!t.rect || (x >= t.rect[0] && x < t.rect[2] && y >= t.rect[1] && y < t.rect[3]))) || null;
      if (tool && (tool.relay || tt.relayHosts.has(hostId))) fire(dlg.key, 'TT', tt.id, 'RELAY', tool.key + SEP + Math.round(x) + SEP + Math.round(y));
      if (tool === current) return;
      leave(); current = tool;
      if (tool && tt.active) { arm(tool); tt.rearm = () => { if (current === tool && tt.active) arm(tool); }; tt.rearmHost = hostId; }   // (pop, with the pointer still on the tool: the tip comes again)
    });
    host.addEventListener('pointerleave', leave);
    host.addEventListener('pointerdown', () => { clearTimeout(timer); timer = 0; if (current && tipBox.tool === current) tipHide(); });
  }
  function tipTree(dlg, c) {                                   // a tree-view's own tips: the text of an item is asked with GETINFOTIP
    if (c.infoTips) return;
    c.infoTips = true;
    const tt = tipSet(dlg, 60000 + c.id);
    let current = '', timer = 0;
    const tool = { key: 'tv' + c.id, host: c.id, rect: null, text: null };
    const leave = () => { clearTimeout(timer); timer = 0; if (tipBox.tool === tool) tipHide(); current = ''; };
    c.el.addEventListener('pointermove', (e) => {
      const row = e.target.closest ? e.target.closest('.ood-tvrow') : null, h = row ? row.dataset.h : '';
      tipBox.x = e.clientX; tipBox.y = e.clientY;
      if (h === current) return;
      leave(); current = h;
      if (!h || !dlg.subs.has(c.id + '.GETINFOTIP')) return;
      timer = setTimeout(() => { timer = 0; if (!ood.dialogs.has(dlg.key) || current !== h) return;
        tipBox.dlg = dlg; tipBox.tt = tt; tipBox.tool = tool;
        note(dlg, c, 'GETINFOTIP', h); }, tt.delay);
    });
    c.el.addEventListener('pointerleave', leave);
    c.el.addEventListener('pointerdown', leave);
  }
  function tipOp(dlg, ttId, name, a, b) {
    const tt = tipSet(dlg, ttId);
    switch (name) {
      case 'add': { const t = JSON.parse(String(a)); tt.tools = tt.tools.filter((x) => x.key !== t.key); tt.tools.push(t); tipHost(dlg, tt, t.host);
        const hc = t.host ? dlg.ctrls.get(t.host) : null; if (hc) hc.el.removeAttribute('title'); return '1'; }
      case 'del': tt.tools = tt.tools.filter((x) => x.key !== String(a)); return '1';
      case 'text': { const t = tt.tools.find((x) => x.key === String(a)); if (!t) return '0'; t.text = b === SEP ? null : String(b); return '1'; }
      case 'relay': if (b === '1') tt.relayHosts.add(Number(a)); else tt.relayHosts.delete(Number(a)); return '1';   // the pointer's moves over this window go to the program
      case 'count': return String(tt.tools.length);
      case 'delay': tt.delay = Math.max(0, Number(a) || 0); return '1';
      case 'maxWidth': { const old = tt.maxWidth; tt.maxWidth = Number(a) || 0; return String(old || -1); }
      case 'title': tt.title = String(a); return '1';
      case 'active': tt.active = (a === '1'); if (!tt.active && tipBox.tt === tt) tipHide(); return '1';
      case 'events': tt.events = String(a); return '1';
      case 'show': if (tipBox.tt === tt && tipBox.tool) tipDisplay(dlg, tt, tipBox.tool, String(a)); return '1';   // the answer to NEEDTEXT or GETINFOTIP
      case 'pos': { const el = tipEl(); el.style.left = Number(a) + 'px'; el.style.top = Number(b) + 'px'; return '1'; }
      case 'pop': if (tipBox.tt === tt) tipHide(); if (tt.rearm) tt.rearm(); return '1';
      case 'shown': return tipBox.shown && tipBox.tt === tt ? (tipBox.tool ? tipBox.tool.key : '') + SEP + tipEl().textContent : '';
      case 'tree': { const c = dlg.ctrls.get(Number(a)); if (!c) return '0'; tipTree(dlg, c); return '1'; }
    }
    return '';
  }

  /* ---- The mouse ----
     mouseSub connects one Windows mouse event of a dialog (id 0) or a control.  The event
     goes to Rexx as ('MOUSE', id, NAME, "state x y delta"): state is the words of
     getMouseArgs() joined with commas, x and y are in the window's client area (in the
     page for MOUSEWHEEL, as Windows gives the screen), delta is the wheel's +-120. */
  const mouse = { x: 0, y: 0, buttons: 0, capture: null, cursor: '' };
  D.addEventListener('pointermove', (e) => { mouse.x = Math.round(e.clientX); mouse.y = Math.round(e.clientY); mouse.buttons = e.buttons; }, true);
  D.addEventListener('pointerdown', (e) => { mouse.buttons = e.buttons; }, true);
  D.addEventListener('pointerup', (e) => { mouse.buttons = e.buttons; }, true);
  function mouseState(e) {
    const w = [];
    if (e.ctrlKey) w.push('Control');
    if (e.buttons & 1) w.push('lButton');
    if (e.buttons & 4) w.push('mButton');
    if (e.buttons & 2) w.push('rButton');
    if (e.shiftKey) w.push('Shift');
    return w.length ? w.join(',') : 'None';
  }
  function mouseFire(dlg, id, host, name, e, delta) {
    const r = host.getBoundingClientRect();
    const sx = host.offsetWidth ? r.width / host.offsetWidth : 1, sy = host.offsetHeight ? r.height / host.offsetHeight : 1;   // a dialog scaled to fit
    const x = name === 'MOUSEWHEEL' ? Math.round(e.clientX) : Math.round((e.clientX - r.left) / (sx || 1));
    const y = name === 'MOUSEWHEEL' ? Math.round(e.clientY) : Math.round((e.clientY - r.top) / (sy || 1));
    fire(dlg.key, 'MOUSE', id, name, mouseState(e) + ' ' + x + ' ' + y + ' ' + (delta || 0));
  }
  function mouseSub(dlg, c, el, name) {
    const id = c ? c.id : 0, host = c ? el : dlg.client;
    dlg.mouseSubs = dlg.mouseSubs || new Set();
    const tag = id + '.' + name;
    if (dlg.mouseSubs.has(tag)) return '1';
    dlg.mouseSubs.add(tag);
    const mine = (e) => !mouse.capture || mouse.capture.host === host;     // a captured mouse belongs to the capturing window
    const button = { L: 0, M: 1, R: 2 }[name[0]];
    const on = (type, f) => host.addEventListener(type, (e) => { if (mine(e)) f(e); });
    if (name === 'MOUSEMOVE') { let last = 0; on('pointermove', (e) => { const t = performance.now(); if (t - last < 30) return; last = t; mouseFire(dlg, id, host, name, e); }); }
    else if (name === 'MOUSEWHEEL') host.addEventListener('wheel', (e) => { e.preventDefault(); e.stopPropagation(); mouseFire(dlg, id, host, name, e, e.deltaY < 0 ? 120 : -120); }, { passive: false });   // the program scrolls, not the browser
    else if (name === 'MOUSELEAVE') on('pointerleave', (e) => mouseFire(dlg, id, host, name, e));
    else if (name === 'MOUSEHOVER') { let t = 0; on('pointerenter', (e) => { clearTimeout(t); t = setTimeout(() => mouseFire(dlg, id, host, name, e), 400); }); host.addEventListener('pointerleave', () => clearTimeout(t)); }
    else if (/BUTTONDOWN$/.test(name)) on('pointerdown', (e) => { if (e.button === button) mouseFire(dlg, id, host, name, e); });
    else if (/BUTTONUP$/.test(name)) on('pointerup', (e) => { if (e.button === button) mouseFire(dlg, id, host, name, e); });
    else if (/BUTTONDBLCLK$/.test(name)) on(button === 0 ? 'dblclick' : 'auxclick', (e) => { if (e.button === button && (button === 0 || e.detail === 2)) mouseFire(dlg, id, host, name, e); });
    else return '0';
    return '1';
  }
  // While a window has captured the mouse, moves and button releases anywhere on the page are its own.
  for (const [type, names] of [['pointermove', ['MOUSEMOVE']], ['pointerup', ['LBUTTONUP', 'MBUTTONUP', 'RBUTTONUP']]]) {
    D.addEventListener(type, (e) => {
      const cap = mouse.capture;
      if (!cap || cap.host.contains(e.target)) return;
      const name = type === 'pointermove' ? names[0] : names[e.button] || names[0];
      if (cap.dlg.mouseSubs && cap.dlg.mouseSubs.has(cap.id + '.' + name)) mouseFire(cap.dlg, cap.id, cap.host, name, e);
    }, true);
  }
  function mouseOp(dlg, c, el, verb, a) {
    const host = c ? el : dlg.client, id = c ? c.id : 0;
    switch (verb) {
      case 'capture': { const old = mouse.capture; mouse.capture = { dlg, id, host }; return old ? old.dlg.key + ' ' + old.id : ''; }
      case 'release': { const old = mouse.capture; mouse.capture = null; return old ? old.dlg.key + ' ' + old.id : ''; }
      case 'getCapture': return mouse.capture ? mouse.capture.dlg.key + ' ' + mouse.capture.id : '';
      case 'state': return mouse.x + ' ' + mouse.y + ' ' + mouse.buttons;
      case 'cursor': {                                         // a CSS cursor name, or the key of a cursor file known to the page
        const old = mouse.cursor; mouse.cursor = String(a);
        const url = ood.images.get(String(a));
        D.body.style.cursor = url ? 'url("' + url + '"), auto' : String(a);
        for (const d of ood.dialogs.values()) d.el.style.cursor = D.body.style.cursor;
        return old; }
    }
    return '';
  }

  ood.op = function (key, id, name, a, b, c2) {
    const dlg = ood.dialogs.get(Number(key)); if (!dlg) return '';
    id = Number(id);
    if (name.startsWith('tip.')) return tipOp(dlg, id, name.slice(4), a, b);   // (a tool tip's ID is not a control's)
    const c = id === 0 ? null : dlg.ctrls.get(id);
    if (id !== 0 && !c) return name === 'exists' ? '0' : '';
    const el = c ? c.el : dlg.el, m = c ? c.main : dlg.el;
    switch (name) {
      case 'exists': return '1';
      case 'kind': return c.kind;
      case 'getText':
        if (!c) return dlg.capEl.textContent;
        if (c.kind === 'EDIT' || (c.kind === 'COMBO' && !c.droplist)) return m.value;
        if (c.kind === 'COMBO') return m.selectedIndex >= 0 ? m.options[m.selectedIndex].textContent : '';
        if (c.kind === 'LIST') return m.selectedIndex >= 0 ? m.options[m.selectedIndex].textContent : '';
        if (c.parts) return c.parts[0].text;
        return c.rawText != null ? c.rawText : (c.textEl || m).textContent;
      case 'setText':
        a = String(a);
        if (!c) { dlg.capEl.textContent = a; return '1'; }
        if (c.parts) { c.parts[0].text = a; stbRender(c); return '1'; }      // (WM_SETTEXT of a status bar: its first part)
        if (c.kind === 'EDIT') { m.value = a; if (m.tagName === 'TEXTAREA') { try { m.setSelectionRange(0, 0); } catch (e) { } m.scrollTop = 0; } cmd(dlg, c, 0x400); cmd(dlg, c, 0x300); return '1'; }   // (WM_SETTEXT leaves the caret at the start)   // as WM_SETTEXT: EN_UPDATE, EN_CHANGE
        if (c.kind === 'COMBO' && !c.droplist) { m.value = a; return '1'; }
        if (c.kind === 'GROUP' && !c.textEl.parentNode && a !== '') el.appendChild(c.textEl);
        c.rawText = a; label(c.textEl || m, a); return '1';
      case 'show': el.hidden = false; if (!c) el.style.visibility = 'visible'; return '1';
      case 'hide': if (c) el.hidden = true; else el.style.visibility = 'hidden'; return '1';
      case 'isVisible': return c ? (el.hidden ? '0' : '1') : (el.style.visibility === 'hidden' ? '0' : '1');
      case 'enable': if (c) { m.disabled = (a === '0'); paintButton(c); } else el.inert = (a === '0'); return '1';
      case 'isEnabled': return c ? (m.disabled ? '0' : '1') : (el.inert ? '0' : '1');
      case 'focus': m.focus(); return '1';
      case 'focusId': { const f = dlg.all.find((x) => x.main === D.activeElement); return f ? String(f.id) : '0'; }
      case 'tab': {
        const f = dlg.all.filter((x) => x.focusable && !x.main.disabled && !x.el.hidden && x.main.tabIndex >= 0);
        const i = f.findIndex((x) => x.main === D.activeElement);
        if (f.length) f[(i + (a === '1' ? 1 : f.length - 1)) % f.length].main.focus();
        return '1'; }
      case 'rect': { const r = el.getBoundingClientRect(); return [r.left, r.top, r.right, r.bottom].map(Math.round).join(' '); }
      case 'gdi': return gdi(dlg, c, el, a, String(b).split(SEP), String(c2).split(SEP));
      case 'clientRect': { const r = (c ? el : dlg.client).getBoundingClientRect(); return '0 0 ' + Math.round(r.width) + ' ' + Math.round(r.height); }
      case 'origin': { const r = dlg.client.getBoundingClientRect(); return Math.round(r.left) + ' ' + Math.round(r.top); }
      case 'move': {
        let x = Number(a), y = Number(b);
        if (c && c.parentCtl) { x += c.parentCtl.el.offsetLeft + c.parentCtl.el.clientLeft; y += c.parentCtl.el.offsetTop + c.parentCtl.el.clientTop; }   // a child of another control: in that one's client area
        el.style.left = x + 'px'; el.style.top = y + 'px'; return '1'; }
      case 'tabStops': {                                       // the stops in pixels; the options already there are shown anew
        if (!c) return '0';
        c.tabStops = String(a).split(' ').filter(Boolean).map(Number).sort((x, y) => x - y);
        for (const op of optsOf(c)) { const shown = listTabbed(c, op.textContent); if (shown !== null) op.label = shown; else op.removeAttribute('label'); }
        return '1'; }
      case 'setParent': {                                      // SetParent(): the control is shown on, and placed in, another control
        const p = dlg.ctrls.get(Number(a)); if (!c || !p) return "0";
        c.parentCtl = p; el.style.zIndex = 6; return '1'; }
      case 'grandChild': {                                     // isGrandChild(): RETURN, ESCAPE, TAB and losing the focus go to the dialog
        if (!c || c.gc) return '1';
        c.gc = true; c.gcTab = (a === '1');
        const m2 = c.main || el;
        m2.addEventListener('keydown', (e) => {
          const key = { Enter: 'enter', Escape: 'escape', Tab: 'tab' }[e.key];
          if (!key) return;
          e.preventDefault(); e.stopPropagation();             // not the dialog's default button, not its cancel
          if (key !== 'tab' || c.gcTab) fire(dlg.key, 'GC', c.id, key);
        });
        m2.addEventListener('blur', () => { if (!el.hidden) fire(dlg.key, 'GC', c.id, 'killfocus'); });
        return '1'; }
      case 'size':
        if (c) { el.style.width = Number(a) + 'px'; if (c.kind !== 'COMBO' || c.simple) el.style.height = Number(b) + 'px'; }   // (a drop-down combo's height is that of its list)
        else { dlg.client.style.width = Number(a) + 'px'; dlg.client.style.height = Math.max(0, Number(b) - dlg.titleEl.offsetHeight) + 'px'; if (dlg.child && dlg.ra) raLayout(dlg); }   // (an embedded dialog has no observer: lay it out now)
        return '1';
      case 'closeBox': { const x = dlg.titleEl.querySelector('.ood-x'); if (x) { x.disabled = (a === '0'); x.style.opacity = a === '0' ? '.35' : ''; } dlg.noClose = (a === '0'); return '1'; }
      case 'top': el.style.zIndex = ++ood.z; return '1';
      case 'default': {                                     // DM_SETDEFID
        const old = dlg.ctrls.get(dlg.defId); if (old && old.kind === 'BUTTON') old.main.classList.remove('ood-def');
        dlg.defId = Number(a); const nw = dlg.ctrls.get(dlg.defId); if (nw && nw.kind === 'BUTTON') nw.main.classList.add('ood-def');
        return '1'; }
      case 'color': { const t = c ? m : dlg.client; if (a !== '') t.style.background = a; if (b !== '') t.style.color = b; return '1'; }   // (a dialog's colour is its client area's)
      case 'font': if (a !== '') m.style.fontFamily = a; if (b !== '') m.style.fontSize = b; if (c2) m.style.fontWeight = c2; return '1';
      case 'textSize': {
        const s = D.createElement('span'); s.style.cssText = 'position:absolute;visibility:hidden;white-space:pre'; s.textContent = String(a);
        dlg.client.appendChild(s); const r = s.getBoundingClientRect(); s.remove();
        return Math.ceil(r.width) + ' ' + Math.ceil(r.height); }
      // edit
      case 'sel': return (m.selectionStart + 1) + ' ' + (m.selectionEnd + 1);
      case 'replaceSel': m.setRangeText(String(a), m.selectionStart, m.selectionEnd, 'end'); c.modified = true; return '1';
      case 'line': { const ls = m.value.split('\n'); return ls[Number(a) - 1] == null ? '' : ls[Number(a) - 1]; }
      case 'cue': m.placeholder = String(a); return '1';
      case 'getCue': return m.placeholder || '';
      case 'tabStop': { const t = c ? c.main : null; if (!t) return '0'; t.tabIndex = a === '1' ? 0 : -1; return '1'; }
      case 'optUid': { const o = optsOf(c)[Number(a)]; if (!o) return '0'; if (!o.dataset.uid) o.dataset.uid = String(c.optUid = (c.optUid || 0) + 1); return o.dataset.uid; }   // an item of a combo or list box, however it moves
      case 'lineOf': { const at = a === '' || Number(a) < 0 ? m.selectionStart : Number(a); return String(m.value.slice(0, at).split('\n').length - 1); }           // EM_LINEFROMCHAR
      case 'lineStart': { const ls = m.value.split('\n'); let n = a === '' || Number(a) < 0 ? m.value.slice(0, m.selectionStart).split('\n').length - 1 : Number(a);
        if (n >= ls.length) return '-1'; let at = 0; for (let k = 0; k < n; k++) at += ls[k].length + 1; return String(at); }                                       // EM_LINEINDEX
      case 'lineLen': { const ls = m.value.split('\n'); const n = a === '' || Number(a) < 0 ? m.value.slice(0, m.selectionStart).split('\n').length - 1 : Number(a); return ls[n] == null ? '0' : String(ls[n].length); }
      case 'tabSize': m.style.tabSize = String(Math.max(1, Number(a))); return '1';
      case 'pad': { const t = c ? c.el : dlg.client; if (a !== '') t.style.padding = String(a).split(' ').map((x) => x + 'px').join(' '); const g = getComputedStyle(t); return [g.paddingLeft, g.paddingTop, g.paddingRight, g.paddingBottom].map((x) => Math.round(parseFloat(x))).join(' '); }
      case 'rowHeight': { const r = c.el.querySelector('.ood-tvrow, tr, option'); return String(r ? Math.round(r.getBoundingClientRect().height) : 16); }
      case 'backdrop': { const url = ood.images.get(String(a)); if (!url) return '0'; const t = c ? c.el : dlg.client;
        t.style.backgroundImage = 'url("' + url + '")'; t.style.backgroundRepeat = has(String(b), 'TILE') || b === '' ? 'repeat' : 'no-repeat';
        if (has(String(b), 'STRETCH')) t.style.backgroundSize = '100% 100%'; return '1'; }   // a tool tip: the browser's own
      // list box and combo box; positions zero-based
      case 'add': return String(listInsert(c, -1, String(a)));
      case 'insert': return String(listInsert(c, Number(a), String(b)));
      case 'itemText': { const k = optsOf(c)[Number(a)]; return k ? k.textContent : ''; }
      case 'find': return String(listFind(c, String(a), Number(b), c2 === '1'));
      case 'selItems': return Array.from(m.options).map((op, i) => op.selected ? i + 1 : 0).filter(Boolean).join(' ');
      case 'selectText': {
        const i = listFind(c, String(a), -1, false);
        if (c.kind === 'LIST' || c.droplist) m.selectedIndex = i; else m.value = i >= 0 ? optsOf(c)[i].textContent : String(a);
        return String(i); }
    }
    if (c && name === 'bitmap') {                             // installBitmapButton: normal, focused|selected|disabled, style
      const [f, sel, dis] = String(b).split(SEP), st = String(c2);
      c.bmp = { n: String(a), f: f || '', s: sel || '', d: dis || '', stretch: has(st, 'STRETCH'), frame: has(st, 'FRAME') };
      if (c.kind === 'BUTTON') { c.main.textContent = ''; paintButton(c); }
      return '1';
    }
    if (c && name === 'isDropList') return c.droplist ? '1' : '0';
    if (name === 'ra.init') return raInit(dlg, String(a));
    if (name === 'ra.page') { if (!c) return '0'; (c.raPages = c.raPages || []).push(Number(a)); return '1'; }
    if (name === 'ra.limits') { if (!dlg.ra) return '0'; raLimits(dlg, JSON.parse(String(a)), JSON.parse(String(b))); return '1'; }
    if (name === 'mouseSub') return mouseSub(dlg, c, el, String(a));
    if (name === 'mouse') return mouseOp(dlg, c, el, String(a), b);
    if (c && name === 'bitmapPos') { c.bmpPos = [Number(a) || 0, Number(b) || 0]; paintButton(c); return '1'; }
    if (c && name === 'image') {                              // a static's image
      const url = ood.images.get(String(a));
      if (c.img) { c.img.src = url || ''; c.img.hidden = !url; if (b === 'STRETCH') c.img.style.cssText = 'width:100%;height:100%'; }
      return url ? '1' : '0';
    }
    if (c && c.mc && name.startsWith('mc.')) return mcOp(dlg, c, name.slice(3), a, b);
    if (c && name === 'dtp.get') return dtpGet(c);
    if (c && name === 'dtp.set') { dtpSet(c, new Date(String(a))); return '1'; }
    if (c && name === 'pointFont') { m.style.fontFamily = '"' + a + '","Segoe UI",Tahoma,sans-serif'; m.style.fontSize = Math.round(Number(b) * 96 / 72 * ood.scale * 100) / 100 + 'px'; const st = String(c2); m.style.fontWeight = st.includes('B') ? 'bold' : 'normal'; m.style.fontStyle = st.includes('I') ? 'italic' : 'normal'; m.style.textDecoration = st.includes('U') ? 'underline' : 'none'; return '1'; }
    if (c && name === 'ud.range') return c.min + ' ' + c.max;
    if (c && name === 'ud.buddy') { const old = c.buddy; if (a !== '') c.buddy = Number(a); return String(old); }
    if (c && name.startsWith('lv.')) { if (!LV_DATA_OPS.has(name)) flushRender(c); return lvOp(dlg, c, name.slice(3), a, b, c2); }
    if (c && c.parts && name.startsWith('sb.')) return stbOp(dlg, c, name.slice(3), a, b);
    if (c && c.btns && name.startsWith('tb.')) return tbOp(dlg, c, name.slice(3), a, b, c2);
    if (c && name.startsWith('cd.')) return cdOp(dlg, c, name.slice(3), a);
    if (c && name.startsWith('tv.')) return tvOp(dlg, c, name.slice(3), a, b, c2);
    if (c && name.startsWith('tab.')) return tabOp(dlg, c, name.slice(4), a, b, c2);
    ood.log.push('op ' + name);
    return '';
  };

  /* ---- Tool bar ----
     A button: {cmd, text, style, state, image}.  style and state are sets of the Windows
     keywords (style: BUTTON SEP CHECK GROUP CHECKGROUP DROPDOWN ...; state: ENABLED CHECKED
     PRESSED HIDDEN INDETERMINATE MARKED ...).  A click on an enabled button sends
     ('CMD', cmd, 0), as a push button does.  A CHECK button turns CHECKED on and off; a
     CHECKGROUP button is checked and the others of its run of CHECKGROUP buttons are not.
     Indexes are from 0 here.  Images are not drawn: a button shows its text. */
  function tbRender(dlg, c) {
    c.el.textContent = '';
    c.btns.forEach((b, i) => {
      if (b.state.has('HIDDEN')) return;
      if (b.style.has('SEP')) { const sp = D.createElement('span'); sp.className = 'ood-tbsep'; c.el.appendChild(sp); return; }
      const e = D.createElement('button'); e.type = 'button'; e.className = 'ood-tbbtn'; e.dataset.cmd = String(b.cmd); e.textContent = b.text;
      e.disabled = !b.state.has('ENABLED');
      if (b.state.has('CHECKED') || b.state.has('PRESSED')) e.classList.add('ood-pushed');
      if (b.state.has('INDETERMINATE')) e.style.opacity = '.6';
      if (b.style.has('CHECK') || b.style.has('CHECKGROUP')) e.setAttribute('aria-pressed', b.state.has('CHECKED') ? 'true' : 'false');
      e.addEventListener('click', () => {
        if (b.style.has('CHECKGROUP')) {
          let lo = i, hi = i;
          while (lo > 0 && c.btns[lo - 1].style.has('CHECKGROUP')) lo--;
          while (hi < c.btns.length - 1 && c.btns[hi + 1].style.has('CHECKGROUP')) hi++;
          for (let k = lo; k <= hi; k++) c.btns[k].state.delete('CHECKED');
          b.state.add('CHECKED'); tbRender(dlg, c);
        } else if (b.style.has('CHECK')) { if (b.state.has('CHECKED')) b.state.delete('CHECKED'); else b.state.add('CHECKED'); tbRender(dlg, c); }
        fire(dlg.key, 'CMD', b.cmd, 0);
      });
      c.el.appendChild(e);
    });
  }
  function tbOp(dlg, c, name, a, b, c2) {
    const words = (t) => new Set(String(t).toUpperCase().split(' ').filter(Boolean));
    const byCmd = (cmd) => c.btns.find((x) => x.cmd === Number(cmd) && !x.style.has('SEP'));
    const show = (x) => [x.cmd, x.text, [...x.style].join(' '), [...x.state].join(' '), x.image].join(SEP);
    switch (name) {
      case 'insert': { const parts = String(b).split(SEP), at = Number(a);            // insert(index or -1, cmd SEP text SEP style SEP state SEP image)
        const btn = { cmd: Number(parts[0]), text: parts[1] || '', style: words(parts[2] || 'BUTTON'), state: words(parts[3] || ''), image: Number(parts[4] || -1) };
        if (at < 0 || at >= c.btns.length) c.btns.push(btn); else c.btns.splice(at, 0, btn);
        tbRender(dlg, c); return '1'; }
      case 'count': return String(c.btns.length);
      case 'indexOf': return String(c.btns.findIndex((x) => x.cmd === Number(a) && !x.style.has('SEP')));
      case 'get': return c.btns[Number(a)] ? show(c.btns[Number(a)]) : '';
      case 'byCmd': { const x = byCmd(a); return x ? show(x) : ''; }
      case 'setText': { const x = byCmd(a); if (!x) return '0'; x.text = String(b); tbRender(dlg, c); return '1'; }
      case 'setImage': { const x = byCmd(a); if (!x) return '0'; x.image = Number(b); return '1'; }
      case 'setState': { const x = byCmd(a); if (!x) return '0'; if (c2 === '1') x.state.add(String(b)); else x.state.delete(String(b)); tbRender(dlg, c); return '1'; }
      case 'has': { const x = byCmd(a); return x && x.state.has(String(b)) ? '1' : '0'; }
      case 'height': return String(Math.round(c.el.getBoundingClientRect().height));
    }
    return '';
  }

  /* ---- Status bar ----
     Parts are numbered from 0 here.  A part's edge is its right edge in pixels of the bar; -1 is
     "to the end of the bar".  In simple mode the bar shows one text and hides its parts. */
  function stbRender(c) {
    const el = c.el || c.main; if (!el) return;
    el.textContent = '';
    if (c.simple) { const p = D.createElement('div'); p.className = 'ood-stbpart'; p.style.flex = '1'; p.textContent = c.simpleText; el.appendChild(p); return; }
    let left = 0;
    c.parts.forEach((part, i) => {
      const p = D.createElement('div'); p.className = 'ood-stbpart'; p.dataset.part = String(i); p.textContent = part.text; if (part.tip) p.title = part.tip;
      if (part.edge < 0) p.style.flex = '1'; else { p.style.width = Math.max(0, part.edge - left) + 'px'; left = part.edge; }
      el.appendChild(p);
    });
  }
  function stbOp(dlg, c, name, a, b) {
    const i = Number(a), part = c.parts[i];
    switch (name) {
      case 'setParts': { const edges = String(a).split(' ').map(Number); if (!edges.length || edges.some((e) => !Number.isInteger(e))) return '0';
        c.parts = edges.map((e, k) => ({ edge: e, text: c.parts[k] ? c.parts[k].text : '', tip: c.parts[k] ? c.parts[k].tip : '' })); stbRender(c); return '1'; }
      case 'parts': return c.parts.map((p) => p.edge).join(' ');
      case 'setText': if (i === 255 || c.simple && a === '') { c.simpleText = String(b); stbRender(c); return '1'; } if (!part) return '0'; part.text = String(b); stbRender(c); return '1';
      case 'text': if (i === 255) return c.simpleText; return part ? part.text : '';
      case 'has': return part || i === 255 ? '1' : '0';                // (part 256 of Windows, here 255, is the simple mode's text)
      case 'setTip': if (!part) return '0'; part.tip = String(b); stbRender(c); return '1';
      case 'tip': return part ? part.tip : '';
      case 'simple': c.simple = (a === '1'); stbRender(c); return '1';
      case 'isSimple': return c.simple ? '1' : '0';
      case 'rect': { const p = c.el.querySelector('[data-part="' + i + '"]'); if (!p) return ''; const o = c.el.getBoundingClientRect(), r = p.getBoundingClientRect();
        return [r.left - o.left, r.top - o.top, r.right - o.left, r.bottom - o.top].map(Math.round).join(' '); }
      case 'minHeight': c.el.style.minHeight = Number(a) + 'px'; return '1';
      case 'bk': { const old = c.el.style.background || ''; c.el.style.background = String(a); return old; }
    }
    return '';
  }
  function lvOp(dlg, c, name, a, b, c2) {
    const i = Number(a);
    switch (name) {
      case 'insCol': {
        const [text, w, fmt] = String(b).split(SEP); const at = i < 0 || i > c.cols.length ? c.cols.length : i;
        c.cols.splice(at, 0, { text, w: Number(w), fmt: fmt || 'left' });
        c.rows.forEach((r) => { if (r.cells.length > at) r.cells.splice(at, 0, ''); });
        later(c, lvRender); return String(at); }
      case 'delCol': if (!c.cols[i]) return '0'; c.cols.splice(i, 1); c.rows.forEach((r) => r.cells.splice(i, 1)); later(c, lvRender); return '1';
      case 'hit': {                                            // the row and column at a point of the client area: "row col", row -1 for none
        const o = c.el.getBoundingClientRect(), x = o.left + Number(a), y = o.top + Number(b);
        const trs = [...c.el.querySelectorAll('tbody tr')];
        for (let r = 0; r < trs.length; r++) {
          const q = trs[r].getBoundingClientRect();
          if (y < q.top || y >= q.bottom || x < q.left || x >= q.right) continue;
          const tds = [...trs[r].children]; let col = 0;
          tds.forEach((td, k) => { const t = td.getBoundingClientRect(); if (x >= t.left && x < t.right) col = k; });
          return r + ' ' + col;
        }
        return '-1 0'; }
      case 'rect': {                                           // the row's rectangle, or with a column that cell's, in the client area: "l t r b"
        const tr = c.el.querySelectorAll('tbody tr')[i]; if (!tr) return '';
        const cell = (b === '' || b === undefined || Number(b) < 0) ? tr : tr.children[Number(b)]; if (!cell) return '';
        const o = c.el.getBoundingClientRect(), q = cell.getBoundingClientRect();
        const l = Math.round(q.left - o.left - c.el.clientLeft), t = Math.round(q.top - o.top - c.el.clientTop);
        return l + ' ' + t + ' ' + (l + Math.round(q.width)) + ' ' + (t + Math.round(q.height)); }
      case 'colCount': return String(c.cols.length);
      case 'colInfo': return c.cols[i] ? c.cols[i].text + SEP + c.cols[i].w + SEP + c.cols[i].fmt : '';
      case 'setColWidth': if (!c.cols[i]) return '0'; c.cols[i].w = Number(b); later(c, lvRender); return '1';
      case 'insRow': {
        const at = i < 0 || i > c.rows.length ? c.rows.length : i;
        c.rows.splice(at, 0, { cells: String(b).split(SEP), sel: false, chk: false, uid: ++c.uid });
        if (c.focusIdx >= at) c.focusIdx++;
        later(c, lvRender); return c2 === 'U' ? at + ' ' + c.uid : String(at); }       // (with 'U': the index and the new row's uid)
      case 'setCell': if (!c.rows[i]) return '0'; c.rows[i].cells[Number(b)] = String(c2); later(c, lvRender); return '1';
      case 'cell': return c.rows[i] && c.rows[i].cells[Number(b)] != null ? c.rows[i].cells[Number(b)] : '';
      case 'del': if (!c.rows[i]) return '0'; c.rows.splice(i, 1); if (c.focusIdx === i) c.focusIdx = -1; else if (c.focusIdx > i) c.focusIdx--; later(c, lvRender); return '1';
      case 'clear': c.rows = []; c.focusIdx = -1; later(c, lvRender); return '1';
      case 'next': return String(lvNext(c, i, String(b)));
      case 'state':
        if (!c.rows[i]) return '0';
        if (b === 'SELECT') { if (c.single) c.rows.forEach((r, k) => { if (k !== i) lvSel(dlg, c, k, false); }); lvSel(dlg, c, i, true); }
        else if (b === 'DESELECT') lvSel(dlg, c, i, false); else lvFocus(dlg, c, i);
        return '1';
      case 'itemState': return c.rows[i] ? [(c.rows[i].sel ? 'SELECTED' : ''), (i === c.focusIdx ? 'FOCUSED' : '')].filter(Boolean).join(' ') : '';
      case 'deselAll': c.rows.forEach((r, k) => lvSel(dlg, c, k, false)); return '1';
      case 'check':
        c.rows.forEach((r, k) => { if ((i < 0 || k === i) && !!r.chk !== (b === '1')) { r.chk = b === '1'; note(dlg, c, 'CHECK', k + SEP + (r.chk ? 'CHECKED' : 'UNCHECKED')); } });
        later(c, lvRender); return '1';
      case 'isChecked': return c.rows[i] && c.rows[i].chk ? '1' : '0';
      case 'ex':
        if (a === 'GET') return Array.from(c.ex).join(' ');
        String(b).split(/\s+/).filter(Boolean).forEach((w) => { if (a === 'ADD') c.ex.add(w); else c.ex.delete(w); });
        later(c, lvRender); return '1';
      case 'find': {
        const t = String(a).toLowerCase(), n = c.rows.length, start = Number(b), partial = has(String(c2), 'P'), wrap = has(String(c2), 'W');
        for (let k = 1; k <= n; k++) {
          let j = start + k; if (j >= n) { if (!wrap) break; j -= n; }
          const v = String(c.rows[j].cells[0] || '').toLowerCase();
          if (partial ? v.startsWith(t) : v === t) return String(j);
        }
        return '-1'; }
      case 'view': if (a === '') return c.view; c.view = String(a); later(c, lvRender); return '1';
      case 'uid': return c.rows[i] ? String(c.rows[i].uid) : '0';
      case 'order': {                                          // the rows in a new order: the uids, in the order wanted
        const by = new Map(c.rows.map((r) => [r.uid, r])), focus = c.rows[c.focusIdx], out = [];
        for (const u of String(a).split(' ')) { const r = by.get(Number(u)); if (r) { out.push(r); by.delete(Number(u)); } }
        for (const r of by.values()) out.push(r);
        c.rows = out; c.focusIdx = focus ? out.indexOf(focus) : -1; lvRender(c); return '1'; }
      case 'uids': return c.rows.map((r) => r.uid).join(' ');
      case 'row': return c.rows[i] ? c.rows[i].cells.join(SEP) : '';
      case 'sort': { const col = i, dir = b === 'D' ? -1 : 1; c.rows.sort((x, y) => dir * String(x.cells[col] || '').localeCompare(String(y.cells[col] || ''), undefined, { numeric: true })); c.focusIdx = -1; later(c, lvRender); return '1'; }
    }
    return '';
  }
  function tvOp(dlg, c, name, a, b, c2) {
    const h = Number(a), nd = c.nodes.get(h);
    const sibs = (x) => (x.parent ? c.nodes.get(x.parent).kids : c.roots);
    switch (name) {
      case 'hit': {                                            // what is at a point of the client area: "handle LOCATION"
        const o = c.el.getBoundingClientRect(), t = D.elementFromPoint(o.left + c.el.clientLeft + Number(a), o.top + c.el.clientTop + Number(b));
        const row = t && c.el.contains(t) ? t.closest('.ood-tvrow') : null;
        if (!row) return '0 NOWHERE';
        const where = t.classList.contains('ood-tvtw') ? 'ONBUTTON' : t === row ? (o.left + Number(a) < row.firstElementChild.getBoundingClientRect().left ? 'ONINDENT' : 'ONRIGHT') : 'ONITEM ONLABEL';
        return row.dataset.h + ' ' + where; }
      case 'rect': {                                           // the row of an item, or only its text, in the client area: "l t r b"
        const row = c.el.querySelector('.ood-tvrow[data-h="' + h + '"]'); if (!row) return '';
        const part = b === '1' ? row.lastElementChild : row;
        const o = c.el.getBoundingClientRect(), q = part.getBoundingClientRect();
        const l = Math.round(q.left - o.left - c.el.clientLeft), t = Math.round(q.top - o.top - c.el.clientTop);
        return l + ' ' + t + ' ' + (l + Math.round(q.width)) + ' ' + (t + Math.round(q.height)); }
      case 'ins': {
        const [text, opts] = String(c2).split(SEP); const parent = c.nodes.get(h);
        const id = ++c.nextH, list = parent ? parent.kids : c.roots;
        c.nodes.set(id, { h: id, text, parent: parent ? h : 0, kids: [], open: has(opts || '', 'EXPANDED'), bold: has(opts || '', 'BOLD') });
        if (b === 'FIRST') list.unshift(id);
        else if (b === 'SORT') { let k = 0; while (k < list.length && c.nodes.get(list[k]).text.localeCompare(text) <= 0) k++; list.splice(k, 0, id); }
        else if (b === 'LAST' || b === '') list.push(id);
        else { const k = list.indexOf(Number(b)); if (k < 0) list.push(id); else list.splice(k + 1, 0, id); }
        later(c, tvRender); return String(id); }
      case 'del': if (!nd) return '0'; { const l = sibs(nd); l.splice(l.indexOf(h), 1); tvDrop(c, h); later(c, tvRender); return '1'; }
      case 'clear': c.nodes.clear(); c.roots = []; c.selH = 0; later(c, tvRender); return '1';
      case 'expand': return tvOpen(dlg, c, h, String(b)) ? '1' : '0';
      case 'find': {
        const t = String(a).toLowerCase(); let go = Number(b) === 0;
        const all = []; const walk = (l) => l.forEach((x) => { all.push(x); walk(c.nodes.get(x).kids); }); walk(c.roots);
        for (const x of all) {
          if (!go) { if (x === Number(b)) go = true; continue; }
          const v = c.nodes.get(x).text.toLowerCase(); if (c2 === '1' ? v.startsWith(t) : v === t) return String(x);
        }
        return '0'; }
      case 'rel': {
        if (!nd) return '0';
        if (b === 'CHILD') return String(nd.kids[0] || 0);
        if (b === 'PARENT') return String(nd.parent);
        const l = b.endsWith('VISIBLE') ? tvVisible(c) : sibs(nd), k = l.indexOf(h);
        if (k < 0) return '0';
        return String((b.startsWith('NEXT') ? l[k + 1] : l[k - 1]) || 0); }
      case 'kids': return (nd ? nd.kids : c.roots).join(' ');                 // the children of an item; of item 0: the root items
      case 'order': { const list = nd ? nd.kids : c.roots, want = String(b).split(' ').map(Number).filter((x) => list.includes(x));
        const rest = list.filter((x) => !want.includes(x)); list.length = 0; list.push(...want, ...rest); later(c, tvRender); return '1'; }
      case 'special': return String(a === 'ROOT' ? (c.roots[0] || 0) : a === 'SELECTED' ? c.selH : a === 'FIRSTVISIBLE' ? (c.roots[0] || 0) : 0);
      case 'info': return nd ? nd.text + SEP + nd.kids.length + SEP + [(nd.open ? 'EXPANDED' : ''), (nd.bold ? 'BOLD' : ''), (h === c.selH ? 'SELECTED' : '')].filter(Boolean).join(' ') : '';
      case 'text': return nd ? nd.text : '';
      case 'modify': {
        if (!nd) return '0'; const [flag, text, opts] = String(b).split(SEP);
        if (has(flag, 'T')) nd.text = text;
        if (has(flag, 'O')) { nd.bold = has(opts, 'BOLD') ? true : has(opts, 'NOTBOLD') ? false : nd.bold; if (has(opts, 'EXPANDED')) nd.open = !has(opts, 'NOTEXPANDED'); }
        later(c, tvRender); return '1'; }
      case 'select': if (h !== 0 && !nd) return '0'; { let p = nd && nd.parent; while (p) { c.nodes.get(p).open = true; p = c.nodes.get(p).parent; } tvSelect(dlg, c, h, 'UNKNOWN'); later(c, tvRender); return '1'; }
    }
    return '';
  }
  function tabOp(dlg, c, name, a, b) {
    const i = Number(a);
    switch (name) {
      case 'ins': { const at = i < 0 || i > c.tabs.length ? c.tabs.length : i; c.tabs.splice(at, 0, { text: String(b) }); if (c.cur < 0) c.cur = 0; else if (at <= c.cur) c.cur++; tabRender(c); return String(at); }
      case 'text': return c.tabs[i] ? c.tabs[i].text : '';
      case 'setText': if (!c.tabs[i]) return '0'; c.tabs[i].text = String(b); tabRender(c); return '1';
      case 'selectText': { const t = String(a).toLowerCase(), k = c.tabs.findIndex((x) => plain(x.text).toLowerCase() === t || x.text.toLowerCase() === t); if (k >= 0) { c.cur = k; tabRender(c); } return String(k); }
      case 'outer': { const o = dlg.client.getBoundingClientRect(), r = c.el.getBoundingClientRect(); return [r.left - o.left, r.top - o.top, r.right - o.left, r.bottom - o.top].map(Math.round).join(' '); }   // the whole control, in the dialog's client area
      case 'rect': { const o = dlg.client.getBoundingClientRect(), r = c.page.getBoundingClientRect(); return [r.left - o.left + 2, r.top - o.top + 2, r.right - o.left - 2, r.bottom - o.top - 2].map(Math.round).join(' '); }
    }
    return '';
  }

  /* ---- message box ------------------------------------------------------ */
  /* ---- Handing a file to the user (the standby printer) ----
     ood.deliver(name, mime, hex, title): the bytes of a file of the program's file system, as
     hex.  The page has no printer and no desktop, so it shows the file in a panel with four
     actions, each started by the user's own click (a browser refuses them otherwise):
     Print (the browser's print of the shown file), Open (a new tab), Save (a download), Close.
     ood.delivered lists what was handed over: {name, mime, size, title, magic}. */
  ood.windowAt = function (x, y) {                            // the window at a point of the screen: "key id", or ''
    const t = D.elementFromPoint(Number(x), Number(y)); if (!t) return '';
    for (const d2 of [...ood.dialogs.values()].reverse()) { if (!d2.el.contains(t)) continue; const k = d2.all.find((q) => q.id > 0 && q.el.contains(t)); return d2.key + ' ' + (k ? k.id : 0); }
    return '';
  };
  ood.delivered = [];
  ood.deliver = function (name, mime, hex, title) {
    boot();
    hex = String(hex);
    const bytes = new Uint8Array(hex.length >> 1);
    for (let i = 0; i < bytes.length; i++) bytes[i] = parseInt(hex.substr(i * 2, 2), 16);
    const url = URL.createObjectURL(new Blob([bytes], { type: String(mime) }));
    ood.delivered.push({ name: String(name), mime: String(mime), size: bytes.length, title: String(title || name), magic: String.fromCharCode(...bytes.slice(0, 5)), url });
    D.querySelectorAll('.ood-deliver').forEach((x) => x.remove());
    const el = D.createElement('div'); el.className = 'ood-deliver'; el.style.zIndex = ++ood.z + 100000;
    const bar = D.createElement('div'); bar.className = 'ood-deliverbar';
    const cap = D.createElement('span'); cap.textContent = String(title || name) + '  (' + name + ', ' + bytes.length + ' bytes)'; bar.appendChild(cap);
    const view = D.createElement('iframe'); view.className = 'ood-deliverview'; view.title = String(title || name); view.src = url;
    const act = (label, make) => { const a = D.createElement('a'); a.textContent = label; a.href = url; a.className = 'ood-deliveract'; make(a); bar.appendChild(a); return a; };
    act('Print', (a) => { a.addEventListener('click', (e) => { e.preventDefault(); try { view.contentWindow.focus(); view.contentWindow.print(); } catch (err) { W.open(url, '_blank'); } }); });
    act('Open', (a) => { a.target = '_blank'; a.rel = 'noopener'; });
    act('Save', (a) => { a.download = String(name); });
    act('Close', (a) => { a.addEventListener('click', (e) => { e.preventDefault(); el.remove(); }); });
    el.appendChild(bar); el.appendChild(view); D.body.appendChild(el);
    return String(bytes.length);
  };

  ood.msgBox = function (token, text, title, buttons, icon) {
    boot();
    const key = -Number(token);
    const names = { OK: ['OK:1'], OKCANCEL: ['OK:1', 'Cancel:2'], YESNO: ['Yes:6', 'No:7'], YESNOCANCEL: ['Yes:6', 'No:7', 'Cancel:2'],
      RETRYCANCEL: ['Retry:4', 'Cancel:2'], ABORTRETRYIGNORE: ['Abort:3', 'Retry:4', 'Ignore:5'], CANCELTRYCONTINUE: ['Cancel:2', 'Try Again:10', 'Continue:11'] };
    const set = names[String(buttons || 'OK').toUpperCase()] || names.OK;
    const back = D.createElement('div'); back.className = 'ood-back'; back.style.zIndex = ++ood.z;
    const el = D.createElement('div'); el.className = 'ood-dlg ood-msgbox'; el.style.zIndex = ++ood.z;
    el.style.fontSize = Math.round(9 * 96 / 72 * ood.scale) + 'px';
    const t = D.createElement('div'); t.className = 'ood-title'; const cap = D.createElement('span'); cap.textContent = title || ''; t.appendChild(cap);
    const body = D.createElement('div'); body.style.cssText = 'padding:1.4em 1.6em;background:#fff;white-space:pre-wrap;display:flex;gap:1em;align-items:flex-start;max-width:34em;user-select:text';
    const glyph = { ERROR: '⛔', HAND: '⛔', STOP: '⛔', WARNING: '⚠️', EXCLAMATION: '⚠️', QUESTION: '❓', INFORMATION: 'ℹ️', ASTERISK: 'ℹ️' }[String(icon || '').toUpperCase()];
    if (glyph) { const g = D.createElement('div'); g.textContent = glyph; g.style.fontSize = '2em'; g.style.lineHeight = '1'; body.appendChild(g); }
    const msg = D.createElement('div'); msg.className = 'ood-msgtext'; msg.textContent = text; body.appendChild(msg);
    const row = D.createElement('div'); row.style.cssText = 'padding:.8em 1em;display:flex;gap:.6em;justify-content:flex-end';
    const prevFocus = D.activeElement;
    const done = (v) => { el.remove(); back.remove(); if (prevFocus && prevFocus.isConnected) prevFocus.focus(); fire(key, 'MSGBOX', token, v); };
    set.forEach((s, i) => {
      const [name, v] = s.split(':'); const b = D.createElement('button'); b.className = 'ood-c'; b.textContent = name;
      b.style.cssText = 'position:static;min-width:6em;height:1.9em;padding:0 .8em'; if (i === 0) b.classList.add('ood-def');
      b.dataset.value = v; b.addEventListener('click', () => done(v)); row.appendChild(b);
    });
    el.addEventListener('keydown', (e) => { if (e.key === 'Escape') done(set.some((s) => s.endsWith(':2')) ? '2' : set[0].split(':')[1]); });
    el.append(t, body, row); D.body.append(back, el);
    el.style.left = Math.max(0, (W.innerWidth - el.offsetWidth) / 2) + 'px'; el.style.top = Math.max(0, (W.innerHeight - el.offsetHeight) / 3) + 'px';
    row.firstChild.focus();
    return '1';
  };

  /* The size of a text in dialog units of a font (no dialog needed), and in pixels. */
  ood.measure = function (text, fontName, fontSize) {
    boot();
    const box = D.createElement('div'); box.className = 'ood-dlg';
    box.style.cssText = 'visibility:hidden;left:0;top:0;border:0';
    box.style.fontSize = Math.round(Number(fontSize || 8) * 96 / 72 * ood.scale * 100) / 100 + 'px';
    if (fontName && !/^MS Shell Dlg|^MS Sans Serif|^System$/i.test(fontName)) box.style.fontFamily = '"' + fontName + '","Segoe UI",Tahoma,sans-serif';
    const base = D.createElement('span'); base.style.whiteSpace = 'nowrap';
    base.textContent = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    const t = D.createElement('span'); t.style.cssText = 'white-space:pre;display:inline-block'; t.textContent = String(text);
    box.append(base, D.createElement('br'), t); D.body.appendChild(box);
    const b = base.getBoundingClientRect(), r = t.getBoundingClientRect();
    box.remove();
    const fx = Math.floor((b.width / 26 + 1) / 2) / 4, fy = Math.round(b.height) / 8;
    return Math.ceil(r.width / fx) + ' ' + Math.ceil(r.height / fy) + ' ' + Math.ceil(r.width) + ' ' + Math.ceil(r.height) + ' ' + fx + ' ' + fy;
  };

  /* ---- menus ------------------------------------------------------------- */
  function menuTree(data) {                                   // records "depth id text flags", depth first
    const root = { kids: [] }, path = [root];
    String(data).split('\x1e').filter(Boolean).forEach((rec) => {
      const [depth, id, text, flags] = rec.split(SEP), it = { id: Number(id), text, flags: ' ' + (flags || '') + ' ', kids: [] };
      path.length = Number(depth) + 1; path[path.length - 1].kids.push(it); path.push(it);
    });
    return root.kids;
  }
  function closeMenus() { D.querySelectorAll('.ood-menu').forEach((m) => m.remove()); D.querySelectorAll('.ood-mopen').forEach((b) => b.classList.remove('ood-mopen')); if (ood.menuDone) { const f = ood.menuDone; ood.menuDone = null; f(0); } }
  function openMenu(items, x, y, pick, level) {
    D.querySelectorAll('.ood-menu').forEach((m) => { if (Number(m.dataset.level) >= level) m.remove(); });
    const box = D.createElement('div'); box.className = 'ood-menu'; box.dataset.level = level; box.style.zIndex = ++ood.z;
    items.forEach((it) => {
      if (it.flags.includes(' SEPARATOR ')) { box.appendChild(D.createElement('hr')); return; }
      const row = D.createElement('div'); row.className = 'ood-mi'; row.dataset.id = it.id;
      const off = it.flags.includes(' GRAYED ') || it.flags.includes(' DISABLED ');
      if (off) row.classList.add('ood-off');
      const [name, key] = it.text.split('\t');
      const mark = D.createElement('span'); mark.className = 'ood-mark'; mark.textContent = it.flags.includes(' CHECKED ') ? (it.flags.includes(' RADIO ') ? '\u2022' : '\u2713') : '';
      const tx = D.createElement('span'); tx.className = 'ood-mtext'; label(tx, name);
      const acc = D.createElement('span'); acc.className = 'ood-macc'; acc.textContent = it.kids.length ? '\u25B8' : (key || '');
      row.append(mark, tx, acc); box.appendChild(row);
      row.addEventListener('click', (e) => {
        e.stopPropagation(); if (off) return;
        if (it.kids.length) { const r = row.getBoundingClientRect(); openMenu(it.kids, r.right - 2, r.top, pick, level + 1); }
        else { ood.menuDone = null; closeMenus(); pick(it.id); }
      });
    });
    D.body.appendChild(box);
    box.style.left = Math.max(0, Math.min(x, W.innerWidth - box.offsetWidth)) + 'px';
    box.style.top = Math.max(0, Math.min(y, W.innerHeight - box.offsetHeight)) + 'px';
  }
  D.addEventListener('pointerdown', (e) => { if (!e.target.closest('.ood-menu') && !e.target.closest('.ood-menubar')) closeMenus(); }, true);
  D.addEventListener('keydown', (e) => { if (e.key === 'Escape' && D.querySelector('.ood-menu')) { e.stopPropagation(); closeMenus(); } }, true);

  ood.setMenu = function (key, data) {
    const dlg = ood.dialogs.get(Number(key)); if (!dlg) return '0';
    if (dlg.menuEl) { dlg.menuEl.remove(); dlg.menuEl = null; }
    const tops = menuTree(data); if (!tops.length) return '1';
    const bar = dlg.menuEl = D.createElement('div'); bar.className = 'ood-menubar';
    tops.forEach((it) => {
      const b = D.createElement('button'); b.type = 'button'; b.tabIndex = -1; label(b, it.text); b.dataset.id = it.id;
      if (it.flags.includes(' GRAYED ') || it.flags.includes(' DISABLED ')) b.disabled = true;
      b.addEventListener('click', () => {
        if (!it.kids.length) { closeMenus(); fire(dlg.key, 'CMD', it.id, 0); return; }
        const was = b.classList.contains('ood-mopen'); closeMenus(); if (was) return;
        b.classList.add('ood-mopen'); const r = b.getBoundingClientRect();
        openMenu(it.kids, r.left, r.bottom, (id) => fire(dlg.key, 'CMD', id, 0), 0);
      });
      bar.appendChild(b);
    });
    dlg.el.insertBefore(bar, dlg.client);
    return '1';
  };
  ood.popupMenu = function (token, x, y, data) {
    boot(); closeMenus();
    const done = (id) => fire(-Number(token), 'MSGBOX', token, id);
    ood.menuDone = done;
    openMenu(menuTree(data), Number(x), Number(y), (id) => done(id), 0);
    return '1';
  };

  /* ---- images: Rexx sends each file once, as a data URL ------------------- */
  ood.images = new Map();
  ood.image = function (name, url) { ood.images.set(String(name), String(url)); return '1'; };
  ood.hasImage = (name) => (ood.images.has(String(name)) ? '1' : '0');
  function paintButton(c) {                                   // the bitmap for the button's present state
    const b = c.bmp; if (!b) return;
    const m = c.main;
    const key = m.disabled && b.d ? b.d : c.down && b.s ? b.s : D.activeElement === m && b.f ? b.f : b.n;
    const url = ood.images.get(key);
    m.style.backgroundImage = url ? 'url("' + url + '")' : 'none';
    m.style.backgroundRepeat = 'no-repeat';
    m.style.backgroundSize = b.stretch ? '100% 100%' : 'auto';
    m.style.backgroundPosition = b.stretch ? '0 0' : c.bmpPos ? c.bmpPos[0] + 'px ' + c.bmpPos[1] + 'px' : 'center';   // setBitmapPosition: from the top left
    if (!b.frame) { m.style.border = '0'; m.style.backgroundColor = 'transparent'; }
    if (url) m.classList.add('ood-bmp');
  }

  ood.screen = () => W.innerWidth + ' ' + W.innerHeight;
  ood.setHandler = function (fn) { ood.handler = fn; return '1'; };
})(window);
