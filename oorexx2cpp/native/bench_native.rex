n = .Accumulator~new(0)
do i = 1 to 25000
  n~increment(1)
end
say n~current
::requires 'rx2cpp_accumulator' LIBRARY
