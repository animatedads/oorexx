/* ::REQUIRES "name" LIBRARY directives (external ooRexx API libraries such as rxsock or rxmath).
   Only this one directive form is accepted; every other :: directive fails closed. The library names
   are discovered from tokens before parsing so calls earlier in the file can resolve to external
   routines (ooRexx resolves calls at run time: internal label, then built-in, then external). */
::class RxLibraryRules public
::method discover class
  use arg stream
  tokens = stream~tokens
  libs = .array~new
  i = 1
  do while i <= tokens~items
    if tokens[i]~text \= '::' | tokens[i]~kind \= 'OP' then do
      i = i + 1
      iterate
    end
    if i + 3 > tokens~items then stream~fail('incomplete directive')
    if tokens[i + 1]~text \= 'REQUIRES' then do
      stream~position(i + 1)
      stream~fail('unsupported directive (only ::REQUIRES "name" LIBRARY is implemented)')
    end
    kind = tokens[i + 2]~kind
    if kind \= 'STRING' & kind \= 'IDENT' then do
      stream~position(i + 2)
      stream~fail('::REQUIRES needs a library name')
    end
    if tokens[i + 3]~text \= 'LIBRARY' | tokens[i + 3]~kind \= 'IDENT' then do
      stream~position(i + 3)
      stream~fail('only ::REQUIRES ... LIBRARY is implemented (no Rexx program requires, no options)')
    end
    name = tokens[i + 2]~text
    if kind == 'IDENT' then name = name~lower
    if name == '' | verify(name, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.') \= 0 then do
      stream~position(i + 2)
      stream~fail('library name must be a plain file stem')
    end
    if i + 4 <= tokens~items & tokens[i + 4]~kind \= 'SEP' & tokens[i + 4]~kind \= 'EOF' then do
      stream~position(i + 4)
      stream~fail('unexpected tokens after ::REQUIRES ... LIBRARY')
    end
    libs~append(name)
    i = i + 4
  end
  return libs
/* The directive tokens are consumed after the program body and any routines. */
::method consume class
  use arg stream
  do while stream~is('::')
    stream~next; stream~next; stream~next; stream~next
    stream~skipSeparators
  end
