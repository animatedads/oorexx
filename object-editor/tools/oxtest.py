#!/usr/bin/env python3
"""oxtest.py -- drive the ooRexx Object Editor page in headless Chromium.
Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

usage: python3 tools/oxtest.py [scenario ...]     (after rexx tools/build.rex)
Scenarios: reflect, edit, requires, complete, oodialog, libraries (default: all).
Python only drives the browser (Playwright); what the editor finds and does
is ooRexx (src/ObjectEditor.cls), tested without a browser by
tests/t01_object.rex.  Each step is logged."""
import os, subprocess, sys, time, pathlib
from playwright.sync_api import sync_playwright
ROOT = pathlib.Path(__file__).resolve().parent.parent
SITE, SHOTS, PORT = ROOT / 'site', ROOT / 'shots', 8042
DESIGNER = pathlib.Path(os.environ.get('OOD_DESIGNER', ROOT.parent / 'oodialog-designer'))   # the designer's tests/fixtures/assist_mock_server.mjs
MOCK = 8975
SSCMOCK = 8979
def log(*a): print('oxtest:', *a, flush=True)
class Fail(Exception): pass
def expect(what, got, want):
    if got != want: raise Fail(f'{what}: expected {want!r}, got {got!r}')
    log('  ok', what)
def expect_in(what, part, whole):
    if part not in whole: raise Fail(f'{what}: {part!r} not in {str(whole)[:300]!r}')
    log('  ok', what)
def settle(pg, ms=500): time.sleep(ms / 1000)
def ready(pg):
    pg.goto(f'http://localhost:{PORT}/objed.html')
    pg.wait_for_function("window.oxEditor && window.oxEditor.ready === true", timeout=60000); settle(pg)   # in any language
def status(pg): return pg.inner_text('#status')
def pick_class(pg, n): pg.click(f'#classes [data-cls="{n}"]'); settle(pg, 700)
def member_rows(pg): return [r.get_attribute('data-member') for r in pg.query_selector_all('#members tbody tr')]
def row(pg, name): return pg.locator(f'#members tbody tr[data-member="{name}"]')
def source(pg):
    pg.click('#btnSource'); pg.wait_for_selector('#sourceView:not([hidden])'); t = pg.inner_text('#sourceText'); pg.click('#btnSourceClose'); return t
def popup(pg):
    pg.wait_for_timeout(700)
    return [d.get_attribute('data-label') for d in pg.query_selector_all('#pop div')] if pg.is_visible('#pop') else []
def open_method(pg, cls, name):
    pick_class(pg, cls); pg.click(f'#members tbody tr[data-member="{name}"] td.nm'); settle(pg)

def sc_reflect(pg):
    """What reflection finds: classes, hierarchy with mixin, own and inherited members."""
    ready(pg)
    expect('classes in file order', [d.get_attribute('data-cls') for d in pg.query_selector_all('#classes .cls')], ['Printable', 'Person', 'Employee'])
    pick_class(pg, 'Employee')
    expect_in('hierarchy shows the mixin', 'Employee + Printable', pg.inner_text('#hierarchy'))
    expect('own members', member_rows(pg), ['salary', 'describe'])
    pg.check('#showInherited'); settle(pg, 900)
    rows = member_rows(pg)
    expect('inherited in lookup order: mixin, then superclass', (rows.index('print') < rows.index('name') < rows.index('objectname')), True)
    expect('private attribute shown private', row(pg, 'notes').locator('td').nth(2).inner_text(), 'private')
    pg.click('#sideTabs button[data-side="CLASS"]'); settle(pg, 700)
    expect_in('class side: Person\'s fromJson inherited', 'fromJson', member_rows(pg))
    pg.screenshot(path=str(SHOTS / 'reflect.png'))

