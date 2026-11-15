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
        if (dlg.subs.has('0.RESIZE')) fire(key, 'WM', 0, 'RESIZE', client.clientWidth + SEP + client.clientHeight);
        clearTimeout(timer);
        timer = setTimeout(() => { if (ood.dialogs.has(key) && dlg.subs.has('0.SIZEMOVEENDED')) fire(key, 'WM', 0, 'SIZEMOVEENDED', ''); }, 250);
      }).observe(client);
    }
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
      if (dlg.subs.has('0.KEY')) fire(dlg.key, 'KEY', e.keyCode, (e.shiftKey ? 'S' : '') + (e.ctrlKey ? 'C' : '') + (e.altKey ? 'A' : ''));
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
      default:                                              // a control kind not ported yet
        el = main = D.createElement('div'); el.className = 'ood-todo'; el.textContent = spec.kind + ' ' + c.id; c.focusable = false;
    }
    c.el = el; c.main = main;
    place(dlg, el, c);
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
  function later(c, fn) { if (c.dirty) return; c.dirty = true; queueMicrotask(() => { c.dirty = false; fn(c); }); }

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
  }
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
    const hit = (e) => {
      const tr = e.target.closest('tbody tr'), td = e.target.closest('td');
      return tr ? [tr.sectionRowIndex, td ? td.cellIndex : 0] : [-1, -1];
    };
    c.el.addEventListener('click', (e) => {
      const th = e.target.closest('th');
      if (th) { note(dlg, c, 'COLUMNCLICK', th.cellIndex); return; }
      const [i, sub] = hit(e);
      if (e.target.classList.contains('ood-lvchk')) {
        c.rows[i].chk = e.target.checked; note(dlg, c, 'CHECK', i + SEP + (e.target.checked ? 'CHECKED' : 'UNCHECKED')); return;
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
        if (c.kind === 'EDIT') { m.value = a; cmd(dlg, c, 0x400); cmd(dlg, c, 0x300); return '1'; }   // as WM_SETTEXT: EN_UPDATE, EN_CHANGE
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
      case 'tip': (c ? c.el : el).title = String(a); return '1';
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
    if (c && name === 'bitmapPos') { c.bmpPos = [Number(a) || 0, Number(b) || 0]; paintButton(c); return '1'; }
    if (c && name === 'image') {                              // a static's image
      const url = ood.images.get(String(a));
      if (c.img) { c.img.src = url || ''; c.img.hidden = !url; if (b === 'STRETCH') c.img.style.cssText = 'width:100%;height:100%'; }
      return url ? '1' : '0';
    }
    if (c && name === 'dtp.get') return dtpGet(c);
    if (c && name === 'dtp.set') { dtpSet(c, new Date(String(a))); return '1'; }
    if (c && name === 'pointFont') { m.style.fontFamily = '"' + a + '","Segoe UI",Tahoma,sans-serif'; m.style.fontSize = Math.round(Number(b) * 96 / 72 * ood.scale * 100) / 100 + 'px'; const st = String(c2); m.style.fontWeight = st.includes('B') ? 'bold' : 'normal'; m.style.fontStyle = st.includes('I') ? 'italic' : 'normal'; m.style.textDecoration = st.includes('U') ? 'underline' : 'none'; return '1'; }
    if (c && name === 'ud.range') return c.min + ' ' + c.max;
    if (c && name === 'ud.buddy') { const old = c.buddy; if (a !== '') c.buddy = Number(a); return String(old); }
    if (c && name.startsWith('lv.')) return lvOp(dlg, c, name.slice(3), a, b, c2);
    if (c && name.startsWith('tv.')) return tvOp(dlg, c, name.slice(3), a, b, c2);
    if (c && name.startsWith('tab.')) return tabOp(dlg, c, name.slice(4), a, b, c2);
    ood.log.push('op ' + name);
    return '';
  };

  function lvOp(dlg, c, name, a, b, c2) {
    const i = Number(a);
    switch (name) {
      case 'insCol': {
        const [text, w, fmt] = String(b).split(SEP); const at = i < 0 || i > c.cols.length ? c.cols.length : i;
        c.cols.splice(at, 0, { text, w: Number(w), fmt: fmt || 'left' });
        c.rows.forEach((r) => { if (r.cells.length > at) r.cells.splice(at, 0, ''); });
        later(c, lvRender); return String(at); }
      case 'delCol': if (!c.cols[i]) return '0'; c.cols.splice(i, 1); c.rows.forEach((r) => r.cells.splice(i, 1)); later(c, lvRender); return '1';
      case 'colCount': return String(c.cols.length);
      case 'colInfo': return c.cols[i] ? c.cols[i].text + SEP + c.cols[i].w + SEP + c.cols[i].fmt : '';
      case 'setColWidth': if (!c.cols[i]) return '0'; c.cols[i].w = Number(b); later(c, lvRender); return '1';
      case 'insRow': {
        const at = i < 0 || i > c.rows.length ? c.rows.length : i;
        c.rows.splice(at, 0, { cells: String(b).split(SEP), sel: false, chk: false, uid: ++c.uid });
        if (c.focusIdx >= at) c.focusIdx++;
        later(c, lvRender); return String(at); }
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
      case 'sort': { const col = i, dir = b === 'D' ? -1 : 1; c.rows.sort((x, y) => dir * String(x.cells[col] || '').localeCompare(String(y.cells[col] || ''), undefined, { numeric: true })); c.focusIdx = -1; later(c, lvRender); return '1'; }
    }
    return '';
  }
  function tvOp(dlg, c, name, a, b, c2) {
    const h = Number(a), nd = c.nodes.get(h);
    const sibs = (x) => (x.parent ? c.nodes.get(x.parent).kids : c.roots);
    switch (name) {
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
      case 'rect': { const o = dlg.client.getBoundingClientRect(), r = c.page.getBoundingClientRect(); return [r.left - o.left + 2, r.top - o.top + 2, r.right - o.left - 2, r.bottom - o.top - 2].map(Math.round).join(' '); }
    }
    return '';
  }

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
