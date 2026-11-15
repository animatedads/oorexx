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
import subprocess, sys, time, os, pathlib, base64
TEXT = ('.rex', '.rc', '.h', '.cls', '.txt', '.dlg', '.inp')
BINARY = ('.bmp', '.ico', '.png', '.gif', '.jpg', '.dll', '.exe', '.res', '.cur')
from playwright.sync_api import sync_playwright
ROOT = pathlib.Path(__file__).resolve().parent.parent
PORT = 8017
def log(*a): print('oodtest:', *a, flush=True)
def start_in_own_dir(pg, rel, files):
    """Run an example with its own directory as the current directory, as its author did."""
    cwd = '/home/rexx/' + str(pathlib.PurePosixPath(rel).parent) if '/' in rel else '/home/rexx'
    mine = dict(files)
    for f in ('ooDialog.cls', 'oodWeb.cls', 'ooShapes.cls'): mine[cwd + '/' + f] = files['/home/rexx/' + f]
    pg.evaluate('([prog, files, cwd]) => window.oodRun(prog, files, cwd)', [pathlib.PurePosixPath(rel).name, mine, cwd])

def sweep(tree, report):
    """Run every .rex of a tree that requires ooDialog.cls, 5 s each, and classify what happens."""
    import re, json
    for f in ('ooDialog.cls', 'oodWeb.cls', 'ooShapes.cls'):
        (ROOT / 'site' / f).write_bytes((ROOT / 'dist' / f).read_bytes())
    files = {'/home/rexx/' + f: (ROOT / 'dist' / f).read_text() for f in ('ooDialog.cls', 'oodWeb.cls', 'ooShapes.cls')}
    progs = []
    for x in sorted(tree.rglob('*')):
        if x.is_file() and x.suffix.lower() in BINARY:
            files['/home/rexx/' + str(x.relative_to(tree))] = {'b64': base64.b64encode(x.read_bytes()).decode()}
        if x.is_file() and x.suffix.lower() in TEXT:
            text = x.read_text(encoding='latin-1')
            files['/home/rexx/' + str(x.relative_to(tree))] = text
            if x.suffix.lower() == '.rex' and re.search(r'::requires\s+["\']ooDialog.cls', text, re.I): progs.append(x)
    srv = subprocess.Popen(['node', str(ROOT / 'site/serve.mjs'), str(ROOT / 'site'), '--port', str(PORT)],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1.2)
    rows = []
    try:
        with sync_playwright() as p:
            b = p.chromium.launch()
            for n, x in enumerate(progs, 1):
                rel = str(x.relative_to(tree))
                pg = b.new_page(viewport={'width': 1000, 'height': 700})
                pg.goto(f'http://localhost:{PORT}/harness.html')
                start_in_own_dir(pg, rel, files)
                state = 'timeout'
                for _ in range(25):
                    time.sleep(0.2)
                    if pg.evaluate('window.oodDone !== null'): state = 'ended'; break
                    if pg.evaluate("document.querySelector('.ood-dlg:not(.ood-msgbox)') !== null"):
                        time.sleep(0.6); state = 'dialog'; break
                    if pg.evaluate("document.querySelector('.ood-msgbox') !== null"):
                        time.sleep(0.3); state = 'message'; break
                out = ''.join(pg.evaluate('window.oodOut'))
                m = re.search(r'native function (\w+)', out)
                err = re.search(r'Error (\d+)(?:\.\d+)?:? +(.*)', out)
                todo = pg.evaluate("[...new Set([...document.querySelectorAll('.ood-todo')].map(e => e.textContent.split(' ')[0]))].join(' ')")
                outside = re.search(r'(winsystm\.cls|orexxole\.cls|OLEObject)', out, re.I)   # not ooDialog: Windows system classes and OLE
                if outside and state != 'dialog': verdict = 'outside:' + outside.group(1)
                elif m: verdict = 'native:' + m.group(1)
                elif err and state != 'dialog':
                    detail = re.search(r'Error (\d+\.\d+): +([^\n]*)', out)
                    text = ('Error ' + detail.group(1) + ' ' + detail.group(2)) if detail else out[err.start():err.start() + 90].replace('\n', ' ')
                    # a part of a larger program, started on its own: it names its files from the program's directory
                    verdict = ('component:' if re.search(r'Could not find (file|routine) "[^"]*\\', text) else 'error:') + text[:110]
                elif state == 'dialog': verdict = 'shows' + (' placeholders:' + todo if todo else '') + (' +error' if err else '')
                elif state == 'message': verdict = 'message:' + pg.evaluate("document.querySelector('.ood-msgtext').textContent").replace('\n', ' ')[:90]
                else: verdict = state
                rows.append((rel, verdict)); log(f'{n}/{len(progs)}', rel, '->', verdict[:110])
                pg.close()
            b.close()
    finally:
        srv.terminate()
    report.write_text('\n'.join(f'{a}\t{v}' for a, v in rows) + '\n')
    kinds = {}
    for _, v in rows:
        k = v.split(' ')[0] if v.startswith('native:') else v.split(':')[0].split(' ')[0]
        kinds[k] = kinds.get(k, 0) + 1
    log('sweep summary:', json.dumps(dict(sorted(kinds.items(), key=lambda kv: -kv[1]))))
    return 0

