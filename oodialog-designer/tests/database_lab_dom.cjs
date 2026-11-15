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
const model = {
  async language(lang) { labLanguage = lang; return lang; },
  async databaseNames() { return [...databases.keys()].join('\n'); },
  async name() { return current; },
  async createDatabase(name) { assert.match(name, /^[A-Za-z_][A-Za-z0-9_]*$/); databases.set(name, new Map()); current = name; return true; },
  async openDatabase(name) { assert(databases.has(name)); current = name; return true; },
  async tableNames() { return [...databases.get(current).keys()].join('\n'); },
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
  async previewJSON(name) { return this.executeJSON('SELECT * FROM ' + name); },
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
window.OodNlsPage = { lang: 'en', has() { return false; }, apply() {} };
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
  click('dbClose');
  assert(document.getElementById('dbOverlay').hidden);
  console.log('DATABASE LAB DOM: 11 interaction checks PASS');
})().catch((error) => { console.error(error); process.exitCode = 1; });
