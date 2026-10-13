/* Two compiled libraries in one process must not share runtime state (hooks, current context, SELF). */
::class TwoA public
::method make class
  return self~new('A')
::method init
  expose tag
  use arg tag
  self~mark
::method mark private
  expose tag
  tag = tag || '!'
::method tag
  expose tag
  return tag self~class~id
::method other
  use arg obj
  return obj~tag self~tag
