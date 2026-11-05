/* x~CONTAINS and x~ISA as rx::sendContains / rx::sendIsA (ExprMessage), and string[i] (rx::indexValue): string
   receivers answered in place, the first ISA of a class asked of the interpreter, receivers that are objects (a String
   subclass, an Array, a MutableBuffer), quoted selectors, numbers as receivers and positions, a message instruction.
   Output identical to the interpreter. Claude (Opus 5.5), 2026-11-05. */
s = 'abcdefgh'
say s~contains('cd') s~contains('x') s~contains('') ''~contains('a') s~contains(s) s~contains(s || 'z') s~contains('h')
n = 'de'; say s~contains(n) s~contains(n || 'f') 'aXa'~contains('x') '123'~contains(2) (12 * 3)~contains(6)
say s~isA(.String) s~isA(.Object) s~isA(.Array) s~isA(.String) (1 + 1)~isA(.String) ''~isA(.String)
a = .array~of(1, 2); say a~isA(.Array) a~isA(.String) a~isA(.Collection)
u = .ustr~new('hello'); say u~contains('ell') u~isA(.String) u[2]
say s[1] s[8] '[' || s[9] || ']' s[2 + 1] s['3'] s[1]~length
i = 4; say s[i] s[i * 2] s~'CONTAINS'('ab') s~'ISA'(.String) (12 * 3)[2]
say s~contains('bc')~length s[1]~contains('a') s~isA(.String)~contains(1)
s~contains('a')
say result
s~isA(.Array)
say result
c = .String; say s~isA(c) s~isA(.ustr) u~isA(.ustr)
m = .mutablebuffer~new('xyz'); say m~isA(.MutableBuffer) m~isA(.String)
exit
::class ustr subclass string
::method contains
  return 'con(' || arg(1) || ')'
::method isA
  return 'isa'
::method '[]'
  return 'ix(' || arg(1) || ')'
