a = .Counter~new(0)
b = .Multiplier~new(1000)
do i = 1 to 2000
  v = a~add(1)
  if v \== i then exit 9
end
say a~current
say b~current
::requires 'two_classes.cls'
