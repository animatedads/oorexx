/* .Set~of / .Bag~of native; SEND / SENDWITH to native classes */
s = .Set~of('a', 'b', 'a')
say s~items s~hasItem('a') s~hasItem('c') s~isEmpty
b = .Bag~of('a', 'b', 'a')
say b~items b~hasItem('a')
t = .Set~sendWith('of', .array~of('x', 'y'))
say t~items t~hasItem('y') t~class~id
u = .Set~send('of', 'p')
say u~items u~hasItem('p')
a = .Array~sendWith('of', .array~of(1, , 3))
say a~items a~size a[3]
e = .Set~sendWith('new', .array~new)
say e~isEmpty
say Set2('m', 'n')~items
s~put('z')
say s~items s~allItems~sort~makeString('L', ',')
say .Stem~send('new', 'Q.')['1']
d = .Directory~sendWith('NEW', .array~new)
d['K'] = 1
say d~items
signal on syntax
x = .Set~of('a', , 'b')
say 'not reached'
syntax:
say 'error' condition('o')~code
exit
::routine Set2; return .Set~sendWith("of", Arg(1, "A"))
