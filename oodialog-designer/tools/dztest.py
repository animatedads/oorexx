#!/usr/bin/env python3
"""dztest.py -- drive the ooDialog Designer page in headless Chromium.
Architecture: Tom Dyer.  Code: Claude (Opus 5.5).

usage: python3 tools/dztest.py [scenario ...]     (after rexx tools/build.rex)
Scenarios: hand, calculator, threads, refuse, saveopen, views, gadgets, libraries, graph, trace, languages, ui_de, plugins, assist, source, bound (default: all).
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
GHMOCK = 8978                # tests/fixtures/github_mock_server.mjs, for the source scenario
MOCK = 8974                 # tests/fixtures/assist_mock_server.mjs, for the assist scenario
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
    pg.wait_for_function("window.oodDesigner && window.oodDesigner.ready === true", timeout=60000)   # in any language
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

def sc_gadgets(pg):
    """Tree view, track bar, date picker: drawn while designing, then run: the
    tree's SELCHANGED and the track bar's position."""
    ready(pg); open_example(pg, 'examples/Gadgets.rex')
    expect('round trip in the browser is byte-identical', program_text(pg), (SITE / 'examples/Gadgets.rex').read_text())
    expect_in('tree drawn', 'RxSock', pg.inner_text('#client .dz[data-name="tvRexx"]'))
    pg.screenshot(path=str(SHOTS / 'gadgets_design.png'))
    run(pg)
    pg.click('.ood-dlg .ood-tv >> text=RxSock'); settle(pg)
    expect_in('tree event', 'Node: RxSock', dlg_text(pg))
    press(pg, 'Read the level'); settle(pg)
    expect_in('track bar position', 'Level: 30', dlg_text(pg))
    pg.screenshot(path=str(SHOTS / 'gadgets_run.png'))
    press(pg, 'Close'); expect('closed', wait_end(pg)['rc'], 2)

def sc_libraries(pg):
    """Libraries: connect to Alchemy, install the logging framework, use it, put a
    LogService in the shared scope, reach it from an event with expose sharedScope, run."""
    ready(pg); open_example(pg, 'examples/Calculator.rex')
    pg.click('#btnLibraries'); pg.wait_for_selector('#libPanel .lp-lib', timeout=60000)
    pg.fill('#lpFilter', 'oorexx_logging'); pg.wait_for_timeout(1500)
    pg.click('#lpList .lp-lib[data-lib="alchemy:oorexx_logging"]'); pg.wait_for_selector('#lpDetail h3', timeout=60000)
    pg.click('#lpInstall'); pg.wait_for_selector('#lpGoodies details', timeout=90000)
    pg.click('#lpUse'); pg.wait_for_function("document.getElementById('libPanel').hidden", timeout=30000); settle(pg, 700)
    expect('::requires in the design', snap(pg)['requires'], ['lib/alchemy/LoggingCore.cls'])
    pg.fill('#newSharedName', 'logging'); pg.fill('#newSharedValue', '.LogService~new("calculator")'); pg.click('#btnAddShared'); settle(pg, 700)
    expect('shared scope entry', [(e['name'], e['value']) for e in snap(pg)['shared']], [('logging', '.LogService~new("calculator")')])
    pick_event(pg, 'form', 'INIT')
    type_code(pg, 'expose sharedScope\nL = sharedScope["logging"]\nself~status~setText("Logging service:" L~serviceId)')
    src = program_text(pg)
    expect_in('program requires the library', '::requires "lib/alchemy/LoggingCore.cls"', src)
    expect_in('program makes the shared scope', 'self~sharedScope["logging"] = .LogService~new("calculator")', src)
    pg.screenshot(path=str(SHOTS / 'libraries_design.png'))
    run(pg)
    expect_in('the event reached the library through the shared scope', 'Logging service: calculator', dlg_text(pg))
    pg.screenshot(path=str(SHOTS / 'libraries_run.png'))
    press(pg, 'Close'); expect('closed', wait_end(pg)['rc'], 2)

def wait_graph(pg):
    settle(pg, 150); pg.wait_for_function("document.getElementById('graph').dataset.ready === '1'", timeout=20000); settle(pg, 150)
def js_drag(pg, src, dst):
    """HTML5 drag and drop by events, for a target out of view: Playwright's
    mouse drag scrolls the target into view after pressing the mouse, so the
    drag would start on whatever block has scrolled under the pointer."""
    pg.evaluate("""([src, dst]) => {
        const a = document.querySelector(src), b = document.querySelector(dst), dt = new DataTransfer();
        a.dispatchEvent(new DragEvent('dragstart', { bubbles: true, dataTransfer: dt }));
        b.dispatchEvent(new DragEvent('dragover', { bubbles: true, cancelable: true, dataTransfer: dt }));
        b.dispatchEvent(new DragEvent('drop', { bubbles: true, cancelable: true, dataTransfer: dt }));
        a.dispatchEvent(new DragEvent('dragend', { bubbles: true, dataTransfer: dt }));
    }""", [src, dst])
def pick_method(pg, name):
    pg.click(f'#tree [data-method="{name}"]'); wait_graph(pg)
def code_lines(pg): return pg.input_value('#code').split('\n')
def blocks(pg, kind): return pg.locator(f'#graph .gb.k-{kind}').count()
def block_with(pg, kind, text):
    return pg.locator(f'#graph .gb.k-{kind} > .gh', has_text=text).last   # its own header, not a block inside it

def sc_graph(pg):
    """The graph beside the code: the calculator's operate method drawn as
    blocks; drag a block from the palette in, change it, move it, delete it,
    wrap a THEN in do...end; the caret lights its block; bad code is shown."""
    ready(pg); open_example(pg, 'examples/Calculator.rex')
    pick_method(pg, 'operate')
    original = pg.input_value('#code')
    expect('three IFs drawn', blocks(pg, 'if'), 3)
    expect('a SELECT with three WHENs and an OTHERWISE', [blocks(pg, 'select'), blocks(pg, 'when'), blocks(pg, 'otherwise')], [1, 3, 1])
    SHOTS.mkdir(exist_ok=True); pg.screenshot(path=str(SHOTS / 'graph_operate.png'))
    # a block selects its code
    block_with(pg, 'select', 'select').click(); settle(pg)
    sel = pg.evaluate("(() => { const c = document.getElementById('code'); return c.value.slice(c.selectionStart, c.selectionEnd); })()")
    expect('the select block selects its code', sel.split('\n')[0].strip(), 'select')
    expect_in('it explains itself', 'SELECT', pg.inner_text('#gExplain'))
    # drag a SAY from the palette in after USE STRICT ARG (top level, place 2)
    pg.drag_and_drop('#gPalette .gpal:text-is("say")', '#graph .gdrop[data-parent="0"][data-index="2"]'); wait_graph(pg)
    expect('say inserted as line 2', code_lines(pg)[1].strip(), 'say "text"')
    # double-click it to change it
    block_with(pg, 'say', 'say "text"').dblclick(); pg.fill('#graph .gedit', 'say "op is" op'); pg.keyboard.press('Enter'); wait_graph(pg)
    expect('say changed', code_lines(pg)[1].strip(), 'say "op is" op')
    # move it down, past the first two IFs
    js_drag(pg, '#graph .gb.k-say', '#graph > .gslot > .gdrop[data-index="5"]'); wait_graph(pg)
    lines = [l.strip() for l in code_lines(pg)]
    expect('moved: second line is the first IF again', lines[1], 'if self~entry \\== "" then self~enter')
    expect('and it sits just before b = ...', lines[lines.index('b = self~stack~pull') - 1], 'say "op is" op')
    # delete it: back to the original
    pg.click('#graph .gb.k-say > .gh'); pg.click('#gDelete'); wait_graph(pg)
    expect('deleted: the code is as it was', pg.input_value('#code').rstrip('\n'), original.rstrip('\n'))
    # the caret lights the innermost block
    pg.evaluate("(() => { const c = document.getElementById('code'); const i = c.value.indexOf('answer = a + b'); c.focus(); c.setSelectionRange(i, i); c.dispatchEvent(new KeyboardEvent('keyup')); })()"); settle(pg)
    expect_in('caret lights the assignment', 'answer = a + b', pg.inner_text('#graph .gb.sel > .gh'))
    # wrap the THEN of the first IF in do...end
    block_with(pg, 'message', 'self~enter').click(); settle(pg)
    expect('wrap offered for a THEN', pg.is_enabled('#gWrap'), True)
    pg.click('#gWrap'); wait_graph(pg)
    expect_in('wrapped', 'then do', pg.input_value('#code'))
    expect_in('the design took it', 'then do', program_text(pg))
    # code that does not parse: shown, graph left as it was
    pg.fill('#code', original.rstrip('\n') + '\nif then\n'); settle(pg, 1200)
    expect('parse error shown', pg.is_visible('#gError'), True)
    pg.screenshot(path=str(SHOTS / 'graph_error.png'))
    pg.fill('#code', original); settle(pg, 1200)
    expect('error gone when mended', pg.is_visible('#gError'), False)
    # Code | Graph | Both
    pg.click('#views [data-view="code"]'); expect('code only', pg.is_visible('#graph'), False)
    pg.click('#views [data-view="graph"]'); expect('graph only', pg.is_visible('#code'), False)
    pg.click('#views [data-view="both"]'); expect('both', [pg.is_visible('#code'), pg.is_visible('#graph')], [True, True])

def sc_trace(pg):
    """The trace run: run the calculator with probes, do 1 Enter 2 +, and walk the
    steps: the method shown, the block lit, the variables and what changed."""
    ready(pg); open_example(pg, 'examples/Calculator.rex')
    pg.click('#btnTrace'); pg.wait_for_selector('.ood-dlg', timeout=60000); settle(pg, 500)
    for k in ['1', 'Enter', '2', '+']: press(pg, k); settle(pg, 300)
    settle(pg, 800)
    expect('the traced program still sums', pg.input_value('.ood-dlg input'), '3')
    n = pg.evaluate("+document.getElementById('tStep').max") + 1
    if n < 10: raise Fail(f'only {n} steps recorded')
    log('  ok', n, 'steps recorded')
    expect_in('following: the last step is in operate', 'operate', pg.inner_text('#tWhere'))
    expect_in('operate is shown', 'method operate', pg.inner_text('#codeTitle'))
    expect('a block is lit', pg.locator('#graph .gb.run').count(), 1)
    expect_in('variables shown', 'ANSWER', pg.inner_text('#tVars'))
    vars = dict(r.split('\t', 1) for r in pg.inner_text('#tVars tbody').split('\n') if '\t' in r)
    expect('ANSWER is 3', vars.get('ANSWER'), '3')
    pg.screenshot(path=str(SHOTS / 'trace_operate.png'))
    # the first step: the INIT event
    pg.evaluate("(() => { const s = document.getElementById('tStep'); s.value = 0; s.dispatchEvent(new Event('input')); })()"); settle(pg, 900)
    expect_in('step 1 is the INIT event', 'on_form_init', pg.inner_text('#tWhere'))
    expect_in('its event is shown', 'form · INIT', pg.inner_text('#codeTitle'))
    press(pg, 'Close'); expect('closed', wait_end(pg)['rc'], 2)
    pg.click('#tNext'); settle(pg, 900)
    expect_in('step 2, after the run', 'step 2 of', pg.inner_text('#tWhere'))
    pg.click('#tClose'); expect('trace closed', pg.is_visible('#traceBar'), False)

def s_cell(pg, key, lang):
    return pg.locator(f'#sTable tr[data-key="{key}"] input[data-lang="{lang}"]')
def s_set(pg, key, lang, text):
    c = s_cell(pg, key, lang); c.fill(text); c.press('Enter'); settle(pg, 700)

def sc_languages(pg):
    """Contacts into German: make it translatable, add de, translate in the
    Strings grid, an event string with %1, a translator's file out and back,
    the design shown in German with a too-long text marked, then run in German."""
    ready(pg); open_example(pg, 'examples/Contacts.rex')
    pg.click('#btnStrings'); pg.wait_for_selector('#stringsView:not([hidden])')
    pg.fill('#sBase', 'en'); pg.click('#sOn'); settle(pg, 700)
    expect('translatable: base en', snap(pg)['languages'], ['en'])
    expect('a key per text (not the separator)', pg.locator('#sTable tbody tr').count(), 10)
    pg.fill('#sNewLang', 'de'); pg.click('#sAddLang'); settle(pg, 700)
    expect('German column', pg.locator('#sTable th[data-lang="de"]').count(), 1)
    expect_in('all to do', '10 to do', pg.inner_text('#sTable th[data-lang="de"]'))
    s_set(pg, 'form.title', 'de', 'Kontakte')
    s_set(pg, 'tabMain.tabs', 'de', 'Personen|Notizen')
    s_set(pg, 'lvPeople.columns', 'de', 'Name:80|Rolle:84|Seit:30')
    s_set(pg, 'btnClose.text', 'de', 'Schließen und beenden')
    s_set(pg, 'mnuAdd.popup', 'de', '&Personen')
    s_set(pg, 'mnuAdd.text', 'de', 'Rexx-Person &hinzufügen')
    s_set(pg, 'mnuExit.text', 'de', '&Beenden')
    expect_in('three left to do', '3 to do', pg.inner_text('#sTable th[data-lang="de"]'))
    # an event string, with %1
    pg.fill('#sNewKey', 'msg.count'); pg.fill('#sNewText', '%1 people'); pg.click('#sAddKey'); settle(pg, 700)
    s_set(pg, 'msg.count', 'de', '%1 Personen')
    # the translator's file: out, one more text, back
    with pg.expect_download() as dl: pg.click('#sTable th[data-lang="de"] button[title^="Download"]')
    text = pathlib.Path(dl.value.path()).read_text(encoding='utf-8')
    expect_in('export: key = text with the base above', '-- en: Close\nbtnClose.text = Schließen und beenden', text)
    expect_in('export: untranslated is empty', '\nmnuGrid.text =\n', text)
    text = text.replace('mnuGrid.text =\n', 'mnuGrid.text = &Gitterlinien\n')
    pg.evaluate("window.oodDesigner.importLang = 'de'")   # what the ⇧ button sets before it opens the file dialog
    pg.set_input_files('#sFile', files=[{'name': 'Contacts.de.txt', 'mimeType': 'text/plain', 'buffer': text.encode('utf-8')}]); settle(pg, 900)
    expect_in('import reported', '9 strings set in de', status(pg))
    expect('import set the text', s_cell(pg, 'mnuGrid.text', 'de').input_value(), '&Gitterlinien')
    pg.screenshot(path=str(SHOTS / 'languages_strings.png'))
    pg.click('#sClose')
    # the event uses the string
    pick_event(pg, 'mnuAdd', 'CLICKED')
    type_code(pg, 'self~lvPeople~addRow( , , "Rony Flatscher", "BSF4ooRexx", 2000)\nself~lblInfo~setText(self~nls("msg.count", self~lvPeople~items))')
    # the design in German
    pg.select_option('#lang', 'de'); settle(pg, 900)
    expect('title in German', pg.inner_text('#formTitle'), 'Kontakte')
    expect('tabs in German', pg.inner_text('#client .dz[data-name="tabMain"]').split(), ['Personen', 'Notizen'])
    expect('menu bar in German (View has no German yet: English)', pg.inner_text('#formMenu').split(), ['Personen', 'View'])
    expect('too long in German: marked', pg.locator('#client .dz.overflow[data-name="btnClose"]').count(), 1)
    expect_in('and named in the status', 'btnClose', status(pg))
    expect('properties keep the base text', pg.evaluate("window.oodDesigner.snap.controls.find(c => c.name === 'btnClose').text"), 'Close')
    pg.screenshot(path=str(SHOTS / 'languages_design_de.png'))
    src = program_text(pg)
    expect_in('a ::RESOURCE per language', '::resource strings.de\nform.title = Kontakte\n', src)
    # run in German
    run(pg)
    expect_in('runs in German: the title', 'Kontakte', pg.inner_text('.ood-dlg'))
    expect_in('umlauts and ß come through', 'Schließen und beenden', dlg_text(pg))
    pg.click('.ood-menubar >> text=Personen'); pg.click('.ood-menu >> text=Rexx-Person hinzufügen'); settle(pg)
    expect_in('event string with %1, in German', '5 Personen', dlg_text(pg))
    pg.screenshot(path=str(SHOTS / 'languages_run_de.png'))
    pg.click('.ood-menubar >> text=Personen'); pg.click('.ood-menu >> text=Beenden')
    expect('Beenden cancels', wait_end(pg)['rc'], 2)
    # and in the base language
    pg.select_option('#lang', 'en'); settle(pg, 900)
    expect('title back in English', pg.inner_text('#formTitle'), 'Contacts')
    # saved and opened again: the languages come back
    pg.evaluate("(src) => window.oodDesigner.openSource(src, 'again')", src); settle(pg, 900)
    expect('reopened with its languages', snap(pg)['languages'], ['en', 'de'])
    expect('round trip byte-identical', program_text(pg), src)

def sc_ui_de(pg):
    """The designer itself in German, from its ::RESOURCE strings.de: the bar,
    palette, properties, events, graph, a refusal from the Rexx model, the
    Strings panel; kept over a reload; then back to English."""
    ready(pg)
    pg.select_option('#uiLang', 'de'); settle(pg, 900)
    expect_in('it says so', 'Der Designer spricht jetzt de', status(pg))
    expect('the bar', [pg.inner_text('#btnOpen'), pg.inner_text('#btnRun'), pg.inner_text('#btnStrings')], ['Öffnen…', '▶ Ausführen', 'Texte…'])
    expect('the palette', pg.inner_text('#kinds div >> nth=0'), 'Schaltfläche')
    expect('the page language', pg.evaluate('document.documentElement.lang'), 'de')
    pg.click('#kinds div >> nth=0'); settle(pg, 700)
    expect_in('a status with %1', 'btn1 hinzugefügt', status(pg))
    expect_in('the properties title: the control kind', 'Schaltfläche', pg.inner_text('#propTitle'))
    expect_in('a property label', 'Breite', pg.inner_text('#props'))
    # the Rexx model refuses in German
    i = pg.locator('#props [data-prop="name"]'); i.fill('1abc'); i.press('Enter'); settle(pg, 700)
    expect('a refusal from OodDesigner.cls, in German', status(pg), 'Der Name 1abc muss mit einem Buchstaben oder _ beginnen')
    # an action menu, the graph
    pick_event(pg, 'btn1', 'CLICKED')
    pg.drag_and_drop('#tree .name[data-ctl="btn1"]', '#code'); pg.wait_for_selector('#menu:not([hidden])')
    expect_in('actions in German', 'Text setzen', pg.inner_text('#menu'))
    pg.click('#menu [data-action="Set its text"]'); settle(pg, 900); wait_graph(pg)
    pg.click('#graph .gb > .gh'); settle(pg)
    expect_in('the graph explains in German', 'Nachricht: schickt einem Objekt eine Nachricht', pg.inner_text('#gExplain'))
    expect('the block kind in German', pg.inner_text('#graph .gb .gk'), 'NACHRICHT' if pg.evaluate("getComputedStyle(document.querySelector('#graph .gk')).textTransform") == 'uppercase' else 'Nachricht')
    pg.click('#btnStrings'); pg.wait_for_selector('#stringsView:not([hidden])')
    expect('the Strings panel', pg.inner_text('#sOn'), 'Übersetzbar machen')
    pg.click('#sClose')
    pg.click('#btnLibraries'); pg.wait_for_selector('#libPanel:not([hidden])'); settle(pg, 900)
    expect('the Libraries panel (OxUi.cls), in German', pg.inner_text('#libPanel .lp-head strong'), 'Bibliotheken')
    pg.click('#lpClose')
    pg.screenshot(path=str(SHOTS / 'ui_de.png'))
    # kept over a reload, then back
    ready(pg)
    expect('German after a reload', pg.inner_text('#btnOpen'), 'Öffnen…')
    pg.select_option('#uiLang', 'en'); settle(pg, 900)
    expect('back in English', pg.inner_text('#btnOpen'), 'Open…')
    expect('the palette in English', pg.inner_text('#kinds div >> nth=0'), 'Push button')

def sc_plugins(pg):
    """Plugins: Boston Crab switched on in the Plugins panel; a P1 trap typed
    into an event is found, flagged in the graph and fixed with Fix; still on
    after a reload; its message follows the designer's language; switched off."""
    ready(pg); pg.evaluate("localStorage.removeItem('oodDesigner.plugins')"); ready(pg)
    pg.click('#btnPlugins'); pg.wait_for_selector('#plugPanel:not([hidden])'); settle(pg, 600)
    expect_in('the catalogue lists Boston Crab', 'Boston Crab: ooRexx pitfalls', pg.inner_text('#ppList'))
    expect('off until switched on', pg.is_checked('#pp-bostoncrab'), False)
    pg.check('#pp-bostoncrab'); settle(pg, 1500)
    expect_in('switched on', 'switched on', status(pg))
    pg.click('#ppClose')
    drop_kind(pg, 'Push button', 40, 30)
    pick_event(pg, 'btn1', 'CLICKED')
    pg.fill('#code', "say '\"'(1 + 1)'\"'\nsay 'done'"); settle(pg, 1600); wait_graph(pg); settle(pg, 600)
    expect('a finding shown', pg.locator('#diag .dg').count(), 1)
    expect_in('it is P1, on line 1', 'line 1', pg.inner_text('#diag .dg'))
    expect('the graph flags its block', pg.locator('#graph .gb.flag').count(), 1)
    pg.screenshot(path=str(SHOTS / 'plugins_finding.png'))
    pg.click('#diag .dg-fix'); settle(pg, 1600)
    expect('fixed in the code', pg.input_value('#code').split('\n')[0], "say '\"' || (1 + 1)'\"'")
    expect('the finding is gone', pg.is_visible('#diag'), False)
    expect_in('the event code took it', "say '\"' || (1 + 1)", program_text(pg))
    # kept over a reload, and in the designer's language
    ready(pg)
    drop_kind(pg, 'Push button', 40, 30); pick_event(pg, 'btn1', 'CLICKED')
    pg.fill('#code', "x = 'zz'x"); settle(pg, 1600)
    expect('still on after a reload: P2 found', pg.get_attribute('#diag .dg', 'data-rule'), 'P2')
    pg.select_option('#uiLang', 'de'); settle(pg, 1500); pg.evaluate('window.oodDesigner.diagnoseNow()'); settle(pg, 900)
    expect_in('the message in German', 'Hexadezimal', pg.inner_text('#diag'))
    pg.select_option('#uiLang', 'en'); settle(pg, 1200)
    pg.click('#btnPlugins'); pg.wait_for_selector('#plugPanel:not([hidden])'); settle(pg, 600)
    pg.uncheck('#pp-bostoncrab'); settle(pg, 1200); pg.click('#ppClose'); settle(pg, 900)
    expect('switched off: nothing shown', pg.is_visible('#diag'), False)

