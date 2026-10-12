/* Interpreted-table fixture: compiled class with interpreted methods, an interpreted class and its subclass. */
::class Counter public
::method init
  expose n
  use arg n = 0
::method bump
  expose n
  n = n + 1
  return n
::method describe            -- moved to the interpreter (no EXPOSE)
  return 'Counter at' self~bump 'via' self~where
::method where private       -- moved; called from interpreted and compiled code
  return .context~executable~class~id
::method total                -- compiled; calls an interpreted method of its own class
  return self~describe '/' self~where
::method peek                 -- EXPOSE: cannot move (prefer -> warning, stays compiled)
  expose n
  return n
::method make class           -- class method moved
  use arg start
  return self~new(start)
::class Shape public
::method init
  expose sides
  use arg sides
::method sides
  expose sides
  return sides
::method name
  return 'shape with' self~sides 'sides'
::class Square subclass Shape public
::method init
  self~init:super(4)
::method name
  return 'square:' self~name:super
