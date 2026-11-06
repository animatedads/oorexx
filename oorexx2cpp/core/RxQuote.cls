/* Convert byte strings to literal-safe C++ ASCII, never use host code evaluation. */
::class RxQuote public
/* A C++ identifier part for any Rexx name: letters, digits and _ unchanged, every other byte as _HH (hex). A class
   id may be any string in ooRexx (::class "LENGTH.testGroup"); only the C++ names are mangled, never the Rexx name. */
::method identifier class
  use arg value
  answer = ''
  do i = 1 to value~length
    c = value~substr(i, 1)
    if verify(c, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_') == 0 then answer = answer || c
    else answer = answer || '_' || c2x(c)
  end
  return answer
::method cpp class
  use arg value
  answer = '"'
  do i = 1 to value~length
    c = value~substr(i, 1)
    byte = x2d(c2x(c))
    select
      when c == '"' then answer = answer || '\"'
      when c == '\' then answer = answer || '\\'
      when byte = 10 then answer = answer || '\n'
      when byte = 13 then answer = answer || '\r'
      when byte = 9 then answer = answer || '\t'
      when byte >= 32 & byte <= 126 then answer = answer || c
      otherwise do
        first = byte % 64
        second = (byte // 64) % 8
        third = byte // 8
        answer = answer || '\' || first || second || third
      end
    end
  end
  if pos('00'x, value) > 0 then return 'std::string(' || answer || '"' || ', ' || value~length || ')'
  return answer || '"'
/* The string of a ::ROUTINE ... EXTERNAL directive line ('LIBRARY rxmath RxCalcSqrt'), '' when it has none. */
::class RxExternalSpec public
::method of class
  use strict arg decl
  at = decl~upper~pos(' EXTERNAL ')
  if at = 0 then return ''
  spec = decl~substr(at + 10)~strip
  q = spec~left(1)
  if q \== '"' & q \== "'" then return ''
  spec = spec~substr(2)
  return spec~left(max(0, spec~pos(q) - 1))
