/* One ::METHOD selector directive; method bodies use separately loaded
   statement-rule classes and an independent expression precedence pipeline. */
::class RxOperatorSelectors public
/* ooRexx operator method names -> identifier-safe symbol part ('' when not an operator). */
::method symbol class
  use arg name
  names = .directory~new
  names['+'] = 'plus'
  names['-'] = 'minus'
  names['*'] = 'times'
  names['/'] = 'divide'
  names['%'] = 'intdiv'
  names['//'] = 'remainder'
  names['**'] = 'power'
  names['||'] = 'concat'
  names['|'] = 'or'
  names['&'] = 'and'
  names['&&'] = 'xor'
  names['='] = 'eq'
  names['=='] = 'seq'
  names['\='] = 'ne'
  names['\=='] = 'sne'
  names['<>'] = 'ltgt'
  names['><'] = 'gtlt'
  names['<'] = 'lt'
  names['>'] = 'gt'
  names['<='] = 'le'
  names['>='] = 'ge'
  names['<<'] = 'slt'
  names['>>'] = 'sgt'
  names['<<='] = 'sle'
  names['>>='] = 'sge'
  names['\<'] = 'nlt'
  names['\>'] = 'ngt'
  names['\<<'] = 'nslt'
  names['\>>'] = 'nsgt'
  names['\'] = 'not'
  if names~hasIndex(name) then return names[name]
  return ''
::class RxHybridMethodDirective public
::method parse
  use arg ctx
  s = ctx~stream
  s~expect('::'); s~expect('METHOD')
  if s~peek~kind \= 'IDENT' & s~peek~kind \= 'STRING' then s~fail('expected method selector')
  name = s~next~text
  if name == '[]' | name == '[]=' | .RxOperatorSelectors~symbol(name) \== '' then nop
  else if verify(name, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_') > 0 then
    s~fail('unsupported native method selector')
  /* UNKNOWN is an ordinary method to compile: the interpreter invokes it for messages no method answers. */
  /* A user UNINIT is compiled under its own name; the generated UNINIT runs it, then releases the native state. */
  if name == 'UNINIT' then name = 'RX2CPP_USER_UNINIT'
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