def sc_edit(pg):
    """Edits are made in the source and read back by reflection; a bad one is refused."""
    ready(pg); pick_class(pg, 'Person')
    pg.fill('#newMemberName', 'email'); pg.select_option('#newMemberKind', 'ATTRIBUTE'); pg.click('#btnAddMember'); settle(pg, 800)
    expect_in('attribute added', 'email', member_rows(pg))
    row(pg, 'age').locator('select.vis').select_option('private'); settle(pg, 800)
    expect_in('age now private in the source', '::method age private', source(pg))
    expect('reflection agrees', row(pg, 'age').locator('select.vis').input_value(), 'private')
    pg.fill('#newClassName', 'Broken'); pg.fill('#newClassSuper', 'NoSuchClass'); pg.click('#btnAddClass'); settle(pg, 800)
    expect_in('a class under a missing superclass is refused', 'does not compile', status(pg))
    expect('no class added', [d.get_attribute('data-cls') for d in pg.query_selector_all('#classes .cls')], ['Printable', 'Person', 'Employee'])
    pg.fill('#newClassName', 'Manager'); pg.fill('#newClassSuper', 'Employee'); pg.click('#btnAddClass'); settle(pg, 900)
    expect_in('Manager under Employee', 'Manager', pg.inner_text('#hierarchy'))
    expect_in('three levels down', '└ Employee', pg.inner_text('#hierarchy'))

def sc_requires(pg):
    """A ::requires loads its library: its classes appear, and complete."""
    ready(pg)
    pg.fill('#newRequires', 'nosuch.cls'); pg.click('#btnAddRequires'); settle(pg, 800)
    expect_in('a ::requires that does not load is refused', 'does not compile', status(pg))
    pg.fill('#newRequires', 'csvStream.cls'); pg.click('#btnAddRequires'); settle(pg, 900)
    expect_in('csvStream.cls lists its classes', 'CsvStream', pg.inner_text('#requires'))
    open_method(pg, 'Person', 'age')
    pg.click('#code'); pg.keyboard.press('Control+End'); pg.keyboard.type('\n  s = .CSV')
    expect_in('.CSV completes from the new library', 'CsvStream', popup(pg))
    pg.keyboard.press('Escape')

def sc_complete(pg):
    """Completion from the objects: self~, x = .Class~new, class side, expose; accepting one."""
    ready(pg); open_method(pg, 'Employee', 'describe')
    pg.click('#code'); pg.keyboard.press('Control+End'); pg.keyboard.type('\n  say self~na')
    expect('self~na', popup(pg), ['name'])
    pg.keyboard.press('Enter'); settle(pg, 300)
    expect_in('accepted', 'say self~name', pg.input_value('#code'))
    pg.keyboard.type('\n  p = .Person~new("Ann")\n  say p~')
    items = popup(pg)
    expect('p~ gives Person\'s public members, not its private ones', ('age' in items, 'addNote' in items, 'notes' in items), (True, True, False))
    pg.keyboard.press('Escape')
    pg.keyboard.type('\n  q = .Person~')
    expect_in('.Person~ gives the class side', 'fromJson', popup(pg))
    pg.keyboard.press('Escape')
    pg.keyboard.type('\n  self~')
    items = popup(pg)
    expect('self~ includes inherited and private', ('print' in items, 'notes' in items, 'salary' in items), (True, True, True))
    pg.screenshot(path=str(SHOTS / 'complete.png'))
    pg.keyboard.press('Escape')
    open_method(pg, 'Person', 'age')
    pg.click('#code'); pg.keyboard.press('Control+End'); pg.keyboard.type('\n  expose n')
    pg.keyboard.press('Control+Space')
    expect('expose gives the attributes', popup(pg), ['name', 'notes'])

def sc_oodialog(pg):
    """An ooDialog program: its main code is not run; UserDialog's chain and methods are found."""
    ready(pg); pg.select_option('#example', 'examples/Calculator.rex')
    pg.wait_for_function("document.getElementById('status').textContent.includes('Calculator')", timeout=60000); settle(pg, 900)
    expect('no dialog was shown', pg.evaluate("document.querySelector('.ood-dlg') === null"), True)
    h = pg.inner_text('#hierarchy')
    expect_in('chain through ooDialog', 'PlainBaseDialog', h); expect_in('to UserDialog', 'UserDialog', h)
    expect_in('ooDialog.cls classes listed', 'UserDialog', pg.inner_text('#requires'))
    open_method(pg, 'Calculator', 'digit')
    pg.click('#code'); pg.keyboard.press('Control+End'); pg.keyboard.type('\n  self~createPush')
    expect_in('UserDialog methods complete', 'createPushButton', popup(pg))
    pg.keyboard.press('Escape')
    pg.keyboard.type('\n  self~lcd~')
    pg.screenshot(path=str(SHOTS / 'oodialog.png'))

