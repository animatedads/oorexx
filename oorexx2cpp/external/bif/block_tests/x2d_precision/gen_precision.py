import random,itertools,sys
R=random.Random(71951)
a=set()
base=['','0','F','A','FF','FFF','F F','F FF','F FFFF','FF FF','FF  FF','ff','AB CD','1 0',' 1','1 ','  ','1 1','F\tFF','F\t\tFF','FF\tFF','F'*100,'0'*100,'F'*8000, '1'*8193,'F'*8194]
widths=['-','0','1','2','3','4','7','8','9','16','24','36','50','100','-0','-0.0','-0.1','-1','+1','+0','1.0','1E0',' 2 ','3.0','100000000000000000000000000000', '0.0001','2.000000','-0.0001','1.5','xyz']
for b,w in itertools.product(base,widths):a.add((b,w))
chars='0123456789ABCDEFabcdef \t\x00\xffGg'
for n in [0,1,2,3,4,5,6,7,8,9,10,15,16,30,50,99,200]:
 for _ in range(500):
  b=''.join(R.choices(chars,k=n));w=R.choice(widths);a.add((b,w))
for n in [20,64,128,256,512,1024]:
 for _ in range(60):
  b=''.join(R.choices('0123456789ABCDEF',k=n));w=R.choice(widths);a.add((b,w))
with open(sys.argv[1],'w') as f:
 for b,w in sorted(a):f.write(b.encode('latin1').hex().upper()+'|'+('-' if w=='-' else w.encode('latin1').hex().upper())+'\n')
print(len(a))
