/* oorexxpython (Josep Maria Blasco's ooRexx/Python bridge) from compiled code: Python modules used from compiled
   methods, and Python calling back into compiled code (a compiled routine as a sort key, a method of a compiled
   object, a compiled class extending threading.Thread whose RUN Python calls on its own thread). */
::requires "python.cls"
::class PyDemo public
::method run
  math = .py~import("math")
  say "sqrt(2):" .py~round(math~sqrt(2), 6)
  words = "pear", "fig", "banana", "kiwi"
  say "sorted by length:" .py~sorted(words, .py~kw("key", .context~package~findRoutine("byLength")))
  .py~exec("def total(acct): return acct.balance() + 10")
  say "Python called a compiled method:" .py~main~total(.Account~new)
  json = .py~import("json")
  d = json~loads('{"y": "two", "x": [1, 2]}')
  say "json:" json~dumps(d, .py~kw("sort_keys", .true)) d["x"][1]
  w = .Worker~new(.py~kw("name", "worker"))
  w~start
  w~join
  say "squares:" .py~list(.py~map(.context~package~findRoutine("square"), (1, 2, 3, 4)))
  return "done"
::routine byLength
  return length(arg(1))
::routine square
  return arg(1) ** 2
::class Account
::method balance
  return 90
::class Worker subclass PyObject
::method activate class
  .py~extend(self, "threading.Thread")
::method run
  say "compiled RUN on a Python thread:" self~name
