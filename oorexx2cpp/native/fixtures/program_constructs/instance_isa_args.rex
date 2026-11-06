/* ISA of compiled instances whose classes define none (the answer cached per class and class asked about, by method
   table or, for a class with no methods, by name), identity comparisons of compiled instances, and native method calls
   whose arguments come from the thread's pool: nested and recursive calls, omitted arguments, many arguments.
   Output identical to the interpreter. Claude (Opus 5.5), 2026-11-05. */
a = .animal~new('rex'); d = .dog~new('fido'); e = .empty~new; f = .empty~new; g = .emptier~new
do 2
  say a~isA(.animal) a~isA(.dog) a~isA(.Object) a~isA(.Array) a~isA(.String)
  say d~isA(.animal) d~isA(.dog) d~isA(.empty) d~isA(.Object)
  say e~isA(.empty) e~isA(.animal) e~isA(.Object) g~isA(.empty) g~isA(.emptier) g~isA(.dog)
end
c = .dog; say d~isA(c) a~isA(c) d~isA(.animal~class) .dog~isA(.Class) .dog~isA(.dog)
say (a == a) (a == d) (a \== d) (e == f) (e = e) (d == 'fido') (a == .nil) (e \= g)
say a~name d~name d~speak('loud') d~speak d~speak(, 'twice') d~many(1, 2, , 4, 5, 6, 7, 8)
say d~depth(5) a~nest(d, 3) a~argc() a~argc(1) a~argc(, , 3) a~argc(.nil)
say d~chain(a~name, d~speak(a~name), a~argc(1, 2))
exit
::class animal
::method init
  expose name
  use arg name
::method name
  expose name
  return name
::method argc
  s = arg()
  do i = 1 to arg()
    s = s || (arg(i, 'E') = 1)~substr(1, 1)
  end
  return s
::method nest
  use arg other, n
  if n = 0 then return other~name
  return n || '>' || self~nest(other, n - 1) || '<' || other~speak(n)
::class dog subclass animal
::method speak
  if arg(1, 'O') then return 'woof' || arg(2)
  return 'WOOF(' || arg(1) || ')' || arg(2)
::method many
  s = ''
  do i = 1 to arg()
    if arg(i, 'E') then s = s || arg(i)
    else s = s || '_'
  end
  return s arg()
::method depth
  use arg n
  if n = 0 then return 0
  return n + self~depth(n - 1)
::method chain
  return arg(1) '|' arg(2) '|' arg(3) '|' self~many(arg(1), , arg(3))
::class empty
::class emptier subclass empty