POKE_JS = """
async () => {
  const sleep = (ms) => new Promise(r => setTimeout(r, ms));
  const base = document.querySelectorAll('.ood-dlg:not(.ood-child):not(.ood-msgbox)').length;
  const acts = [];
  const tidy = async () => {                       // close whatever an action opened
    for (let i = 0; i < 5; i++) {
      await sleep(150);
      const m = [...document.querySelectorAll('.ood-msgbox')].pop();
      if (m) { m.querySelector('button.ood-c').click(); continue; }
      document.querySelectorAll('.ood-menu').forEach(x => x.remove());
      const d = [...document.querySelectorAll('.ood-dlg:not(.ood-child):not(.ood-msgbox)')];
      if (d.length > base) { const x = d.pop().querySelector('.ood-x'); if (x && !x.disabled) { x.click(); continue; } }
      break;
    }
  };
  const top = () => [...document.querySelectorAll('.ood-dlg:not(.ood-child):not(.ood-msgbox)')][base - 1];
  const leave = /^(ok|cancel|exit|close|quit|done|end|leave|bye|stop|finish|no|yes)\\b/i;
  const dlg = top(); if (!dlg) return acts;
  const all = (sel) => [...dlg.querySelectorAll(sel)].filter(e => e.offsetParent !== null && !e.disabled);
  for (const b of all('.ood-tabbtn').slice(0, 6)) { b.click(); acts.push('tab'); await tidy(); }
  for (const r of all('.ood-lv tbody tr').slice(0, 2)) { r.click(); acts.push('row'); await tidy(); }
  for (const r of all('.ood-tvrow').slice(0, 2)) { r.click(); acts.push('node'); await tidy(); }
  for (const c of all('.ood-check input').slice(0, 6)) { c.click(); acts.push('check'); await tidy(); }
  for (const sel of all('select').slice(0, 4)) { if (sel.options.length) { sel.selectedIndex = Math.min(1, sel.options.length - 1); sel.dispatchEvent(new Event('change', {bubbles: true})); acts.push('select'); await tidy(); } }
  for (const e of all('input.ood-edit:not([readonly]), textarea.ood-edit:not([readonly])').slice(0, 3)) { e.value = '12'; e.dispatchEvent(new Event('input', {bubbles: true})); acts.push('type'); await tidy(); }
  for (const b of all('.ood-menubar button').slice(0, 4)) { b.click(); await sleep(100); const it = document.querySelector('.ood-menu .ood-mi:not(.ood-off)'); if (it && !leave.test(it.textContent.trim())) { it.click(); acts.push('menu'); } await tidy(); }
  for (const b of all('button.ood-c').filter(b => !leave.test(b.textContent.trim())).slice(0, 10)) {
    if (!document.body.contains(b) || b.disabled) continue;
    b.click(); acts.push('button:' + b.textContent.trim().slice(0, 14)); await tidy();
    if (document.querySelectorAll('.ood-dlg:not(.ood-child):not(.ood-msgbox)').length < base) return acts;
  }
  const d2 = top();
  if (d2) { const x = d2.querySelector('.ood-x'); if (x && !x.disabled) { x.click(); acts.push('close'); } await tidy(); }
  return acts;
}
"""

