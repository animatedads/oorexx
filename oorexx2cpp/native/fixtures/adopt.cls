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
::class Money public
::method init
  expose cents
  use arg cents
::method cents
  expose cents
  return cents
::method "=="
  expose cents
  use arg other
  return cents == other~cents
::method compare
  use arg a, b
  return (a == b) (a \== b) (a = b)
::class Rank public inherit Orderable
::method init
  expose v
  use arg v
::method v
  expose v
  return v
::method compareTo
  expose v
  use arg other
  return sign(v - other~v)
::method compare
  use arg a, b
  return (a == b) (a = b) (a \== b) (a < b)
::class Shape public
::method init
  expose kind
  use arg kind = 'shape'
::method kind
  expose kind
  return kind
::method create class
  return self~new
::method clone
  return self~class~new('clone of' self~kind)
::class Circle subclass Shape public
::method init
  self~init:super('circle')
::class Parser public
::method fromText class
  use strict arg text, limit = 10
  return self~new(text, limit)
::method init
  expose text limit parts
  use strict arg text, limit = 10
  parts = .array~new
  self~split
::method split private
  expose text parts
  do w over text~makearray(' ')
    parts~append(w)
  end
::method count
  expose parts
  return parts~items