def sc_libraries(pg):
    """Connect to the Alchemy provider, find the logging framework, install it (with
    what it requires), see what it offers by reflection, use it: ::requires, completion."""
    ready(pg); pick_class(pg, 'Person')
    pg.click('#btnLibraries'); pg.wait_for_selector('#libPanel .lp-lib', timeout=60000)
    expect_in('Alchemy provider listed', 'Alchemy', pg.inner_text('#lpProvider'))
    pg.fill('#lpFilter', 'oorexx_logging'); pg.wait_for_timeout(1500)
    pg.click('#lpList .lp-lib[data-lib="alchemy:oorexx_logging"]')
    pg.wait_for_selector('#lpDetail h3', timeout=60000)
    expect_in('details read', 'ooRexx Logging Framework', pg.inner_text('#lpDetail'))
    pg.click('#lpInstall')
    pg.wait_for_selector('#lpGoodies details', timeout=90000)
    expect_in('installed with its ::requires', 'MethodInterposition.cls', pg.inner_text('#lpNotes'))
    g = pg.inner_text('#lpGoodies')
    expect_in('goodies found by reflection', '.LogService', g)
    pg.screenshot(path=str(SHOTS / 'libraries.png'))
    pg.click('#lpUse'); pg.wait_for_function("document.getElementById('libPanel').hidden", timeout=30000); settle(pg, 900)
    expect_in('::requires added', 'lib/alchemy/LoggingCore.cls', pg.inner_text('#requires'))
    expect_in('in the source', '::requires "lib/alchemy/LoggingCore.cls"', source(pg))
    open_method(pg, 'Person', 'age')
    pg.click('#code'); pg.keyboard.press('Control+End'); pg.keyboard.type('\n  log = .LogSer')
    expect_in('.LogSer completes from the library', 'LogService', popup(pg))
    pg.keyboard.press('Enter'); pg.keyboard.type('~new("person")\n  say log~serv')
    expect('log~ after log = .LogService~new knows serviceId', popup(pg), ['serviceId'])

def sc_ui_de(pg):
    """The editor in German (OxUi.cls ::RESOURCE strings.de): bar, panes, a
    refusal from ObjectEditor.cls, the Libraries panel; then English again."""
    ready(pg)
    pg.select_option('#uiLang', 'de'); settle(pg, 900)
    expect_in('it says so', 'Der Editor spricht jetzt de', status(pg))
    expect('the bar', [pg.inner_text('#btnOpen'), pg.inner_text('#btnSource')], ['Öffnen…', 'Quelltext'])
    expect('a column', pg.inner_text('#members th >> nth=2'), 'Sichtbarkeit')
    pg.fill('#newClassName', '1x'); pg.click('#btnAddClass'); settle(pg, 900)
    expect('a refusal from ObjectEditor.cls, in German', status(pg), 'Ein Name für class beginnt mit einem Buchstaben: 1x')
    pg.click('#btnLibraries'); pg.wait_for_selector('#libPanel:not([hidden])'); settle(pg, 900)
    expect('the Libraries panel', [pg.inner_text('#libPanel .lp-head strong'), pg.inner_text('#lpConnect')], ['Bibliotheken', 'GitHub-Repository verbinden'])
    pg.screenshot(path=str(SHOTS / 'ui_de.png'))
    pg.click('#lpClose')
    pg.select_option('#uiLang', 'en'); settle(pg, 900)
    expect('English again', pg.inner_text('#btnOpen'), 'Open…')

