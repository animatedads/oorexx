/* DATATYPE(s, 'S') and SYMBOL(s) for signed-exponent forms: trunk bug #2080 (a mantissa of digits and one period before E+n / E-n). Claude (Opus 5.5), 2026-11-19. */
do s over .array~of('X1E+2', 'A23E+2', '.E+2', '1AE+2', '1E2E+3', '1.2E+3', '1.2.3E+3', '.5E-1', '12E+', 'E+2', '1e+5', 'abc', '1.2.3', 'a.b.', '3E', '1E2X')
  say s datatype(s, 'S') symbol(s)
end
