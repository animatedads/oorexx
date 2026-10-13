/* Parenthesised patterns are expressions (ooRexx), not only a single symbol. */
s = 'a3b3c,d'
parse var s x (3) y
say x '|' y
sep = ','
parse var s p (1 + 2) q (sep) r
say p '|' q '|' r
parse var s u (sep || '') v
say u '|' v
parse var s . =(1 + 1) w +(2 * 1) z
say w '|' z
