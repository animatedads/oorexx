/* The numeric subset of ooRexx package ::OPTIONS.
 * ooRexx Reference 5.0, section 3.6 (printed pages 100-102): options
 * accumulate in source order, including duplicates and successive directives.
 * This native backend currently admits the subset DIGITS, FUZZ, FORM only.
 * Runtime conditions, TRACE, and PROLOG must fail closed until supported.
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
::method init
  expose digits fuzz form present
  digits = 9
  fuzz = 0
  form = 'SCIENTIFIC'
  present = .false
::method parse
  expose digits fuzz form present
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
            when name == 'FORM' then do
              if j + 1 > tokens~items then self~reject(token~line, 'FORM needs SCIENTIFIC or ENGINEERING')
              value = tokens[j+1]~text
              if value \= 'SCIENTIFIC' & value \= 'ENGINEERING' then
                self~reject(tokens[j+1]~line, 'unsupported FORM value ' || value)
              form = value
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
  expose digits fuzz form present
  if \present then return ''
  return '::options digits ' || digits || ' fuzz ' || fuzz || ' form ' || form
::method reject private
  use arg line, reason
  raise syntax 40.1 array('rx2cpp: native ::OPTIONS line ' || line || ': ' || reason)
::requires 'core/RxLexer.cls'
