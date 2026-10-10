/* A.I. is compound, unlike the literal stem A.; do not reset other keys. */
i = 3
a.3.x = 'old'
a.i. = 'default-sub'
say a.3.x a.3. a.i.
a.i.x = 'new'
say a.3.x a.i.
a.i. = 'again'
say a.3.x a.i.
