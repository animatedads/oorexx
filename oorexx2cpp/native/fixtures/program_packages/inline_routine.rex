/* a routine whose body follows its directive on the same line (Josep Maria Blasco, case 1) */
say twice(21) three() empty()
::routine twice public; return arg(1) * 2
::routine three; x = 3
  return x
::routine empty public;
  return 'e'
