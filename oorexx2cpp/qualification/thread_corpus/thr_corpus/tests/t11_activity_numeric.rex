/* NUMERIC settings belong to the activation, not inherited into started messages */
numeric digits 20
numeric fuzz 3
m = .N~new~start("D")
say "started message:" m~result
say "send:" .N~new~send("D")
say "caller:" digits() fuzz()
::class N
::method d unguarded
  return digits() fuzz()
