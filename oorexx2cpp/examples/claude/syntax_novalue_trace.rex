signal on novalue name gone
say 'trace' trace() 'address' address()
trace off
say 'trace' trace()
trace value 'N'
address value 'FOO'
say 'address' address()
if 1 then nop
else say 'never'
x = 'set'
say x
say undefinedvar
say 'not reached'
exit
gone:
  say 'NOVALUE trapped'
