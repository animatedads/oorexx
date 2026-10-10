/* Run one source as interpreted or native by selecting the requires clause.
   Source executable was extracted unchanged from the oracle other than require. */
n = .Accumulator~new(10)
other = .Accumulator~new(2)
say n~increment(7)
say n~current
say other~increment(5)
say n~increment(-3)
say other~current
say n~current
say n~echo('41'x || '00'x || '42'x)~length
say n == n
say n == other
say n = other
say n \= other
say n~class~id
say n~echo('line' || '00'x || 'end')~c2x
::requires 'rx2cpp_accumulator' library
