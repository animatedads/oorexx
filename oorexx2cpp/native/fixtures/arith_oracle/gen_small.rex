/* gen_small.rex N SEED: "digits fuzz a op b" cases for + - * with plain operands of at most DIGITS digits under DIGITS
   1..18 (the 128-bit path, small_math), rounding on most results; the interpreter's result for each. */
parse arg n seed
call random , , seed
cases = .stream~new('cases_small.txt'); cases~open('write replace')
exp = .stream~new('expected_small.txt'); exp~open('write replace')
do i = 1 to n
  d = random(1, 18); f = 0
  op = word('+ - *', random(1, 3))
  a = num(d); b = num(d)
  cases~lineout(d f a op b)
  numeric digits d
  select
    when op == '+' then r = a + b
    when op == '-' then r = a - b
    otherwise r = a * b
  end
  numeric digits
  exp~lineout(r)
end
cases~close; exp~close
exit
num: procedure
  use arg d
  len = random(1, d)
  s = ''
  do len; s = s || random(0, 9); end
  select case random(1, 5)
    when 1 then nop
    when 2 then do; p = random(0, len); s = left(s, p) || '.' || substr(s, p + 1); if p = 0 then s = '0' || s; end
    when 3 then s = '0.' || copies('0', random(0, 8)) || s
    when 4 then s = s || copies('0', random(0, 6))
    otherwise s = left(s, 1) || '.' || substr(s, 2)
  end
  if length(s~changeStr('.', '')~strip('L', '0')) > d then s = left(s, d)   -- (at most DIGITS digits)
  if right(s, 1) == '.' then s = s || '0'
  if random(0, 1) then s = '-' || s
  return s
