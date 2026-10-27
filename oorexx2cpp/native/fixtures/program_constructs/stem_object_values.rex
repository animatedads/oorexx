/* stem_object_values.rex: s.[tail] = object answered by the stem itself (an object VALUE; the indexes are strings) */
t = .Thing~new("a")
call show
s. = .false
s.["X"] = t
s.["Y", "Z"] = .Thing~new("b")
s.["N"] = .nil
say s.~hasIndex("X") s.~hasIndex("Y.Z") s.~hasIndex("Q") (s.x == t) s.["Y", "Z"]~name (s.n == .nil)
s.[] = .Thing~new("dflt")
say s.q~name s.~hasIndex("X") s.["Q"]~name
s.["K"] = t
say s.~items (s.k == t)
drop s.k
say s.k
r = f()
say r~opts~items r~opts["ORDER"] r~opts["="]~name (r~opts["ID"] == 7)
n. = 0
n.[1] = t
n.["2"] = 5
say n.1~name n.2 n.3
say n.~items
n.7 = "seven"; n.abc = "x"; drop n.2
say n.~items
n.2000000 = 1; n.["P", "Q"] = t
say n.~items
n. = "reset"
say n.~items n.1
exit

f: procedure
  options. = .false
  options.order = ""
  options.id = 7
  options.["="] = .Thing~new("eq")
  if options.~hasIndex("=") then options.order ||= " ="
  return .Holder~new(options.)

show: say "start"; return

::class Thing
::attribute name
::method init
  expose name
  use arg name
::class Holder

::method init
  expose opts.
  use strict arg opts.
::method opts
  expose opts.
  return opts.
