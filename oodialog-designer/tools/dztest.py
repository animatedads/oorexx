#!/usr/bin/env python3
"""dztest.py -- drive the ooDialog Designer page in headless Chromium.
Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

usage: python3 tools/dztest.py [scenario ...]     (after rexx tools/build.rex)
Scenarios: hand, calculator, threads, refuse, saveopen, views (default: all).
Python is used here only because this tool drives a browser (Playwright);
the designer's model, generator and reader are ooRexx (src/OodDesigner.cls)
and are tested without a browser by tests/t01_model.rex.  Progress is logged
per step so a run is never a black box."""
import subprocess, sys, time, pathlib, re
from playwright.sync_api import sync_playwright
ROOT = pathlib.Path(__file__).resolve().parent.parent
SITE = ROOT / 'site'
SHOTS = ROOT / 'shots'
PORT = 8032
def log(*a): print('dztest:', *a, flush=True)

class Fail(Exception): pass
def expect(what, got, want):
    if got != want: raise Fail(f'{what}: expected {want!r}, got {got!r}')
    log('  ok', what)
def expect_in(what, part, whole):
    if part not in whole: raise Fail(f'{what}: {part!r} not in {whole[:300]!r}')
    log('  ok', what)

def ready(pg):
    pg.goto(f'http://localhost:{PORT}/designer.html')
    pg.wait_for_function("document.getElementById('status').textContent.startsWith('Ready')", timeout=60000)
def snap(pg):
    return pg.evaluate('window.oodDesigner.snap')
def status(pg): return pg.inner_text('#status')
def settle(pg, ms=400): time.sleep(ms / 1000)
def drop_kind(pg, label, x, y):
    pg.drag_and_drop(f'#kinds div:text-is("{label}")', '#client', target_position={'x': x, 'y': y}); settle(pg)
def set_prop(pg, prop, value):
    i = pg.locator(f'#props [data-prop="{prop}"]'); i.fill(str(value)); i.press('Enter'); settle(pg)
def pick_event(pg, ctl, ev):
    pg.click(f'#tree [data-ev="{ctl}.{ev}"]'); settle(pg)
def type_code(pg, code):
    pg.fill('#code', code); pg.click('#formTitle'); settle(pg, 700)
def run(pg):
    pg.click('#btnRun'); pg.wait_for_selector('.ood-dlg', timeout=60000); settle(pg, 500)
def wait_end(pg):
    pg.wait_for_function('window.oodDone !== null', timeout=30000); return pg.evaluate('window.oodDone')
def press(pg, label, **kw):
    pg.locator('.ood-dlg button', has_text=re.compile('^' + re.escape(label) + '$')).first.click(**kw)
def dlg_text(pg): return pg.inner_text('.ood-dlg').replace('\n', ' ')
def open_example(pg, path):
    pg.select_option('#example', path)
    pg.wait_for_function("document.getElementById('status').textContent.startsWith('Opened')", timeout=30000); settle(pg)
def program_text(pg):
    pg.click('#btnProgram'); pg.wait_for_selector('#programView:not([hidden])'); t = pg.inner_text('#programText')
    pg.click('#btnProgramClose'); return t

