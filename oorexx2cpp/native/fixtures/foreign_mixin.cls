/* A mixin of an interpreter class (MIXINCLASS Object): classes of other native roots, and interpreted classes, inherit
   it; its methods and its EXPOSEd variables (its own scope) work on each object, as interpreted. */
::class Counter mixinclass Object public
::constant kind 'counter'
::method bump
  expose count
  if \var('COUNT') then count = 0
  count += 1
  return count
::method count
  expose count
  if var('COUNT') then return count
  return 'none'
::class A public inherit Counter
::method init
  expose name count
  use arg name
  count = 'A-scope'
::method name
  expose name count
  return name count
::class B public inherit Counter
::class C public subclass A
::method init
  forward class (super)
::class D public subclass Counter
::method init
  expose count
  count = 100
