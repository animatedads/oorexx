/* Floating methods (.METHODS), classes changed at run time (DEFINE), metaclasses (kept interpreted), as interpreted. */
::method floatA
  return 'floating A'
::class MetaT public
::method run
  o = .Plain~enhanced(.methods)
  say o~floatA
  .Sub~define('M', "return self~m:super 'x'")
  a = .Sub~new
  say a~m
  .Sub~define('M')
  say a~m (.Sub~new~hasMethod('M'))
  cl = .object~mixinclass('Cm', .Counter)
  x = cl~new; y = cl~new
  say cl~made cl~metaclass~id
::class Plain
::class Base
::method m
  return 'base'
::class Sub subclass Base
::class Counter mixinclass class
::attribute made get
::method new
  expose made
  if \var('MADE') then made = 0
  made += 1
  forward class (super)