def sc_assist(pg):
    """Assist: the code assistance plugin switched on, its key given in its
    settings (never shown again, never saved), Ask... on an event: a proposal
    that passes, seen as a diff and as graphs, is applied; one with a Boston
    Crab pitfall cannot be; German."""
    mock = subprocess.Popen(['node', str(ROOT / 'tests' / 'fixtures' / 'assist_mock_server.mjs'), str(MOCK)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(0.8)
    try:
        ready(pg); pg.evaluate("localStorage.removeItem('oodDesigner.plugins')"); ready(pg)
        expect('no Ask... until a plugin gives code assistance', pg.is_visible('#btnAsk'), False)
        pg.click('#btnPlugins'); pg.wait_for_selector('#plugPanel:not([hidden])'); settle(pg, 600)
        expect_in('the catalogue lists code assistance', 'Code assistance (Anthropic, OpenAI)', pg.inner_text('#ppList'))
        pg.check('#pp-assist'); pg.wait_for_selector('[data-plugin=assist] [data-setting="anthropic.key"]', timeout=60000); settle(pg, 400)
        expect('the provider is a choice', pg.eval_on_selector('[data-plugin=assist] [data-setting=provider]', 'e => e.tagName + ":" + e.value'), 'SELECT:anthropic')
        u = pg.locator('[data-plugin=assist] [data-setting="anthropic.url"]'); u.fill(f'http://127.0.0.1:{MOCK}'); u.press('Tab'); settle(pg, 900)
        k = pg.locator('[data-plugin=assist] [data-setting="anthropic.key"]'); k.fill('FAKE-ANTHROPIC-KEY-51'); k.press('Tab'); settle(pg, 900)
        k = pg.locator('[data-plugin=assist] [data-setting="anthropic.key"]')
        expect('the key field is empty again', k.input_value(), '')
        expect_in('and says a key is set', '(set', k.get_attribute('placeholder'))
        expect('the key is nowhere in the page', 'FAKE-ANTHROPIC-KEY-51' in pg.content(), False)
        expect('nor in its storage', 'FAKE-ANTHROPIC' in pg.evaluate('JSON.stringify(Object.assign({}, localStorage))'), False)
        pg.screenshot(path=str(SHOTS / 'assist_settings.png'))
        pg.click('#ppClose')
        drop_kind(pg, 'Push button', 40, 30)
        pick_event(pg, 'btn1', 'CLICKED')
        pg.fill('#code', 'say 1'); pg.click('#formTitle'); settle(pg, 900)
        expect('Ask... is there', pg.is_visible('#btnAsk'), True)
        pg.click('#btnAsk'); pg.wait_for_selector('#askPanel:not([hidden])')
        expect_in('it says which code', 'on_btn1_clicked', pg.inner_text('#akWhat'))
        pg.fill('#akTask', 'GOOD: add up 1 to 10 and show it'); pg.click('#akGo')
        pg.wait_for_function("document.getElementById('askPanel').dataset.status !== ''", timeout=60000); settle(pg, 300)
        expect('a proposal that passes', pg.get_attribute('#askPanel', 'data-status'), 'ok')
        expect_in('with its model and cost', 'claude-haiku-5-5', pg.inner_text('#akInfo')); expect_in('  cost', '$', pg.inner_text('#akInfo'))
        expect('the old line marked gone', pg.locator('#akOld .ak-del').count(), 1)
        expect('the new lines marked new', pg.locator('#akNew .ak-add').count(), 6)
        expect_in('  among them', 'total = total + i', pg.inner_text('#akNew'))
        expect('Apply can be pressed', pg.is_enabled('#akApply'), True)
        pg.screenshot(path=str(SHOTS / 'assist_proposal.png'))
        pg.click('[data-akview=graph]')
        pg.wait_for_function("document.getElementById('askPanel').dataset.graphReady === '1'", timeout=30000)
        expect('the proposal as a graph: its loop', pg.locator('#akNew .gb.k-loop, #akNew .gb.k-do').count(), 1)
        expect('  every block of it new', pg.locator('#akNew .gb.ak-add').count(), pg.locator('#akNew .gb').count())
        expect('the code now as a graph: one SAY, gone', pg.locator('#akOld .gb.ak-del').count(), 1)
        pg.screenshot(path=str(SHOTS / 'assist_graph.png'))
        pg.click('[data-akview=code]'); settle(pg, 300)
        pg.click('#akApply'); settle(pg, 1200)
        expect('applied: the code is the proposal', 'total = total + i' in pg.input_value('#code'), True)
        expect_in('and the program has it', 'total = total + i', program_text(pg))
        pg.click('#btnAsk'); pg.wait_for_selector('#askPanel:not([hidden])')
        pg.fill('#akTask', 'TRAP'); pg.click('#akGo')
        pg.wait_for_function("document.getElementById('askPanel').dataset.status !== ''", timeout=60000); settle(pg, 300)
        expect('a proposal with a pitfall', pg.get_attribute('#askPanel', 'data-status'), 'refused')
        expect_in('the reason shown', 'Boston Crab: P1 on line 2', pg.inner_text('#akNotes'))
        expect('Apply cannot be pressed', pg.is_enabled('#akApply'), False)
        pg.screenshot(path=str(SHOTS / 'assist_refused.png'))
        pg.click('#akClose')
        pg.select_option('#uiLang', 'de'); settle(pg, 1500)
        pg.click('#btnAsk'); pg.wait_for_selector('#askPanel:not([hidden])')
        expect_in('the panel in German', 'Um einen Vorschlag bitten', pg.inner_text('#askPanel'))
        pg.fill('#akTask', 'TRAP'); pg.click('#akGo')
        pg.wait_for_function("document.getElementById('askPanel').dataset.status !== ''", timeout=60000); settle(pg, 300)
        expect_in('its reasons in German', 'in Zeile 2', pg.inner_text('#akNotes'))
        pg.click('#akClose'); pg.select_option('#uiLang', 'en'); settle(pg, 1200)
    finally:
        mock.terminate()

def sc_source(pg):
    """Source: the git plugin over GitHub's API (a stand-in), from the Source
    panel: the design committed as a new file, changed and committed again
    (the changes shown first), its history, the first version opened back;
    a commit after someone else's is refused."""
    mock = subprocess.Popen(['node', str(ROOT / 'tests' / 'fixtures' / 'github_mock_server.mjs'), str(GHMOCK)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(0.8)
    def setting(key, value):
        f = pg.locator(f'[data-plugin=git] [data-setting="{key}"]'); f.fill(value); f.press('Tab'); settle(pg, 700)
    try:
        ready(pg); pg.evaluate("localStorage.removeItem('oodDesigner.plugins')"); ready(pg)
        expect('no Repository... until a plugin does source control', pg.is_visible('#btnScm'), False)
        pg.click('#btnPlugins'); pg.wait_for_selector('#plugPanel:not([hidden])'); settle(pg, 600)
        pg.check('#pp-git'); pg.wait_for_selector('[data-plugin=git] [data-setting="token"]', timeout=60000); settle(pg, 300)
        setting('repo', 'owner/demo'); setting('folder', 'designs'); setting('api', f'http://127.0.0.1:{GHMOCK}'); setting('token', 'FAKE-GITHUB-TOKEN-73')
        expect('the token is nowhere in the page', 'FAKE-GITHUB-TOKEN-73' in pg.content(), False)
        pg.click('#ppClose')
        expect('Repository... is there', pg.is_visible('#btnScm'), True)
        drop_kind(pg, 'Push button', 40, 30)
        pg.click('#btnScm'); pg.wait_for_selector('#srcPanel:not([hidden])'); settle(pg, 1500)
        expect_in('the folder listed', 'designs/Hello.rex', pg.inner_text('#scFiles'))
        pg.fill('#scPath', 'designs/MyDialog.rex'); pg.click('#scCheck'); settle(pg, 600)
        expect('a new file', pg.get_attribute('#scState', 'data-state'), 'NEW')
        pg.fill('#scMsg', 'A dialog with a button'); pg.click('#scCommit')
        pg.wait_for_function("document.getElementById('srcPanel').dataset.committed", timeout=30000); settle(pg, 600)
        expect_in('committed', 'Committed', pg.inner_text('#scNotes'))
        expect('now current', pg.get_attribute('#scState', 'data-state'), 'CURRENT')
        pg.click('#scClose')
        pg.click('#formTitle'); settle(pg); set_prop(pg, 'title', 'Greetings')
        pg.click('#btnScm'); pg.wait_for_selector('#srcPanel:not([hidden])'); settle(pg, 1500)
        expect_in('the change shown, as it will be committed', 'Greetings', pg.inner_text('#scDiff .ak-add'))
        pg.screenshot(path=str(SHOTS / 'source_changes.png'))
        pg.evaluate("document.getElementById('srcPanel').dataset.committed = ''")
        pg.fill('#scMsg', 'Title: Greetings'); pg.click('#scCommit')
        pg.wait_for_function("document.getElementById('srcPanel').dataset.committed", timeout=30000); settle(pg, 900)
        expect('committed again', pg.get_attribute('#srcPanel', 'data-committed'), 'ok')
        expect('the history: two commits', pg.locator('#scHistory li').count(), 2)
        expect_in('  newest first', 'Title: Greetings', pg.inner_text('#scHistory li >> nth=0'))
        pg.click('#scHistory li >> nth=1 >> button'); settle(pg, 900)
        expect('the first version shown', 'Greetings' in pg.inner_text('#scVerText'), False)
        pg.screenshot(path=str(SHOTS / 'source_history.png'))
        pg.click('#scVerOpen'); settle(pg, 1500); pg.click('#scClose')
        pg.click('#formTitle'); settle(pg)
        expect('opened back: the title as it was', pg.input_value('#props [data-prop="title"]'), 'My Dialog')
        pg.click('#btnScm'); pg.wait_for_selector('#srcPanel:not([hidden])'); settle(pg, 1500)
        pg.evaluate(f"fetch('http://127.0.0.1:{GHMOCK}/move?path=designs/MyDialog.rex')"); settle(pg, 500)
        pg.click('#scCheck'); settle(pg, 900)
        expect('someone else committed: moved', pg.get_attribute('#scState', 'data-state'), 'MOVED')
        pg.evaluate("document.getElementById('srcPanel').dataset.committed = ''")
        pg.fill('#scMsg', 'Over theirs'); pg.click('#scCommit')
        pg.wait_for_function("document.getElementById('srcPanel').dataset.committed", timeout=30000); settle(pg, 300)
        expect('refused', pg.get_attribute('#srcPanel', 'data-committed'), 'refused')
        expect_in('  saying why', 'moved on', pg.inner_text('#scNotes'))
        pg.click('#scClose')
    finally:
        mock.terminate()

def sc_bound(pg):
    """Bound: the People example, a dialog bound to one object over five
    tables (oorexx_mapped_objects on NoSQLServer). It opens Tom's Person,
    with his phone from per_ext, his employer from com and his addresses
    through per_addr; Save commits a changed name and phone in one
    transaction (the SAVED event says so); an emptied name (NOT NULL) is
    refused in a message, and the dialog stays open. Then (v0.10) another
    employer is picked, an address removed and one added in the row fields,
    and the commit holds them all."""
    ready(pg); open_example(pg, 'examples/People.rex')
    src = program_text(pg)
    expect('round trip in the browser is byte-identical', src, (SITE / 'examples/People.rex').read_text())
    expect('the form names its object', snap(pg)['binding']['object'], 'Person')
    pg.click('#formTitle'); settle(pg)
    expect('the binding in the form\'s properties', pg.input_value('#props [data-prop="databases"]'), 'ent=ent')
    expect_in('SAVED among the form\'s events', 'SAVED', pg.inner_text('#tree'))
    pg.screenshot(path=str(SHOTS / 'bound_design.png'))
    run(pg)
    pg.wait_for_selector('.ood-dlg', timeout=60000); settle(pg, 1500)
    fields = pg.locator('.ood-dlg input[type="text"], .ood-dlg input:not([type])')
    expect('the name, from per', fields.nth(0).input_value(), 'Tom Dyer')
    expect('the phone, from per_ext', fields.nth(1).input_value(), '0141 555 0100')
    t = dlg_text(pg)
    expect_in('the employer, through per_company', 'Anduin', t)
    expect_in('the addresses, through per_addr', 'Byres Road', t)
    expect_in('  both of them', 'Augasse 2-6', t)
    pg.screenshot(path=str(SHOTS / 'bound_run.png'))
    fields.nth(0).fill(''); settle(pg, 200)
    press(pg, 'Save'); settle(pg, 1500)
    expect_in('an empty name: refused, in a message', 'NOT NULL', pg.inner_text('body'))
    pg.screenshot(path=str(SHOTS / 'bound_refused.png'))
    press(pg, 'OK'); settle(pg, 500)
    expect('the dialog stays open', pg.locator('.ood-dlg').count() >= 1, True)
    fields = pg.locator('.ood-dlg input[type="text"], .ood-dlg input:not([type])')
    fields.nth(0).fill('Tom Dyer (Alchemy)'); fields.nth(1).fill('0141 555 0199'); settle(pg, 200)
    # v0.10: the reference picker, the selected row's fields, Remove and Add
    combo = pg.locator('.ood-dlg select').first
    expect('the employer is chosen in a combo box', combo.evaluate('s => s.options[s.selectedIndex].textContent'), 'Anduin')
    expect('  it offers none and every company', combo.evaluate('s => [...s.options].map(o => o.textContent)'), ['', 'Anduin', 'WU Wien'])
    combo.select_option(label='WU Wien'); settle(pg, 200)
    rows = pg.locator('.ood-dlg tbody tr')
    expect('the first address shown in its fields', fields.nth(2).input_value(), 'Byres Road')
    rows.nth(1).click(); settle(pg, 800)
    expect('another row selected: its fields', fields.nth(2).input_value() + '|' + fields.nth(3).input_value(), 'Augasse 2-6|Wien')
    press(pg, 'Remove'); settle(pg, 800)
    expect('Remove: one row left', rows.count(), 1)
    expect('  the fields show the row that is left', fields.nth(2).input_value(), 'Byres Road')
    press(pg, 'Add'); settle(pg, 800)
    expect('Add: a new row', rows.count(), 2)
    expect('  its fields empty and open', [fields.nth(2).input_value(), fields.nth(2).is_enabled()], ['', True])
    fields.nth(2).fill('Great Western Road'); fields.nth(3).fill('Glasgow'); settle(pg, 200)
    rows.nth(0).click(); settle(pg, 800)
    expect('  leaving the row writes its cells', ' '.join(rows.nth(1).inner_text().split()), 'Great Western Road Glasgow')
    pg.screenshot(path=str(SHOTS / 'bound_edit.png'))
    press(pg, 'Save')
    r = wait_end(pg)
    expect('saved: closed with OK', r['rc'], 1)
    out = pg.inner_text('#out')
    expect_in('the SAVED event ran after the commit', 'saved: Tom Dyer (Alchemy) (0141 555 0199)', out)
    expect_in('  the chosen employer was committed', 'employer: WU Wien', out)
    expect_in('  the kept address', 'address: Byres Road / Glasgow', out)
    expect_in('  the added address', 'address: Great Western Road / Glasgow', out)
    expect('  the removed one is gone', 'Augasse' in out, False)

SCENARIOS = {'hand': sc_hand, 'calculator': sc_calculator, 'threads': sc_threads, 'refuse': sc_refuse, 'saveopen': sc_saveopen, 'views': sc_views, 'gadgets': sc_gadgets, 'libraries': sc_libraries, 'graph': sc_graph, 'trace': sc_trace, 'languages': sc_languages, 'ui_de': sc_ui_de, 'plugins': sc_plugins, 'assist': sc_assist, 'source': sc_source, 'bound': sc_bound}
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
