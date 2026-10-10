a = .IndexedCell~new
b = .IndexedCell~new
say 'initial' a~index a~value
say 'get1' a[3]
a[7] = 12
say 'after' a~index a~value a[7] a~'[]'(9)
say 'second' b~index b~value
b[4] = 20
say 'different' b~index b~value b[4] a~value
say 'direct' a~'[]='(33, 5) a~index a[5]
say 'two' a~combine(8,9)
c = .IndexedChild~new
c[6] = 14
say 'child' c~index c~value c[6] c~identify
say 'isolated' a~value b~value
exit
::requires 'rx2cpp_objindex_setter' library
