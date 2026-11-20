/* ADDRESS environment command WITH INPUT / OUTPUT / ERROR, as the interpreter runs it (rx::interpreterCommand,
   CommandIo): NORMAL, STEM, STREAM and USING (a string, a stem, an array, a list), OUTPUT and ERROR REPLACE / APPEND,
   input and output together, the same stem in and out, RC, a failing command, an expression in parentheses, from the
   program, an internal procedure, a method and a routine. Before: the WITH part was compiled into the command string.
   Output identical to the interpreter. Claude (Opus 5.5), 2026-11-15. */
address system 'echo one; echo two' with output stem v.
say v.0 v.1 v.2 rc
address system 'echo three' with output append stem v.
say v.0 v.3
address system 'echo four' with output replace stem v.
say v.0 v.1 v.[2]
in.0 = 3; in.1 = 'cherry'; in.2 = 'apple'; in.3 = 'banana'
address system 'sort' with input stem in. output stem out.
say out.0 out.1 out.2 out.3
address system 'cat' with input using 'single line' output stem s.
say s.0 s.1
lines = .array~of('b2', 'a1', '', 'c3')
address system 'sort' with input using (lines) output stem t.
say t.0 t.1 t.2 t.3
coll = .array~of('kept')
address system 'echo added' with output append using (coll)
say coll~items coll[1] coll[2]
lst = .list~of('x')
address system 'echo fresh' with output replace using (lst)
say lst~items lst[lst~first]
call lineout 'aw_in.txt', 'from file 1'; call lineout 'aw_in.txt', 'from file 2'; call lineout 'aw_in.txt'
address system 'cat' with input stream 'aw_in.txt' output stream 'aw_out.txt'
call lineout 'aw_out.txt'
say lines('aw_out.txt') linein('aw_out.txt'); call lineout 'aw_out.txt'
name = 'aw_out.txt'
address system 'echo appended' with output append stream (name)
call stream name, 'c', 'close'
say charin(name, 1, chars(name))~changeStr('0a'x, '|')
address system 'echo err >&2; echo out' with output stem o. error stem e.
say o.0 o.1 e.0 e.1
address system 'echo both >&2' with error append stem o.
say o.0 o.2
address system 'exit 3' with output stem x.
say 'rc' rc x.0
address system 'echo normal' with output normal
q.0 = 2; q.1 = 'zz'; q.2 = 'aa'
address system 'sort' with input stem q. output stem q.
say q.0 q.1 q.2
say inproc() .w~new~run(3) viaRoutine()
address system 'rm -f aw_in.txt aw_out.txt'
exit
inproc: procedure
  address system 'echo in procedure' with output stem p.
  return p.1
::class w
::method run
  use arg n
  address system 'seq' n with output stem m.
  return m.0 m.[m.0]
::routine viaRoutine
  address system 'echo routine' with output stem r.
  return r.1
