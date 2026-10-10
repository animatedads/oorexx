/* Positional scalar arguments use ooRexx ARGLIST, including holes and extra slots. */
::class MultiArgumentHost public
::method init
  expose status
  status = 'ready'
::method status
  expose status
  return status

::routine RX3 PUBLIC
  use arg a, b, c
  return a * 100 + b * 10 + c
::routine RX4 PUBLIC
  use arg a, b, c, d
  return a || '-' || b || '-' || c || '-' || d
::routine RX6 PUBLIC
  use arg a, b, c, d, e, f
  return a + b + c + d + e + f
::routine RX16 PUBLIC
  use arg a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p
  return a + b + c + d + e + f + g + h + i + j + k + l + m + n + o + p
::routine RX_POW3 PUBLIC
  numeric digits 60
  use arg base, exp, mod
  res = 1
  base = base // mod
  do while exp > 0
    if exp // 2 == 1 then res = (res * base) // mod
    base = (base * base) // mod
    exp = exp % 2
  end
  return res
::routine RX_SECRET4 PRIVATE
  use arg a, b, c, d
  return a || b || c || d
::routine RX_BIND PUBLIC
  use arg first, second, third
  return '[' || first || '][' || second || '][' || third || ']'
::routine RX17 PUBLIC
  use arg a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q
  return a + b + c + d + e + f + g + h + i + j + k + l + m + n + o + p + q
::routine RX_ZERO PUBLIC
  return 'no params'
