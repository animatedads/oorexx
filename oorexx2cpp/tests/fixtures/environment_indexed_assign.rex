.local['RXT'] = .directory~new
.local['RXT']['k'] = 'v1'
say .local['RXT']['k']
a = .array~new(2,2); a[1,2] = 'x'; say a[1,2]
d = .directory~new; d['inner'] = .directory~new; d['inner']['z'] = 5; say d['inner']['z']
