/* One ::METHOD selector directive; method bodies use separately loaded
   statement-rule classes and an independent expression precedence pipeline. */
::class RxHybridMethodDirective public
::method parse
  use arg ctx
  s = ctx~stream
  s~expect('::'); s~expect('METHOD')
  if s~peek~kind \= 'IDENT' & s~peek~kind \= 'STRING' then s~fail('expected method selector')
  name = s~next~text
  if name == '[]' | name == '[]=' then nop
  else if verify(name, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_') > 0 then
    s~fail('unsupported native method selector')
  if wordpos(name, 'UNKNOWN UNINIT') > 0 then s~fail('reserved lifecycle method')
  /* Threading v0.1: the only method option accepted is GUARDED or UNGUARDED.
     It is carried to the ooRexx method declaration; anything else is rejected. */
  guard = ''
  if s~peek~kind == 'IDENT' & wordpos(s~peek~text, 'GUARDED UNGUARDED') > 0 then guard = s~next~text
  s~separator
  return .array~of(name, guard)