def sc_hand(pg):
    """Build a small dialog by hand: drop, rename, style, variable, events, drag an
    action onto the code, move and resize with the mouse, then run it."""
    ready(pg)
    drop_kind(pg, 'Entry field', 40, 30); expect('entry dropped', snap(pg)['controls'][0]['name'], 'txt1')
    set_prop(pg, 'name', 'who')
    drop_kind(pg, 'Push button', 40, 70); set_prop(pg, 'name', 'btnHello'); set_prop(pg, 'text', '&Hello')
    drop_kind(pg, 'Text', 40, 110); set_prop(pg, 'name', 'lblOut'); set_prop(pg, 'w', 150)
    drop_kind(pg, 'Push button', 200, 70); set_prop(pg, 'text', 'OK'); pg.select_option('#props [data-prop="role"]', 'OK'); settle(pg)
    names = [c['name'] for c in snap(pg)['controls']]; expect('four controls named', names, ['who', 'btnHello', 'lblOut', 'btn1'])
    # a variable: an attribute of the dialog
    pg.fill('#newVarName', 'count'); pg.fill('#newVarValue', '0'); pg.click('#btnAddVar'); settle(pg)
    expect('variable added', [v['name'] for v in snap(pg)['vars']], ['count'])
    # an event, and VisPro's drag a control onto the code
    pick_event(pg, 'btnHello', 'CLICKED')
    pg.fill('#code', 'self~count = self~count + 1\n'); pg.click('#code'); pg.keyboard.press('Control+End')
    pg.drag_and_drop('#tree .name[data-ctl="lblOut"]', '#code'); pg.wait_for_selector('#menu:not([hidden])')
    pg.click('#menu [data-action="Set its text"]'); settle(pg, 800)
    expect_in('action inserted', 'self~lblOut~setText("text")', pg.input_value('#code'))
    type_code(pg, 'self~count = self~count + 1\nself~lblOut~setText("Hello," self~who~getText "(" || self~count || ")")')
    pick_event(pg, 'form', 'INIT')
    type_code(pg, 'self~who~setText("Tom")')
    evs = [(e['control'], e['event']) for e in snap(pg)['events']]
    expect('events in the design', evs, [('form', 'INIT'), ('btnHello', 'CLICKED')])
    # move with the mouse: lblOut by +20 DU across
    st = pg.evaluate('[window.oodDesigner.fx, window.oodDesigner.fy]')
    before = [c for c in snap(pg)['controls'] if c['name'] == 'lblOut'][0]
    box = pg.locator('#client .dz[data-name="lblOut"]').bounding_box()
    pg.mouse.move(box['x'] + 10, box['y'] + 4); pg.mouse.down(); pg.mouse.move(box['x'] + 10 + 20 * st[0], box['y'] + 4, steps=6); pg.mouse.up(); settle(pg, 600)
    after = [c for c in snap(pg)['controls'] if c['name'] == 'lblOut'][0]
    expect('moved 20 DU right', int(after['x']) - int(before['x']), 20)
    # resize the button with its corner handle
    pg.click('#client .dz[data-name="btnHello"]'); settle(pg)
    h = pg.locator('#client .dz[data-name="btnHello"] .h.se').bounding_box()
    pg.mouse.move(h['x'] + 4, h['y'] + 4); pg.mouse.down(); pg.mouse.move(h['x'] + 4 + 10 * st[0], h['y'] + 4, steps=5); pg.mouse.up(); settle(pg, 600)
    b = [c for c in snap(pg)['controls'] if c['name'] == 'btnHello'][0]
    expect('button 10 DU wider', b['w'], '60')
    SHOTS.mkdir(exist_ok=True); pg.screenshot(path=str(SHOTS / 'hand_design.png'))
    src = program_text(pg)
    expect_in('program is a UserDialog', '::class MyDialog subclass UserDialog', src)
    expect_in('program connects the event', 'self~connectButtonEvent(101, "CLICKED", "on_btnHello_clicked")', src)
    run(pg)
    expect('INIT ran', pg.input_value('.ood-dlg input'), 'Tom')
    pg.fill('.ood-dlg input', 'Josep Maria')
    press(pg, 'Hello'); press(pg, 'Hello'); settle(pg, 500)
    expect_in('event code ran with the variable', 'Hello, Josep Maria (2)', dlg_text(pg))
    pg.screenshot(path=str(SHOTS / 'hand_run.png'))
    press(pg, 'OK')
    expect('ended with OK', wait_end(pg)['rc'], 1)

def sc_calculator(pg):
    """The EDM2 DrDialog review's RPN calculator: open it (read back from its own
    ::RESOURCE), check the round trip in the browser, run it, do sums."""
    ready(pg); open_example(pg, 'examples/Calculator.rex')
    src = program_text(pg)
    expect('round trip in the browser is byte-identical', src, (SITE / 'examples/Calculator.rex').read_text())
    pg.screenshot(path=str(SHOTS / 'calculator_design.png'))
    run(pg)
    for k in ['1', '2', 'Enter', '3', '0', '+']: press(pg, f'{k}')
    settle(pg); expect('12 Enter 30 +', pg.input_value('.ood-dlg input'), '42')
    for k in ['6', '*']: press(pg, f'{k}')
    settle(pg); expect('then 6 *', pg.input_value('.ood-dlg input'), '252')
    pg.screenshot(path=str(SHOTS / 'calculator_run.png'))
    press(pg, 'Close'); expect('closed with Cancel', wait_end(pg)['rc'], 2)

def sc_threads(pg):
    """Threads: a background event works while the dialog still answers clicks,
    and a timer ticks on its own thread."""
    ready(pg); open_example(pg, 'examples/Threads.rex')
    run(pg); settle(pg, 900)
    expect_in('timer thread ticks', 'Time', dlg_text(pg))
    press(pg, 'Start work'); settle(pg, 400)
    for _ in range(3): press(pg, 'Ping'); settle(pg, 150)
    mid = dlg_text(pg)
    expect_in('dialog answered while the job ran', 'pings: 3', mid)
    pg.screenshot(path=str(SHOTS / 'threads_run.png'))
    pg.wait_for_function("document.querySelector('.ood-dlg').innerText.includes('Done')", timeout=20000)
    expect_in('job finished on its thread', 'Pings while working: 3', dlg_text(pg))
    press(pg, 'Close'); expect('closed', wait_end(pg)['rc'], 2)

