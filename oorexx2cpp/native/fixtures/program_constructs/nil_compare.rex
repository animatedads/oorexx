/* .nil in comparisons: a string compared with .nil, .nil compared with objects (identity), under SIGNAL ON NOSTRING */
signal on nostring
x = 'abc'; n = 5; o = .object~new; d = .directory~new; e = .nil
say (x == .nil) (x \== .nil) (x = .nil) (x \= .nil) (x <> .nil) (x >< .nil) (x > .nil) (x < .nil)
say (x >= .nil) (x <= .nil) (x \< .nil) (x \> .nil) (x >> .nil) (x << .nil) (x >>= .nil) (x <<= .nil) (x \<< .nil) (x \>> .nil)
say (n == .nil) (n \= .nil) (n > .nil) ('' == .nil) ('' \== .nil)
say (.nil == o) (.nil \== o) (.nil = d) (.nil \= d) (.nil == e) (.nil \== e) (.nil = .nil) (.nil == x) (.nil \== x)
say (o == .nil) (o \== .nil) (e == .nil) (d \== .nil)
t = .Thing~new
say (.nil == t) (.nil \== t) (t == .nil) (t \== .nil)
say 'done'
exit
nostring: say 'NOSTRING raised' condition('d'); exit
::class Thing
::attribute v
