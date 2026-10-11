/* ::OPTIONS directive (ooRexx reference 3.6): package-wide initial NUMERIC settings.
   Implemented: DIGITS n, FUZZ n, FORM SCIENTIFIC|ENGINEERING, PROLOG/NOPROLOG (no effect on a
   program that cannot be required).  Options accumulate across directives in source order; the
   last value wins; DIGITS must exceed FUZZ after every directive (interpreter Error 33.1).
   Not implemented, fail closed: TRACE, ALL, ERROR, FAILURE, LOSTDIGITS, NOSTRING, NOTREADY, NOVALUE.
   Invalid values are reported at compile time with a source location (the interpreter raises
   Error 26.5 / 25.11 / 19.917 / 33.1 while loading the program, before any output). */
::class RxOptionsRules public
::method discover class
  use arg stream
  tokens = stream~tokens
  digits = 9
  fuzz = 0
  form = 'SCIENTIFIC'
  prologEnabled = .true
  used = .false
  i = 1
  do while i <= tokens~items
    if tokens[i]~kind \= 'OP' | tokens[i]~text \= '::' | i + 1 > tokens~items then do
      i = i + 1
      iterate
    end
    if tokens[i + 1]~kind \= 'IDENT' | tokens[i + 1]~text \= 'OPTIONS' then do
      i = i + 1
      iterate
    end
    used = .true
    i = i + 2
    do while i <= tokens~items & tokens[i]~kind \= 'SEP' & tokens[i]~kind \= 'EOF'
      word = tokens[i]~text
      if tokens[i]~kind \= 'IDENT' then do
        stream~position(i)
        stream~fail('::OPTIONS expects a keyword (Error 25)')
      end
      select
        when word == 'DIGITS' then do
          digits = self~wholeValue(stream, tokens, i + 1, 'DIGITS', 1)
          i = i + 2
        end
        when word == 'FUZZ' then do
          fuzz = self~wholeValue(stream, tokens, i + 1, 'FUZZ', 0)
          i = i + 2
        end
        when word == 'FORM' then do
          if i + 1 > tokens~items then f = ''
          else f = tokens[i + 1]
          if f == '' then do
            stream~position(i)
            stream~fail('::OPTIONS FORM needs SCIENTIFIC or ENGINEERING (Error 25.11)')
          end
          if f~kind \= 'IDENT' | (f~text \= 'SCIENTIFIC' & f~text \= 'ENGINEERING') then do
            stream~position(i + 1)
            stream~fail('::OPTIONS FORM must be followed by the symbol SCIENTIFIC or ENGINEERING (Error 25.11)')
          end
          form = f~text
          i = i + 2
        end
        when word == 'PROLOG' | word == 'NOPROLOG' then do
          prologEnabled = word == 'PROLOG'
          i = i + 1
        end
        otherwise do
          stream~position(i)
          stream~fail('::OPTIONS ' || word || ' is not implemented')
        end
      end
    end
    if digits <= fuzz then do
      stream~position(i)
      stream~fail('Value of NUMERIC DIGITS (' || digits || ') must exceed value of NUMERIC FUZZ (' || fuzz || ') (Error 33.1)')
    end
  end
  stream~position(1)
  opts = .directory~new
  opts~put(digits, 'DIGITS')
  opts~put(fuzz, 'FUZZ')
  opts~put(form, 'FORM')
  opts~put(used, 'USED')
  opts~put(prologEnabled, 'PROLOG')
  return opts
/* A symbol or string holding a whole number (1E2 is 100); sign tokens are rejected like the interpreter. */
::method wholeValue class
  use arg stream, tokens, index, name, minimum
  if index > tokens~items then t = .nil
  else t = tokens[index]
  if t == .nil | (t~kind \= 'NUMBER' & t~kind \= 'IDENT' & t~kind \= 'STRING') then do
    stream~position(min(index, tokens~items))
    stream~fail('String or symbol expected as ' || name || ' value (Error 19.917)')
  end
  raw = t~text
  if datatype(raw, 'W') == 0 then do
    stream~position(index)
    stream~fail(name || ' value must be a whole number; found "' || raw || '" (Error 26.5)')
  end
  value = raw + 0
  if value < minimum then do
    stream~position(index)
    if minimum == 1 then kindText = 'a positive'
    else kindText = 'a non-negative'
    stream~fail(name || ' value must be ' || kindText || ' whole number; found "' || raw || '" (Error 26.5)')
  end
  if value > 999999999 then do
    stream~position(index)
    stream~fail(name || ' value is too large for this implementation')
  end
  return value
