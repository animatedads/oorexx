/* Native String methods on plain strings in a compiled library (no interpreter String round trip). */
::class SMTest public
::method run
  s = 'hello world'
  r = s~string s~makestring s~request('string') s~request('STRING')
  r = r '|' s~pos('o') s~pos('o', 6) s~pos('') s~pos('z') s~pos('o', 99) s~lastpos('o') s~lastpos('o', 6) s~lastpos('')
  r = r '|' 'abc'~changestr('', 'x') 'abcabc'~changestr('bc', 'X', 1) 'aaaa'~changestr('aa', 'b') 'abcabc'~changestr('b', '', 0)
  r = r '|' 'abc'~countstr('') 'aaaa'~countstr('aa') 'a.b.c'~countstr('.') 'x'~changestr('x', 'yy')
  r = r '|' s~isA(.string) s~isA(.object) s~isA(.array) s~isA(.SMTest) s~isA(.mutablebuffer) s~isA(.String)
  r = r '|' s~pos('o', ' 6 ') 5~pos(5) 'x'~request('array')~class~id
  return r
