/* Interpreter objects referenced by compiled code are collectable once compiled code drops them (UNINIT, weak references). */
::class LifetimeTest public
::method make1
  return .object~new
::method make2
  use arg x
  return 1
::method make3
  return .weakReference~new(arg(1))
::method churn
  -- compiled string churn: the interpreter still collects (a weakly referenced object goes)
  w = .weakReference~new(.relation~new)
  n = 0
  loop while w~value \= .nil & n < 50
    n += 1
    loop 100
      x = copies("*", 100000)
    end
  end
  return (w~value == .nil)
::method uninit
  self~class~uninits = self~class~uninits + 1
::method uninits class attribute
::method init class
  self~uninits = 0
