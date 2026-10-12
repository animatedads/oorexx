a = .array~of(1,2,3); a[2] += 10; i = 3; a[i] *= 5
d = .directory~new; d['x'] = 'ab'; d['x'] ||= 'cd'
say a[1] a[2] a[3] d['x']
