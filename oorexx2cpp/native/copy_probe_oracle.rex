a = .Accumulator~new(5)
b = a~copy
say a~current b~current
say b~increment(3)
say a~current b~current
say a = b
::requires 'hybrid/accumulator.cls'
