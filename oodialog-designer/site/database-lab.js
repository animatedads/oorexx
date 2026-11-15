/* Database Lab UI for the ooDialog Designer and Object Editor.
 * Only DOM and transport live here. A separate ooRexx/WASM session loads
 * Alchemy's OodDatabaseLab + NoSQLServer; JS never owns a database or schema.
 */
(function () {
  'use strict';
  const D = document;
  const $ = (id) => D.getElementById(id);
  const T = (key) => window.OodNlsPage?.has(key) ? window.OodT(key) : key;
  const state = { runtime: null, session: null, lab: null, pending: Promise.resolve(), ready: false };
  const types = ['INTEGER', 'VARCHAR', 'TEXT', 'DECIMAL', 'BOOLEAN', 'DATE', 'DATETIME', 'BLOB'];

  function textError(error) { return String(error?.message || error).split('\n')[0]; }
  function note(message, bad) {
    $('dbNotice').textContent = message;
    $('dbNotice').classList.toggle('bad', !!bad);
  }
  function run(action) {
    const task = state.pending.then(action);
    state.pending = task.catch(() => {});
    return task.catch((error) => { note(textError(error), true); throw error; });
  }
  const tag = (tagName, props = {}) => Object.assign(D.createElement(tagName), props);

  function makeColumn(name = '', type = 'TEXT', nullable = true, primary = false, unique = false) {
    const tr = tag('tr');
    const n = tag('input', { value: name, placeholder: T('db.column') });
    const ty = tag('select');
    for (const t of types) ty.append(tag('option', { value: t, textContent: t }));
    ty.value = type;
    const nu = tag('input', { type: 'checkbox', checked: !!nullable });
    const pk = tag('input', { type: 'checkbox', checked: !!primary });
    const uq = tag('input', { type: 'checkbox', checked: !!unique });
    const del = tag('button', { textContent: '✕', title: T('db.removeColumn') });
    del.type = 'button'; del.addEventListener('click', () => tr.remove());
    for (const control of [n, ty, nu, pk, uq, del]) {
      const td = tag('td'); td.append(control); tr.append(td);
    }
    pk.addEventListener('change', () => { if (pk.checked) nu.checked = false; });
    $('dbColumns').append(tr);
  }
  function columnSpec() {
    const rows = [...$('dbColumns').children];
    return rows.map((tr) => {
      const [name, type, nullable, primary, unique] = [...tr.querySelectorAll('input, select')];
      return [name.value.trim(), type.value, nullable.checked ? '1' : '0', primary.checked ? '1' : '0', unique.checked ? '1' : '0'].join('\t');
    }).join('\n');
  }
  function setExampleColumns() {
    $('dbColumns').textContent = '';
    makeColumn('id', 'INTEGER', false, true);
    makeColumn('name', 'TEXT', false);
  }
  function selectOptions(id, names, placeholder) {
    const sel = $(id), selected = sel.value;
    sel.textContent = '';
    sel.append(tag('option', { value: '', textContent: placeholder }));
    for (const name of names) sel.append(tag('option', { value: name, textContent: name }));
    if (names.includes(selected)) sel.value = selected;
  }

  async function boot() {
    if (state.ready) return;
    note(T('db.loading'));
    const manifest = await fetch('database-lab/manifest.txt');
    if (!manifest.ok) throw new Error(T('db.notBuilt'));
    const filenames = (await manifest.text()).split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
    if (!filenames.includes('OodDatabaseLab.cls') || !filenames.includes('NoSQLServer.cls')) throw new Error(T('db.badManifest'));
    const files = {};
    for (const name of filenames) {
      if (!/^[A-Za-z][A-Za-z0-9]*\.cls$/.test(name)) throw new Error(T('db.badManifest'));
      const file = await fetch('database-lab/' + name);
      if (!file.ok) throw new Error(T('db.badManifest') + ': ' + name);
      files['/home/rexx/' + name] = await file.text();
    }
    state.session = await state.runtime.start({ files, js: { page: true, worker: true } });
    await state.session.loadPackage('OodDatabaseLab.cls');
    state.lab = await state.session.eval('return .OodDatabaseLab~new()');
    state.ready = true;
    note(T('db.sessionOnly'));
    await refreshDatabases();
  }

  async function refreshDatabases() {
    const names = String(await state.lab.databaseNames()).split('\n').filter(Boolean);
    selectOptions('dbDatabases', names, T('db.chooseDatabase'));
    $('dbCurrent').textContent = String(await state.lab.name()) || T('db.none');
  }
  async function refreshTables() {
    const names = String(await state.lab.tableNames()).split('\n').filter(Boolean);
    selectOptions('dbTables', names, T('db.chooseTable'));
    return names;
  }
  async function openDatabase(name) {
    if (!name) return note(T('db.chooseDatabase'), true);
    await state.lab.openDatabase(name);
    await refreshDatabases();
    $('dbDatabases').value = name;
    await refreshTables();
    $('dbTableName').value = '';
    setExampleColumns();
    $('dbResults').textContent = '';
    note(T('db.opened') + ' ' + name);
  }
  async function loadTable() {
    const table = $('dbTables').value;
    if (!table) return;
    $('dbTableName').value = table;
    const lines = String(await state.lab.schema(table)).split('\n').filter(Boolean);
    $('dbColumns').textContent = '';
    for (const line of lines) {
      const [name, type, nullable, primary, unique] = line.split('\t');
      makeColumn(name, type, nullable === '1', primary === '1', unique === '1');
    }
    await displayRows(await state.lab.previewJSON(table));
  }
  function displayRows(json) {
    const data = JSON.parse(String(json));
    const target = $('dbResults'); target.textContent = '';
    const title = tag('p', { textContent: [data.status, data.error, data.message, T('db.rows') + ' ' + data.rowCount, T('db.affected') + ' ' + data.affectedRows, data.truncated ? T('db.truncated') : ''].filter(Boolean).join('  ·  ') });
    target.append(title);
    if (data.status !== 'SUCCESS') { note(data.error + ': ' + data.message, true); return; }
    if (!data.rows || !data.rows.length) return;
    const table = tag('table'), thead = tag('thead'), headings = tag('tr'), tbody = tag('tbody');
    const columns = Object.keys(data.rows[0]);
    for (const c of columns) headings.append(tag('th', { textContent: c }));
    thead.append(headings);
    for (const row of data.rows) {
      const tr = tag('tr');
      for (const c of columns) tr.append(tag('td', { textContent: row[c] === null ? 'NULL' : String(row[c] ?? '') }));
      tbody.append(tr);
    }
    table.append(thead, tbody); target.append(table);
  }
  async function createTable(replace) {
    const name = $('dbTableName').value.trim(), spec = columnSpec();
    if (!name || !spec) return note(T('db.needTable'), true);
    if (replace && !confirm(T('db.confirmReplace'))) return;
    if (replace) await state.lab.replaceEmptyTable(name, spec);
    else await state.lab.createTable(name, spec);
    await refreshTables();
    $('dbTables').value = name;
    await loadTable();
    note(T(replace ? 'db.replaced' : 'db.createdTable') + ' ' + name);
  }

  async function show() {
    $('dbOverlay').hidden = false;
    await run(boot);
  }
  function hide() { $('dbOverlay').hidden = true; }

  function init(runtime) {
    state.runtime = runtime;
    const button = tag('button', { id: 'btnDatabaseLab', textContent: T('db.button') });
    button.dataset.nls = 'db.button';
    $('btnLibraries').after(button);
    button.addEventListener('click', () => show().catch(() => {}));
    const overlay = tag('div', { id: 'dbOverlay', className: 'db-overlay' });
    overlay.hidden = true;
    overlay.setAttribute('role', 'dialog'); overlay.setAttribute('aria-modal', 'true'); overlay.setAttribute('aria-label', T('db.title'));
    overlay.innerHTML = `
      <div class="db-panel">
        <div class="db-head"><h2 data-nls="db.title">Database Lab</h2><button id="dbClose" data-nls="db.close">Close</button></div>
        <div id="dbNotice" role="status"></div>
        <div class="db-grid">
          <section><h3 data-nls="db.database">Database</h3>
            <div class="db-line"><select id="dbDatabases" aria-label="Database"></select><button id="dbOpen" data-nls="db.open">Open</button></div>
            <div class="db-line"><input id="dbNew" placeholder="new_database" aria-label="New database"><button id="dbCreate" data-nls="db.create">Create</button></div>
            <p><span data-nls="db.current">Current</span>: <strong id="dbCurrent">—</strong></p>
            <h3 data-nls="db.tables">Tables</h3>
            <div class="db-line"><select id="dbTables" aria-label="Table"></select><button id="dbPreview" data-nls="db.preview">Preview</button></div>
            <button id="dbDrop" class="db-danger" data-nls="db.drop">Drop selected table…</button>
          </section>
          <section><h3 data-nls="db.schema">Table schema</h3>
            <label><span data-nls="db.tableName">Table name</span> <input id="dbTableName" placeholder="customers"></label>
            <div class="db-scroll"><table class="db-columns"><thead><tr>
              <th data-nls="db.column">Column</th><th data-nls="db.type">Type</th><th data-nls="db.nullable">Nullable</th><th data-nls="db.primary">Primary</th><th data-nls="db.unique">Unique</th><th></th>
            </tr></thead><tbody id="dbColumns"></tbody></table></div>
            <div class="db-line"><button id="dbAddCol" data-nls="db.addColumn">Add column</button>
              <button id="dbNewTable" data-nls="db.newTable">New table</button>
              <button id="dbMakeTable" data-nls="db.createTable">Create table</button>
              <button id="dbReplace" data-nls="db.replace">Replace EMPTY table…</button></div>
          </section>
        </div>
        <section><h3 data-nls="db.sql">SQL test bench</h3>
          <textarea id="dbSql" spellcheck="false" aria-label="SQL" placeholder="INSERT INTO customers (id,name) VALUES (1,'Ada')"></textarea>
          <div class="db-line"><button id="dbRun" data-nls="db.run">Execute SQL</button><span data-nls="db.sqlHint">One NoSQLServer SQL statement at a time. CREATE, INSERT, UPDATE, DELETE, SELECT, DROP.</span></div>
          <div id="dbResults" class="db-results" aria-live="polite"></div>
        </section>
        <p class="db-foot" data-nls="db.sessionOnly">Test data lives in this WASM session, not in a production database. Reloading the editor loses it.</p>
      </div>`;
    D.body.append(overlay);
    window.OodNlsPage?.apply(overlay);
    $('dbClose').addEventListener('click', hide);
    overlay.addEventListener('click', (e) => { if (e.target === overlay) hide(); });
    $('dbCreate').addEventListener('click', () => run(async () => {
      const name = $('dbNew').value.trim();
      await state.lab.createDatabase(name); await openDatabase(name);
    }).catch(() => {}));
    $('dbOpen').addEventListener('click', () => run(() => openDatabase($('dbDatabases').value)).catch(() => {}));
    $('dbTables').addEventListener('change', () => run(loadTable).catch(() => {}));
    $('dbPreview').addEventListener('click', () => run(loadTable).catch(() => {}));
    $('dbAddCol').addEventListener('click', () => makeColumn());
    $('dbNewTable').addEventListener('click', () => { $('dbTables').value = ''; $('dbTableName').value = ''; setExampleColumns(); });
    $('dbMakeTable').addEventListener('click', () => run(() => createTable(false)).catch(() => {}));
    $('dbReplace').addEventListener('click', () => run(() => createTable(true)).catch(() => {}));
    $('dbDrop').addEventListener('click', () => run(async () => {
      const name = $('dbTables').value;
      if (!name || !confirm(T('db.confirmDrop') + ' ' + name + '?')) return;
      await state.lab.dropTable(name); await refreshTables();
      $('dbColumns').textContent = ''; $('dbTableName').value = ''; $('dbResults').textContent = '';
      note(T('db.dropped') + ' ' + name);
    }).catch(() => {}));
    $('dbRun').addEventListener('click', () => run(async () => {
      const json = await state.lab.executeJSON($('dbSql').value);
      displayRows(json);
      await refreshTables();
    }).catch(() => {}));
    setExampleColumns();
  }
  window.OodDatabaseLabPage = { setup: init, state };
})();
