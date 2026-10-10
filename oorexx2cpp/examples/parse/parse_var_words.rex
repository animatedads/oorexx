/* Final target retains remaining source bytes including blanks. */
text = '  alpha  beta   gamma  '
parse var text first second rest
say first
say second
say rest
