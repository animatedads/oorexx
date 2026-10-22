/* == and \== of interpreter objects: identity where the object runs Object's own, its method otherwise */
r = .context~package~findRoutine('ident')
say (r == .nil) (r \== .nil) (r == r) (r \== r) (r == 'x') (r \== 'x')
p = .context~package
say (p == .context~package) (p \== .nil)
q = .queue~new
say (q == q) (q == .queue~new) (q \== .nil)
m = .mutablebuffer~new('abc')
say (m == 'abc') (m \== 'abc')
c = .object~subclass('INTERPRETED')
c~define('==', 'return arg(1) == ''yes''')
c~define('\==', 'return \(arg(1) == ''yes'')')
w = c~new
say (w == .nil) (w == 'yes') (w \== 'yes')
s = .stream~new('nosuchfile')
say (s == s) (s == .nil)
exit
::routine ident; return arg(1)
