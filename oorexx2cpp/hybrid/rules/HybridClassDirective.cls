/* Parse native class headers without baking class-graph rules into lexer.
   ooRexx accepts PUBLIC, SUBCLASS and MIXINCLASS in differing positions;
   INHERIT must be the last option. Graph legality is checked separately.
   The standalone hybrid compiler still rejects inheritance via context.
*/
::class RxHybridClassDirective public
::method parse
  use arg ctx
  s = ctx~stream
  s~expect('::'); s~expect('CLASS')
  if s~peek~kind \= 'IDENT' then s~fail('expected class identifier')
  name = s~next~text
  publicSeen = .false
  parentSeen = .false
  inheritSeen = .false
  do while s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF'
    select
      when s~accept('PUBLIC') then do
        if publicSeen then s~fail('duplicate PUBLIC option')
        publicSeen = .true
      end
      when s~accept('SUBCLASS') then do
        if parentSeen then s~fail('duplicate parent option')
        if s~peek~kind \= 'IDENT' then s~fail('SUBCLASS needs a parent identifier')
        ctx~setParentName(s~next~text)
        parentSeen = .true
      end
      when s~accept('MIXINCLASS') then do
        if parentSeen then s~fail('duplicate parent option')
        if s~peek~kind \= 'IDENT' then s~fail('MIXINCLASS needs a parent identifier')
        ctx~setMixinParentName(s~next~text)
        parentSeen = .true
      end
      when s~accept('INHERIT') then do
        if inheritSeen then s~fail('duplicate INHERIT option')
        if s~peek~kind \= 'IDENT' then s~fail('INHERIT needs at least one mixin')
        do while s~peek~kind == 'IDENT'
          ctx~addMixin(s~next~text)
        end
        inheritSeen = .true
        /* INHERIT is always the final option, including PUBLIC. */
        if s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF' then
          s~fail('INHERIT must be final option')
      end
      otherwise s~fail('unsupported CLASS option')
    end
    if inheritSeen then leave
  end
  s~separator
  return name
