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
    const title = dlg.titleEl = D.createElement('div'); title.className = 'ood-title';
    const cap = dlg.capEl = D.createElement('span'); cap.textContent = spec.title || '';
    title.appendChild(cap);
    if (!has(opts, 'NOMENU')) {
      const x = D.createElement('button'); x.className = 'ood-x'; x.textContent = '✕'; x.tabIndex = -1;
      x.addEventListener('click', () => fire(key, 'CMD', 2, 0));
      title.appendChild(x);
    }
    const client = dlg.client = D.createElement('div'); client.className = 'ood-client';
    el.append(title, client);
    if (dlg.modal) { dlg.back = D.createElement('div'); dlg.back.className = 'ood-back'; dlg.back.style.zIndex = ++ood.z; D.body.appendChild(dlg.back); dlg.back.hidden = true; }
    el.style.zIndex = ++ood.z;
    D.body.appendChild(el);

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
    el.style.left = Math.round(left) + 'px'; el.style.top = Math.round(top) + 'px';
    ood.dialogs.set(key, dlg);
    for (const c of ctrls || []) addControl(dlg, c);
    wireDialog(dlg);
    return dlg.fx + ' ' + dlg.fy + ' ' + Math.round(rect.width) + ' ' + Math.round(rect.height);
  };

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
    });
    dlg.titleEl.addEventListener('pointerup', () => { drag = null; });
    el.addEventListener('pointerdown', () => { if (el.style.zIndex != ood.z && !dlg.modal) el.style.zIndex = ++ood.z; }, true);
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

  ood.show = function (key, how) {
    const dlg = ood.dialogs.get(Number(key)); if (!dlg) return '0';
    how = String(how || '').toUpperCase();
    const hide = has(how, 'HIDE');
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
        main.addEventListener('focus', () => cmd(dlg, c, 6));
        main.addEventListener('blur', () => cmd(dlg, c, 7));
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
      default:                                              // a control kind not ported yet
        el = main = D.createElement('div'); el.className = 'ood-todo'; el.textContent = spec.kind + ' ' + c.id; c.focusable = false;
    }
    c.el = el; c.main = main;
    place(dlg, el, c);
    if (c.kind === 'COMBO' && c.droplist) el.style.height = Math.round(12 * dlg.fy) + 'px';   // cy is the dropped height
    if (c.kind === 'COMBO' && !c.droplist) el.style.height = Math.round(12 * dlg.fy) + 'px';
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

  /* list helpers: positions are zero-based here, as in the Win32 messages */
  const optsOf = (c) => (c.items ? c.items : c.main).children;
  function listInsert(c, at, text) {
    const op = D.createElement('option'); op.textContent = text; if (c.items) op.value = text;
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
      case 'BUTTON': case 'CHECK': case 'RADIO':
        switch (msg) {
          case 0xF5: m.click(); return '0';                                   // BM_CLICK
          case 0xF0: return String(c.tri ? (c.state || 0) : (m.checked ? 1 : 0)); // BM_GETCHECK
          case 0xF1: if (c.tri) c.state = w; m.checked = w === 1; m.indeterminate = w === 2; return '0'; // BM_SETCHECK
          case 0xF2: return String((m.checked ? 1 : 0) | (D.activeElement === m ? 8 : 0)); // BM_GETSTATE
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
    ood.log.push('msg ' + c.kind + ' 0x' + msg.toString(16));
    return '0';
  };
  const bgr = (v) => 'rgb(' + (v & 255) + ',' + ((v >> 8) & 255) + ',' + ((v >> 16) & 255) + ')';

  /* ---- operations that carry text, and window operations ---------------- */
  ood.op = function (key, id, name, a, b, c2) {
    const dlg = ood.dialogs.get(Number(key)); if (!dlg) return '';
    id = Number(id);
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
        return c.rawText != null ? c.rawText : (c.textEl || m).textContent;
      case 'setText':
        a = String(a);
        if (!c) { dlg.capEl.textContent = a; return '1'; }
        if (c.kind === 'EDIT' || (c.kind === 'COMBO' && !c.droplist)) { m.value = a; return '1'; }
        if (c.kind === 'GROUP' && !c.textEl.parentNode && a !== '') el.appendChild(c.textEl);
        c.rawText = a; label(c.textEl || m, a); return '1';
      case 'show': el.hidden = false; if (!c) el.style.visibility = 'visible'; return '1';
      case 'hide': if (c) el.hidden = true; else el.style.visibility = 'hidden'; return '1';
      case 'isVisible': return c ? (el.hidden ? '0' : '1') : (el.style.visibility === 'hidden' ? '0' : '1');
      case 'enable': if (c) m.disabled = (a === '0'); else el.inert = (a === '0'); return '1';
      case 'isEnabled': return c ? (m.disabled ? '0' : '1') : (el.inert ? '0' : '1');
      case 'focus': m.focus(); return '1';
      case 'focusId': { const f = dlg.all.find((x) => x.main === D.activeElement); return f ? String(f.id) : '0'; }
      case 'tab': {
        const f = dlg.all.filter((x) => x.focusable && !x.main.disabled && !x.el.hidden && x.main.tabIndex >= 0);
        const i = f.findIndex((x) => x.main === D.activeElement);
        if (f.length) f[(i + (a === '1' ? 1 : f.length - 1)) % f.length].main.focus();
        return '1'; }
      case 'rect': { const r = el.getBoundingClientRect(); return [r.left, r.top, r.right, r.bottom].map(Math.round).join(' '); }
      case 'clientRect': { const r = (c ? el : dlg.client).getBoundingClientRect(); return '0 0 ' + Math.round(r.width) + ' ' + Math.round(r.height); }
      case 'origin': { const r = dlg.client.getBoundingClientRect(); return Math.round(r.left) + ' ' + Math.round(r.top); }
      case 'move': el.style.left = Number(a) + 'px'; el.style.top = Number(b) + 'px'; return '1';
      case 'size':
        if (c) { el.style.width = Number(a) + 'px'; el.style.height = Number(b) + 'px'; }
        else { dlg.client.style.width = Number(a) + 'px'; dlg.client.style.height = Math.max(0, Number(b) - dlg.titleEl.offsetHeight) + 'px'; }
        return '1';
      case 'closeBox': { const x = dlg.titleEl.querySelector('.ood-x'); if (x) { x.disabled = (a === '0'); x.style.opacity = a === '0' ? '.35' : ''; } dlg.noClose = (a === '0'); return '1'; }
      case 'top': el.style.zIndex = ++ood.z; return '1';
      case 'default': {                                     // DM_SETDEFID
        const old = dlg.ctrls.get(dlg.defId); if (old && old.kind === 'BUTTON') old.main.classList.remove('ood-def');
        dlg.defId = Number(a); const nw = dlg.ctrls.get(dlg.defId); if (nw && nw.kind === 'BUTTON') nw.main.classList.add('ood-def');
        return '1'; }
      case 'color': if (a !== '') m.style.background = a; if (b !== '') m.style.color = b; return '1';
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
    ood.log.push('op ' + name);
    return '';
  };

  /* ---- message box ------------------------------------------------------ */
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

  ood.screen = () => W.innerWidth + ' ' + W.innerHeight;
  ood.setHandler = function (fn) { ood.handler = fn; return '1'; };
})(window);
