import random, pathlib
rng=random.Random(53196)
D=pathlib.Path(__file__).parent
cases=[]
def add(block,name,*args): cases.append((block,name,tuple(a if isinstance(a,bytes) else str(a).encode('latin1') for a in args)))
# Block 1: bit and hex
for s in [b'',b'A',b'\x00\xff\x80',bytes(range(10)),b'12345',b'\x00\x00']:
 add('bytes','C2X',s)
for s in ['','0','1','01','101','10001','10101010','111100000001']:
 add('bytes','B2X',s)
for s in ['','0','a','Af','09','123abc','000000']:
 add('bytes','X2B',s)
for s in ['','00','FF','dead','41 42','00 0A 7F']:
 add('bytes','X2C',s)
for name in ['BITAND','BITOR','BITXOR']:
 for a,b in [(b'',b''),(b'',b'abc'),(b'abc',b''),(b'A',b'B'),(b'ABC',b'Q'),(b'\x00\xff',b'\xff\x00\x01'),(bytes(range(6)),bytes(range(3)))]:
  add('bytes',name,a,b)
  for p in [b'\x00',b'\xff',b'.']:
   add('bytes',name,a,b,p)
 for s in [b'',b'hello']:add('bytes',name,s)
# Block 2: search and replacement
for name in ['POS','LASTPOS']:
 for hay in ['', 'ababa','abcabc','abcde','  a a  ', 'xxxabc']:
  for needle in ['', 'a', 'ab','bc','zz']:
   add('search',name,needle,hay)
   for start in [1,2,4,7]:add('search',name,needle,hay,start)
for a,b in [('', ''),('a','aaa'),('aba','ababa'),('bc','abcabc'),('z','abcdef'),(' ','a b c')]:
 add('search','COUNTSTR',a,b)
 for replacement in ['','X','xyz']:
  add('search','CHANGESTR',a,b,replacement)
  for cnt in [0,1,2,5]: add('search','CHANGESTR',a,b,replacement,cnt)
for a,b in [('',''),('abc','abc'),('abc','ABC'),('a','b'),('a','a.')]:
 add('search','COMPARE',a,b)
 for pad in ['.','z']: add('search','COMPARE',a,b,pad)
for a,b in [('abc','a'),('abc','ab'),('abc',''),('abc','abcd'),('',''),('abc','bc')]:
 add('search','ABBREV',a,b)
 for n in [0,1,2,4]: add('search','ABBREV',a,b,n)
# Block 3: word processing
word_samples=['',' ','  a b  ',' a  b   c d ','\ta\tb\t','a\t b\t c','a\x0bb c','a\x0cb c','a\x0db c','a\x85b c','abc','  one   two  three   ']
for s in word_samples:
 for name in ['WORDS','SPACE']:add('words',name,s)
 for n in [0,1,2,3]:add('words','SPACE',s,n)
 for n in [1,2,3,4,8]:
  for name in ['WORD','WORDINDEX','WORDLENGTH','SUBWORD','DELWORD']:add('words',name,s,n)
  for name in ['SUBWORD','DELWORD']:
   for length in [0,1,2,5]:add('words',name,s,n,length)
for phrase in ['','a','a b','b  c','one two','two three']:
 for hay in word_samples:
  add('words','WORDPOS',phrase,hay)
  for start in [1,2,5]:add('words','WORDPOS',phrase,hay,start)
# Block 4: transformation and padding
for s in ['','a','abc','abcdef','  a  ','a\x00b','a\tb\n','\xffbc']:
 for name in ['UPPER','LOWER','REVERSE']:add('text',name,s)
 for start in [1,2,3,9]:
  for name in ['UPPER','LOWER','DELSTR','SUBSTR']:add('text',name,s,start)
  for length in [0,1,2,6]:
   for name in ['UPPER','LOWER','DELSTR','SUBSTR']:add('text',name,s,start,length)
 for n in [0,1,3,6,9]:
  for name in ['LEFT','RIGHT','CENTER','CENTRE']:add('text',name,s,n)
  for name in ['LEFT','RIGHT','CENTER','CENTRE']:add('text',name,s,n,'-')
 for name in ['STRIP','SPACE']:add('text',name,s)
 for mode in ['B','L','T']: add('text','STRIP',s,mode)
 for n in [0,1,3]: add('text','SPACE',s,n,'-')
 for at in [0,1,3,8]:
  add('text','INSERT','z',s,at)
  for length in [0,1,3]:add('text','INSERT','z',s,at,length,'.')
 for at in [1,2,5]:
  add('text','OVERLAY','z',s,at)
  for length in [0,1,3]:add('text','OVERLAY','z',s,at,length,'.')
for name in ['COPIES']:
 for s in ['','a','abc']:
  for n in [0,1,2,9]:add('text',name,s,n)
with (D/'matrix.tsv').open('w') as f:
 for i,(block,name,args) in enumerate(cases):f.write('\t'.join([str(i),name,block]+[x.hex().upper() for x in args])+'\n')
with (D/'oracle.rex').open('w') as f:
 for i,(block,name,args) in enumerate(cases):
  cmd=','.join("x2c('"+x.hex().upper()+"')" for x in args)
  f.write(f"say '{i}:' || c2x({name}({cmd}))\n")
(D/'cases.tsv').write_text(''.join(f'{i}\t{b}\t{n}\t'+','.join(repr(a) for a in args)+'\n' for i,(b,n,args) in enumerate(cases)))
from collections import Counter
print(len(cases),Counter(x[0] for x in cases))
