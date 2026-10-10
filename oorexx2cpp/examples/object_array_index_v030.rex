a = .array~new
a~append('red')
a~append('blue')
say a[1]
say a[2]
a[2] = 'green'
say a[2]
say a~'[]'(1)
a[4] = 'four'
say a[4]
