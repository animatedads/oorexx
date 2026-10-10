/* Interpreter oracle for inherited .Object comparator messages. */
a = .Bare~new
b = .Bare~new
alias = a
say 'bare a = a:' (a = a)
say 'bare a = b:' (a = b)
say 'bare a == a:' (a == a)
say 'bare a == b:' (a == b)
say 'bare a \= a:' (a \= a)
say 'bare a \= b:' (a \= b)
say 'bare a \== b:' (a \== b)
say 'bare a <> b:' (a <> b)
say 'bare a >< b:' (a >< b)
say 'bare alias == a:' (alias == a)
custom = .OnlyEquals~new
say 'custom = b:' (custom = b)
say 'custom \= b:' (custom \= b)
say 'custom == b:' (custom == b)
say 'custom \== b:' (custom \== b)
say 'custom <> b:' (custom <> b)
::class Bare
::class OnlyEquals
::method '='
  use arg ignored
  return 1
