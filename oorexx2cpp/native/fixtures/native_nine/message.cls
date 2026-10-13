::class NativeNineProbe public
::method run
  r = .array~of('one','two')
  m = .message~new(r, 'ITEMS')
  a = m~messageName m~target~class~id m~completed
  m~send
  return a '|' m~completed m~hasResult m~result
