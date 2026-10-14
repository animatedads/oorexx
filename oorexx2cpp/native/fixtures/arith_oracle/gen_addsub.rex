/* gen_addsub.rex N SEED: N random "digits a op b" cases, then the interpreter's result for each (cases.txt, expected.txt). */
parse arg n seed
call random , , seed
cases = .stream~new('cases_addsub.txt'); cases~open('write replace')
exp = .stream~new('expected_addsub.txt'); exp~open('write replace')
do i = 1 to n
  d = random(1, 12); if random(0, 4) = 0 then d = random(13, 40)
  a = num(); b = num()
  op = word('+ -', random(1, 2))
  cases~lineout(d a op b)
  numeric digits d
  if op == '+' then r = a + b; else r = a - b
  numeric digits
  exp~lineout(r)
end
cases~close; exp~close
exit
num: procedure
  len = random(1, 16); if random(0, 4) = 0 then len = random(15, 45)
  s = ''
  do len; s = s || random(0, 9); end
  select case random(1, 6)
    when 1 then s = s || '.' || copies('0', random(0, 3))
    when 2 then do; p = random(0, len); s = left(s, p) || '.' || substr(s, p + 1); if p = 0 then s = '0' || s; end
    when 3 then s = s || 'E' || word('+ -', random(1, 2)) || random(0, 20)
    when 4 then s = random(1, 9) || copies('0', random(0, 12))
    otherwise nop
  end
  if random(0, 1) then s = '-' || s
  return s
