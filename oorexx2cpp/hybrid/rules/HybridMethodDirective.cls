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
  /* Options as the interpreter's directive parser defines them (any order, no duplicates):
     PUBLIC | PRIVATE, PROTECTED, GUARDED | UNGUARDED, CLASS, ABSTRACT. They are carried verbatim to the
     generated class declaration, where the interpreter itself applies them. ATTRIBUTE, EXTERNAL and
     DELEGATE are different method kinds and fail closed. */
  opts = .RxHybridMethodOptions~new
  do while s~peek~kind == 'IDENT' & wordpos(s~peek~text, 'PUBLIC PRIVATE PROTECTED GUARDED UNGUARDED CLASS ABSTRACT') > 0
    opts~add(s, s~next~text)
  end
  if s~peek~kind == 'IDENT' & wordpos(s~peek~text, 'ATTRIBUTE EXTERNAL DELEGATE') > 0 then
    s~fail('native method option ' || s~peek~text || ' is not supported')
  guard = opts~guard
  s~separator
  return .array~of(name, guard, opts)
/* The option set of one ::METHOD / ::ATTRIBUTE directive. */
::class RxHybridMethodOptions public
::attribute guard get
::attribute isClass get
::attribute isAbstract get
::method init
  expose access protect guard isClass isAbstract
  access = ''; protect = ''; guard = ''; isClass = .false; isAbstract = .false
::method add
  expose access protect guard isClass isAbstract
  use arg s, word
  word = word~upper
  select
    when word == 'PUBLIC' | word == 'PRIVATE' then do
      if access \== '' then s~fail('duplicate or conflicting access option ' || word)
      access = word
    end
    when word == 'PROTECTED' then do
      if protect \== '' then s~fail('duplicate PROTECTED')
      protect = word
    end
    when word == 'GUARDED' | word == 'UNGUARDED' then do
      if guard \== '' then s~fail('duplicate or conflicting guard option ' || word)
      guard = word
    end
    when word == 'CLASS' then do
      if isClass then s~fail('duplicate CLASS')
      isClass = .true
    end
    when word == 'ABSTRACT' then do
      if isAbstract then s~fail('duplicate ABSTRACT')
      isAbstract = .true
    end
  end
/* The text placed after the selector in the generated ooRexx class declaration (CLASS and the native binding are added by the emitter). */
::method declaration
  expose access protect guard isAbstract
  return (access protect guard)~space
