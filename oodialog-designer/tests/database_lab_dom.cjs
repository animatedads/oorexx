/* UI-wiring qualification without a browser or duplicate SQL implementation.
 * Architecture: Tom Dyer. Code: ChatGPT (GPT-6).
 * Uses a mock model only to check DOM events and message arguments. The real
 * Alchemy model is separately tested in its own package with ooRexx/WASM.
 * Run: npm install --no-save jsdom@27 && node tests/database_lab_dom.cjs
 */
const { JSDOM } = require('jsdom');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '..');
const dom = new JSDOM('<!doctype html><html><body><button id="btnLibraries">Libraries</button></body></html>', {
  url: 'http://localhost/', runScripts: 'outside-only'
});
const { window } = dom;
const { document } = window;
const databases = new Map();
let current = '';
let labLanguage = '';
const graphFixture = [
  'TABLE\taddress\t0',
  'COLUMN\taddress\tid\tINTEGER\t0\t1\t0',
  'COLUMN\taddress\tcity\tTEXT\t1\t0\t0',
  'TABLE\tperson\t1',
  'COLUMN\tperson\tid\tINTEGER\t0\t1\t0',
  'COLUMN\tperson\tname\tTEXT\t0\t0\t1',
  'TABLE\tperson_address\t0',
  'COLUMN\tperson_address\tid\tINTEGER\t0\t1\t0',
  'COLUMN\tperson_address\tperson_id\tINTEGER\t0\t0\t0',
  'COLUMN\tperson_address\taddress_id\tINTEGER\t0\t0\t0',
  'FK\tperson_address\tperson_id\tperson\tid\tCASCADE',
  'FK\tperson_address\taddress_id\taddress\tid\tRESTRICT',
  'TABLE\tperson_ext\t0',
  'COLUMN\tperson_ext\tid\tINTEGER\t0\t1\t0'
].join('\n').replace(/\\t/g, '\t');
let graphCurrentFixture = graphFixture;
const graphAddedLinks = [];
const model = {
  async module_version() { return '0.1.3'; },
  async language(lang) { labLanguage = lang; return lang; },
  async databaseNames() { return [...databases.keys()].join('\n'); },
  async name() { return current; },
  async createDatabase(name) { assert.match(name, /^[A-Za-z_][A-Za-z0-9_]*$/); databases.set(name, new Map()); current = name; return true; },
  async openDatabase(name) { assert(databases.has(name)); current = name; return true; },
  async tableNames() { return [...databases.get(current).keys()].join('\n'); },
  async graphLines(extra) { assert.equal(typeof extra, 'string'); return graphCurrentFixture + graphAddedLinks.join('') + (extra ? '\n' + extra : ''); },
  async addRelationship(parent, parentColumn, child, childColumn, onDelete) {
    assert.equal(typeof parent, 'string');
    assert.equal(typeof onDelete, 'string');
    const line = '\n' + ['FK', child, childColumn, parent, parentColumn, onDelete].join('\t');
    assert(!graphAddedLinks.some((item) => item.includes('\t' + childColumn + '\t')), 'duplicate relation refused by mock');
    graphAddedLinks.push(line);
    return 'SUCCESS';
  },
  async schema(name) { return databases.get(current).get(name).columns; },
  async createTable(name, columns) { assert(columns.includes('id\tINTEGER\t0\t1\t0')); databases.get(current).set(name, { columns, rows: [] }); return 'SUCCESS'; },
  async replaceEmptyTable(name, columns) {
    const table = databases.get(current).get(name);
    if (table.rows.length) {
      if (labLanguage === 'de') {
        throw new Error('Error 93.900: Incorrect call to method. (Die Tabelle enthält Zeilen; eine Schemamigration wird noch nicht unterstützt.)');
      }
      throw new Error('Table contains rows; schema migration is not yet supported');
    }
    table.columns = columns; return 'SUCCESS';
  },
  async dropTable(name) { databases.get(current).delete(name); return 'SUCCESS'; },
  async previewJSON(name) {
    const table = databases.get(current).get(name);
    return JSON.stringify({ status: 'SUCCESS', error: 'SUCCESS', message: '', rowCount: table.rows.length,
      affectedRows: 0, rows: table.rows, truncated: false });
  },
  async executeJSON(sql) {
    const table = databases.get(current).get('customers');
    if (/^INSERT /i.test(sql)) table.rows.push({ id: 1, name: 'Ada' });
    if (/^DELETE /i.test(sql)) table.rows = [];
    return JSON.stringify({ status: 'SUCCESS', error: 'SUCCESS', message: '', rowCount: table.rows.length,
      affectedRows: table.rows.length, rows: table.rows, truncated: false });
  }
};
const runtime = {
  async start({ files }) {
    assert(files['/home/rexx/OodDatabaseLab.cls']);
    assert(files['/home/rexx/NoSQLServer.cls']);
    assert(files['/home/rexx/AlchemyObject.cls']);
    return { async loadPackage(name) { assert.equal(name, 'OodDatabaseLab.cls'); }, async eval(source) { assert(source.includes('.OodDatabaseLab~new')); return model; } };
  }
};
window.fetch = async (url) => {
  const resolved = path.resolve(root, 'site', url);
  assert(resolved.startsWith(path.resolve(root, 'site') + path.sep));
  return { ok: true, async text() { return fs.readFileSync(resolved, 'utf8'); } };
};
window.confirm = () => true;
window.OodNlsPage = { lang: 'en', has(key) { return key === 'db.graphDelete'; }, apply() {} };
window.OodT = (key) => key === 'db.graphDelete' ? (window.OodNlsPage.lang === 'de' ? 'BEI LÖSCHEN' : 'ON DELETE') : key;
window.eval(fs.readFileSync(path.join(root, 'site/database-lab.js'), 'utf8'));
window.OodDatabaseLabPage.setup(runtime);
const click = (id) => document.getElementById(id).click();
const tick = () => new Promise((resolve) => setTimeout(resolve, 15));
async function until(predicate, message) {
  for (let i = 0; i < 300; i++) { if (predicate()) return; await tick(); }
  throw new Error('Timed out: ' + message + '; ' + document.getElementById('dbNotice')?.textContent);
}