def sc_plugins(pg):
    """Plugins in the Object Editor: Boston Crab on, a P2 trap typed into a
    method is found and fixed, and the method compiles; then switched off."""
    ready(pg); pg.evaluate("localStorage.removeItem('oodDesigner.plugins')"); ready(pg)
    pg.click('#btnPlugins'); pg.wait_for_selector('#plugPanel:not([hidden])'); settle(pg, 600)
    pg.check('#pp-bostoncrab'); settle(pg, 1500); pg.click('#ppClose')
    open_method(pg, 'Employee', 'describe')
    body = pg.input_value('#code')
    pg.fill('#code', "tag = 'zz'x\n" + body); settle(pg, 1800)
    expect('the finding: P2', pg.get_attribute('#diag .dg', 'data-rule'), 'P2')
    pg.click('#diag .dg-fix'); settle(pg, 1800)
    expect('fixed', pg.input_value('#code').split('\n')[0], "tag = 'zz' || x")
    expect('and the method compiles', pg.inner_text('#edState'), 'compiles')
    expect('no findings left', pg.is_visible('#diag'), False)
    pg.click('#btnPlugins'); pg.wait_for_selector('#plugPanel:not([hidden])'); settle(pg, 600)
    pg.uncheck('#pp-bostoncrab'); settle(pg, 1200); pg.click('#ppClose')

