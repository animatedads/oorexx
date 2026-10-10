#!/usr/bin/env python3
# Oracle corpus only. No production BIF or compiler logic in Python.
from pathlib import Path
from random import Random
import sys
seed=Random(106241)
values={b'',b' ',b'\t',b'0',b'-0',b'+0',b'+ 0',b'- 0',b'0e500',b'0e-50000',b'1e-500',b'1e500',b'1e+1000',b'NaN',b'Inf',b'0x1',b'0.0',b'.000001',b'.0000009',b'0000.0001',b'  + 0.00050 ',b'0.000',b'.0',b'0.',b'0.e0',b'0e0',b'0E+99999999999',b'-.00001',b'-1',b'-0.0001',b'2147484',b'2147483.01',b'junk',b'1 2',b'1e+',b'0 e0',b'0\x00',b'\xff',b'0\xff',b'0\n',b'0\r',b'0\t',b'\t0',b'0  ',b'  0',b'1E-10000'}
for i in range(500):
    n=seed.randrange(0,999)
    first=seed.choice([b'',b'  ',b'\t',b'+ ',b'- ',b' + ',b' - '])
    last=seed.choice([b'',b' ',b'\t'])
    payload=b'0.'+f'{n:06d}'.encode() # <=1 millisecond
    if seed.randrange(4)==0: payload+=seed.choice([b'e-1',b'E-10',b'e+0',b'e+',b'x',b'\x00'])
    values.add(first+payload+last)
for i in range(300):
    payload=bytes(seed.choice(b'ABCXYZ_!?.-+eE\x00\xff') for _ in range(seed.randrange(1,6)))
    values.add(payload)
p=Path(sys.argv[1]);p.parent.mkdir(parents=True,exist_ok=True)
p.write_text(''.join(v.hex().upper()+'\n' for v in sorted(values)))
print('cases',len(values))
