/* INTERPRET in compiled methods and routines: locals, stems, DROP, exposed variables, NUMERIC, a whole loop, ARG,
   RETURN inside the string, a syntax error in the string, a routine without SELF. */
::class InterpretTest public
::attribute counter
::method init
  expose counter
  counter = 5
::method run
  expose counter
  x = 12
  interpret 'x=1'
  say 'x' x
  a.1 = 'one'; a.2 = 'two'
  interpret 'b = a.1 a.2; a.3 = "three"; drop x'
  say b a.3 symbol('X')
  interpret 'counter = counter + 1; y = counter'
  say 'counter' counter y
  interpret 'numeric digits 4'
  say 'digits' digits() 2/3
  str = "i = 0;" -
        "loop label aha1;" -
        "   i = i + 1;" -
        "   leave aha1;" -
        "end aha1;"
  interpret str
  say 'i' i
  say 'arg' self~withArg('A', 'B')
  say 'ret' self~early
  say self~bad
  say 'routine' interpRoutine(7)
::method withArg
  interpret 'parse arg p, q; r = p || q'
  return r arg()
::method early
  interpret 'return "early"'
  return 'late'
::method bad
  signal on syntax
  interpret 'z = 1 +'
  return 'none'
syntax: return 'syntax' condition('o')~code
::routine interpRoutine public
  use arg v
  interpret 'w = v * 2'
  return w
