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
  opts = .RxHybridMethodOptions~new
  do while s~peek~kind == 'IDENT' & wordpos(s~peek~text, 'GET SET PUBLIC PRIVATE PROTECTED GUARDED UNGUARDED CLASS') > 0
    word = s~next~text~upper
    if word == 'GET' | word == 'SET' then do
      if mode \== 'BOTH' then s~fail('duplicate or conflicting GET/SET')
      mode = word
    end
    else opts~add(s, word)
  end
  s~separator
  ctx~addAttribute(name, mode, opts)
::requires 'hybrid/rules/HybridMethodDirective.cls'
