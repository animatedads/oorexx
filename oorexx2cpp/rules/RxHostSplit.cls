/* Hosted tier: split a program into its natively compiled main section and the directive section (everything from
   the first :: directive on) that the embedded interpreter runs as one package. Line based, so it also works for
   directive sections the lexer cannot tokenize. Block comments (nestable) and quoted strings are skipped. */
::class RxHostSplit public
/* 1-based line number of the first directive, or 0 when the program has none. */
::method firstDirectiveLine class
  use arg source
  nl = '0a'x
  depth = 0
  line = 0
  rest = source
  do while rest \== ''
    parse var rest text (nl) rest
    line = line + 1
    text = text~strip('T', '0d'x)
    pos = 1
    atStart = .true
    do while pos <= length(text)
      ch = substr(text, pos, 1)
      two = substr(text, pos, 2)
      if depth > 0 then do
        if two == '*/' then do; depth = depth - 1; pos = pos + 2; end
        else if two == '/*' then do; depth = depth + 1; pos = pos + 2; end
        else pos = pos + 1
        iterate
      end
      if two == '/*' then do; depth = depth + 1; pos = pos + 2; atStart = .false; iterate; end
      if two == '--' then leave
      if ch == '"' | ch == "'" then do
        q = ch
        pos = pos + 1
        do while pos <= length(text) & substr(text, pos, 1) \== q
          pos = pos + 1
        end
        pos = pos + 1
        atStart = .false
        iterate
      end
      if ch == ' ' | ch == '09'x then do; pos = pos + 1; iterate; end
      if atStart & two == '::' then return line
      atStart = .false
      pos = pos + 1
    end
  end
  return 0
/* Returns array(mainSource, unitSource); the unit is padded with blank lines so interpreter diagnostics keep the
   original line numbers. */
::method split class
  use arg source, firstLine
  nl = '0a'x
  mainPart = ''
  unitPart = copies(nl, firstLine - 1)
  rest = source
  line = 0
  do while rest \== ''
    parse var rest text (nl) rest
    line = line + 1
    if line < firstLine then mainPart = mainPart || text || nl
    else unitPart = unitPart || text || nl
  end
  return .array~of(mainPart, unitPart)
/* Names of the ::ROUTINE directives in the unit (upper case, simple symbols only). */
::method routineNames class
  use arg unit
  names = .directory~new
  nl = '0a'x
  rest = unit
  do while rest \== ''
    parse var rest text (nl) rest
    text = strip(text, 'T', '0d'x)
    if translate(word(text, 1)) == '::ROUTINE' then do
      name = word(text, 2)
      if name \== '' & verify(name, "'" || '"') > 0 & pos(name~left(1), "'" || '"') = 0 then names[translate(name)] = .true
    end
  end
  return names
