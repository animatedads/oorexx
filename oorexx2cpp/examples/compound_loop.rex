/* Compound indexes in counted loops; no BIF dependency. */
x. = 'missing'
do i = 1 to 12
  x.i = i * i
end
do i = 1 to 12
  say x.i
end
say x.13
