/* One package may contain several independent ::CLASS definitions.
   Package-level ::OPTIONS declarations are parsed separately and erased
   from class sections; other unsupported package directives fail closed.
   We use the Rexx lexer to find declarations so quoted text and block
   comments cannot accidentally be treated as class boundaries. */
::class RxNativePackageParser public
::attribute options get
::method parse
  expose options
  use arg source
  options = .RxNativePackageOptions~new~parse(source)
  tokens = .RxLexer~new(source)~scan
  positions = .array~new
  optionsLines = .directory~new
  previous = 'SEP'
  do i = 1 to tokens~items
    tok = tokens[i]
    if tok~kind == 'EOF' then leave
    if tok~text == '::' & previous == 'SEP' then do
      if i + 1 > tokens~items then self~reject(tok~line, 'incomplete directive')
      directive = tokens[i+1]~text
      if directive == 'CLASS' then positions~append(tok~line)
      else if directive == 'OPTIONS' then do
        /* Removing a physical line must not discard a neighbouring directive
           after a semicolon, or a continued token stream. Fail closed. */
        if optionsLines~hasIndex(tok~line) then
          self~reject(tok~line, 'multiple ::OPTIONS on one line unsupported')
        j = i + 2
        do while j <= tokens~items & tokens[j]~kind \= 'SEP' & tokens[j]~kind \= 'EOF'
          if tokens[j]~line \= tok~line then
            self~reject(tok~line, 'continued ::OPTIONS directive unsupported')
          j += 1
        end
        do k = 1 to tokens~items
          if tokens[k]~line == tok~line & tokens[k]~kind \= 'SEP' then do
            if k < i | k >= j then
              self~reject(tok~line, '::OPTIONS must occupy its own line')
          end
        end
        optionsLines[tok~line] = .true
      end
      else if directive \= 'METHOD' & directive \= 'ATTRIBUTE' & directive \= 'CONSTANT' then self~reject(tok~line, 'unsupported directive ' || directive)
    end
    if tok~kind == 'SEP' then previous = 'SEP'
    else previous = 'OTHER'
  end
  if positions~items == 0 then self~reject(1, 'package contains no ::CLASS')
  lines = source~makeArray('0a'x)
  first = positions[1]
  /* Source before the first class must contain comments and whitespace only. */
  prefix = ''
  do j = 1 to first - 1
    prefix = prefix || lines[j] || '0a'x
  end
  if prefix \== '' then do
    pre = .RxLexer~new(prefix)~scan
    j = 1
    do while j <= pre~items
      token = pre[j]
      if token~kind == 'EOF' then leave
      if token~kind == 'SEP' then do
        j += 1
        iterate
      end
      if token~text == '::' & j + 1 <= pre~items & pre[j+1]~text == 'OPTIONS' then do
        if \options~present then self~reject(token~line, 'unvalidated ::OPTIONS')
        j += 2
        do while j <= pre~items & pre[j]~kind \= 'SEP' & pre[j]~kind \= 'EOF'
          j += 1
        end
        iterate
      end
      self~reject(token~line, 'top-level executable code is unsupported')
    end
  end
  units = .array~new
  names = .directory~new
  roots = .directory~new
  definitions = .directory~new
  scopes = .directory~new
  graphRules = .RxNativeInheritanceRules~new
  do i = 1 to positions~items
    start = positions[i]
    if i < positions~items then finish = positions[i+1] - 1
    else finish = lines~items
    section = ''
    do j = start to finish
      /* ooRexx package options do not belong to any individual class.
         Retain an empty line to preserve source-location diagnostics. */
      if optionsLines~hasIndex(j) then section = section || '0a'x
      else section = section || lines[j] || '0a'x
    end
    unit = .RxHybridCompiler~new(section, .true)~parse
    name = unit~className
    if names~hasIndex(name) then self~reject(start, 'duplicate class ' || name)
    /* A superclass must already exist in this same native package.
       Requiring parent-first order makes the class scope graph unambiguous. */
    if unit~parentName \== '' then do
      if \names~hasIndex(unit~parentName) then
        self~reject(start, 'unknown or forward parent ' || unit~parentName)
      if unit~methods~items == 0 then
        self~reject(start, 'subclass with no native methods')
      do m over unit~methods
        if m~selector == 'INIT' then
          self~reject(start, 'subclass INIT requires explicit SUPER dispatch (not implemented)')
      end
    end
    graphRules~validate(unit, names, definitions, roots, scopes)
    names[name] = .true
    definitions[name] = unit
    if unit~parentName == '' then roots[name] = name
    else roots[name] = roots[unit~parentName]
    units~append(unit)
  end
  return units
::method reject private
  use arg lineNo, reason
  raise syntax 40.1 array('rx2cpp: native package line ' || lineNo || ': ' || reason)
::requires 'core/RxLexer.cls'
::requires 'hybrid/compiler/RxHybridCompiler.cls'
::requires 'native/NativeInheritanceRules.cls'

::requires 'native/NativePackageOptions.cls'
