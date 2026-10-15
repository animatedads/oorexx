/* Bug 1: an object passed through RequestGlobalReference + ReleaseGlobalReference is never collected. */
c = .Object~new; w = .WeakReference~new(c); drop c   -- control: never seen by native code
o = .Object~new; v = .WeakReference~new(o)
.Probe~keepRelease(o); drop o                         -- native code takes and releases a global reference
do i = 1 to 20
  call gc 'F'
  do 10; x = .Object~new; end                         -- push the new objects out of the interpreter's save stack
  if w~value == .nil & v~value == .nil then leave
end
say 'control collected:   ' (w~value == .nil)
say 'released collected:  ' (v~value == .nil)       -- expected 1; ooRexx 5.3.0 prints 0

/* Bug 2: an error raised while a native method's arguments are processed is not visible to CheckCondition(). */
signal on syntax
say 'native SendMessage:  ' .Probe~sendOpen('grefbugq', 4)   -- expected condition=1 result=NULL
say 'returned normally'
exit
syntax:
say 'SYNTAX' condition('o')~code 'raised only when the native method returned'

::class Probe
::method keepRelease class external 'LIBRARY grefbug keep_release'
::method sendOpen    class external 'LIBRARY grefbug send_open'
