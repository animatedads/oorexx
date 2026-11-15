/* plugins.js -- the Plugins panel and the findings strip, for the ooDialog
   Designer and the ooRexx Object Editor.  Architecture: Tom Dyer.
   Code: Claude (Opus 5.5).

   The plugins and what they decide are ooRexx (OodPlugins.cls, in the page's
   session); this file shows them.  A secret setting goes from its field to
   the host's secret store (OodSecrets) and is never shown again.

   await OodPluginsPage.setup(sess, { status, rx, onChange })
   OodPluginsPage.open()                       the panel
   await OodPluginsPage.diagnose(text)         [{plugin, rule, line, column, severity, fixId, message}]
   await OodPluginsPage.fix(plugin, text, id)  the text fixed
   OodPluginsPage.show(box, findings, { onFix, onLine })   the strip
   await OodPluginsPage.setLanguage(lang) */
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
      const inp = el('input', { type: secret ? 'password' : 'text', value: secret ? '' : value, autocomplete: 'off' });
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
  }
  window.OodPluginsPage = { setup, open, diagnose, fix, show, setLanguage, enabled };
})();
