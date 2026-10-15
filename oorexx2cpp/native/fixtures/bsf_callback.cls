/* Java calling back into compiled Rexx (BsfCreateRexxProxy): compiled objects as a java.util.Comparator (Java's sort
   calls COMPARE) and as a java.lang.Runnable (RUN called by a Java thread, and through the Java interface). */
::requires "BSF.CLS"
::class CallbackDemo public
::method run
  list = .bsf~new("java.util.ArrayList")
  do w over .array~of("pear", "fig", "banana", "kiwi", "apple", "date")
    list~add(w)
  end
  byLength = .ByLength~new
  cmp = BsfCreateRexxProxy(byLength, , "java.util.Comparator")
  bsf.loadClass("java.util.Collections")~sort(list, cmp)
  say "sorted by length:" list~toString "(compare called:" byLength~calls || ")"
  counter = .Counter~new
  r = BsfCreateRexxProxy(counter, , "java.lang.Runnable")
  t = .bsf~new("java.lang.Thread", r)
  t~bsf.invoke("start")      -- (START alone is Object~start, the Rexx concurrency method)
  t~join
  say "after Java thread:" counter~runs
  r~bsf.invoke("run")        -- (RUN alone is Object~run)
  say "after r~run through Java:" counter~runs
  return "done"
::class ByLength public
::method init
  expose calls
  calls = 0
::method compare
  expose calls
  use arg a, b
  calls += 1
  if a~length < b~length then return -1
  if a~length > b~length then return 1
  if a << b then return -1
  if a == b then return 0
  return 1
::method calls
  expose calls
  return calls
::class Counter public
::method init
  expose runs
  runs = 0
::method run
  expose runs
  runs += 1
  say "RUN called from Java, run" runs
::method runs
  expose runs
  return runs
