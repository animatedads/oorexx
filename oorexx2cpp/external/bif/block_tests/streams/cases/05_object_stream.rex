/* Interpreter .Stream object, distinct from stream BIF name and value. */
f='object_stream.dat'
s=.stream~new(f)
say 'object-class='s~class~id
say 'initial-state='s~state
say 'obj-open-write='s~open('WRITE REPLACE')
say 'obj-lineout1='s~lineout('ONE')
say 'obj-lineout2='s~lineout('TWO')
say 'obj-state='s~state
say 'obj-close-write='s~close
say 'obj-open-read='s~open('READ')
say 'obj-line1='s~linein
say 'obj-line2='s~linein
say 'obj-line3='c2x(s~linein)
say 'obj-state-eof='s~state
say 'obj-close-read='s~close
