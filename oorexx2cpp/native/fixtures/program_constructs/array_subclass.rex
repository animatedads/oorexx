/* Subclasses of .Array made by compiled code: the array part native until the instance crosses to the interpreter */
s = .Stack~new
say s~isEmpty s~items s~size
s~push('a'); s~push('b'); s~push('c')
say s~top s~items s~size s~last s~first s~firstItem
say s~pop s~pop s~items s~isEmpty
say s[1] s~at(1) s~hasIndex(1) s~hasIndex(2) (s[2] == .nil)
s[4] = 'd'
say s~items s~size s~last s~lastItem s~remove(4) s~size s~items
do x over s; say 'over' x; end
say s~allItems~items s~allIndexes~makeString('L', ',') s~makeArray~items
s~append('e')
say s~lastItem s~last
/* messages the class and the array do not answer natively: the interpreter's object, items and size as they were */
say s~class~id s~isA(.Array) s~isA(.Stack) s~isA(.String)
say s~makeString('L', ',') s~size s~items
s~push('f')
say s~pop s~top s~items
/* attributes with the array part */
t = .Template.List~new
t~begin = 'b1'; t~end = 'e1'
t~append('x'); t~append('y')
say t~begin t~end t~items t[2]
say t~string t~items t~begin
/* SELF[] and SELF~lastItem in compiled methods */
l = .Instruction.List~new
l~append(.Item~new(1, 2)); l~append(.Item~new(3, 4))
say l~begin l~end l~items
/* a trailing empty slot keeps the size when it crosses */
u = .Stack~new
u[3] = 'z'; u~remove(3)
say u~size u~items
say Show(u) u~size u~items
/* a subclass of a subclass; NEW with a size goes to the interpreter */
d = .Deep~new
d~push(1); d~push(2)
say d~depth d~pop d~class~id
e = .Stack~new(5)
say e~size e~items e~class~id
/* an Array subclass with its own INIT: the interpreter's */
o = .Own~new
say o~items o[1] o~tag
/* instances held by other instances (cycles), many of them */
do i = 1 to 3000
  a = .Stack~new; b = .Stack~new
  a~push(b); b~push(a)
end
say 'cycles done' (a~top~top == a)
/* an interpreter object put into the array and taken back */
q = .Stack~new
q~push(.directory~new)
q~top['k'] = 'v'
say q~top['k'] q~pop~items
exit
::routine Show
  use arg x
  return x~class~id x~items x~size
::class Stack subclass Array public
::method top
  return self~lastItem
::method pop
  temp = self~top
  self~delete(self~last)
  return temp
::method push
  self~append(arg(1))
::class Deep subclass Stack
::method depth
  return self~items
::class Template.List subclass Array
::attribute begin
::attribute end
::class Instruction.List subclass Array
::method begin
  return self[1]~begin
::method end
  return self~lastItem~end
::class Item
::attribute begin
::attribute end
::method init
  expose begin end
  use arg begin, end
::class Own subclass Array
::attribute tag
::method init
  expose tag
  tag = 'own'
  self~init:super
  self[1] = 'first'
