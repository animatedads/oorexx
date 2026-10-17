/* whole-number operators and machine-integer loops: every edge falls back to the interpreter's results */
say 1 + 2 '|' 7 - 10 '|' 6 * 7 '|' 7 % 2 '|' (-7) % 2 '|' 7 // 3 '|' (-7) // 3 '|' 7 // -3 '|' 0 // 5 '|' 6 / 3 '|' 7 / 2 '|' (-6) / 3
say 999999999 + 1 '|' (-999999999) - 1 '|' 99999 * 99999 '|' 123456789 * 10 '|' 999999999 % 1 '|' '05' + 1 '|' ' 5' + 1 '|' '+5' + 1
say 5.0 + 1 '|' 1e2 + 1 '|' 2 * 0.5 '|' 10 / 4 '|' 1 / 3
say 5 = '05' '|' 5 = ' 5 ' '|' 5 == '05' '|' 5 < 10 '|' 'abc' < 'abd' '|' 10 > 9 '|' 10 >> 9 '|' 5 \= 5.0 '|' 5 <> 6 '|' 5 >< 5
numeric digits 5
say 99999 + 1 '|' 12345 * 3 '|' 100000 % 3 '|' 12 + 3
numeric digits 9
numeric fuzz 1
say 1234567 = 1234568 '|' 5 < 6
numeric fuzz 0
signal on syntax name z1
say 5 % 0
z1: say 'syntax' rc
signal on syntax name z2
say 5 // 0
z2: say 'syntax' rc
signal on syntax name z3
say 'a' + 1
z3: say 'syntax' rc
/* loops */
do i = 1 to 3; say 'a' i; end
do i = 3 to 1 by -1; say 'b' i; end
do i = 1 to 10 by 4; say 'c' i; end; say 'after c' i
do i = 1 to 5; if i = 2 then i = 4; say 'd' i; end
do i = 1 to 5; if i = 2 then i = '3'; say 'e' i; end
do i = 1 to 5; if i = 2 then i = 3.5; say 'f' i; end
do i = 1 to 3; if i = 2 then i = '+2'; say 'g' i; end
do i = 999999997 to 1000000002 for 8; say 'h' i; end
do i = -999999998 to -1000000002 by -2 for 6; say 'k' i; end
do i = 1.5 to 4; say 'l' i; end
do i = 1 to 3.5; say 'm' i; end
do i = 1 to 20 by 7 for 2; say 'n' i; end
do i = 90 to 1000000 for 15; numeric digits 2; say 'o' i; if i > 200 then leave; end
numeric digits 9
do i = 1 to 6; if i = 3 then drop i; say 'p' i; if symbol('I') = 'LIT' then leave; end
do i = 5 for 3; say 'q' i; end
do i = 1 to 3; interpret 'i = i + 1'; say 'r' i; end
do i = 1 to 3; call bump; say 's' i; end
numeric fuzz 1
do i = 1 to 3; say 't' i; end
numeric fuzz 0
x = .array~of(1,2); do i = 1 to x~items; say 'u' x[i]; end
do i = 0 to 2; say 'v' i * 3 i // 2 i % 2 -i; end
n = 0; do while n < 5; n = n + 2; end; say 'w' n
n = 10; do until n <= 3; n = n - 4; end; say 'x' n
select; when 3 > 2 then say 'y yes'; otherwise say 'y no'; end
j = 0; do i = 1 to 100000; j = j + i; end; say 'z' j i
exit
bump: i = i + 1; return
syntax: say 'unexpected syntax' rc; exit