(async () => {
  click('btnDatabaseLab');
  await until(() => window.OodDatabaseLabPage.state.ready, 'model loaded');
  assert(!document.getElementById('dbOverlay').hidden);
  click('dbTabGraph');
  await until(() => document.querySelector('#dbGraph p'), 'empty graph without an open database');
  assert(!document.getElementById('dbNotice').classList.contains('bad'), 'empty graph does not raise an error');
  click('dbTabSql');
  document.getElementById('dbNew').value = 'TestBrowser';
  click('dbCreate');
  await until(() => document.getElementById('dbCurrent').textContent === 'TestBrowser', 'database created');
  document.getElementById('dbTableName').value = 'customers';
  click('dbMakeTable');
  await until(() => document.querySelector('#dbTables option[value="customers"]'), 'table created');
  document.getElementById('dbSql').value = "INSERT INTO customers VALUES (1,'Ada')";
  click('dbRun');
  await until(() => document.getElementById('dbResults').textContent.includes('Ada'), 'SQL execution');
  click('dbReplace');
  await until(() => document.getElementById('dbNotice').textContent.includes('Table contains rows'), 'populated schema refused');
  window.OodNlsPage.lang = 'de';
  click('dbClose'); click('btnDatabaseLab');
  await until(() => labLanguage === 'de', 'model switched to German');
  click('dbReplace');
  await until(() => document.getElementById('dbNotice').textContent.includes('Die Tabelle enthält Zeilen'), 'German refusal');
  assert(!document.getElementById('dbNotice').textContent.includes('Error 93.900'), 'ooRexx wrapper stripped');
  document.getElementById('dbSql').value = 'DELETE FROM customers WHERE id=1';
  click('dbRun');
  await until(() => !databases.get('TestBrowser').get('customers').rows.length, 'row removed');
  click('dbAddCol');
  const last = document.querySelector('#dbColumns tr:last-child');
  last.querySelector('input').value = 'active';
  last.querySelector('select').value = 'BOOLEAN';
  click('dbReplace');
  await until(() => databases.get('TestBrowser').get('customers').columns.includes('active\tBOOLEAN'), 'empty schema replaced');
  click('dbDrop');
  await until(() => databases.get('TestBrowser').size === 0, 'table dropped');
  // The UI model is a transport mock: graph lines are a catalogue fixture,
  // not inferred from DOM or parsed SQL in the browser.
  for (const name of ['address', 'person', 'person_ext', 'person_address']) {
    databases.get('TestBrowser').set(name, { columns: 'id\tINTEGER\t0\t1\t0', rows: [] });
  }
  click('dbOpen');
  await until(() => document.querySelector('#dbTables option[value="person"]'), 'graph fixtures selected');
  click('dbTabGraph');
  await until(() => document.querySelector('.db-graph-svg'), 'SVG graph rendered');
  assert.equal(document.querySelectorAll('.db-graph-table').length, 3, 'three ordinary table boxes');
  assert.equal(document.querySelectorAll('.db-graph-junction').length, 1, 'link table is a compact junction');
  assert.equal(document.querySelectorAll('.db-graph-edges path[marker-end]').length, 2, 'two FK arrows');
  assert(document.getElementById('dbGraph').textContent.includes('BEI LÖSCHEN CASCADE'), 'German FK label');
  const stableSvg = document.querySelector('.db-graph-svg').outerHTML;
  click('dbGraphRefresh');
  await until(() => document.querySelector('.db-graph-svg')?.outerHTML === stableSvg, 'stable layout');
  const objectLines = [
    'OBJECT\tPERSON\tENT.person',
    'PART\tPERSON\t-\tEXT\tENT.person_ext\t-\tOWNED',
    'PART\tPERSON\taddresses\tLINK\tENT.address\tENT.person_address\tSHARED',
    'FUTURE\tunknown'
  ].join('\n').replace(/\\t/g, '\t');
  document.getElementById('dbObjectLines').value = objectLines;
  click('dbGraphRefresh');
  await until(() => document.querySelector('.db-graph-objects rect'), 'object outline rendered');
  assert(document.getElementById('dbGraph').textContent.includes('addresses 1..n'), 'PART association caption');
  assert(!document.getElementById('dbGraph').textContent.includes('FUTURE'), 'unknown kinds ignored');
  const personBox = document.querySelector('.db-graph-table[data-table="person"]');
  const extBox = document.querySelector('.db-graph-table[data-table="person_ext"]');
  const personRect = personBox.querySelector('rect'), extRect = extBox.querySelector('rect');
  assert.equal(personRect.getAttribute('y'), extRect.getAttribute('y'), 'EXT beside its main table');
  personBox.dispatchEvent(new window.Event('click', { bubbles: true }));
  await until(() => document.getElementById('dbTableName').value === 'person', 'table click selects schema editor');
  assert(document.getElementById('dbTabGraph').classList.contains('on'), 'graph tab remains active');

  // Graph authoring: one pointer drag plus one click-to-connect fallback.
  graphCurrentFixture += '\n' + [
    'TABLE\tcustomers\t0', 'COLUMN\tcustomers\tid\tINTEGER\t0\t1\t0',
    'TABLE\tsales\t0', 'COLUMN\tsales\tid\tINTEGER\t0\t1\t0',
    'TABLE\tcustomers_sales\t0', 'COLUMN\tcustomers_sales\tcustomers_id\tINTEGER\t0\t0\t0',
    'COLUMN\tcustomers_sales\tsales_id\tINTEGER\t0\t0\t0'
  ].join('\n');
  click('dbGraphRefresh');
  await until(() => document.querySelector('.db-graph-column[data-db-table="customers"][data-db-column="id"]'), 'relationship source rendered');
  document.getElementById('dbGraphOnDelete').value = 'CASCADE';
  const source = document.querySelector('.db-graph-column[data-db-table="customers"][data-db-column="id"]');
  const targetColumn = document.querySelector('.db-graph-column[data-db-table="customers_sales"][data-db-column="customers_id"]');
  const schemaSvg = document.querySelector('.db-graph-svg');
  Object.defineProperty(schemaSvg, 'viewBox', { value: { baseVal: { x: 0, y: 0, width: 1120, height: 900 } } });
  function pointer(type, id, x) {
    const event = new window.MouseEvent(type, { bubbles: true, cancelable: true, button: 0, clientX: x, clientY: 50 });
    Object.defineProperty(event, 'pointerId', { value: id });
    return event;
  }
  source.dispatchEvent(pointer('pointerdown', 7, 10));
  window.dispatchEvent(pointer('pointermove', 7, 55));
  targetColumn.dispatchEvent(pointer('pointerup', 7, 55));
  await until(() => graphAddedLinks.length === 1, 'first FK persisted through model');
  assert.equal(graphAddedLinks[0], '\nFK\tcustomers_sales\tcustomers_id\tcustomers\tid\tCASCADE', 'pointer drag respects ON DELETE');
  await until(() => document.getElementById('dbGraph').textContent.includes('BEI LÖSCHEN CASCADE'), 'first link drawn in German');
  document.getElementById('dbGraphOnDelete').value = 'RESTRICT';
  document.querySelector('.db-graph-column[data-db-table="sales"][data-db-column="id"]').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
  document.querySelector('.db-graph-column[data-db-table="customers_sales"][data-db-column="sales_id"]').dispatchEvent(new window.MouseEvent('click', { bubbles: true }));
  await until(() => graphAddedLinks.length === 2, 'second FK persisted by selecting two columns');
  assert.equal(graphAddedLinks[1], '\nFK\tcustomers_sales\tsales_id\tsales\tid\tRESTRICT', 'second link retains action');
  await until(() => document.querySelectorAll('.db-graph-junction').length === 2, 'new link table becomes compact junction');
  click('dbTabSql');
  assert(!document.getElementById('dbSqlPanel').hidden, 'SQL tab restored');
  click('dbClose');
  assert(document.getElementById('dbOverlay').hidden);
  console.log('DATABASE LAB DOM: 30 interaction checks PASS');
})().catch((error) => { console.error(error); process.exitCode = 1; });
