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
            pg.click('.ood-menubar >> text=File'); pg.click('.ood-menu >> text=Exit')
            pg.wait_for_function("document.getElementById('state').textContent.startsWith('ended')", timeout=20000)
            good = got == '42' and state1 == 'ended, rc 0' and pg.inner_text('#state') == 'ended, rc 0'
            log(name, 'display', got, '| first run', state1, '| second run', pg.inner_text('#state'), '| dialog within the window:', fits, '->', 'PASS' if good else 'FAIL')
            ok = ok and good
            pg.close()
        b.close()
finally:
    srv.terminate()
sys.exit(0 if ok else 1)
