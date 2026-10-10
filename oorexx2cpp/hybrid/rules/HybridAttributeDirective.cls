/* A native class attribute is compiled into a getter and a setter bound to
   one class-owned field. This first slice accepts a simple scalar attribute
   declaration; typed, abstract, class, and delegated forms fail closed. */
::class RxHybridAttributeDirective public
::method parse
  use arg ctx
  s = ctx~stream
  s~expect('::'); s~expect('ATTRIBUTE')
  if s~peek~kind \= 'IDENT' then s~fail('ATTRIBUTE requires a simple name')
  name = s~next~text
  if pos('.', name) > 0 then s~fail('compound ATTRIBUTE names are unsupported')
  mode = 'BOTH'
  if s~accept('GET') then mode = 'GET'
  else if s~accept('SET') then mode = 'SET'
  s~separator
  ctx~addAttribute(name, mode)
