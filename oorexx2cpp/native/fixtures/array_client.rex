t = .ATest~new
say t~basics
say t~sparse
say t~types
say t~loop
a = t~leave
say a~items a~size a[3]~class~id a[3]~items
a[3]~append('in')
say a[3]~items
say t~later(a)
say t~keep(.array~new)
say t~sorted
do i over .array~of(0, 'x', 1.5, '1.0', 1)
  say 'index' i '->' tryIndex(t, i)
end
exit
tryIndex: procedure
  use arg t, i
  signal on syntax name bad
  return t~index(i)~string
bad:
  return 'error' condition('O')~code
