a = .Counter~new(10)
b = .Multiplier~new(100)
say a~add(2)
say b~add(3)
say a~current
say b~current
say (a = b)
say (a == a)
say a~literal
::requires 'rx2cpp_dual' library
