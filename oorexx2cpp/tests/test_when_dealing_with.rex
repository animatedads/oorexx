/* Scope recognition and activation semantics: direct ooRexx unit tests. */
checks = 0
engine = .RxWhenDealingWith~new
call eq engine~depth, 1
call eq engine~identify('/* ::class fake */ ' || "'::method fake'"), 'LOGIC'
call eq engine~identify(' -- comment' || '0a'x || '::class Genuine public'), 'CLASS'
call eq engine~identify('::method act'), 'METHOD'
call eq engine~identify('::routine worker'), 'ROUTINE'
call eq engine~identify('procedure expose a'), 'PROCEDURE'
call eq engine~identify('signal on syntax name handle'), 'SIGNAL'
call eq engine~identify('::options noprolog'), 'PACKAGE_OPTIONS'
call eq engine~identify('say "hello"'), 'LOGIC'
call eq engine~shouldRunPrologue('REQUIRE'), .true
engine~setPrologPolicy(.false)
call eq engine~shouldRunPrologue('REQUIRE'), .false
call eq engine~shouldRunPrologue('DIRECT'), .true
engine~setPrologPolicy(.true)
prologue = engine~setScope('say "hello"', 'PROLOGUE')
call eq prologue~variablePolicy, 'LOCAL'
call eq prologue~argumentPolicy, 'POSITIONAL_OBJECTS'
call eq prologue~numericPolicy, 'PACKAGE'
handler = .ScopeProbe~new
engine~rexxLogic(handler, 2)
call eq handler~calls, 1
call eq handler~lastDepth, 2
trap = engine~setScope('signal on syntax', 'SIGNAL')
call eq trap~activation, prologue
call eq trap~variablePolicy, 'SAME_ACTIVATION'
engine~endScope
engine~endScope
routine = engine~setScope('::routine helper')
call eq routine~variablePolicy, 'ISOLATED'
procedure = engine~setScope('procedure expose a')
call eq procedure~variablePolicy, 'ISOLATED_EXPOSE'
call eq procedure~numericPolicy, 'INHERIT'
engine~endScope
engine~endScope
class = engine~setScope('::class MyClass')
call eq class~activation, .nil
method = engine~setScope('::method run')
call eq method~variablePolicy, 'LOCAL_WITH_OBJECT_EXPOSE'
engine~rexxLogic(handler, 3)
call eq handler~calls, 2
engine~endScope
engine~endScope
call eq engine~depth, 1
say 'PASS when-dealing-with scope' checks 'assertions'
exit 0

eq: procedure expose checks
  use arg actual, expected
  if actual \== expected then do
    say 'FAIL:' actual 'expected' expected
    exit 1
  end
  checks += 1
  return

::class ScopeProbe
::attribute calls get
::attribute lastDepth get
::method init
  expose calls lastDepth
  calls = 0
  lastDepth = -1
::method rexxInstruction
  expose calls lastDepth
  use arg lastDepth
  calls += 1
::requires 'core/RxWhenDealingWith.cls'
