/* Stem objects in a compiled method: Stem methods the compiled stem does not implement, interpreter stems bound to
   stem variables, and operators sent to a stem (forwarded to its default value). */
::class StemObjectTest public
::method run class
  a.1 = "abc"
  a.1.2..4 = "def"
  d = a.~toDirectory
  say d~items d[1] d["1.2..4"]
  say a.~at("1") a.~at a.~items a.~hasIndex(1)
  b. = "x"
  say b.~"[]"(1,2) b.~items b.[7]
  s = .stem~new("def")
  a. = s
  say a.~"[]" a.1 (a.~"[]" == s~"[]")
  s[5] = "five"
  say a.5
  say a.||"x" (a. = s) (a. == a.) (b.||"y") (c.||"z")
  c. = 5
  say c. + 1 (c. > 4) -c.
  signal on syntax
  e.1 = 1
  x = e.~toDirectory(1)
  say "no error"
  exit
syntax:
  say "SYNTAX" condition('o')~code
