from pathlib import Path
D=Path(__file__).parent;cases=[]
for name in ['POS','LASTPOS']:
 for hay in ['','ababa','abcabc','abcbcbc','a','aaaaa',' abc def ']:
  for needle in ['','a','ab','bc','cbc','x']:
   for start in [1,2,3,4,6,8,10]:
    for span in [0,1,2,3,4,6,12]:
     cases.append((name,[needle,hay,str(start),str(span)]))
with (D/'range.tsv').open('w') as f, (D/'range.rex').open('w') as rx:
 for i,(name,ar) in enumerate(cases):
  f.write('\t'.join([str(i),name,'range']+[x.encode().hex().upper() for x in ar])+'\n')
  rx.write('say "'+str(i)+':" || c2x('+name+'('+','.join("x2c('"+x.encode().hex().upper()+"')" for x in ar)+'))\n')
print(len(cases))