def poke(tree, lo, hi):
    """Depth probe: for each example that shows a dialog (sweep.tsv), use its controls and record what goes wrong."""
    import re, json
    files = {'/home/rexx/' + f: (ROOT / 'dist' / f).read_text() for f in ('ooDialog.cls', 'oodWeb.cls', 'ooShapes.cls')}
    for x in sorted(tree.rglob('*')):
        if x.is_file() and x.suffix.lower() in BINARY:
            files['/home/rexx/' + str(x.relative_to(tree))] = {'b64': base64.b64encode(x.read_bytes()).decode()}
        if x.is_file() and x.suffix.lower() in TEXT:
            files['/home/rexx/' + str(x.relative_to(tree))] = x.read_text(encoding='latin-1')
    progs = [l.split('\t')[0] for l in (ROOT / 'sweep.tsv').read_text().splitlines() if l.split('\t')[1].startswith(('shows', 'message'))][lo:hi]
    for f in ('ooDialog.cls', 'oodWeb.cls', 'ooShapes.cls'):
        (ROOT / 'site' / f).write_bytes((ROOT / 'dist' / f).read_bytes())
    srv = subprocess.Popen(['node', str(ROOT / 'site/serve.mjs'), str(ROOT / 'site'), '--port', str(PORT)],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1.2)
    rows = []
    try:
        with sync_playwright() as p:
            b = p.chromium.launch()
            for n, rel in enumerate(progs, lo + 1):
                pg = b.new_page(viewport={'width': 1000, 'height': 700})
                perr = []
                pg.on('pageerror', lambda e: perr.append(str(e)[:120]))
                pg.goto(f'http://localhost:{PORT}/harness.html')
                start_in_own_dir(pg, rel, files)
                try:
                    pg.wait_for_selector('.ood-dlg', timeout=8000); time.sleep(0.5)
                    for _ in range(4):                   # a program may open with message boxes
                        if pg.evaluate("document.querySelector('.ood-dlg:not(.ood-msgbox)') !== null"): break
                        if pg.evaluate("(() => { const m = document.querySelector('.ood-msgbox'); if (m) m.querySelector('button.ood-c').click(); return !!m; })()"): time.sleep(0.8)
                        else: time.sleep(0.5)
                    todo = pg.evaluate("[...new Set([...document.querySelectorAll('.ood-todo')].map(e => e.textContent.split(' ')[0]))].join(' ')")
                    acts = pg.evaluate(POKE_JS)
                except Exception as e:
                    todo, acts = '', ['PROBE FAILED ' + str(e).splitlines()[0][:80]]
                ended = False
                for _ in range(150):                     # close whatever is still open, topmost first, until the program ends (up to a minute: queued clicks may each open another dialog)
                    if pg.evaluate('window.oodDone !== null'): ended = True; break
                    pg.evaluate("""(() => {
                      const m = [...document.querySelectorAll('.ood-msgbox')].pop();
                      if (m) { m.querySelector('button.ood-c').click(); return; }
                      const tried = (window.__tried = window.__tried || new WeakSet());   // each way out is tried once
                      const ds = [...document.querySelectorAll('.ood-dlg:not(.ood-child)')].sort((a, b) => Number(b.style.zIndex) - Number(a.style.zIndex));
                      for (const d of ds) {                // topmost first; a dialog that refuses to close is passed over for its owner
                        const x = d.querySelector('.ood-x');
                        if (x && !x.disabled && !tried.has(x)) { tried.add(x); x.click(); return; }
                        const b = [...d.querySelectorAll('button.ood-c')].find(b => !b.disabled && !tried.has(b) && /^(ok|cancel|exit|close|quit|done|end|finish)/i.test(b.textContent.trim()));
                        if (b) { tried.add(b); b.click(); return; }
                        if (!tried.has(d)) { tried.add(d); d.dispatchEvent(new KeyboardEvent('keydown', {key: 'Escape', bubbles: true})); return; }
                      }
                    })()""")
                    time.sleep(0.4)
                out = ''.join(pg.evaluate('window.oodOut'))
                unknown = pg.evaluate("window.__ood ? [...new Set(window.__ood.log)].join(' | ') : ''")
                probs = []
                for m in re.finditer(r'native function (\w+)', out): probs.append('native:' + m.group(1))
                for m in re.finditer(r'is connected but is not produced yet', out): probs.append('event-not-produced')
                for m in re.finditer(r'Error (\d+\.\d+): +([^\n]{0,70})', out):
                    if 'native function' not in m.group(2): probs.append('error ' + m.group(1) + ' ' + m.group(2).strip())
                for u in unknown.split(' | '):
                    if u: probs.append('unhandled ' + u)
                if todo: probs.append('placeholder ' + todo)
                for e in perr: probs.append('pageerror ' + e)
                if not ended:
                    left = pg.evaluate("[...document.querySelectorAll('.ood-dlg:not(.ood-child)')].map(e => (e.classList.contains('ood-msgbox') ? 'msgbox: ' + e.querySelector('.ood-msgtext').textContent.slice(0, 60) : 'dialog: ' + ((e.querySelector('.ood-title span') || {}).textContent || '')) + (e.querySelector('.ood-x') && e.querySelector('.ood-x').disabled ? ' [close disabled]' : '')).join(' / ')")
                    probs.append('did-not-end, left open: ' + (left or 'nothing').replace('\n', ' '))
                probs = sorted(set(probs))
                rows.append((rel, len(acts), probs))
                log(f'{n}', rel, 'actions', len(acts), '->', ('; '.join(probs))[:150] if probs else 'clean')
                if os.environ.get('OODPOKE_VERBOSE'):
                    log('   actions:', ' '.join(acts)[:300])
                    for l in out.splitlines()[:25]: log('   |', l[:170])
                pg.close()
            b.close()
    finally:
        srv.terminate()
    with open(ROOT / 'poke.tsv', 'a') as o:
        for rel, n, probs in rows: o.write(rel + '\t' + str(n) + '\t' + ' ; '.join(probs) + '\n')
    return 0

