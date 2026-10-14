/* gen_ops.rex N SEED: "digits fuzz a op b" cases for * / % // ** = < >, and the interpreter's result (or ERR code). */
parse arg n seed
call random , , seed
cases = .stream~new('cases_ops.txt'); cases~open('write replace')
exp = .stream~new('expected_ops.txt'); exp~open('write replace')
signal on syntax
do i = 1 to n
  d = random(1, 12); if random(0, 4) = 0 then d = random(13, 40); f = 0
  if random(0, 3) = 0 then f = random(0, d - 1)
  op = word('* / % // ** = < > == \=', random(1, 10))
  a = num(); b = num()
  if op == '**' then b = random(0, 12) * word('1 -1', random(1, 2))
  cases~lineout(d f a op b)
  r = calc(d, f, a, op, b)
  exp~lineout(r)
end
cases~close; exp~close
exit
calc: procedure
  use arg d, f, a, op, b
  signal on syntax name bad
  numeric digits d; numeric fuzz f
  select
    when op == '*' then r = a * b
    when op == '/' then r = a / b
    when op == '%' then r = a % b
    when op == '//' then r = a // b
    when op == '**' then r = a ** b
    when op == '=' then r = a = b
    when op == '<' then r = a < b
    when op == '>' then r = a > b
    when op == '==' then r = a == b
    otherwise r = a \= b
  end
  return r
bad:
  return 'ERR' condition('o')~code
syntax: say 'gen failed' condition('o')~message; exit 1
num: procedure
  len = random(1, 14); if random(0, 4) = 0 then len = random(15, 45)
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
