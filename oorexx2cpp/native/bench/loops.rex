/* tight arithmetic and control loops (IBM's 10x-25x category) */
parse arg n .
if n = '' then n = 300000
/* 1: sum with remainder and a compare */
s = 0
do i = 1 to n
  s = s + i // 7
  if s > 100000 then s = s - 100000
end
say 'sum' s
/* 2: nested counting loops */
c = 0
do a = 1 to 300
  do b = a to 300 by 3
    c = c + 1
  end
end
say 'nested' c
/* 3: iterative fibonacci mod 1000000 */
x = 0; y = 1
do k = 1 to n
  t = (x + y) // 1000000
  x = y; y = t
end
say 'fib' y
/* 4: sieve on a stem */
m = n % 10
p. = 1
do i = 2 to m
  if p.i then do j = i * i to m by i; p.j = 0; end
end
cnt = 0
do i = 2 to m; if p.i then cnt = cnt + 1; end
say 'primes' cnt
/* 5: while loop with integer divide */
z = 0; w = n
do while w > 0
  z = z + w // 10
  w = w % 10
  if w = 0 & z < n then do; w = n - z; n = 0; end
end
say 'digits' z
