/* Super calls through three levels in one compiled library: FORWARD CLASS (SUPER) CONTINUE in INIT and ~m:super, on
   instances of the subclasses (each class must reach its own parent, not its subclass's). */
::class Base public
::method init
  expose trail
  use arg tag = 'none'
  trail = 'base(' || tag || ')'
::method add
  expose trail
  use arg x
  trail = trail '+' x
::method trail
  expose trail
  return trail
::method describe
  return 'base'
::method kind class
  return 'Base-kind'
::class Mid public subclass Base
::method init
  use arg tag = 'mid-default'
  forward class (super) array (tag) continue
  self~add('mid')
::method describe
  return 'mid>' || self~describe:super
::method kind class
  return 'Mid>' || self~kind:super
::class Leaf public subclass Mid
::method init
  forward class (super) array ('leaf-tag') continue
  self~add('leaf')
::method describe
  return 'leaf>' || self~describe:super
::method kind class
  return 'Leaf>' || self~kind:super
