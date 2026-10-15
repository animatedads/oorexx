/* A condition the interpreter raises during a call from compiled code (NOSTRING of a promoted stem) stays in the compiled method's own Rexx frame, as interpreted: it never reaches the caller. */
::class StemT public
::method run
  v207.='ab'
  v207.1='cd'
  call sub0207 v207., v207.1
  say 'result' result
  return
sub0207:
  .Checker~same(arg(1), "ab")
  .Checker~same(arg(2), "cd")
  return "ARG"(1)||"ARG"(2)
