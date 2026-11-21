/* The qualified native-package subset of ooRexx ::OPTIONS.
 * ooRexx Reference 5.0, section 3.6 (printed pages 100-102): options
 * accumulate in source order, including duplicates and successive directives.
 * Numeric DIGITS/FUZZ/FORM, no-code PROLOG/NOPROLOG, TRACE OFF, and the
 * condition policies NOVALUE / ERROR / FAILURE / LOSTDIGITS / NOSTRING /
 * NOTREADY / ALL SYNTAX | CONDITION (NOVALUE ERROR: SYNTAX, as the
 * interpreter accepts it) are admitted; other tracing modes fail closed.
 * syntax: the conditions raised as SYNTAX errors, as the bits of
 * rx::ActivationScope::SyntaxOption (ERROR 1, FAILURE 2, LOSTDIGITS 4,
 * NOSTRING 8, NOTREADY 16, NOVALUE 32).
 * The class parser removes each verified, stand-alone ::OPTIONS directive
 * from its class sections after numeric defaults have been collected.
 * The class method activation receives these defaults independently of the
 * invoking program. This parser never evaluates numeric expressions.
 */
::class RxNativePackageOptions public
::attribute digits get
::attribute fuzz get
::attribute form get
::attribute present get
::attribute prolog get
::attribute trace get
::attribute syntax get
::method init
  expose digits fuzz form present prolog trace syntax conditions
  syntax = 0
  conditions = .false
  digits = 9
  fuzz = 0
  form = 'SCIENTIFIC'
  present = .false
  prolog = 'PROLOG'
  trace = 'OFF'
::method parse
  expose digits fuzz form present prolog trace syntax conditions
  use arg source
  tokens = .RxLexer~new(source)~scan
  previous = 'SEP'
  do i = 1 to tokens~items
    token = tokens[i]
    if token~kind == 'EOF' then leave
    if token~text == '::' & previous == 'SEP' then do
      if i + 1 > tokens~items then self~reject(token~line, 'missing directive name')
      name = tokens[i+1]~text
      if name == 'OPTIONS' then do
        present = .true
        seenAny = .false
        j = i + 2
        do while j <= tokens~items & tokens[j]~kind \= 'SEP' & tokens[j]~kind \= 'EOF'
          name = tokens[j]~text
          select
            when name == 'DIGITS' | name == 'FUZZ' then do
              if j + 1 > tokens~items then self~reject(token~line, name || ' requires a whole-number literal')
              number = tokens[j+1]
              if number~kind \= 'NUMBER' | verify(number~text, '0123456789') > 0 then
                self~reject(number~line, name || ' needs an unsigned whole-number literal')
              if number~text~length > 6 then self~reject(number~line, name || ' exceeds supported limit')
              n = number~text + 0
              if name == 'DIGITS' then digits = n
              else fuzz = n
              j += 2
            end
            when name == 'PROLOG' | name == 'NOPROLOG' then do
              /* Native package sources never contain main/prolog executable
                 code. Preserve interpreter metadata, but do not pretend that
                 an executable prolog has been compiled into the .so. */
              prolog = name
              j += 1
            end
            when name == 'TRACE' then do
              if j + 1 > tokens~items then self~reject(token~line, 'TRACE needs a setting')
              value = tokens[j+1]~text
              /* Compiled C++ method bodies have no Rexx instruction tracing.
                 Only OFF is equivalent to the native execution semantics. */
              if value \= 'OFF' & value \= 'O' then
                self~reject(tokens[j+1]~line, 'native TRACE currently supports only OFF')
              trace = 'OFF'
              j += 2
            end
            when name == 'FORM' then do
              if j + 1 > tokens~items then self~reject(token~line, 'FORM needs SCIENTIFIC or ENGINEERING')
              value = tokens[j+1]~text
              if value \= 'SCIENTIFIC' & value \= 'ENGINEERING' then
                self~reject(tokens[j+1]~line, 'unsupported FORM value ' || value)
              form = value
              j += 2
            end
            when wordpos(name, 'NOVALUE ERROR FAILURE LOSTDIGITS NOSTRING NOTREADY ALL') > 0 then do
              if j + 1 > tokens~items then self~reject(token~line, name || ' needs SYNTAX or CONDITION')
              value = tokens[j+1]~text
              if tokens[j+1]~kind \= 'IDENT' then self~reject(tokens[j+1]~line, 'Symbol expected after' name 'keyword (Error 20.904)')
              allowed = 'SYNTAX CONDITION'
              if name == 'NOVALUE' then allowed = 'SYNTAX CONDITION ERROR'
              if wordpos(value, allowed) = 0 then
                self~reject(tokens[j+1]~line, 'Unknown keyword on' name 'option; found "' || value || '" (Error 25.926)')
              bits = 63
              if name \== 'ALL' then bits = 2 ** (wordpos(name, 'ERROR FAILURE LOSTDIGITS NOSTRING NOTREADY NOVALUE') - 1)
              if value == 'CONDITION' then syntax = .RxNativePackageOptions~clearBits(syntax, bits)
              else syntax = .RxNativePackageOptions~setBits(syntax, bits)
              conditions = .true
              j += 2
            end
            otherwise self~reject(tokens[j]~line, 'unsupported ::OPTIONS clause ' || name)
          end
          seenAny = .true
        end
        if \seenAny then self~reject(token~line, 'empty ::OPTIONS declaration')
        i = j - 1
      end
    end
    if token~kind == 'SEP' then previous = 'SEP'
    else previous = 'OTHER'
  end
  if digits < 1 | digits > 100000 then self~reject(1, 'DIGITS outside supported 1..100000')
  if fuzz < 0 | fuzz >= digits then self~reject(1, 'FUZZ must be less than DIGITS')
  return self
::method directive
  expose digits fuzz form present prolog trace syntax conditions
  if \present then return ''
  /* the interpreter's package has the same condition policies, for its interpreted code */
  policy = ''
  if conditions then do
    names = 'ERROR FAILURE LOSTDIGITS NOSTRING NOTREADY NOVALUE'
    do k = 1 to words(names)
      if .RxNativePackageOptions~hasBit(syntax, 2 ** (k - 1)) then policy = policy word(names, k) 'syntax'
      else policy = policy word(names, k) 'condition'
    end
  end
  return '::options digits ' || digits || ' fuzz ' || fuzz || ' form ' || form || ' ' || prolog || ' trace ' || trace || policy
::method hasBit class
  use arg bits, bit
  return (bits % bit) // 2 = 1
::method setBits class
  use arg bits, mask
  r = 0
  do b = 0 to 5
    if self~hasBit(bits, 2 ** b) | self~hasBit(mask, 2 ** b) then r += 2 ** b
  end
  return r
::method clearBits class
  use arg bits, mask
  r = 0
  do b = 0 to 5
    if self~hasBit(bits, 2 ** b) & \self~hasBit(mask, 2 ** b) then r += 2 ** b
  end
  return r
::method reject private
  use arg line, reason
  raise syntax 40.1 array('rx2cpp: native ::OPTIONS line ' || line || ': ' || reason)
::requires 'core/RxLexer.cls'
