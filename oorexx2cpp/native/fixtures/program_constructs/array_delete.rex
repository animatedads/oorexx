/* Array~delete natively: the item out, later items down one, the size one less */
a = .array~of('a', 'b', 'c')
say a~delete(2) a~items a~size a~makeString('L', ',')
say a~delete(5) a~items a~size
b = .array~new(5)
b[1] = 'x'; b[3] = 'y'
say b~delete(2) b~size b~items b[2] b~last
say b~delete(4) b~size b~items
say b~delete(2) b~size b~items b~last
n = .array~new
n~append('p'); n~append('q')
do while \n~isEmpty
  say n~delete(n~last) n~items
end
c = Array('one', 'two', 'three')
say c~delete(1) c[1] c~size
signal on syntax
a~delete(0)
syntax: say 'error' condition('o')~code
exit
::routine Array; return arg(1, 'A')
