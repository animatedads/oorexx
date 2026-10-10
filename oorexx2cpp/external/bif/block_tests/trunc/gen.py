#!/usr/bin/env python3
from pathlib import Path
import random,sys
r=random.Random(102210);out=Path(sys.argv[1]);values={b'0',b'-0',b'0.000',b'-0.000',b'1',b'-1',b'1.2345',b'9.9995',b'99999.99',b'.0009995',b'-0.0009995',b'1E+20',b'1E-20',b'123.456789',b'1.2E-3',b'  - 12.345  ',b'',b'abc',b'1..2',b'--1',b'1e+',b'1\x00',b'\xff'}
for _ in range(4500):
    sign=r.choice([b'',b'-',b'+',b' ',b'  - ',b'  +'])
    left=bytes(r.choice(b'0123456789') for _ in range(r.randrange(1,27)))
    frac=bytes(r.choice(b'0123456789') for _ in range(r.randrange(0,24)))
    e=r.choice([b'',b'',b'',b'E+2',b'E-2',b'e+10',b'E-15',b'E+100',b'E-100'])
    values.add(sign+left+(b'.'+frac if r.randrange(3) else b'')+e+r.choice([b'',b' ',b'\t']))
with out.open('w') as f:
    for v in sorted(values):
        for n in ['-','0','1','2','4','9','20']:
            f.write(v.hex().upper()+'|'+n+'\n')
print('cases',len(values)*7)
