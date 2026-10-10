say .MultiArgumentHost~new~status
say rx3(2,3,4)
say rx4('red','green','blue','gold')
say rx6(1,2,3,4,5,6)
say rx16(1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1)
say rx_pow3(7,5,13)
say rx_pow3(3,17,19)
say rx_bind('one', 'two', 'three')
say rx_bind('one')
say rx_bind('one',, 'three')
say rx_bind('one', 'two', 'three', 'extra')
say rx_bind()
say rx17(1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1)
say rx_zero('extra')
signal on syntax name blocked
say rx_secret4(1,2,3,4)
say 'ERROR: private escaped'
exit 5
blocked:
  say 'private inaccessible'
::requires 'routine_many.cls'
