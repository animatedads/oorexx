.environment~checker = .Checker
signal on any name caught
.StemT~new~run
say "end"
exit
caught: say "caller caught" condition("C") condition("D")
::class Checker public
::method same class
  use arg a, b
  say "same" (a == b)
