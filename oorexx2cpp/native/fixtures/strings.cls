/* String results and concatenation in compiled class methods (with SELF sends). */
::class S public
::method init
  expose t
  use arg start
  t = start
::method add
  expose t
  use arg x
  t = t || x
  return t
::method who
  return "A>" || self~add("x") || "/" || self~add("y")
