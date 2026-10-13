/* X2C / X2B / X2D / B2X with blanks, tabs, odd groups and invalid characters, as BIFs and as String methods. */
::class X public
::method init
::method run
  cases = .array~of('4142', '41 42', ' 4142', '4142 ', '41' || '09'x || '42', '', 'a', '141', '41  42', '4 142', 'GG', '41' || '0a'x || '42', '41' || '0d'x)
  do c over cases
    say c2x(c) '->' self~try(c)
  end
::method try
  use arg c
  signal on syntax
  return c2x(x2c(c))
syntax:
  return 'error' condition('O')~code
::method methods
  cases = .array~of('4142', '41 42', ' 4142', 'GG', '1 01', '10101', '1x')
  do c over cases
    say c2x(c) 'm->' self~tryM(c)
  end
::method tryM
  use arg c
  signal on syntax
  return c~x2c~c2x c~x2b c~x2d c~b2x
syntax:
  return 'error' condition('O')~code
