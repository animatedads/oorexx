/* CONDITION options: A C D E I O R S, a null or unknown option 40.904, 'O' a copy, 'R' resets. Claude (Opus 5.5), 2026-11-19. */
say '['condition()']' '['condition('E')']' '['condition('r')']'
signal on syntax name s1; x = condition(''); s1: say rc condition('o')~message condition('E') condition('C')
o1 = condition('O'); o2 = condition('O'); say o1 == o2 o1~code
say condition('R') '['condition('C')']' condition('O')
call sub
exit
sub:
signal on syntax name s2
x = condition('Z')
s2: say rc condition('O')~message
say condition('E')
return