def sc_assist(pg):
    """Ask... in the Object Editor: the code assistance plugin on, a key and the stand-in's address given; a proposal for a method that passes is applied and compiles; one that does not compile cannot be applied."""
    mock = subprocess.Popen(['node', str(DESIGNER / 'tests' / 'fixtures' / 'assist_mock_server.mjs'), str(MOCK)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(0.8)
    try:
        ready(pg); pg.evaluate("localStorage.removeItem('oodDesigner.plugins')"); ready(pg)
        pg.click('#btnPlugins'); pg.wait_for_selector('#plugPanel:not([hidden])'); settle(pg, 600)
        pg.check('#pp-assist'); pg.wait_for_selector('[data-plugin=assist] [data-setting="anthropic.key"]', timeout=60000)
        u = pg.locator('[data-plugin=assist] [data-setting="anthropic.url"]'); u.fill(f'http://127.0.0.1:{MOCK}'); u.press('Tab'); settle(pg, 900)
        k = pg.locator('[data-plugin=assist] [data-setting="anthropic.key"]'); k.fill('FAKE-ANTHROPIC-KEY-51'); k.press('Tab'); settle(pg, 900)
        pg.click('#ppClose')
        open_method(pg, 'Employee', 'describe')
        expect('Ask... is there', pg.is_visible('#btnAsk'), True)
        pg.click('#btnAsk'); pg.wait_for_selector('#askPanel:not([hidden])')
        expect_in('it names the method', 'describe', pg.inner_text('#akWhat'))
        pg.fill('#akTask', 'BROKEN'); pg.click('#akGo')
        pg.wait_for_function("document.getElementById('askPanel').dataset.status !== ''", timeout=60000)
        expect('a proposal that does not compile', pg.get_attribute('#askPanel', 'data-status'), 'refused')
        expect('cannot be applied', pg.is_enabled('#akApply'), False)
        pg.fill('#akTask', 'PROSE'); pg.click('#akGo')
        pg.wait_for_function("document.getElementById('akInfo').textContent.indexOf('passes') >= 0", timeout=60000)
        expect('one that passes', pg.get_attribute('#askPanel', 'data-status'), 'ok')
        pg.screenshot(path=str(SHOTS / 'assist_objed.png'))
        pg.click('#akApply'); settle(pg, 1500)
        expect('applied', pg.input_value('#code'), 'say "prose"')
        expect('and the method compiles', pg.inner_text('#edState'), 'compiles')
    finally:
        mock.terminate()

def sc_ssc(pg):
    """Semantic Source Control in the Object Editor (a stand-in store): the class file opened from the store, a method changed, the commit proposed as one method's new edition for review."""
    mock = subprocess.Popen(['node', str(DESIGNER / 'tests' / 'fixtures' / 'ssc_mock_server.mjs'), str(SSCMOCK)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(0.8)
    def setting(key, value):
        f = pg.locator(f'[data-plugin=ssc] [data-setting="{key}"]'); f.fill(value); f.press('Tab'); settle(pg, 700)
    try:
        ready(pg); pg.evaluate("localStorage.removeItem('oodDesigner.plugins')"); ready(pg)
        pg.click('#btnPlugins'); pg.wait_for_selector('#plugPanel:not([hidden])'); settle(pg, 600)
        pg.check('#pp-ssc'); pg.wait_for_selector('[data-plugin=ssc] [data-setting="session"]', timeout=60000)
        setting('endpoint', f'http://127.0.0.1:{SSCMOCK}/mcp'); setting('root', 'oorexx://demo/Greeter'); setting('session', 'FAKE-SSC-SESSION-84')
        pg.click('#ppClose')
        pg.click('#btnScm'); pg.wait_for_selector('#srcPanel:not([hidden])'); settle(pg, 1500)
        expect_in('the store\'s file listed', 'src/Greeter.cls', pg.inner_text('#scFiles'))
        pg.click('#scFiles li[data-path="src/Greeter.cls"] button'); settle(pg, 2000)
        expect('current', pg.get_attribute('#scState', 'data-state'), 'CURRENT')
        pg.click('#scClose')
        open_method(pg, 'Greeter', 'greet')
        body = pg.input_value('#code')
        pg.fill('#code', body.replace('return "Hello," name', 'return "Hello," name || "!"')); pg.locator('#code').blur(); settle(pg, 1800)
        expect('it compiles', pg.inner_text('#edState'), 'compiles')
        pg.click('#btnScm'); pg.wait_for_selector('#srcPanel:not([hidden])'); settle(pg, 1200)
        expect_in('the change shown', '|| "!"', pg.inner_text('#scDiff .ak-add'))
        pg.fill('#scMsg', 'An exclamation'); pg.click('#scCommit')
        pg.wait_for_function("document.getElementById('srcPanel').dataset.committed", timeout=30000); settle(pg, 600)
        expect('proposed', pg.get_attribute('#srcPanel', 'data-committed'), 'ok')
        expect_in('  as one method\'s edition', 'method Greeter~greet: proposed as ssr_', pg.inner_text('#scNotes'))
        expect_in('  for review', 'nothing is accepted until it is reviewed', pg.inner_text('#scNotes'))
        expect('  history: the unit', pg.locator('#scHistory li').count(), 1)
        pg.screenshot(path=str(SHOTS / 'ssc_proposed.png'))
    finally:
        mock.terminate()

SCENARIOS = {'reflect': sc_reflect, 'edit': sc_edit, 'requires': sc_requires, 'complete': sc_complete, 'oodialog': sc_oodialog, 'libraries': sc_libraries, 'ui_de': sc_ui_de, 'plugins': sc_plugins, 'assist': sc_assist, 'ssc': sc_ssc}
def main():
    names = sys.argv[1:] or list(SCENARIOS)
    SHOTS.mkdir(exist_ok=True)
    srv = subprocess.Popen(['node', str(SITE / 'serve.mjs'), str(SITE), '--port', str(PORT)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1.2); failed = []
    try:
        with sync_playwright() as p:
            b = p.chromium.launch()
            for n in names:
                pg = b.new_page(viewport={'width': 1280, 'height': 900})
                pg.on('pageerror', lambda e: log('PAGEERROR', e))
                log('RUN', n, '--', SCENARIOS[n].__doc__)
                try: SCENARIOS[n](pg); log('PASS', n)
                except Exception as e:
                    log('FAIL', n, '::', ' | '.join(str(e).splitlines()[:30])[:3000]); failed.append(n)
                    try: log('  status:', status(pg)); pg.screenshot(path=str(SHOTS / (n + '_fail.png')))
                    except Exception: pass
                pg.close()
            b.close()
    finally: srv.terminate()
    log('summary:', len(names) - len(failed), 'passed,', len(failed), 'failed, of', len(names), failed or '')
    return 1 if failed else 0
sys.exit(main())
