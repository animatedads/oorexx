/* Message sends on variable receivers (ExprMessage: a string receiver used in place, an object receiver held by a
   copy, the result declared at its first value): chains, cascades, index read and assign, attribute assign and +=,
   the message instruction. Output identical to the interpreter. Claude (Opus 5.5), 2026-11-05. */
s = 'abcdef'
say s~substr(2, 3) s~length s~reverse~upper s~substr(2)~substr(2)
a = .array~of(10, 20, 30)
say a[2] a~items a[1] + a[3]
a[2] = 'two'; say a[2]
a[3] += 5; say a[3]
o = .t~new
o~n = 4; say o~n
o~n += 3; say o~n
o~bump
say o~n
say o~~bump~n o~n
q = .array~new; q~~append(1)~~append(2); say q~items q~makestring(, ',')
r = o~swap(o); say r~n o~class~id
d = .directory~new; d~x = 'dx'; say d~x d['X']
n = 12; say n~d2x n~length (n + 1)~length
e = ''; say '[' || e~length || e~substr(1, 2) || ']'
t = .stem~new; t[5] = 'five'; say t[5] t[6]
::class t
::attribute n
::method bump
  expose n
  n = n + 1
::method swap
  use arg other
  return .t~new~~setn(other~n * 10)
::method setn
  expose n
  use arg n
