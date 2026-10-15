/* .CONTEXT in compiled code (RexxContext): NUMERIC, VARIABLES (SELF, SUPER, stems), EXECUTABLE, NAME, LINE, RS, ARGS, CONDITION; .RS. */
::class CtxT public
::method run
  numeric digits 12
  say .context~digits .context~fuzz .context~form
  a = 'Fred'; b.1 = 'Foo'
  d = .context~variables
  say d~items d['A'] d['B.'][1] (d['SELF'] == self) (d['SUPER'] == self~class~superclass)
  say (.context~executable == self~class~method('RUN')) .context~name .context~line
  say .context~rs .rs
  'true'
  say .context~rs .rs
  'false'
  say .context~rs .rs
  say self~meth(1, , 3)
  say inner() rtn()
  signal on syntax
  x = 1/0
  return
syntax:
  say (condition('o') == .context~condition) (condition('o')~code == .context~condition~code)
  return
inner: return .context~name
::method meth
  a = .context~args
  return a~size a~items a[1] a[3] (a[2] == .nil)
::routine rtn
  return .context~name (.context~executable == .context~package~findRoutine('RTN'))
