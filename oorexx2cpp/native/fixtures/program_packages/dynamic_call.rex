say r('A')
say .c~new~m('B')
call ('lab.'||'X') 1
say result
say lowr()
exit
::routine r
  use arg k
  call ("OPT."k)
  return result
OPT.A:
  return 'internal A'
::class c
::method m
  use arg k
  call ("OPT."k) 7
  return result
OPT.B:
  return 'internal B' arg(1)
::routine 'LAB.X'
  return 'routine' arg(1)
::routine lowr
  signal on syntax
  call ('opt.a')
  return result
syntax:
  return 'lowr case:' condition('o')~code
OPT.A:
  return 'never'
