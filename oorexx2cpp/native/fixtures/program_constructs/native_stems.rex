/* .Stem~new in compiled code: a native stem until it crosses or meets a message it does not answer */
s = .stem~new
say s['A'] s~hasIndex('A') s~hasIndex
s[] = 'dflt'
say s['A'] s~hasIndex('A')
s['A'] = 1; s[3] = 'three'
say s['A'] s[3] s~hasIndex('A') s~hasIndex(3) s~hasIndex(4) s~hasIndex('A', 'B')
s['A', 'B'] = 'ab'
say s['A.B'] s~hasIndex('A', 'B')
t = .stem~new('T.')
say t[1] t~hasIndex(1)
say s~isA(.stem) (s~class == .stem) .stem~id
say s~items
u = .stem~new
u['K'] = 'v'
.local['MYSTEM'] = u
say .mystem['K'] u['K']
u['K'] = 'w'
say .mystem['K'] u~hasIndex('K') u~hasIndex('Z')
call show u
say u['NEW']
exit
show: procedure
  use arg st
  st['NEW'] = 'from routine'
  say st['K']
  return
