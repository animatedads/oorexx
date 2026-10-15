/* Lexical ruleset: quotes, nested Rexx comments, strict supported tokens. */
::class RxLexer public
::method init
  expose source p line col out
  use arg source
  p = 1; line = 1; col = 1
  out = .array~new
::method char
  expose source p
  use arg offset
  if arg(1, 'O') then offset = 0
  posn = p + offset
  if posn < 1 | posn > source~length then return ''
  return source~substr(posn, 1)
::method move
  expose p line col
  c = self~char
  p = p + 1
  if c == '0a'x then do
    line = line + 1; col = 1
  end
  else col = col + 1
  return c
::method emit
  expose out line col
  use arg kind, text, markLine, markCol
  out~append(.RxToken~new(kind, text, markLine, markCol, line, col))
::method fault
  expose line col
  use arg reason
  raise syntax 40.1 array ('rx2cpp:' || line || ':' || col || ': ' || reason)
::method scan
  expose p line col out source
  if self~char == '#' & self~char(1) == '!' then do
    do while self~char \== '' & self~char \= '0a'x
      self~move
    end
  end
  do while p <= source~length
    markLine = line; markCol = col
    c = self~char
    select
      when c == ' ' | c == '09'x | c == '0d'x then self~move
      when c == '0a'x | c == ';' then do
        self~move
        self~emit('SEP', '<sep>', markLine, markCol)
      end
      when c == '-' & self~char(1) == '-' then do
        do while self~char \== '' & self~char \= '0a'x
          self~move
        end
      end
      when c == '/' & self~char(1) == '*' then do
        self~move; self~move
        depth = 1
        do while depth > 0 & self~char \== ''
          if self~char == '/' & self~char(1) == '*' then do
            self~move; self~move; depth = depth + 1
          end
          else if self~char == '*' & self~char(1) == '/' then do
            self~move; self~move; depth = depth - 1
          end
          else self~move
        end
        if depth > 0 then self~fault('unclosed block comment')
      end
      when c == "'" | c == '"' then do
        quote = self~move
        value = ''; raw = ''; closed = .false
        do while self~char \== ''
          ch = self~move
          if ch == '0a'x then self~fault('newline inside quoted string')
          if ch == quote then do
            if self~char == quote then do
              self~move; value = value || quote; raw = raw || quote || quote
            end
            else do
              closed = .true; leave
            end
          end
          else do
            value = value || ch; raw = raw || ch
          end
        end
        if \closed then self~fault('unclosed quoted string')
        /* 'hex'X and 'bits'B are hexadecimal / binary string literals, NOT a string abutted to a variable
           named X or B -- unless the X/B starts a longer symbol ('a'xy). Same test as the ooRexx scanner. */
        suffix = self~char
        if suffix \== '' & pos(suffix, 'xXbB') > 0 & \self~isRexxSymbolChar(self~char(1)) then do
          self~move
          if translate(suffix) == 'X' then value = self~packHex(raw)
          else value = self~packBinary(raw)
        end
        self~emit('STRING', value, markLine, markCol)
      end
      when self~isStart(c) then do
        value = ''
        do while self~isSymbolRest(self~char)
          value = value || self~move
        end
        self~emit('IDENT', value~translate, markLine, markCol)
      end
      /* Decimal numbers are ONE atom, including .5, 1., and 1.2E-3.
         Do not merge a leading symbol's dot into a number. */
      when self~isDigit(c) | (c == '.' & self~isDigit(self~char(1))) then do
        value = ''
        do while self~isDigit(self~char)
          value = value || self~move
        end
        if self~char == '.' then do
          value = value || self~move
          do while self~isDigit(self~char)
            value = value || self~move
          end
        end
        /* LanguageParser::scanSymbol: E starts an exponent only before a digit, or before a sign and a digit; otherwise it
           and any further symbol characters make a constant symbol (1E, 1e-x is 1E - X, 1ABC, 3.X), whose value is its
           name in upper case. */
        signedExponent = .false
        if (self~char == 'E' | self~char == 'e') & pos(self~char(1), '+-') > 0 & self~isDigit(self~char(2)) then do
          /* a signed exponent must end the symbol; a symbol character after its digits (1e-5a) backs the scan up to the
             sign: the symbol is 1E */
          k = 3
          do while self~isDigit(self~char(k)); k = k + 1; end
          signedExponent = \self~isSymbolRest(self~char(k))
          if \signedExponent then do
            self~move
            self~emit('NUMBER', value || 'E', markLine, markCol)
            iterate
          end
        end
        if (self~char == 'E' | self~char == 'e') & (self~isDigit(self~char(1)) | signedExponent) then do
          self~move
          value = value || 'E'
          if self~char == '+' | self~char == '-' then value = value || self~move
          do while self~isDigit(self~char)
            value = value || self~move
          end
        end
        do while self~isSymbolRest(self~char)
          value = value || self~move~translate
        end
        self~emit('NUMBER', value, markLine, markCol)
      end
      /* Recognise augmented assignment as a distinct token before single
         operators. Unsupported combinations are kept intact so diagnostics
         cannot accidentally treat them as different valid instructions. */
      when (c == '/' & self~char(1) == '/' & self~char(2) == '=') | -
           (c == '*' & self~char(1) == '*' & self~char(2) == '=') | -
           (c == '&' & self~char(1) == '&' & self~char(2) == '=') | -
           (c == '|' & self~char(1) == '|' & self~char(2) == '=') then do
        op = self~move || self~move || self~move
        self~emit('OP', op, markLine, markCol)
      end
      when c == '|' & self~char(1) == '|' then do
        self~move; self~move
        self~emit('OP', '||', markLine, markCol)
      end
      when c == '&' & self~char(1) == '&' then do
        self~move; self~move
        self~emit('OP', '&&', markLine, markCol)
      end
      when pos(c, '+-*/%|&') > 0 & self~char(1) == '=' then do
        op = self~move || self~move
        self~emit('OP', op, markLine, markCol)
      end
      when c == '~' & self~char(1) == '~' then do
        self~move; self~move
        self~emit('OP', '~~', markLine, markCol)
      end
      /* Special environment class symbols, initially only .ARRAY. */
      /* ... alone (USE ARG a, ...): one token */
      when c == '.' & self~char(1) == '.' & self~char(2) == '.' & \self~isSymbolRest(self~char(3)) then do
        self~move; self~move; self~move
        self~emit('OP', '...', markLine, markCol)
      end
      /* .. and ... (and .._x): environment symbols whose name starts with a dot; an unknown one is its own name. */
      when c == '.' & self~char(1) == '.' then do
        self~move
        value = ''
        do while self~isSymbolRest(self~char)
          value = value || self~move
        end
        self~emit('DOTIDENT', value~translate, markLine, markCol)
      end
      when c == '.' & self~isStart(self~char(1)) then do
        self~move
        value = ''
        do while self~isSymbolRest(self~char)
          value = value || self~move
        end
        self~emit('DOTIDENT', value~translate, markLine, markCol)
      end
      when c == '[' | c == ']' then do
        self~move
        self~emit('OP', c, markLine, markCol)
      end
      when c == ',' then do
        self~move
        /* A comma that ends a line (blanks and comments aside) continues the clause and is not a token. */
        if \self~continued then self~emit('OP', c, markLine, markCol)
      end
      when c == '~' | c == '.' | c == '|' then do
        self~move
        self~emit('OP', c, markLine, markCol)
      end
      when c == ':' & self~char(1) == ':' then do
        self~move; self~move
        self~emit('OP', '::', markLine, markCol)
      end
      when c == ':' then do
        self~move
        self~emit('OP', ':', markLine, markCol)
      end
      /* Strict comparisons << >> <<= >>= and the negated forms \< \> \<< \>> */
      when (c == '<' | c == '>') & self~char(1) == c then do
        op = self~move || self~move
        if self~char == '=' then op = op || self~move
        self~emit('OP', op, markLine, markCol)
      end
      when c == '\' & (self~char(1) == '<' | self~char(1) == '>') then do
        op = self~move || self~move
        if self~char == right(op, 1) then op = op || self~move
        self~emit('OP', op, markLine, markCol)
      end
      when c == '\' & self~char(1) == '=' then do
        self~move; self~move
        op = '\='
        if self~char == '=' then do
          self~move; op = '\=='
        end
        self~emit('OP', op, markLine, markCol)
      end
      /* Other .Object/.String inequality aliases, distinct selectors. */
      when (c == '<' & self~char(1) == '>') | (c == '>' & self~char(1) == '<') then do
        op = self~move || self~move
        self~emit('OP', op, markLine, markCol)
      end
      when c == '=' & self~char(1) == '=' then do
        self~move; self~move
        self~emit('OP', '==', markLine, markCol)
      end
      when (c == '<' | c == '>') & self~char(1) == '=' then do
        op = self~move || self~move
        self~emit('OP', op, markLine, markCol)
      end
      when (c == '/' & self~char(1) == '/') | (c == '*' & self~char(1) == '*') then do
        op = self~move || self~move
        self~emit('OP', op, markLine, markCol)
      end
      when c == '-' & self~continuedAfterMove then nop
      when pos(c, '+-*/%=<>()&\') > 0 then do
        self~move
        self~emit('OP', c, markLine, markCol)
      end
      /* The interpreter's Scanner also takes 'AA'x and 'AC'x (code page not signs) as the backslash: \ \= \== \< \<< \> \>> */
      when c == 'aa'x | c == 'ac'x then do
        self~move
        op = '\'
        if self~char == '=' then do
          op = op || self~move
          if self~char == '=' then op = op || self~move
        end
        else if self~char == '<' | self~char == '>' then do
          d = self~move
          op = op || d
          if self~char == d then op = op || self~move
        end
        self~emit('OP', op, markLine, markCol)
      end
      otherwise self~fault("unsupported source character '" || c || "'")
    end
  end
  self~emit('EOF', '<eof>', line, col)
  out = self~joinOperators(out)
  /* LOOP is DO's synonym when it starts a clause (a lone LOOP loops forever); elsewhere it is an ordinary symbol. */
  fixed = .array~new
  do i = 1 to out~items
    tok = out[i]
    if tok~kind == 'IDENT' & tok~text == 'LOOP' then do
      atStart = (i == 1)
      if \atStart then do
        prev = out[i - 1]
        atStart = prev~kind == 'SEP' | (prev~kind == 'IDENT' & wordpos(prev~text, 'THEN ELSE OTHERWISE') > 0)
      end
      following = out[i + 1]
      isVariable = following~kind == 'OP' & pos(following~text, '=~(,)') > 0
      if following~kind == 'STRING' | following~kind == 'EOF' & .false then isVariable = isVariable
      if atStart & \isVariable then do
        /* DO followed by the marker <LOOP> (no source text produces it): the DO rule treats a LOOP with no repetitor
           and no conditional as LOOP FOREVER; everything else is as DO. */
        fixed~append(.RxToken~new('IDENT', 'DO', tok~line, tok~col, tok~endLine, tok~endCol))
        fixed~append(.RxToken~new('IDENT', '<LOOP>', tok~line, tok~col, tok~endLine, tok~endCol))
        iterate
      end
    end
    fixed~append(tok)
  end
  return fixed
/* The characters of an operator may be separated by blanks and comments on the same line (`1 < /**/ > 2` is <>,
   `'' |  | 'x'` is ||, `x + = 1` is +=): the interpreter's Scanner continues an operator with nextSpecial(), which skips
   them. Consecutive operator tokens join when the result is an operator that Scanner builds that way. */
::method joinOperators private
  use arg tokens
  joined = '::  ~~  //  **  &&  ||  ==  <<  <<= <=  <>  >>  >>= >=  ><  \=  \== \>  \>> \<  \<< ' || -
           '+=  -=  %=  /=  //= *=  **= &=  &&= |=  ||='
  merged = .array~new
  do i = 1 to tokens~items
    tok = tokens[i]
    if tok~kind == 'OP' & merged~items > 0 then do
      prev = merged[merged~items]
      if prev~kind == 'OP' & prev~endLine == tok~line & wordpos(prev~text || tok~text, joined) > 0 then do
        merged[merged~items] = .RxToken~new('OP', prev~text || tok~text, prev~line, prev~col, tok~endLine, tok~endCol)
        iterate
      end
    end
    merged~append(tok)
  end
  return merged
/* After a , or - has been consumed: if only blanks/comments remain before the newline , swallow them and
   the newline and answer true (line continuation); otherwise leave the position untouched and answer false. */
::method continued
  expose p line col
  sp = p; sl = line; sc = col
  do forever
    c = self~char
    if c == ' ' | c == '09'x | c == '0d'x then self~move
    else if c == '-' & self~char(1) == '-' then do
      do while self~char \== '' & self~char \= '0a'x
        self~move
      end
    end
    else if c == '/' & self~char(1) == '*' then do
      self~move; self~move
      depth = 1
      do while depth > 0 & self~char \== ''
        if self~char == '/' & self~char(1) == '*' then do
          self~move; self~move; depth = depth + 1
        end
        else if self~char == '*' & self~char(1) == '/' then do
          self~move; self~move; depth = depth - 1
        end
        else self~move
      end
    end
    else leave
  end
  if self~char == '0a'x then do
    self~move
    return .true
  end
  p = sp; line = sl; col = sc
  return .false
/* A lone - is consumed here only when it ends a line (continuation); returns false and consumes nothing otherwise. */
::method continuedAfterMove
  expose p line col
  sp = p; sl = line; sc = col
  if self~char \== '-' then return .false
  self~move
  if self~continued then return .true
  p = sp; line = sl; col = sc
  return .false
/* Characters that can continue a Rexx symbol (decides whether 'x' after a quote is a hex-literal marker). */
::method isRexxSymbolChar private
  use arg c
  return c \== '' & verify(c, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._!?$@#') = 0
::method badLiteral private
  use arg subcode, text
  self~fault('Invalid hexadecimal or binary string (15.' || subcode || '): ' || text)
/* 'hex'X: the same checks and packing as the ooRexx interpreter's LanguageParser::packHexLiteral. */
::method packHex private
  use arg raw
  len = raw~length
  if len == 0 then return ''
  groupCount = 0; nibbles = 0
  do i = len to 1 by -1
    c = raw~substr(i, 1)
    if c == ' ' | c == '09'x then do
      if i == 1 | i == len then self~badLiteral(1, 'Incorrect location of whitespace character in position' i 'in hexadecimal string.')
      else if groupCount // 2 \= 0 then self~badLiteral(5, 'Hexadecimal strings must be grouped in units that are multiples of two characters.')
      groupCount = 0
    end
    else do
      groupCount = groupCount + 1; nibbles = nibbles + 1
    end
  end
  nibbleStart = nibbles // 2
  chars = nibbles % 2 + nibbleStart
  out = ''; p = 1
  do n = 1 to chars
    byte = 0
    do while raw~substr(p, 1) == ' ' | raw~substr(p, 1) == '09'x
      p = p + 1
    end
    do k = nibbleStart to 1
      nib = raw~substr(p, 1); p = p + 1
      if nib == '' | pos(nib, '0123456789abcdefABCDEF') == 0 then -
        self~badLiteral(3, 'Only 0-9, a-f, A-F, and whitespace characters are valid in a hexadecimal string; found "' || nib || '".')
      byte = byte * 16 + x2d(nib)
    end
    nibbleStart = 0
    out = out || d2c(byte)
  end
  return out
/* 'bits'B: the same checks and packing as LanguageParser::packBinaryLiteral. */
::method packBinary private
  use arg raw
  len = raw~length
  if len == 0 then return ''
  groupCount = 0; bits = 0
  do i = len to 1 by -1
    c = raw~substr(i, 1)
    if c == ' ' | c == '09'x then do
      if i == 1 | i == len then self~badLiteral(2, 'Incorrect location of whitespace character in position' i 'in binary string.')
      else if groupCount // 4 \= 0 then self~badLiteral(6, 'Binary strings must be grouped in units that are multiples of four characters.')
      groupCount = 0
    end
    else do
      groupCount = groupCount + 1; bits = bits + 1
    end
  end
  byteSize = bits // 8
  chars = bits % 8 + (byteSize \= 0)
  if byteSize == 0 then byteSize = 8
  out = ''; p = 1
  do n = 1 to chars
    byte = 0
    do k = 1 to byteSize
      bit = raw~substr(p, 1); p = p + 1
      do while bit == ' ' | bit == '09'x
        bit = raw~substr(p, 1); p = p + 1
      end
      byte = byte * 2
      if bit == '1' then byte = byte + 1
      else if bit \== '0' then self~badLiteral(4, 'Only 0, 1, and whitespace characters are valid in a binary string; found "' || bit || '".')
    end
    byteSize = 8
    out = out || d2c(byte)
  end
  return out
::method isStart private
  use arg c
  return c \== '' & pos(c, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_!?') > 0
::method isRest private
  use arg c
  return self~isStart(c) | self~isDigit(c)
/* The dot belongs to a compound symbol only AFTER the name has begun.
   Leading-dot environment symbols and decimal numerics remain unsupported. */
::method isSymbolRest private
  use arg c
  return self~isRest(c) | c == '.'
::method isDigit private
  use arg c
  return c \== '' & pos(c, '0123456789') > 0
::requires 'core/RxToken.cls'
