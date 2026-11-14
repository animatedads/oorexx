#!/usr/bin/env python3
"""cfn.py NAME [NAME...] : print the C++ source of upstream ooDialog natives (reading aid).
   cfn.py --sigs : write dist/sigs.txt, one joined signature per native."""
import re, sys, glob
src = {}
for f in glob.glob('upstream/ooDialog/*.cpp'):
    src[f] = open(f, encoding='latin-1').read()
pat = re.compile(r'^Rexx(?:Method|Routine)\d+\(\s*\w+\s*,\s*(\w+)[^)]*\)', re.M | re.S)
def all_fns():
    for f, t in src.items():
        for m in pat.finditer(t):
            yield f, t, m
if sys.argv[1] == '--sigs':
    with open('dist/sigs.txt', 'w') as o:
        for f, t, m in sorted(all_fns(), key=lambda x: x[2].group(1).lower()):
            o.write(' '.join(m.group(0).split()) + '\n')
    sys.exit(0)
want = {a.lower() for a in sys.argv[1:]}
for f, t, m in all_fns():
    if m.group(1).lower() in want:
        end = t.find('\n}\n', m.end())
        body = t[m.start():end + 2]
        body = re.sub(r'\n\s*\n', '\n', body)
        print(f'// {f.split("/")[-1]}'); print(body); print()
