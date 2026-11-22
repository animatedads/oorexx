#!/usr/bin/env python3
"""ooddemo.py -- check the demo page (site/oodialog.html) in headless Chromium:
run the calculator sample, compute 7*6, end it, then run a second sample in the same page.
Architecture: Tom Dyer.  Code: Claude (Fable 5.2)."""
import subprocess, sys, time, pathlib
from playwright.sync_api import sync_playwright
ROOT = pathlib.Path(__file__).resolve().parent.parent
def log(*a): print('ooddemo:', *a, flush=True)
srv = subprocess.Popen(['node', str(ROOT / 'site/serve.mjs'), str(ROOT / 'site'), '--port', '8019'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(1.2)
ok = True
try:
    with sync_playwright() as p:
        b = p.chromium.launch()
        for name, size in (('desktop', {'width': 1000, 'height': 700}), ('phone', {'width': 390, 'height': 800})):
            pg = b.new_page(viewport=size)
            pg.on('pageerror', lambda e: log('PAGEERROR', e))
            pg.goto('http://localhost:8019/oodialog.html')
            pg.select_option('#sample', label='Calculator (upstream sample, RcDialog)')
            pg.click('#run'); log(name, 'run calculator')
            pg.wait_for_selector('.ood-dlg >> text=Sqrt', timeout=40000)
            for key in ('7', '*', '6', '='): pg.click(f'.ood-dlg button:text-is("{key}")')
            time.sleep(0.4)
            got = pg.evaluate("document.querySelector('.ood-dlg input').value")
            fits = pg.evaluate("(() => { const r = document.querySelector('.ood-dlg').getBoundingClientRect(); return r.left >= 0 && r.right <= innerWidth; })()")
            pg.screenshot(path=str(ROOT / 'shots' / f'demo_{name}.png'))
            pg.click('.ood-dlg button:text-is("Exit")')
            pg.wait_for_function("document.getElementById('state').textContent.startsWith('ended')", timeout=20000)
            state1 = pg.inner_text('#state')
            pg.select_option('#sample', label='Menu bar')
            pg.click('#run'); pg.wait_for_selector('.ood-menubar >> text=File', timeout=40000)
            pg.click('.ood-menubar >> text=View'); pg.click('.ood-menu >> text=Status bar'); time.sleep(0.4)
            menu = pg.inner_text('.ood-dlg .ood-static')            # the sample shows its toggles in the dialog
            pg.click('.ood-menubar >> text=File'); pg.click('.ood-menu >> text=Exit')
            pg.wait_for_function("document.getElementById('state').textContent.startsWith('ended')", timeout=20000)
            good = got == '42' and state1 == 'ended, rc 0' and pg.inner_text('#state') == 'ended, rc 0' and menu == 'Toolbar: on, Status bar: on, Ruler: off'
            ended = "document.getElementById('state').textContent.startsWith('ended')"
            # the calculator with keys: typed, not clicked
            pg.select_option('#sample', label='Calculator with keys (upstream sample + connectKeyPress)')
            pg.click('#run'); pg.wait_for_selector('.ood-dlg >> text=Sqrt', timeout=40000)
            pg.keyboard.type('44'); time.sleep(0.4); pg.keyboard.press('Shift+Equal'); pg.keyboard.type('6'); time.sleep(0.3); pg.keyboard.press('Enter'); time.sleep(0.5)
            keys = pg.evaluate("document.querySelector('.ood-dlg input').value")
            pg.click('.ood-dlg button:text-is("Exit")'); pg.wait_for_function(ended, timeout=20000)
            # tool tips: rest the pointer on the Test button
            pg.select_option('#sample', label='Tool tips (upstream sample; needs a mouse)')
            pg.click('#run'); pg.wait_for_selector('.ood-dlg >> text=Test', timeout=40000); time.sleep(0.5)
            box = pg.locator('.ood-dlg >> text=Test').bounding_box()
            pg.mouse.move(box['x'] + 8, box['y'] + 6); pg.mouse.move(box['x'] + 10, box['y'] + 8); time.sleep(1.0)
            tip = pg.evaluate("(() => { const t = document.querySelector('.ood-tip'); return t && !t.hidden ? t.textContent : ''; })()")
            pg.screenshot(path=str(ROOT / 'shots' / f'demo_tip_{name}.png'))
            pg.click('.ood-dlg >> text=Cancel'); pg.wait_for_function(ended, timeout=20000)
            left = pg.evaluate("document.querySelectorAll('body > [class^=\"ood-\"]').length")
            if left: log(name, 'FAIL: the tool tips run left', left, 'elements on the page'); ok = False
            # the resizable dialog: grow it by its corner, the OK button follows
            pg.select_option('#sample', label='Resizable dialog (upstream sample, ResizingAdmin; drag the corner)')
            pg.click('#run'); pg.wait_for_selector('.ood-dlg button.ood-def', timeout=40000); time.sleep(0.5)
            edge = "(() => { const c = [...document.querySelectorAll('.ood-dlg *')].find(x => x.style.resize === 'both').getBoundingClientRect(), b = document.querySelector('.ood-dlg button.ood-def').getBoundingClientRect(); return [c.right, c.bottom, Math.round(c.right - b.right), Math.round(c.bottom - b.bottom)]; })()"
            r0 = pg.evaluate(edge)
            pg.mouse.move(r0[0] - 4, r0[1] - 4); pg.mouse.down(); pg.mouse.move(r0[0] + 40, r0[1] + 30, steps=5); pg.mouse.up(); time.sleep(0.5)
            r1 = pg.evaluate(edge)
            grown = r1[0] - r0[0] > 20 and r1[1] - r0[1] > 15 and r1[2] == r0[2] and r1[3] == r0[3]
            pg.screenshot(path=str(ROOT / 'shots' / f'demo_resize_{name}.png'))
            pg.click('.ood-dlg button.ood-def'); pg.wait_for_function(ended, timeout=20000)
            log(name, 'keys', keys, '| tip', repr(tip), '| corner dragged', [round(r1[0] - r0[0]), round(r1[1] - r0[1])], 'button kept its margins:', r1[2:] == r0[2:])
            good = good and keys == '50' and tip == 'Press Test to execute a ToolTip test' and grown
            log(name, 'display', got, '| first run', state1, '| second run', pg.inner_text('#state'), '| dialog within the window:', fits, '->', 'PASS' if good else 'FAIL')
            ok = ok and good
            pg.close()
        # Every sample of the page: it shows a dialog, Stop can be pressed while the dialog is
        # open (a real click: Playwright refuses a covered button), and nothing is left behind.
        for engine in (p.chromium, p.firefox, p.webkit):
            try: eb = engine.launch()
            except Exception as e: log(engine.name, 'not installed, skipped'); continue
            pg = eb.new_page(viewport={'width': 1100, 'height': 800})
            errors = []
            pg.on('pageerror', lambda e: errors.append(str(e)))
            pg.goto('http://localhost:8019/oodialog.html')
            labels = pg.evaluate("[...document.getElementById('sample').options].map(o => o.textContent)")
            bad = []
            for label in labels:
                pg.select_option('#sample', label=label)
                pg.click('#run')
                try:
                    pg.wait_for_selector('.ood-dlg', timeout=40000); time.sleep(0.4)
                    if pg.locator('.ood-msgbox').count() and 'nable to find' in pg.inner_text('.ood-msgbox'): raise Exception('message box: ' + pg.inner_text('.ood-msgbox')[:60])
                    pg.click('#stop', timeout=5000)
                    pg.wait_for_function("!document.getElementById('run').disabled", timeout=20000)
                    left = pg.evaluate("document.querySelectorAll('body > [class^=\"ood-\"]').length")
                    if left: raise Exception(f'{left} elements left on the page')
                except Exception as e:
                    bad.append(label + ': ' + str(e).splitlines()[0][:110])
                    pg.reload()
            log(engine.name, len(labels), 'samples:', len(labels) - len(bad), 'show a dialog, stop and leave nothing;', 'page errors:', len(errors), '->', 'PASS' if not bad and not errors else 'FAIL')
            for line in bad + errors: log('  ', line)
            ok = ok and not bad and not errors
            eb.close()
        b.close()
finally:
    srv.terminate()
sys.exit(0 if ok else 1)
