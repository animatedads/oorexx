/* SELF~selector(...) inside compiled methods (threading v0.2).
   Arithmetic only: the compiler has no concatenation operator yet. */
::class Re public
::method init
  expose tag n
  use arg start
  tag = start
  n = 0
::method a
  expose tag
  tag = 1
  return self~b(10) * 100 + tag
::method b
  expose tag
  use arg s
  tag = tag + 1
  return s + tag
::method bump
  expose n
  n = n + 1
  return self~count()
::method count
  expose n
  return n
::method tag
  expose tag
  return tag
::method bad
  return self~nosuchmethod()
