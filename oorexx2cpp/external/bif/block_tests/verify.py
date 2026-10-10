#!/usr/bin/env python3
"""Compare independently executed ooRexx and native outputs per function block."""
import sys
from pathlib import Path
from collections import Counter, defaultdict
root=Path(__file__).resolve().parent
matrix=(root/'matrix.tsv').read_text().splitlines()
range_matrix=(root/'range.tsv').read_text().splitlines()

def verify(rows, reference, native, blocks):
    expected=Path(reference).read_bytes().splitlines()
    observed=Path(native).read_bytes().splitlines()
    if not (len(rows)==len(expected)==len(observed)):
        raise SystemExit('FAIL: line count mismatch '+str((len(rows),len(expected),len(observed))))
    counts=Counter()
    failures=defaultdict(list)
    for row,a,b in zip(rows,expected,observed):
        cols=row.split('\t')
        block=cols[2]
        counts[block]+=1
        if a!=b: failures[block].append((cols[0],cols[1],a.decode('ascii','replace'),b.decode('ascii','replace')))
    for block in blocks:
        f=failures[block]
        print(('FAIL' if f else 'PASS')+f' {block}: {counts[block]-len(f)}/{counts[block]} exact-byte cases')
        for x in f[:10]:print('  ',x)
    if any(failures.values()):raise SystemExit(1)
verify(matrix,root/'matrix.oracle',root/'matrix.native',['bytes','search','words','text'])
verify(range_matrix,root/'range.oracle',root/'range.native',['range'])
