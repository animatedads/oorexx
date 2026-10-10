n = .Accumulator~new(10)
other = .Accumulator~new(2)
say n~increment(7)
say n~current
say other~increment(5)
say n~increment(-3)
say other~current
say n~current
say n~echo('41'x || '00'x || '42'x)~length
::requires 'hybrid/accumulator.cls'
