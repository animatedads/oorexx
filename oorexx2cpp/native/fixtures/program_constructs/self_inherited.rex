/* SELF~isA / SELF~class / SELF~isNil in compiled methods of a class that defines none of them (as Rexx.Clause~init) */
n = 0
do i = 1 to 2000
  c = .Null.Clause~new(i)
  if c~block then n += 1
end
say n c~kind c~nilness c~begin
b = .Block.Clause~new(7)
say b~block b~kind b~nilness b~begin b~isA(.Rexx.Clause) b~isA(.Null.Clause)
o = .Odd~new
say o~isA(.Block.Clause) o~probe
exit
::class Rexx.Clause
::attribute begin
::attribute block
::method init
  expose begin block
  use arg begin
  block = self~isA(.Block.Clause)
::method kind
  return self~class~id
::method nilness
  return self~isNil
::class Null.Clause subclass Rexx.Clause
::class Block.Clause subclass Rexx.Clause
::class Odd
::method isA
  return 'mine'
::method probe
  return self~isA(.Rexx.Clause)
