say '['.mt~new(.nil, 'x')~end']'
say '['.mt~new('y', .nil)~end']'
say '['.mt~new(.nil, .nil, 'z')~end']'
::class mt public
::attribute end
::method init
  expose a b c end
  use strict arg a, b, c = .nil
  end = FindEnd()
  return
FindEnd:
  if a \== .nil then return 'A' a
  if c \== .nil then do
    r = c
    return TheAfter( r )
  end
  if b \== .nil then return TheAfter( b )
::routine TheAfter
  return 'after' arg(1)
