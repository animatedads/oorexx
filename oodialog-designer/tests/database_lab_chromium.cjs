/* Chromium pointer-drag qualification for the Database Lab Graph page.
 * Architecture: Tom Dyer. Code: ChatGPT (GPT-6).
 * Browser UI uses a minimal model fixture; the real ooRexx model is qualified
 * separately by Alchemy's disposable FileDatabaseEngine smoke test.
 * Run: node tests/database_lab_chromium.cjs
 */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const source = fs.readFileSync(path.join(__dirname, '../site/database-lab.js'), 'utf8');
const styles = fs.readFileSync(path.join(__dirname, '../site/database-lab.css'), 'utf8');
const lines = [
  'TABLE\tcustomers\t0', 'COLUMN\tcustomers\tid\tINTEGER\t0\t1\t0',
  'TABLE\tsales\t0', 'COLUMN\tsales\tid\tINTEGER\t0\t1\t0',
  'TABLE\tcustomers_sales\t0',
  'COLUMN\tcustomers_sales\tcustomers_id\tINTEGER\t0\t0\t0',
  'COLUMN\tcustomers_sales\tsales_id\tINTEGER\t0\t0\t0'
].join('\n');

async function drag(page, from, to) {
  const source = page.locator('.db-graph-column[data-db-table="' + from[0] + '"][data-db-column="' + from[1] + '"]');
  const target = page.locator('.db-graph-column[data-db-table="' + to[0] + '"][data-db-column="' + to[1] + '"]');
  await source.scrollIntoViewIfNeeded();
  await target.scrollIntoViewIfNeeded();
  const a = await source.boundingBox(), b = await target.boundingBox();
  assert(a && b, 'both column hit targets must be visible');
  await page.mouse.move(a.x + a.width / 2, a.y + a.height / 2);
  await page.mouse.down();
  await page.mouse.move(b.x + b.width / 2, b.y + b.height / 2, { steps: 18 });
  await page.mouse.up();
}

(async () => {
  const browser = await chromium.launch({ executablePath: '/usr/bin/chromium', headless: true,
    args: ['--no-sandbox'] });
  try {
    const page = await browser.newPage({ viewport: { width: 1512, height: 1050 } });
    const failures = [];
    page.on('pageerror', (e) => failures.push(e.message));
    await page.setContent('<!doctype html><html><body><button id="btnLibraries">Libraries</button></body></html>');
    await page.addStyleTag({ content: styles });
    await page.addScriptTag({ content: source });
    await page.evaluate((fixture) => {
      window.relations = [];
      window.OodNlsPage = { lang: 'en', has() { return false; }, apply() {} };
      window.fetch = async () => ({ ok: true, async text() { return 'OodDatabaseLab.cls\nNoSQLServer.cls\nAlchemyObject.cls\n'; } });
      const model = {
        async module_version() { return '0.1.3'; },
        async language() { return 'en'; },
        async databaseNames() { return 'test'; },
        async name() { return 'test'; },
        async tableNames() { return 'customers\nsales\ncustomers_sales'; },
        async graphLines() { return fixture + window.relations.map((r) => '\nFK\t' + r[2] + '\t' + r[3] + '\t' + r[0] + '\t' + r[1] + '\t' + r[4]).join(''); },
        async addRelationship(...args) { window.relations.push(args); return 'SUCCESS'; }
      };
      const runtime = { async start() { return {
        async loadPackage() {}, async eval() { return model; }
      }; } };
      window.OodDatabaseLabPage.setup(runtime);
    }, lines);
    await page.locator('#btnDatabaseLab').click();
    await page.waitForFunction(() => window.OodDatabaseLabPage.state.ready);
    await page.locator('#dbTabGraph').click();
    await page.locator('.db-graph-column[data-db-table="customers"][data-db-column="id"]').waitFor();
    await drag(page, ['customers', 'id'], ['customers_sales', 'customers_id']);
    await page.waitForFunction(() => window.relations.length === 1);
    assert.deepEqual(await page.evaluate(() => window.relations[0]),
      ['customers', 'id', 'customers_sales', 'customers_id', 'RESTRICT']);
    await drag(page, ['sales', 'id'], ['customers_sales', 'sales_id']);
    await page.waitForFunction(() => window.relations.length === 2);
    assert.deepEqual(await page.evaluate(() => window.relations[1]),
      ['sales', 'id', 'customers_sales', 'sales_id', 'RESTRICT']);
    await page.locator('.db-graph-junction[data-table="customers_sales"]').waitFor();
    assert.equal(failures.length, 0, 'no page JavaScript errors: ' + failures.join('; '));
    console.log('DATABASE LAB CHROMIUM: 2 pointer drags, 2 FK model intentions, junction PASS');
  } finally { await browser.close(); }
})().catch((error) => { console.error(error); process.exitCode = 1; });
