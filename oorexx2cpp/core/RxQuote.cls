/* Convert byte strings to literal-safe C++ ASCII, never use host code evaluation. */
::class RxQuote public
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
