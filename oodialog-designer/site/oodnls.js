/* oodnls.js -- a page's texts from ooRexx ::RESOURCE string tables, read by
   OodNls (OodNls.cls) in the page's ooRexx/WASM session.  Used by the ooDialog
   Designer and the ooRexx Object Editor.
   Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

   await OodNlsPage.load(sess, ['OodUi', 'OxUi'], lang)
       each class (an OodNls with use, tableLines, languages) picks lang, or the
       nearest it has; their tables are merged.  Answers the language used.
   T(key, a1, a2, ...)   a text; %1, %2 take the arguments in one pass, as
       OodNls~nls does (ported here because a page needs its text at once).
   OodNlsPage.apply()    the page's data-nls, data-nls-title, -placeholder,
       -aria and -rich (`code` in it) attributes, from the table.
   OodNlsPage.languages  the languages every class has, the base first. */
(function () {
  'use strict';
  const D = document;
  const page = { table: {}, lang: '', languages: [] };
  function T(key, ...args) {
    const text = page.table[String(key).toUpperCase()];
    if (text === undefined) return '<' + key + '>';
    if (!args.length) return text;
    let out = '', i = 0;
    for (;;) {
      const p = text.indexOf('%', i); if (p < 0) break;
      const m = /^[0-9]*/.exec(text.slice(p + 1))[0], k = Number(m);
      if (m && k > 0 && k <= args.length) { out += text.slice(i, p) + String(args[k - 1]); i = p + 1 + m.length; }
      else { out += text.slice(i, p + 1); i = p + 1; }
    }
    return out + text.slice(i);
  }
  const has = (key) => page.table[String(key).toUpperCase()] !== undefined;
  function setRich(el, text) {
    el.textContent = '';
    text.split('`').forEach((part, i) => el.append(i % 2 ? Object.assign(D.createElement('code'), { textContent: part }) : part));
  }
  function apply(root) {
    const r = root || D;
    r.querySelectorAll('[data-nls]').forEach((e) => { e.textContent = T(e.dataset.nls); });
    r.querySelectorAll('[data-nls-title]').forEach((e) => { e.title = T(e.dataset.nlsTitle); });
    r.querySelectorAll('[data-nls-placeholder]').forEach((e) => { e.placeholder = T(e.dataset.nlsPlaceholder); });
    r.querySelectorAll('[data-nls-aria]').forEach((e) => { e.setAttribute('aria-label', T(e.dataset.nlsAria)); });
    r.querySelectorAll('[data-nls-rich]').forEach((e) => setRich(e, T(e.dataset.nlsRich)));
    if (!root) D.documentElement.lang = page.lang;
  }
  async function load(sess, classes, lang) {
    const table = {}; let used = '', langs = null;
    for (const cls of classes) {
      const got = String(await sess.eval('use arg l; return .' + cls + '~use(l)', lang || ''));
      if (!used) used = got;
      for (const line of String(await sess.eval('return .' + cls + '~tableLines')).split('\n')) {
        const t = line.indexOf('\t'); if (t > 0) table[line.slice(0, t)] = line.slice(t + 1);
      }
      const these = String(await sess.eval('return .' + cls + '~languages')).split(' ').filter(Boolean);
      langs = langs ? langs.filter((l) => these.includes(l)) : these;
    }
    page.table = table; page.lang = used; page.languages = langs || [];
    return used;
  }
  window.OodT = T;
  window.OodNlsPage = { load, apply, T, has, setRich, get lang() { return page.lang; }, get languages() { return page.languages; } };
})();
