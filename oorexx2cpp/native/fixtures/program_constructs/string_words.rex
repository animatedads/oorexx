s = 'Alpha  beta'||'09'x||'GAMMA delta'
do p over ('beta gamma', 'BETA', 'alpha', 'delta x', '', '  ', 'gamma delta', 'Gamma')
  say '['p']' s~containsWord(p) s~caselessContainsWord(p) s~caselessContainsWord(p, 2) s~caselessContainsWord(p, 4) s~caselessContainsWord(p, 5)
end
