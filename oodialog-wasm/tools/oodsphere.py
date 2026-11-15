#!/usr/bin/env python3
"""oodsphere.py: build, check and package the sphere oodialog-wasm.

Architecture: Tom Dyer. Code: Claude (Fable 5.2).

The articles are data in sphere-src/articles.py. This tool makes the sphere from
them with the estate's Sphere Editor (LLM Gopher), so the layout is the editor's.
It is Python because the Sphere Editor is a Python command line tool and the
ooRexx/WASM runtime of this project cannot start another program.

Use (from the project directory, after the release is committed):
  python3 tools/oodsphere.py --gopher PATH/gopher --repo PATH/oorexx-clone --commit COMMIT --out DIR

It prints one line a step. The last line is PASS or FAIL.
Steps: archive the commit; create the sphere; put the articles; attach evidence
(the cited lines are found in the archived files); put the search corpus;
changelog; validate; lint; write the tests and the human page; package; manifest;
run tests/check_sphere.rex and tests/run.sh.
"""
import argparse, hashlib, json, os, shutil, subprocess, sys, zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent

def log(*a):
    print('oodsphere:', *a, flush=True)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--gopher', required=True)
    ap.add_argument('--repo', required=True, help='a clone of animatedads/oorexx with the commit')
    ap.add_argument('--commit', required=True)
    ap.add_argument('--out', required=True, help='work directory; the sphere tree is made in OUT/tree')
    ap.add_argument('--rexx', default='rexx')
    ap.add_argument('--changelog', default='')
    a = ap.parse_args()
    sys.path.insert(0, str(HERE / 'sphere-src'))
    import articles
    S, V = articles.S, articles.VERSION
    out = Path(a.out).resolve(); tree = out / 'tree'; objs = out / 'objs'
    shutil.rmtree(tree, ignore_errors=True); shutil.rmtree(objs, ignore_errors=True); objs.mkdir(parents=True)

    def edit(*args):
        r = subprocess.run([a.gopher, '--profile', 'sphere-authoring', 'sphere', 'edit', *args], capture_output=True, text=True)
        try:
            j = json.loads(r.stdout)
            return j['operation_status']['class'], j.get('result', {})
        except Exception:
            return 'RAW', (r.stdout + r.stderr)[-400:]

    def need(what, got, *ok):
        if got[0] not in ok:
            log('FAIL', what, got[0], str(got[1])[:300]); sys.exit(1)
        log(what, got[0])

    # 1. the evidence archive
    commit = subprocess.run(['git', '-C', a.repo, 'rev-parse', '--short', a.commit], capture_output=True, text=True).stdout.strip()
    zname = 'oodialog-wasm-%s.zip' % commit
    members = ['oodialog-wasm/README.md', 'oodialog-wasm/src', 'oodialog-wasm/tools', 'oodialog-wasm/site/oodfiles.js', 'oodialog-wasm/sphere-src']
    subprocess.run(['git', '-C', a.repo, 'archive', '--format=zip', '-o', str(out / zname), commit, *members], check=True)
    sha = hashlib.sha256((out / zname).read_bytes()).hexdigest()
    log('archive', zname, sha)
    z = zipfile.ZipFile(out / zname)

    # 2. the sphere and its articles
    need('create', edit('create', S, '--path', str(tree), '--title', 'ooDialog on ooRexx/WASM'), 'CREATED')
    for art in articles.ARTICLES:
        f = objs / (art['id'] + '.json'); f.write_text(json.dumps(art, indent=2, ensure_ascii=False))
        need('put ' + art['id'], edit('put', 'article', '--sphere', S, '--path', str(tree), '--from', str(f)), 'CREATED', 'UPDATED')
    man = json.loads((tree / 'packs' / S / '00-sphere.json').read_text())
    man['version'] = V
    man['purpose'] = ('How ooDialog runs in a web browser on ooRexx/WASM: where the code is, how it is built and tested, the contract '
                      'between the native layer and a renderer, the seams other tasks build on, how it differs from Windows, how to port '
                      'a native, and the lessons of the work. For any task that uses, extends, renders or tests ooDialog/WASM.')
    man['start_here'] = ['ops.%s.start' % S]
    f = objs / '00-sphere.json'; f.write_text(json.dumps(man, indent=2))
    need('put sphere', edit('put', 'sphere', '--sphere', S, '--path', str(tree), '--from', str(f)), 'UPDATED', 'CREATED')

    # 3. evidence: find each cited line in the archived file
    for (aid, member, text, span, claim) in articles.EVIDENCE:
        lines = z.read('oodialog-wasm/' + member).decode('utf-8', 'replace').split('\n')
        at = next((i for i, l in enumerate(lines) if text in l), None)
        if at is None:
            log('FAIL evidence: "%s" is not in %s' % (text, member)); sys.exit(1)
        need('evidence %s %s:%d' % (aid.split('.')[-1], member, at + 1),
             edit('evidence', 'article', aid, '--sphere', S, '--path', str(tree), '--artifact', zname, '--sha256', sha,
                  '--member', 'oodialog-wasm/' + member, '--line-start', str(at + 1), '--line-end', str(at + span),
                  '--claim', claim, '--note', 'git archive of animatedads/oorexx commit %s (branch oodialog-wasm)' % commit), 'UPDATED')

    # 4. the corpus: every statement of the articles, for search
    recs = []
    for art in articles.ARTICLES:
        topic = art['id'].split('.')[-1]
        recs.append({'topic': topic, 'article': art['id'], 'rule': art['title'] + '. ' + art['summary']})
        for k, v in art.items():
            if isinstance(v, list) and k not in ('topics', 'provenance'):
                recs += [{'topic': topic, 'article': art['id'], 'field': k, 'rule': s} for s in v]
    corpus = {'kind': 'corpus', 'id': S + '.facts', 'version': V, 'sphere': S,
              'title': 'ooDialog/WASM: every statement of the articles, one a record, for search', 'records': recs}
    f = objs / 'corpus.json'; f.write_text(json.dumps(corpus, indent=1, ensure_ascii=False))
    need('put corpus (%d records)' % len(recs), edit('put', 'corpus', '--sphere', S, '--path', str(tree), '--from', str(f)), 'CREATED', 'UPDATED')

    # 5. the fixed files: tests, human page, integration, changelog
    fixed = HERE / 'sphere-src' / 'fixed'
    for src in sorted(fixed.rglob('*')):
        if src.is_file():
            dst = tree / src.relative_to(fixed); dst.parent.mkdir(parents=True, exist_ok=True)
            text = src.read_text().replace('@VERSION@', V).replace('@PORT@', articles.PORT).replace('@COMMIT@', commit) \
                .replace('@ARCHIVE@', zname).replace('@SHA@', sha).replace('@RECORDS@', str(len(recs))).replace('@ARTICLES@', str(len(articles.ARTICLES)))
            dst.write_text(text); shutil.copymode(src, dst)
    (tree / 'CHANGELOG.md').write_text((HERE / 'sphere-src' / 'CHANGELOG.md').read_text())
    log('fixed files copied')

    # 6. validate, lint, package, manifest
    need('validate', edit('validate', S, '--path', str(tree)), 'VALID')
    need('lint', edit('lint', S, '--path', str(tree)), 'CLEAN')
    zipout = out / ('oodialog_wasm_gopher_sphere_v%s.zip' % V)
    zipout.unlink(missing_ok=True)
    (tree / 'MANIFEST.sha256').unlink(missing_ok=True)
    need('package', edit('package', S, '--path', str(tree), '--out', str(zipout)), 'PACKAGED')
    files = sorted(p.relative_to(tree).as_posix() for p in tree.rglob('*') if p.is_file() and p.name != 'MANIFEST.sha256')
    (tree / 'MANIFEST.sha256').write_text(''.join('%s  %s\n' % (hashlib.sha256((tree / f).read_bytes()).hexdigest(), f) for f in files))
    log('manifest', len(files), 'files')

    # 7. the sphere's own tests
    r = subprocess.run([a.rexx, str(tree / 'tests' / 'check_sphere.rex'), str(tree)], capture_output=True, text=True)
    line = (r.stdout.strip().split('\n') or [''])[-1]; log(line)
    if not line.startswith('PASS'): log('FAIL structural check'); sys.exit(1)
    env = dict(os.environ, GOPHER=a.gopher, SPHERE_ZIP=str(zipout))
    r = subprocess.run(['sh', str(tree / 'tests' / 'run.sh')], capture_output=True, text=True, env=env)
    line = (r.stdout.strip().split('\n') or [''])[-1]; log(line)
    if not line.startswith('PASS'): log('FAIL activation test', r.stderr[-300:]); sys.exit(1)
    log('PASS sphere %s v%s: %s  sha256 %s' % (S, V, zipout, hashlib.sha256(zipout.read_bytes()).hexdigest()))

if __name__ == '__main__':
    main()
