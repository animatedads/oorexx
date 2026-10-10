a = .Accumulator~new(10)
b = .Accumulator~new(3)
say a~increment(7)
say a~current
say b~increment(4)
say a~echo('ab00cd'x)~c2x
say b~current
say a = a
say a == b
::requires 'hybrid/accumulator.cls'
