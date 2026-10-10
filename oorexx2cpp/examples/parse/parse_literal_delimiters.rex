s = 'alpha--beta--gamma'
parse var s first '--' second '--' third
say first
say second
say third
s = 'no match here'
parse var s a 'ZZ' b
say a
say b
