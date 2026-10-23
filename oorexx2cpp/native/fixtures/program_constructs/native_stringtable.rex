/* .StringTable native in compiled code: as the interpreter's, order included */
t = .StringTable~new
say t~isEmpty t~items t['A'] t~hasIndex('A')
t['A'] = 1; t~put(2, 'B'); t['zeta'] = 3; t['A'] = 'one'
say t['A'] t~at('B') t['zeta'] t['ZETA'] t~items t~hasIndex('B') t~hasIndex('C')
t~color = 'red'
say t~color t['COLOR'] t~shape
say t~allIndexes~makeString('L', ',') '|' t~allItems~makeString('L', ',')
say t~class~id t~isA(.StringTable) t~isA(.Directory) (t~class == .StringTable)
do i over t~makeArray; say 'item' i; end
say t~entry('color') t~hasEntry('COLOR')
u = .StringTable~new
u['k'] = 'v'
.local['MYTABLE'] = u
say .mytable['k']
u['k'] = 'w'
say .mytable['k'] u~items
s = .StringTable~new
do i = 1 to 40; s['key' || i] = i; end
say s~allIndexes~makeString('L', ' ')
/* MapCollection OF: pairs (index, item), PUT in argument order; anything else is the interpreter's */
o = .StringTable~of(('&', 'and'), ('=', 'eq'), ('&', 'again'), ('<', .nil))
say o~items o['&'] o['='] (o['<'] == .nil) o~class~id o~allIndexes~makeString('L', ',')
o['>'] = 'gt'
say o~items o['>']
e = .StringTable~of()
say e~items e~class~id
d = .Directory~of(('a', 1), ('b', 2))
say d~a d['b'] d~items d~class~id
signal on syntax name ofError1
x = .StringTable~of(('a', 1, 3))
ofError1: say 'error' condition('o')~code
signal on syntax name ofError2
x = .StringTable~of(('a', 1), 'notanarray')
ofError2: say 'error' condition('o')~code
signal on syntax name ofError3
x = .StringTable~of(('a', 1), , ('b', 2))
ofError3: say 'error' condition('o')~code
