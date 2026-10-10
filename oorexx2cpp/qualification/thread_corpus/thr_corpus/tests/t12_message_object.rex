o = .A~new
m = .Message~new(o, "ADD", "Individual", 3, 4)
m~start
say "start:" m~result
m2 = .Message~new(o, "ADD", "Individual", 10, 20)
say "send:" m2~send
::class A
::method add unguarded
  use arg a, b
  return a + b
