/* ::CONSTANT sent by compiled code: the interpreter's value, inheritance and hiding as interpreted */
n = 0
do i = 1 to 3000
  t = .Term~new
  if \t~isEmpty then n += 1
end
say n t~isEmpty t~kind t~self.isEmpty
l = .ListTerm~new
say l~isEmpty l~kind l~self.isEmpty l~describe
h = .Hider~new
say h~describe h~self.describe h~isEmpty
say .Term~kind (.Term~table == .Term~new~table) (t~table == l~table) t~table~class~id
say t~sum t~text t~"quoted name" t~"Quoted Name"
signal on syntax
say t~kind('extra')
exit
syntax: say 'error' condition('o')~code condition('o')~message
exit
::class Term
::constant isEmpty 0
::constant kind "term"
::constant table (.array~of(1, 2))
::constant sum (3 + 4)
::constant text
::constant "quoted name" 'q'
::method self.isEmpty
  return self~isEmpty
::class ListTerm subclass Term
::constant isEmpty 1
::method describe
  return 'list' self~kind
::class Base
::method describe
  return 'base'
::method isEmpty
  return 'method'
::class Hider subclass Base
::constant describe 'hidden'
::method self.describe
  return self~describe
