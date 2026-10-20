s = .mystr~new('1')
if s then say 'string subclass 1: yes'
z = .mystr~new('0')
if \z then say 'string subclass 0: no'
do while z; leave; end
say 'while ok'
signal on syntax
if .object~new then say 'object: yes'
exit
syntax:
  c = condition('o')
  say c~code c~message
::class mystr subclass string
