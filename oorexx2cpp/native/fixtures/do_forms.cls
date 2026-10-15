/* Every DO / LOOP form (LABEL, COUNTER, controlled with TO BY FOR in any order, OVER, FOREVER, count, WHILE, UNTIL,
   simple and labeled blocks, compound control variables) and the run-time LEAVE / ITERATE / count errors. */
::class DoForms public
::method run
  i = 0
  do
    i = i + 1
    if i > 3 then leave
  end
  say 'simple' i
  do label aha1; say 'in aha1'; leave aha1; say 'not here'; end aha1
  loop label aha2; say 'loop aha2'; leave aha2; end
  n = 0; loop; n += 1; if n = 3 then leave; end; say 'loop forever' n
  c.=0; j=1
  Do i.j=0 to 6; c.1=c.1+1; If i.j=1 Then Leave I.J; End i.j
  say 'compound' c.1 i.1
  s = ''; do i=010e+00 To 20 By -3; s = s i; end; say 'neg by' s '|' i
  s = ''; do i=1 to 10 by 2 for 3; s = s i; end; say 'for' s i
  s = ''; do counter k 4; s = s k; end; say 'counter' s k
  s = ''; do label outer counter q x over .array~of(a,b,c); s = s x q; if x == 'b' then leave outer; end; say 'over' s q
  s = ''; do i = 1 to 3; do j = 1 to 3; if j = 2 then iterate i; s = s i||j; end; end; say 'iterate' s
  s = ''; do i = 1 until i >= 3; s = s i; end; say 'until' s
  s = ''; do 3 while s \== ' x x'; s = s 'x'; end; say 'while' s
  s = ''; loop i = 1 to 2; s = s i; end; say 'loop ctl' s
  self~errors
::method errors
  do e over .array~of('-1', '1.5', 'for')
    say self~bad(e)
  end
  say self~leaveNone
  say self~iterNamed
::method bad
  use arg e
  signal on syntax
  if e == 'for' then do i = 1 for -2; end
  else do e; end
  return 'none'
syntax: return condition('o')~code condition('o')~message
::method leaveNone
  signal on syntax
  do; leave; end
  return 'none'
syntax: return condition('o')~code condition('o')~message
::method iterNamed
  signal on syntax
  do label blk; iterate blk; end
  return 'none'
syntax: return condition('o')~code condition('o')~message
::method stemControls
  c=0 ; b.=2; t.=3; f.=4
  do cv=1 By b. To t. For f.; c=c+1; End
  r.=3
  do r.; c=c+1; end
  return cv c
