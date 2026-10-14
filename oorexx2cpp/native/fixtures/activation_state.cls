/* Built-in state kept per activation, as interpreted: RANDOM seeds and the stream table (LINEIN/LINES/STREAM). */
::class ActivationState public
::method seeded
  r = random(1, 100, 42)
  do 6; r = r random(1, 100); end
  r = r '|' random(, , 7) random() random(5) random(3, , 9) random(,)
  return r '|' self~helper '|' seededRoutine()
::method helper
  return random(0, 999999999, 12345) random(0, 999999999)
::method firstLine
  use arg file
  return linein(file) lines(file) lines(file, 'C') lines(file, 'N')
::method streams
  use arg file
  r = stream(file, 'C', 'QUERY EXISTS') \== ''
  r = r stream(file, 'S') charin(file, 1, 3) chars(file) > 0
  r = r stream(file, 'C', 'CLOSE') stream(file, 'S')
  call lineout file || '.out', 'written'
  call lineout file || '.out'
  return r linein(file || '.out')
::method badLines
  return lines('', 'X')
::method notReady
  use arg file
  signal on notready name eof
  n = 0
  do forever
    l = linein(file)
    n = n + 1
  end
eof:
  return n condition('C') condition('I') (condition('D') \== '') condition('S') stream(file, 'S')
::method untrapped
  use arg file
  r = charin(file, 1, 2)
  do 5; r = r '['linein(file)']'; end
  return r stream(file, 'S')
::method anyTrap
  use arg file
  signal on any
  do forever; x = linein(file); end
any:
  return condition('C')
::method sourceKinds
  call whereFrom
  r = result
  parse source m1 m2 m3
  return r '|' whereFrom() '|' m1 m2 (m3 \== '')
::method sourceLines
  signal on syntax
  r = sourceline() '['sourceline(1)']' '['sourceline(3)']' '['sourceRoutine()']'
  r = r sourceline(sourceline() + 1)
syntax:
  return r condition('O')~code
::routine sourceRoutine
  return sourceline(2)
::routine whereFrom
  parse source system kind file
  return system kind (file \== '')
::routine seededRoutine
  return random(1, 6, 99) random(1, 6)
