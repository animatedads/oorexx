/* native registers: whole-number variables kept as machine integers; every other path sees the same values */
x = '05'; y = x; say 'copy' y y + 0 (y == 5) (y = 5)
a = 5; b = a; c = b + 1; say 'chain' a b c
x = 999999999; x = x + 1; say 'over' x; x = x - 1; say 'back' x
x = 7; y = x / 2; z = x % 2; w = x // 2; say 'div' y z w (6 / 3)
x = -3; y = -x; z = +x; say 'neg' x y z
a = 3; b = 4; say 'logic' (a > 1 & b < 2) (a > 1 | b < 2) (a > 1 && b > 2) (\(a > b)) ((a > 1) + (b < 9))
l1 = a > 1 & b < 2; l2 = \(a > b); l3 = (a > 1) + (b < 9); l4 = a >= 3 | b \= 4; say 'logic2' l1 l2 l3 l4
if a > 1 & b > 3 then say 'if1'; if \(a < b) then say 'no'; else say 'if2'
i = 0; do k = 1 to 5; i = i + k; if i > 6 then i = i - 6; end; say 'loop' i k
n = 0; do j = 1 to 10; n = n + j; if j = 3 then call addten; end; say 'internal' n j
n = 0; do j = 1 to 4; n = n + j; if j = 2 then interpret 'n = n * 100'; end; say 'interpret' n
x = 1; y = value('X', 7) + x; z = x + 1; say 'value' x y z
t = 2; numeric digits 5; t = t * 1000; t = t * 1000; say 'digits' t; numeric digits 9
f = 10; numeric fuzz 1; say 'fuzz' (f = 11) (12345678 = 12345679); numeric fuzz 0
signal on syntax name s1
m = 5; m = m + 1; m = m / 0
s1: say 'after syntax' m rc
q = 2; drop q; signal on novalue name s2
q = q + 1
s2: say 'novalue' condition('D')
signal off novalue
signal on syntax name s3
v = '01'; if v then say 'yes'
s3: say 'logical' rc
r = 3; parse value '12 34' with r s; u = r + s; say 'parse' r s u
p. = 0; do i = 1 to 5; p.i = i * i; end; say 'stem' p.3 p.5 i
call proc 3; say 'proc' g h
e = 4; f = e + inc(); say 'call' e f
z = 1; z = z; say 'self' z
k = 10; do while k > 0; k = k - 3; end; say 'while' k
k = 0; do until k >= 7; k = k + 2; end; say 'until' k
cnt = 0; do i = 1 to 3; do j = i to 3; cnt = cnt + i * j; end; end; say 'nested' cnt i j
s = 0; do i = 1 to 100000; s = s + i // 3; end; say 'big' s
exit
addten: n = n + 10; return
proc: procedure expose g; arg h; g = h * 2; h = h + 1; return
inc: e = e + 1; return 1
