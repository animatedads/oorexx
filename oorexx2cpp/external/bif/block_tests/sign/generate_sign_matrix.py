#!/usr/bin/env python3
# Test data only; native BIF is C++, upstream-source converter is ooRexx.
from pathlib import Path
from itertools import product
import random,sys
out=Path(sys.argv[1]);out.parent.mkdir(parents=True,exist_ok=True)
values={b'',b'0',b'-0',b'+0',b'0.0',b'-0.0',b'.1',b'1.',b'-.1',b'+.1',b'1e0',b'1E+999999999',b'1E+1000000000',b'1e-999999999',b'1e-1000000000',b'0e999999999',b'0e1000000000',b'1e000000000000000000000000000000001',b'1e-000000000000000000000000000000001',b'1e+000000000999999999',b'1e+000000001000000000',b'1e9999999999999999',b'1e-',b'e1',b'1e+2.1',b'1.2.3',b'  ',b'\r',b'\n',b'\t',b'1\r',b'1\t',b'\t1',b'1 2',b'--1',b'1+2',b'+-1',b'1e+-1',b'0'*1200,b'1'*800,b'0.'+b'0'*800+b'1',b'0.'+b'0'*800,b'\x00',b'1\x002',b'\xff',b'  -1.05e+100  ',b'-12E-12'}
base=[b'0',b'1',b'2',b'3',b'9',b'00',b'01',b'10',b'123456789',b'123456789012345678901234567890',b'000000001',b'0.00001',b'.001',b'1.',b'1.2',b'9.99',b'1E+100',b'0E-99']
for b in base:
 for p,q in product((b'',b'+',b'-',b' ',b'  ',b'\t',b' \t'),repeat=2):
  values.add(p+b+q)
for x in (b'',b'0',b'1',b'9',b'123',b'1.0',b'.5',b'0.',b'-2',b'+2'):
 for exponent in (b'',b'e0',b'e-1',b'E+1',b'E999999999',b'e1000000000',b'e-999999999',b'e-1000000000',b'E+',b'e-',b'E00',b'e000000000000001',b'e9999999999999'):
  values.add(x+exponent)
for n in (1,2,3,4):
 for seq in product(b'0-+eE.1 ',repeat=n): values.add(bytes(seq))
r=random.Random(771994)
for n in (0,1,2,3,5,7,12,20,30,80,150,260,800):
 for _ in range(170): values.add(bytes(r.choice(b'0123456789.eE+- \t\x00\xffXABC') for _ in range(n)))
for _ in range(6500):
 p=r.choice((b'',b'+',b'-',b'  ',b'\t',b' \t'))
 i=bytes(r.choice(b'00123456789') for _ in range(r.randrange(0,40)))
 f=bytes(r.choice(b'000123456789') for _ in range(r.randrange(0,40)))
 n=i+(b'.'+f if r.randrange(3) else b'')
 e=(r.choice((b'E',b'e'))+r.choice((b'',b'+',b'-'))+str(r.choice((r.randrange(100),r.randrange(1000000000),999999999,1000000000))).encode()) if r.randrange(2) else b''
 values.add(p+n+e+r.choice((b'',b' ',b'\t',b'  ')))
with out.open('w') as fp:
 for s in sorted(values):fp.write(s.hex().upper()+'\n')
print(len(values))
