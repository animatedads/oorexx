t = .SigTest~new
say t~divide(6, 3)
say t~divide(6, 0)
say t~nomethod
say t~raised
say t~nested
say t~jump
say t~outer
say t~none
say t~any
say t~rearm
nop
nop
nop
nop
say t~arith(1)
say t~arith(2)
say t~arith(3)
say t~arith(4)
say t~arith(5)
say t~arith(6)
say t~arith(7)
signal on syntax name top
x = t~propagate
say 'not here'
top: say 'caller trapped' rc condition('O')['MESSAGE']
say t~counter
