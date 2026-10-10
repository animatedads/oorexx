import itertools,random,sys
from pathlib import Path
r=random.Random(7502)
values={b'',b'0',b'F',b'FF',b'FFFF',b'FFF',b'800',b'7FF',b'FFFFFFFF',b'AB CD',b'A BC',b'AB C',b'A B',b' F',b'F ',b'\tF',b'F\t',b'ZZ',b'0xFF',b'\x00',b'\xff',b'00000',b'00000000000000000'}
for n in range(1,35):
    for j in range(25):
        values.add(bytes(r.choice(b'0123456789ABCDEFabcdef') for _ in range(n)))
for n in range(1,9):
    for seq in itertools.product(b'0F a\t',repeat=n):
        values.add(bytes(seq))
        if len(values)>4200:break
    if len(values)>4200:break
for _ in range(800):
    n=r.randrange(1,160)
    values.add(bytes(r.choice(b'0123456789abcdefABCDEF \t\x00\xffXYZ') for _ in range(n)))
with Path(sys.argv[1]).open('w') as f:
  for v in sorted(values):
    for d in (3,9,34):
      for n in ('-', '0','1','2','3','4','8','16','32'):
         f.write(v.hex().upper()+'|'+n+'|'+str(d)+'\n')
print(len(values)*27)