def main():
    args = sys.argv[1:]
    if '--poke' in args:
        i = args.index('--poke')
        return poke(pathlib.Path(args[i + 1]), int(args[i + 2]), int(args[i + 3]))
    if '--sweep' in args:
        i = args.index('--sweep')
        return sweep(pathlib.Path(args[i + 1]), ROOT / 'sweep.tsv')
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
                    for x in sorted(extra.rglob('*')):   # files beside the test, with sub-directories; binaries go as bytes
                        if not x.is_file(): continue
                        name = '/home/rexx/' + x.relative_to(extra).as_posix()
                        if x.suffix.lower() in BINARY: files[name] = {'b64': base64.b64encode(x.read_bytes()).decode()}
                        else: files[name] = x.read_text(encoding='latin-1')
                if tree:                     # a whole directory, with its subdirectories; images go as base64
                    for x in tree.rglob('*'):
                        if x.is_file() and x.suffix.lower() in TEXT:
                            files['/home/rexx/' + str(x.relative_to(tree))] = x.read_text(encoding='latin-1')
                        elif x.is_file() and x.suffix.lower() in BINARY:
                            files['/home/rexx/' + str(x.relative_to(tree))] = {'b64': base64.b64encode(x.read_bytes()).decode()}
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
                            log('  STEP FAILED', line, '::', ' | '.join(str(e).splitlines()[:12])[:900]); ok = False; break
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
