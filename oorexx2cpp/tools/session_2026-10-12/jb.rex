big = .array~new
do i = 1 to 2000
  d = .directory~new; d['id'] = i; d['name'] = 'item' i; d['vals'] = .array~of(i, i * 2, 'x"y'); big~append(d)
end
t = time('E'); s = .json~toJSON(big); say 'toJSON' format(time('E') - t,,3) s~length
t = time('E'); b = .json~fromJSON(s); say 'fromJSON' format(time('E') - t,,3) b~items
