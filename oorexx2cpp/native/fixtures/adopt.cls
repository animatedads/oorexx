/* Compiled instances that pass through the interpreter come back to compiled code as native instances. */
::class Point public
::method init
  expose x y
  use arg x, y
::method x
  expose x
  return x
::method y
  expose y
  return y
::method plus
  expose x y
  use arg other
  return .Point~new(x + other~x, y + other~y)
::method make class
  use arg x, y
  return self~new(x, y)
::method sum class
  use arg list
  total = 0
  do p over list
    total = total + p~x + p~y
  end
  return total
::method same
  use arg a, b
  return (a == b) (a == self) (b == self)
::method hidden private
  return 'private'
::method callHidden
  use arg other
  return other~hidden
::class Holder public
::method init
  expose items
  items = .array~new
::method keep
  expose items
  use arg p
  items~append(p)
::method total
  expose items
  t = 0
  do p over items
    t = t + p~x
  end
  return t
::method first
  expose items
  return items[1]
