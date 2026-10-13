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
  /* ::CLASS "MixedCase": the class id keeps that spelling; lookups (.MIXEDCASE) are case-insensitive. */
  if s~peek~kind == 'STRING' then do
    declared = s~next~text
    name = declared~upper
    /* Any string is a class id in ooRexx; C++ names are mangled (.RxQuote~identifier), the Rexx name is kept. */
    if name == '' then s~fail('empty quoted class name')
    /* Keep the quoted spelling when it differs from the upper-case name or is not a plain symbol ("A.B"). */
    if declared \== name | verify(name, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_!?') > 0 then ctx~setDeclaredName(declared)
  end
  else do
    if s~peek~kind \= 'IDENT' then s~fail('expected class identifier')
    name = s~next~text
  end
  publicSeen = .false
  privateSeen = .false
  parentSeen = .false
  inheritSeen = .false
  do while s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF'
    select
      when s~accept('PUBLIC') then do
        if publicSeen | privateSeen then s~fail('duplicate PUBLIC/PRIVATE option')
        publicSeen = .true
      end
      when s~accept('PRIVATE') then do
        if publicSeen | privateSeen then s~fail('duplicate PUBLIC/PRIVATE option')
        privateSeen = .true
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
  if ctx~hasMethod('SETPUBLIC') then ctx~setPublic(publicSeen)
  return name
