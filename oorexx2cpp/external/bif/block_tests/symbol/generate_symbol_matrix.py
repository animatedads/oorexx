#!/usr/bin/env python3
# Test data ONLY; native implementation and source rule converter remain C++/ooRexx.
from itertools import product
from pathlib import Path
import random,sys
out=Path(sys.argv[1]); out.parent.mkdir(parents=True,exist_ok=True)
values={b'', b'.',b'..',b'...',b'1',b'0',b'1.',b'.1',b'1.2',b'1.2.3', b'1E+2',b'1E-2',b'1E+',b'1E-',b'1E',b'foo',b'foo.',b'foo.bar',b'foo..bar',b'!_?',b'A\x00B',b'\xff',b'+2',b'-2',b'1+2',b'1e+2',b'fooe+2', b'fooE-1', b'fooe+x',b'1E+2.3', b'\t',b'\r',b'\n',b' ',b'1 2',b'abc-def',b'ABC_DEF',b'?',b'!',b'_',b'a.b.c',b'1.2.3E+2', b'x'*250,b'x'*251,b'1'*250,b'1'*251}
for n in range(1,5):
  for seq in product(b'A1.!?+_-e0\x00\xff',repeat=n): values.add(bytes(seq))
random.seed(99216)
for n in (5,10,32,120,249,250,251,252):
  for _ in range(120): values.add(bytes(random.choice(b'abcXYZ0123._!?E+-\x00\xff') for _ in range(n)))
with out.open('w') as f:
  for v in sorted(values): f.write(v.hex().upper()+'\n')
print('cases',len(values))
