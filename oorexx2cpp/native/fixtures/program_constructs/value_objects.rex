/* VALUE() answers and assigns objects; a stem name's value is the stem object */
a = .array~of(1, 2)
say value('a')~items
b = value('a', .directory~new)
say b~items value('a')~class~id
say value('A.1') value('a.', .stem~new)~class~id
s. = 5
say value('s.')~class~id value('s.')
t. = 'dflt'
t.1 = 'one'
x = value('t.', 'new')
say x~class~id x[1] t.1 t.2
u.7 = 'seven'
y = value('u.', .stem~new)
say y[7] u.7 var('u.7')
z = value('v.')
z[3] = 'three'
say v.3
