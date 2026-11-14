#!/usr/bin/env python3
"""oodtest.py -- run ooDialog/WASM test programs in headless Chromium.
Architecture: Tom Dyer.  Code: Claude (Fable 5.2).

usage: oodtest.py [--shots] test.rex [test.rex ...]
Each test.rex may have a test.steps file beside it, one step per line:
  wait SELECTOR | click SELECTOR | fill SELECTOR TEXT | press KEY | select SELECTOR LABEL
  shot NAME | sleep MS | eval JS | expect JS ==> VALUE
The program's output is compared with test.expect if that file exists.
Python is used here because this tool drives a browser (Playwright); the
library, its generator and its build are ooRexx.  Progress is logged per step."""
import subprocess, sys, time, os, pathlib
from playwright.sync_api import sync_playwright
ROOT = pathlib.Path(__file__).resolve().parent.parent
PORT = 8017
def log(*a): print('oodtest:', *a, flush=True)
def main():
    args = sys.argv[1:]
    shots = '--shots' in args
    tree = None
    if '--tree' in args:
        i = args.index('--tree'); tree = pathlib.Path(args[i + 1]); del args[i:i + 2]
    tests = [a for a in args if not a.startswith('--')]
    for f in ('ooDialog.cls', 'oodWeb.cls', 'ooShapes.cls'):
        (ROOT / 'site' / f).write_bytes((ROOT / 'dist' / f).read_bytes())
    srv = subprocess.Popen(['node', str(ROOT / 'site/serve.mjs'), str(ROOT / 'site'), '--port', str(PORT)],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1.2)
    failed = 0
    try:
        with sync_playwright() as p:
            b = p.chromium.launch()
            for t in tests:
                tp = pathlib.Path(t)
                pg = b.new_page(viewport={'width': 1000, 'height': 700})
                pg.on('pageerror', lambda e: log('PAGEERROR', e))
                pg.on('console', lambda m: log('console', m.text) if m.type == 'error' else None)
                pg.goto(f'http://localhost:{PORT}/harness.html')
                files = {'/home/rexx/' + f: (ROOT / 'dist' / f).read_text() for f in ('ooDialog.cls', 'oodWeb.cls', 'ooShapes.cls')}
                extra = tp.parent / (tp.stem + '.files')
                if extra.is_dir():
                    for x in extra.iterdir():
                        files['/home/rexx/' + x.name] = x.read_text(encoding='latin-1')
                if tree:                     # a whole directory of text files, with its subdirectories
                    for x in tree.rglob('*'):
                        if x.is_file() and x.suffix.lower() in ('.rex', '.rc', '.h', '.cls', '.txt', '.dlg', '.inp'):
                            files['/home/rexx/' + str(x.relative_to(tree))] = x.read_text(encoding='latin-1')
                files['/home/rexx/' + tp.name] = tp.read_text(encoding='latin-1')
                log('RUN', tp.name)
                pg.evaluate('([prog, files]) => window.oodRun(prog, files)', [tp.name, files])
                steps = tp.with_suffix('.steps')
                ok = True
                if steps.exists():
                    for line in steps.read_text().splitlines():
                        line = line.strip()
                        if not line or line.startswith('#'): continue
                        verb, _, rest = line.partition(' ')
                        try:
                            if verb == 'wait': pg.wait_for_selector(rest, timeout=30000)
                            elif verb == 'click': pg.click(rest, timeout=15000)
                            elif verb == 'fill':
                                sel, _, text = rest.partition(' => '); pg.fill(sel, text, timeout=15000)
                            elif verb == 'select':
                                sel, _, text = rest.partition(' => '); pg.select_option(sel, label=text, timeout=15000)
                            elif verb == 'press': pg.keyboard.press(rest)
                            elif verb == 'sleep': time.sleep(int(rest) / 1000)
                            elif verb == 'eval': log('  eval ->', pg.evaluate(rest))
                            elif verb == 'expect':
                                js, _, want = rest.rpartition(' ==> ')
                                got = str(pg.evaluate(js))
                                if got != want: raise Exception(f'expected {want!r}, got {got!r}')
                            elif verb == 'shot':
                                pg.screenshot(path=str(ROOT / 'shots' / (rest + '.png')))
                            log('  step', line[:90])
                        except Exception as e:
                            log('  STEP FAILED', line, '::', str(e).splitlines()[0]); ok = False; break
                try:
                    pg.wait_for_function('window.oodDone !== null', timeout=30000 if ok else 3000)
                except Exception:
                    log('  program did not end'); ok = False
                    pg.screenshot(path=str(ROOT / 'shots' / (tp.stem + '_stuck.png')))
                out = ''.join(pg.evaluate('window.oodOut'))
                done = pg.evaluate('window.oodDone')
                exp = tp.with_suffix('.expect')
                if exp.exists() and out.strip() != exp.read_text().strip():
                    ok = False; log('  OUTPUT DIFFERS from', exp.name)
                if not ok or not exp.exists():
                    for l in out.splitlines()[:60]: log('  |', l[:200])
                if done and done.get('rc') not in (0, None) and not exp.exists():
                    ok = False               # an error ended the program
                log('PASS' if ok else 'FAIL', tp.name, done)
                failed += 0 if ok else 1
                pg.close()
            b.close()
    finally:
        srv.terminate()
    log('summary:', len(tests) - failed, 'passed,', failed, 'failed, of', len(tests))
    return 1 if failed else 0
sys.exit(main())
