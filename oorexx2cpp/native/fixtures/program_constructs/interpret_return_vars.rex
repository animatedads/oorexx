/* INTERPRET: variables set before a RETURN in the code (and in its own FINALLY clause) reach the activation. Claude (Opus 5.5), 2026-11-20. */
say r() x
x = 0
say q() x
exit
r: interpret "x = 5; return 1"
q: interpret "do; x = 7; return 2; finally; x = x + 1; end"
