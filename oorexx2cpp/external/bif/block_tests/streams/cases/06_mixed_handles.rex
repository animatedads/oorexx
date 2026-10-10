/* Mixed names and live .Stream handle: do state and cursors stay coherent? */
f='mixed_handles.dat'
say 'write-open='stream(f,'C','OPEN WRITE REPLACE')
say 'write-bif='lineout(f,'ONE')
say 'close-bif='stream(f,'C','CLOSE')
s=.stream~new(f)
say 'object-open='s~open('READ')
say 'obj-line1='s~linein
say 'obj-close='s~close
say 'bif-line-after='linein(f)
say 'bif-close='stream(f,'C','CLOSE')
say 'object-reopen='s~open('READ')
say 'obj-line-reopen='s~linein
say 'object-lastclose='s~close
