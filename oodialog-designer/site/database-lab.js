/* Database Lab UI for the ooDialog Designer and Object Editor.
 * Architecture: Tom Dyer. Code: ChatGPT (GPT-6).
 * Only DOM and transport live here. A separate ooRexx/WASM session loads
 * Alchemy's OodDatabaseLab + NoSQLServer; JS never owns a database or schema.
 */
(function () {
  'use strict';
  const D = document;
  const $ = (id) => D.getElementById(id);
  const T = (key) => window.OodNlsPage?.has(key) ? window.OodT(key) : key;
  const state = { runtime: null, session: null, lab: null, pending: Promise.resolve(), ready: false, relations: false,
    graphSource: null, graphPointer: null, graphSuppressClick: false };
  const types = ['INTEGER', 'VARCHAR', 'TEXT', 'DECIMAL', 'BOOLEAN', 'DATE', 'DATETIME', 'BLOB'];

  // The worker's 93.900 wrapper is transport syntax, not part of the
  // localized refusal that OodDatabaseLab raised (same contract as designer.js).
  function textError(error) {
    let message = String(error?.message || error);
    const at = message.search(/Error 93\.900:\s*/);
    if (at >= 0) {
      message = message.slice(at).replace(/Error 93\.900:\s*/, '').split('\n')[0];
      const inner = /^[^(]*\((.*)\.\)$/.exec(message);
      return inner ? inner[1] : message;
    }
    return message.split('\n')[0];
  }
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
    state.relations = String(await state.lab.module_version()) === '0.1.3';
    await state.lab.language(window.OodNlsPage?.lang || '');
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
    await refreshGraph();
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

  // Graph lines are a projection of NoSQLServer definitions, never SQL
  // parsed in the browser. OBJECT/PART come from ObjectStore~graphLines.
  const svgNS = 'http://www.w3.org/2000/svg';
  const svgEl = (name, attrs = {}) => {
    const el = D.createElementNS(svgNS, name);
    for (const [key, value] of Object.entries(attrs)) el.setAttribute(key, String(value));
    return el;
  };
  const keyOf = (name) => String(name || '').split('.').pop().toLowerCase();
  const byName = (a, b) => a.name.toLowerCase() < b.name.toLowerCase() ? -1 : a.name.toLowerCase() > b.name.toLowerCase() ? 1 : 0;
  function parseGraph(source) {
    const tables = new Map(), objects = [], parts = [];
    for (const raw of String(source).split(/\r?\n/)) {
      const f = raw.split('\t'), kind = f[0];
      if (kind === 'TABLE' && f.length >= 3) {
        tables.set(keyOf(f[1]), { name: f[1], rows: f[2], columns: [], fks: [] });
      } else if (kind === 'COLUMN' && f.length >= 7) {
        const t = tables.get(keyOf(f[1]));
        if (t) t.columns.push({ name: f[2], type: f[3], nullable: f[4] === '1', primary: f[5] === '1', unique: f[6] === '1' });
      } else if (kind === 'FK' && f.length >= 6) {
        const t = tables.get(keyOf(f[1]));
        if (t) t.fks.push({ column: f[2], parent: f[3], parentColumn: f[4], onDelete: f[5] });
      } else if (kind === 'OBJECT' && f.length >= 3) {
        objects.push({ name: f[1], primary: f[2] });
      } else if (kind === 'PART' && f.length >= 7 && ['ONE', 'MANY', 'LINK', 'EXT'].includes(f[3])) {
        parts.push({ owner: f[1], attribute: f[2], kind: f[3], target: f[4], link: f[5], ownership: f[6] });
      }
      // Unknown line kinds are intentionally ignored.
    }
    const sorted = [...tables.values()].sort(byName);
    for (const t of sorted) {
      const fkNames = new Set(t.fks.map((f) => keyOf(f.column)));
      const other = t.columns.filter((c) => !fkNames.has(keyOf(c.name)));
      t.junction = t.fks.length === 2 && new Set(t.fks.map((f) => keyOf(f.parent))).size === 2 &&
        other.length <= 1 && (other.length === 0 || other[0].primary);
    }
    return { tables, sorted, objects: objects.sort(byName), parts };
  }

  function graphLayout(g) {
    const pos = new Map(), normal = g.sorted.filter((t) => !t.junction), junctions = g.sorted.filter((t) => t.junction);
    const ordered = [], placed = new Set();
    function include(name) {
      const k = keyOf(name), t = g.tables.get(k);
      if (t && !t.junction && !placed.has(k)) { ordered.push(t); placed.add(k); }
    }
    // Keep extension tables directly beside their owning primary table.
    for (const o of g.objects) {
      include(o.primary);
      for (const p of g.parts.filter((p) => p.owner === o.name && p.kind === 'EXT')) include(p.target);
    }
    for (const t of normal) include(t.name);
    let y = 70;
    for (let i = 0; i < ordered.length; i += 2) {
      const pair = ordered.slice(i, i + 2);
      pair.forEach((t, col) => pos.set(keyOf(t.name), { x: col ? 690 : 70, y, w: 360, h: 52 + t.columns.length * 23, junction: false }));
      y += Math.max(...pair.map((t) => pos.get(keyOf(t.name)).h)) + 90;
    }
    for (const [i, t] of junctions.entries()) {
      const parents = t.fks.map((f) => pos.get(keyOf(f.parent))).filter(Boolean);
      const centre = parents.length ? parents.reduce((sum, p) => sum + p.y + p.h / 2, 0) / parents.length : y;
      const h = 42 + t.fks.length * 18;
      pos.set(keyOf(t.name), { x: 485, y: Math.max(45, centre - h / 2 + i * 82), w: 150, h, junction: true });
    }
    const height = Math.max(210, ...[...pos.values()].map((p) => p.y + p.h + 80));
    return { pos, width: 1120, height };
  }

  function graphText(parent, x, y, value, attrs = {}) {
    const el = svgEl('text', { x, y, ...attrs });
    el.textContent = String(value);
    parent.append(el);
    return el;
  }
  function graphAnchor(t, position, column, side) {
    const index = t.junction ? Math.max(0, t.fks.findIndex((f) => keyOf(f.column) === keyOf(column))) :
      Math.max(0, t.columns.findIndex((c) => keyOf(c.name) === keyOf(column)));
    return { x: position.x + (side === 'right' ? position.w : side === 'left' ? 0 : position.w / 2),
      y: position.y + (t.junction ? 40 + index * 18 : 44 + index * 23) };
  }
  function graphColumn(element) {
    return element?.closest?.('.db-graph-column') || null;
  }
  function clearGraphSource() {
    state.graphSource = null;
    $('dbGraph')?.querySelectorAll('.db-graph-column.db-link-source').forEach((el) => el.classList.remove('db-link-source'));
  }
  function selectGraphSource(column) {
    if (column.dataset.dbKey !== '1') return note(T('db.graphNeedKey'), true);
    clearGraphSource();
    state.graphSource = { table: column.dataset.dbTable, column: column.dataset.dbColumn };
    column.classList.add('db-link-source');
    note(T('db.graphChooseTarget') + ': ' + state.graphSource.table + '.' + state.graphSource.column);
  }
  function commitGraphLink(target) {
    const source = state.graphSource;
    if (!source || !target) { clearGraphSource(); return; }
    const childTable = target.dataset.dbTable, childColumn = target.dataset.dbColumn;
    clearGraphSource();
    if (!state.relations) return note(T('db.graphRequires'), true);
    if (source.table === childTable) return note(T('db.graphDifferentTable'), true);
    const action = $('dbGraphOnDelete').value;
    run(async () => {
      await state.lab.addRelationship(source.table, source.column, childTable, childColumn, action);
      await refreshGraph();
      note(T('db.graphLinked') + ': ' + source.table + '.' + source.column + ' → ' + childTable + '.' + childColumn);
    }).catch(() => {});
  }
  function graphPoint(svg, clientX, clientY) {
    const box = svg.getBoundingClientRect(), view = svg.viewBox.baseVal;
    const scaleX = view.width / (box.width || view.width), scaleY = view.height / (box.height || view.height);
    return { x: view.x + (clientX - box.left) * scaleX, y: view.y + (clientY - box.top) * scaleY };
  }
  function graphPointerDown(event) {
    const column = graphColumn(event.target);
    if (!column || column.dataset.dbKey !== '1' || event.button !== 0) return;
    selectGraphSource(column);
    const svg = column.ownerSVGElement || column.closest('svg');
    state.graphPointer = { id: event.pointerId, startX: event.clientX, startY: event.clientY,
      svg, moved: false, line: null };
    event.preventDefault();
    event.stopPropagation();
  }
  function graphPointerMove(event) {
    const drag = state.graphPointer;
    if (!drag || drag.id !== event.pointerId || !drag.svg.isConnected) return;
    if (!drag.moved && Math.hypot(event.clientX - drag.startX, event.clientY - drag.startY) < 6) return;
    drag.moved = true;
    if (!drag.line) {
      const source = drag.svg.querySelector('.db-link-source');
      if (!source) return;
      const bounds = source.getBBox ? source.getBBox() : { x: 0, y: 0, width: 0, height: 0 };
      const start = { x: bounds.x + bounds.width, y: bounds.y + bounds.height / 2 };
      drag.line = svgEl('line', { x1: start.x, y1: start.y, x2: start.x, y2: start.y,
        class: 'db-graph-drag-line' });
      drag.svg.append(drag.line);
    }
    const p = graphPoint(drag.svg, event.clientX, event.clientY);
    drag.line.setAttribute('x2', p.x); drag.line.setAttribute('y2', p.y);
  }
  function graphPointerUp(event) {
    const drag = state.graphPointer;
    if (!drag || drag.id !== event.pointerId) return;
    state.graphPointer = null;
    drag.line?.remove();
    if (!drag.moved) return; // click-to-connect is also supported
    state.graphSuppressClick = true;
    setTimeout(() => { state.graphSuppressClick = false; }, 0);
    const element = D.elementFromPoint?.(event.clientX, event.clientY) || event.target;
    const target = graphColumn(element) || graphColumn(event.target);
    if (target) commitGraphLink(target);
    else { clearGraphSource(); note(T('db.graphDropColumn'), true); }
  }
  function cancelGraphPointer() {
    state.graphPointer?.line?.remove();
    state.graphPointer = null;
    clearGraphSource();
  }
  function graphColumnActivate(event) {
    const column = graphColumn(event.target);
    if (!column || state.graphSuppressClick) return;
    event.preventDefault(); event.stopPropagation();
    if (state.graphSource && (column.dataset.dbTable !== state.graphSource.table || column.dataset.dbColumn !== state.graphSource.column)) {
      commitGraphLink(column);
    } else selectGraphSource(column);
  }
  function drawGraph(source) {
    clearGraphSource();
    const g = parseGraph(source), layout = graphLayout(g), target = $('dbGraph');
    target.textContent = '';
    if (!g.sorted.length) {
      target.append(tag('p', { textContent: T('db.graphEmpty') }));
      return;
    }
    const svg = svgEl('svg', { viewBox: '0 0 ' + layout.width + ' ' + layout.height,
      role: 'group', 'aria-label': T('db.graph'), class: 'db-graph-svg' });
    const defs = svgEl('defs'), marker = svgEl('marker', { id: 'dbFkArrow', viewBox: '0 0 10 10',
      refX: 9, refY: 5, markerWidth: 7, markerHeight: 7, orient: 'auto-start-reverse' });
    marker.append(svgEl('path', { d: 'M 0 0 L 10 5 L 0 10 Z', fill: '#537aa4' }));
    defs.append(marker); svg.append(defs);
    const outlines = svgEl('g', { class: 'db-graph-objects' }), edges = svgEl('g', { class: 'db-graph-edges' }),
      nodes = svgEl('g', { class: 'db-graph-nodes' });
    svg.append(outlines, edges, nodes);

    for (const [i, o] of g.objects.entries()) {
      const members = new Set([keyOf(o.primary)]);
      for (const p of g.parts.filter((p) => p.owner === o.name)) {
        if (p.kind === 'EXT' || p.ownership === 'OWNED') members.add(keyOf(p.target));
        if (p.kind === 'LINK' && p.link !== '-') members.add(keyOf(p.link));
      }
      const boxes = [...members].map((k) => layout.pos.get(k)).filter(Boolean);
      if (!boxes.length) continue;
      const x = Math.min(...boxes.map((p) => p.x)) - 14, y = Math.min(...boxes.map((p) => p.y)) - 26;
      const right = Math.max(...boxes.map((p) => p.x + p.w)) + 14, bottom = Math.max(...boxes.map((p) => p.y + p.h)) + 14;
      const color = ['#9263b4', '#198b80', '#ba7540', '#507fb9'][i % 4];
      outlines.append(svgEl('rect', { x, y, width: right - x, height: bottom - y, rx: 17,
        fill: color, 'fill-opacity': '0.07', stroke: color, 'stroke-width': 2, 'stroke-dasharray': '7 4' }));
      graphText(outlines, x + 12, y + 17, o.name, { fill: color, 'font-weight': 700, 'font-size': 15 });
    }
    function curve(from, to, dashed, label) {
      const mid = (from.x + to.x) / 2;
      edges.append(svgEl('path', { d: 'M ' + from.x + ' ' + from.y + ' C ' + mid + ' ' + from.y + ', ' +
        mid + ' ' + to.y + ', ' + to.x + ' ' + to.y, fill: 'none', stroke: dashed ? '#9760bd' : '#537aa4',
      'stroke-width': dashed ? 2 : 1.7, 'stroke-dasharray': dashed ? '6 4' : 'none',
      'marker-end': dashed ? '' : 'url(#dbFkArrow)' }));
      graphText(edges, mid, (from.y + to.y) / 2 - 8, label, {
        'font-size': 12, fill: dashed ? '#69428b' : '#355d86', 'text-anchor': 'middle',
        stroke: '#f9fbfd', 'stroke-width': 4, 'paint-order': 'stroke' });
    }
    for (const t of g.sorted) {
      const fromBox = layout.pos.get(keyOf(t.name));
      for (const fk of t.fks) {
        const parent = g.tables.get(keyOf(fk.parent)), toBox = layout.pos.get(keyOf(fk.parent));
        if (!parent || !toBox || !fromBox) continue;
        const side = fromBox.x + fromBox.w / 2 < toBox.x + toBox.w / 2 ? 'right' : 'left';
        curve(graphAnchor(t, fromBox, fk.column, side),
          graphAnchor(parent, toBox, fk.parentColumn, side === 'right' ? 'left' : 'right'),
          false, T('db.graphDelete') + ' ' + fk.onDelete);
      }
    }
    for (const p of g.parts) {
      const o = g.objects.find((candidate) => candidate.name === p.owner);
      if (!o) continue;
      const from = layout.pos.get(keyOf(o.primary)), to = layout.pos.get(keyOf(p.target));
      if (!from || !to) continue;
      const suffix = p.kind === 'LINK' && p.link !== '-' ? ' ' + T('db.graphVia') + ' ' + p.link.split('.').pop() : '';
      const cardinality = p.kind === 'MANY' || p.kind === 'LINK' ? '1..n' : '1..1';
      const startSide = from.x <= to.x ? 'right' : 'left';
      curve(graphAnchor(g.tables.get(keyOf(o.primary)), from, '', startSide),
        graphAnchor(g.tables.get(keyOf(p.target)), to, '', startSide === 'right' ? 'left' : 'right'),
        true, (p.attribute === '-' ? p.kind : p.attribute) + ' ' + cardinality + suffix);
    }
    for (const t of g.sorted) {
      const p = layout.pos.get(keyOf(t.name)), group = svgEl('g', { class: t.junction ? 'db-graph-junction' : 'db-graph-table',
        'data-table': t.name, role: 'button', tabindex: 0, 'aria-label': T('db.graphSelect') + ' ' + t.name });
      group.append(svgEl('rect', { x: p.x, y: p.y, width: p.w, height: p.h, rx: t.junction ? 18 : 7,
        fill: t.junction ? '#e5f8ed' : '#fff', stroke: t.junction ? '#40876d' : '#54779b', 'stroke-width': 2 }));
      graphText(group, p.x + 12, p.y + 23, t.name + ' · ' + t.rows + ' ' + T('db.graphRows'), {
        fill: '#213d5a', 'font-size': t.junction ? 13 : 16, 'font-weight': 700 });
      const fields = t.junction ? t.fks.map((fk) => ({ name: fk.column, type: fk.parent.split('.').pop() })) : t.columns;
      for (const [i, c] of fields.entries()) {
        const annotation = t.junction ? ' → ' + c.type :
          (c.primary ? '  ' + T('db.graphPK') : '') + (c.unique ? '  ' + T('db.graphUQ') : '');
        const column = t.columns.find((item) => keyOf(item.name) === keyOf(c.name)) || c;
        const rowY = p.y + (t.junction ? 42 + i * 18 : 46 + i * 23);
        const cell = svgEl('g', { class: 'db-graph-column', 'data-db-table': t.name,
          'data-db-column': c.name, 'data-db-key': column.primary || column.unique ? '1' : '0',
          tabindex: 0, role: 'button', 'aria-label': t.name + '.' + c.name });
        cell.append(svgEl('rect', { x: p.x + 5, y: rowY - (t.junction ? 14 : 18),
          width: p.w - 10, height: t.junction ? 18 : 23, rx: 3, fill: 'transparent' }));
        graphText(cell, p.x + 15, rowY, c.name + (t.junction ? annotation : '  ' + c.type + annotation),
          { fill: '#32495e', 'font-size': t.junction ? 11 : 13 });
        group.append(cell);
      }
      if (t.junction) graphText(group, p.x + p.w - 12, p.y + 22, '⋈', { 'text-anchor': 'end', fill: '#43826d' });
      const choose = () => {
        $('dbTables').value = t.name;
        run(loadTable).catch(() => {});
      };
      group.addEventListener('click', (e) => { if (!graphColumn(e.target) && !state.graphSuppressClick) choose(); });
      group.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); choose(); } });
      nodes.append(group);
    }
    target.append(svg);
  }
  async function refreshGraph() {
    if (!state.ready || !$('dbGraphPanel') || $('dbGraphPanel').hidden) return;
    if (!String(await state.lab.name())) { drawGraph(''); return; }
    drawGraph(await state.lab.graphLines($('dbObjectLines').value));
  }
  function switchTab(graph) {
    $('dbSqlPanel').hidden = graph;
    $('dbGraphPanel').hidden = !graph;
    $('dbTabSql').classList.toggle('on', !graph);
    $('dbTabGraph').classList.toggle('on', graph);
    $('dbTabSql').setAttribute('aria-selected', String(!graph));
    $('dbTabGraph').setAttribute('aria-selected', String(graph));
    if (graph) run(refreshGraph).catch(() => {});
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
    if (state.ready) await run(() => state.lab.language(window.OodNlsPage?.lang || ''));
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
        <div class="db-tabs" role="tablist" aria-label="Database Lab views">
          <button id="dbTabSql" role="tab" aria-controls="dbSqlPanel" aria-selected="true" class="on" data-nls="db.sql">SQL test bench</button>
          <button id="dbTabGraph" role="tab" aria-controls="dbGraphPanel" aria-selected="false" data-nls="db.graph">Graph</button>
        </div>
        <section id="dbSqlPanel" role="tabpanel"><h3 data-nls="db.sql">SQL test bench</h3>
          <textarea id="dbSql" spellcheck="false" aria-label="SQL" placeholder="INSERT INTO customers (id,name) VALUES (1,'Ada')"></textarea>
          <div class="db-line"><button id="dbRun" data-nls="db.run">Execute SQL</button><span data-nls="db.sqlHint">One NoSQLServer SQL statement at a time. CREATE, INSERT, UPDATE, DELETE, SELECT, DROP.</span></div>
          <div id="dbResults" class="db-results" aria-live="polite"></div>
        </section>
        <section id="dbGraphPanel" role="tabpanel" hidden><h3 data-nls="db.graph">Database graph</h3>
          <p data-nls="db.graphHint">Tables, columns and foreign keys come from the NoSQLServer catalogue. Click a table to edit its schema.</p>
          <div class="db-line db-graph-tools"><span data-nls="db.graphDragHint">Drag a primary or unique key to a foreign-key column to create a relationship.</span>
            <label for="dbGraphOnDelete" data-nls="db.graphOnDelete">ON DELETE</label>
            <select id="dbGraphOnDelete" aria-label="ON DELETE"><option value="RESTRICT">RESTRICT</option>
              <option value="CASCADE">CASCADE</option><option value="NO ACTION">NO ACTION</option><option value="SET NULL">SET NULL</option></select>
          </div>
          <label for="dbObjectLines" data-nls="db.graphObjects">ObjectStore graph lines (optional)</label>
          <textarea id="dbObjectLines" spellcheck="false" data-nls-placeholder="db.graphObjectPlaceholder" placeholder="OBJECT&#9;PERSON&#9;ENT.person"></textarea>
          <div class="db-line"><button id="dbGraphRefresh" data-nls="db.graphRefresh">Refresh graph</button></div>
          <div id="dbGraph" class="db-graph" aria-live="polite"></div>
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
    $('dbTabSql').addEventListener('click', () => switchTab(false));
    $('dbTabGraph').addEventListener('click', () => switchTab(true));
    $('dbGraphRefresh').addEventListener('click', () => run(refreshGraph).catch(() => {}));
    $('dbGraph').addEventListener('pointerdown', graphPointerDown);
    $('dbGraph').addEventListener('click', graphColumnActivate);
    $('dbGraph').addEventListener('keydown', (e) => {
      if (graphColumn(e.target) && (e.key === 'Enter' || e.key === ' ')) graphColumnActivate(e);
    });
    window.addEventListener('pointermove', graphPointerMove);
    window.addEventListener('pointerup', graphPointerUp);
    window.addEventListener('pointercancel', cancelGraphPointer);
    window.addEventListener('keydown', (e) => { if (e.key === 'Escape') cancelGraphPointer(); });
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
