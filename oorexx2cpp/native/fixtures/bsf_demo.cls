/* BSF4ooRexx from compiled code: Java classes loaded, objects made, methods called, results back in Rexx. */
::requires "BSF.CLS"
::class BsfDemo public
::method run
  system = bsf.loadClass("java.lang.System")
  system~out~println("Hello from compiled ooRexx, via java.lang.System.out")
  sb = .bsf~new("java.lang.StringBuilder", "rx2cpp")
  sb~append(" -> BSF4ooRexx")~append(" -> Java")
  system~out~println(sb~toString)
  say "StringBuilder length:" sb~length
  list = .bsf~new("java.util.ArrayList")
  do i = 1 to 3
    list~add("item" i)
  end
  say "ArrayList:" list~toString "size" list~size
  say "java.version present:" (system~getProperty("java.version") \== .nil)
  return "done"