def sc_refuse(pg):
    """The design refuses what would break the program, and says why."""
    ready(pg); drop_kind(pg, 'Push button', 30, 30)
    set_prop(pg, 'name', 'execute')
    expect_in('a UserDialog method is refused', 'already a method of UserDialog', status(pg))
    expect('name unchanged', snap(pg)['controls'][0]['name'], 'btn1')
    pick_event(pg, 'btn1', 'CLICKED'); type_code(pg, '::method sneaky')
    expect_in('a directive in code is refused', 'cannot start with ::', status(pg))

def sc_saveopen(pg):
    """Save downloads the program; opening it gives the same design back."""
    ready(pg); open_example(pg, 'examples/Threads.rex')
    with pg.expect_download() as dl: pg.click('#btnSave')
    path = dl.value.path(); text = pathlib.Path(path).read_text()
    expect('saved file is the program', text, (SITE / 'examples/Threads.rex').read_text())
    pg.select_option('#example', ''); settle(pg, 600)
    pg.set_input_files('#file', path)
    pg.wait_for_function("document.getElementById('status').textContent.startsWith('Opened')", timeout=30000)
    expect('reopened design', snap(pg)['form']['name'], 'Threads')

def sc_views(pg):
    """Tabs, list view and menu: pages while designing, the page property, then
    run: the page swaps, the list view's event, the menu adds a row and exits."""
    ready(pg); open_example(pg, 'examples/Contacts.rex')
    expect('round trip in the browser is byte-identical', program_text(pg), (SITE / 'examples/Contacts.rex').read_text())
    shown = lambda: [e.get_attribute('data-name') for e in pg.query_selector_all('#client .dz')]
    expect('page 1 while designing', 'txtNotes' in shown(), False)
    pg.click('#client .dz[data-name="tabMain"] [data-page="2"]'); settle(pg)
    expect('page 2 while designing', ('txtNotes' in shown(), 'lvPeople' in shown()), (True, False))
    expect('menu bar drawn', pg.inner_text('#formMenu').split(), ['People', 'View'])
    pg.click('#client .dz[data-name="lblInfo"]'); settle(pg)
    pg.select_option('#props [data-prop="page"]', 'tabMain:2'); settle(pg)
    expect('page property set', [c['page'] for c in snap(pg)['controls'] if c['name'] == 'lblInfo'], ['tabMain:2'])
    pg.select_option('#props [data-prop="page"]', ''); settle(pg)
    pg.screenshot(path=str(SHOTS / 'views_design.png'))
    run(pg)
    expect('four rows', pg.evaluate("document.querySelectorAll('.ood-dlg .ood-lv tbody tr').length"), 4)
    pg.click('.ood-dlg >> text=Mark Miesfeld'); settle(pg)
    expect_in('list view event', 'Mark Miesfeld -- ooDialog', dlg_text(pg))
    pg.click('.ood-dlg .ood-tabbtn >> text=Notes'); settle(pg)
    expect('notes page shown', pg.evaluate("document.querySelector('.ood-dlg textarea').offsetParent !== null"), True)
    pg.click('.ood-dlg .ood-tabbtn >> text=People'); settle(pg)
    pg.click('.ood-menubar >> text=People'); pg.click('.ood-menu >> text=Add a Rexx person'); settle(pg)
    expect('menu item added a row', pg.evaluate("document.querySelectorAll('.ood-dlg .ood-lv tbody tr').length"), 5)
    pg.screenshot(path=str(SHOTS / 'views_run.png'))
    pg.click('.ood-menubar >> text=People'); pg.click('.ood-menu >> text=Exit')
    expect('Exit cancels', wait_end(pg)['rc'], 2)

SCENARIOS = {'hand': sc_hand, 'calculator': sc_calculator, 'threads': sc_threads, 'refuse': sc_refuse, 'saveopen': sc_saveopen, 'views': sc_views}
def main():
    names = sys.argv[1:] or list(SCENARIOS)
    srv = subprocess.Popen(['node', str(SITE / 'serve.mjs'), str(SITE), '--port', str(PORT)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1.2); failed = []
    try:
        with sync_playwright() as p:
            b = p.chromium.launch()
            for n in names:
                pg = b.new_page(viewport={'width': 1280, 'height': 900}, accept_downloads=True)
                pg.on('pageerror', lambda e: log('PAGEERROR', e))
                log('RUN', n, '--', SCENARIOS[n].__doc__.split('\n')[0])
                try: SCENARIOS[n](pg); log('PASS', n)
                except Exception as e:
                    log('FAIL', n, '::', ' | '.join(str(e).splitlines()[:14])[:1500]); failed.append(n)
                    try: log('  status:', status(pg)); log('  output:', pg.inner_text('#out')[:600]); pg.screenshot(path=str(SHOTS / (n + '_fail.png')))
                    except Exception: pass
                pg.close()
            b.close()
    finally: srv.terminate()
    log('summary:', len(names) - len(failed), 'passed,', len(failed), 'failed, of', len(names), failed or '')
    return 1 if failed else 0
sys.exit(main())
