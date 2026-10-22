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
