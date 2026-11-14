#!/usr/bin/env python3
"""oxtest.py -- drive the ooRexx Object Editor page in headless Chromium.
Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

usage: python3 tools/oxtest.py [scenario ...]     (after rexx tools/build.rex)
Scenarios: reflect, edit, requires, complete, oodialog, libraries (default: all).
Python only drives the browser (Playwright); what the editor finds and does
is ooRexx (src/ObjectEditor.cls), tested without a browser by
tests/t01_object.rex.  Each step is logged."""
import subprocess, sys, time, pathlib
from playwright.sync_api import sync_playwright
ROOT = pathlib.Path(__file__).resolve().parent.parent
SITE, SHOTS, PORT = ROOT / 'site', ROOT / 'shots', 8042
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
    pg.wait_for_function("document.getElementById('status').textContent.startsWith('Opened')", timeout=60000); settle(pg)
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

SCENARIOS = {'reflect': sc_reflect, 'edit': sc_edit, 'requires': sc_requires, 'complete': sc_complete, 'oodialog': sc_oodialog, 'libraries': sc_libraries}
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
                    log('FAIL', n, '::', ' | '.join(str(e).splitlines()[:6])[:900]); failed.append(n)
                    try: log('  status:', status(pg)); pg.screenshot(path=str(SHOTS / (n + '_fail.png')))
                    except Exception: pass
                pg.close()
            b.close()
    finally: srv.terminate()
    log('summary:', len(names) - len(failed), 'passed,', len(failed), 'failed, of', len(names), failed or '')
    return 1 if failed else 0
sys.exit(main())
