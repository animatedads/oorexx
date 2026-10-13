/* One package may contain several independent ::CLASS definitions.
   Package-level ::OPTIONS declarations are parsed separately and erased
   from class sections; other unsupported package directives fail closed.
   We use the Rexx lexer to find declarations so quoted text and block
   comments cannot accidentally be treated as class boundaries. */
::class RxNativePackageParser public
::attribute options get
/* Executable code before the first ::CLASS (the package prolog): run by the interpreter when the library loads. */
::attribute prolog get
/* Interpreted table results: whole classes (source text, unchanged) and single methods per class (directory). */
::attribute interpretedSource get
::attribute interpretedMethods get
::attribute interpretedPublic get
::attribute inputName
::method parse
  expose options prolog interpretedSource interpretedMethods interpretedPublic
  use arg source, table = (.RxNativeInterpretedTable~new)
  prolog = ''
  interpretedSource = ''
  interpretedMethods = .directory~new
  interpretedPublic = .array~new
  directives = .array~new     /* every directive at clause start: line kind name words */
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
      entry = .directory~new
      entry~line = tok~line; entry~kind = directive; entry~name = ''; entry~words = .array~new
      if i + 2 <= tokens~items then if tokens[i+2]~kind \= 'SEP' & tokens[i+2]~kind \= 'EOF' then entry~name = tokens[i+2]~text~upper
      j = i + 3
      do while j <= tokens~items & tokens[j]~kind \= 'SEP' & tokens[j]~kind \= 'EOF'
        entry~words~append(tokens[j]~text~upper)
        j += 1
      end
      directives~append(entry)
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
      /* Prolog code: kept as source (comments included), ::OPTIONS lines removed. */
      do j2 = 1 to first - 1
        if optionsLines~hasIndex(j2) then prolog = prolog || '0a'x
        else prolog = prolog || lines[j2] || '0a'x
      end
      leave
    end
  end
  units = .array~new
  names = .directory~new
  roots = .directory~new
  definitions = .directory~new
  scopes = .directory~new
  graphRules = .RxNativeInheritanceRules~new
  interpretedClasses = .directory~new
  do i = 1 to positions~items
    start = positions[i]
    if i < positions~items then finish = positions[i+1] - 1
    else finish = lines~items
    classEntry = self~directiveAt(directives, start, 'CLASS')
    /* Interpreted table: the whole class, or a class whose parent / mixin is interpreted (it inherits their INIT and
       scopes, which a compiled class cannot sit on top of), runs in the interpreter unchanged. */
    classRule = table~classRule(classEntry~name)
    inheritsInterpreted = ''
    do k = 1 to classEntry~words~items
      w = classEntry~words[k]
      if wordpos(w, 'SUBCLASS MIXINCLASS') > 0 & k < classEntry~words~items then
        if interpretedClasses~hasIndex(classEntry~words[k+1]) then inheritsInterpreted = classEntry~words[k+1]
      if w == 'INHERIT' then do m = k + 1 to classEntry~words~items
        if interpretedClasses~hasIndex(classEntry~words[m]) then inheritsInterpreted = classEntry~words[m]
      end
    end
    if classRule \== .nil | inheritsInterpreted \== '' then do
      if classRule \== .nil then classRule~honoured = .true
      else .error~lineout('rx2cpp: interpreted:' classEntry~name '(inherits interpreted' inheritsInterpreted')')
      do rule over table~methodRules(classEntry~name)   /* its methods are interpreted with it */
        rule~used = .true; rule~honoured = .true
      end
      do j = start to finish
        if optionsLines~hasIndex(j) then interpretedSource = interpretedSource || '0a'x
        else interpretedSource = interpretedSource || lines[j] || '0a'x
      end
      interpretedClasses[classEntry~name] = .true
      if classEntry~words~hasItem('PUBLIC') then interpretedPublic~append(classEntry~name)
      names[classEntry~name] = .true
      iterate
    end
    moved = self~interpretedMethodLines(table, directives, classEntry~name, start, finish, tokens)
    section = ''
    do j = start to finish
      /* ooRexx package options do not belong to any individual class.
         Retain an empty line to preserve source-location diagnostics. */
      if optionsLines~hasIndex(j) | moved~hasIndex(j) then section = section || '0a'x
      else section = section || lines[j] || '0a'x
    end
    if moved~items > 0 then do
      text = ''
      do j = start to finish
        if moved~hasIndex(j) then text = text || lines[j] || '0a'x
      end
      interpretedMethods[classEntry~name] = text
    end
    /* SIGL is a line of the original file: a combined package marks where each file starts. */
    markerLine = 0
    do m = start - 1 to 1 by -1
      if lines[m]~left(25) == '/* ---- rx2cpp combined: ' then do
        markerLine = m
        leave
      end
    end
    unit = .RxHybridCompiler~new(section, .true)
    unit~setLineOffset(start - 1 - markerLine)
    /* PARSE SOURCE names the class's original file: the combine marker's path, else the compiled file itself. */
    if markerLine > 0 then parse value lines[markerLine] with '/* ---- rx2cpp combined: ' sourcePath ' ----'
    else sourcePath = self~inputName
    unit~setSourceName(sourcePath)
    unit = unit~parse
    name = unit~className
    if value('RX2CPP_PROGRESS', , 'ENVIRONMENT') == '1' then
      .error~lineout('rx2cpp: progress' time('E')~format(, 1)'s parsed class' name '(lines' start'..'finish')')
    if names~hasIndex(name) then self~reject(start, 'duplicate class ' || name)
    /* A superclass must already exist in this same native package.
       Requiring parent-first order makes the class scope graph unambiguous. */
    if unit~parentName \== '' then do
      /* An interpreter class (STREAM, ARRAY, ...) is allowed as the parent of a native root class. */
      if \names~hasIndex(unit~parentName) & self~interpreterClass(unit~parentName) then
        unit~useExternalParent
      else if \names~hasIndex(unit~parentName) then
        self~reject(start, 'unknown or forward parent ' || unit~parentName)
      /* An empty subclass only inherits: valid Rexx, it gets no native methods of its own. */
    end
    graphRules~validate(unit, names, definitions, roots, scopes)
    names[name] = .true
    definitions[name] = unit
    if unit~parentName == '' then roots[name] = name
    else roots[name] = roots[unit~parentName]
    units~append(unit)
    if unit~classMethods~items > 0 then units~append(.RxHybridClassSide~new(unit))
  end
  table~checkUnused
  return units
/* The package ::REQUIREs other packages or libraries: a parent that is not defined here may come from them. */
::method setRequiredElsewhere
  expose requiredElsewhere
  use arg requiredElsewhere
::method directiveAt private
  use arg directives, lineNo, kind
  do entry over directives
    if entry~line == lineNo & entry~kind == kind then return entry
  end
  self~reject(lineNo, 'expected ::' || kind)
/* Lines of this class's methods that the table moves to the interpreter (a set of line numbers). A method can move only
   when it shares no variables with the compiled methods of its class. */
::method interpretedMethodLines private
  use arg table, directives, className, start, finish, tokens
  moved = .set~new
  rules = table~methodRules(className)
  if rules~items == 0 then return moved
  inClass = .array~new
  do entry over directives
    if entry~line >= start & entry~line <= finish then inClass~append(entry)
  end
  do rule over rules
    do d = 1 to inClass~items
      entry = inClass[d]
      if entry~name \== rule~methodName then iterate
      if entry~kind == 'ATTRIBUTE' then do
        rule~used = .true
        table~refuse(rule, 'an ::ATTRIBUTE uses the variables of the compiled class')
        iterate
      end
      if entry~kind \== 'METHOD' then iterate
      if (entry~words~hasItem('CLASS')) \= rule~classSide then iterate
      rule~used = .true
      if entry~words~hasItem('ATTRIBUTE') then do
        table~refuse(rule, 'an attribute method uses the variables of the compiled class')
        iterate
      end
      if wordpos(entry~name, 'INIT UNINIT') > 0 then do
        table~refuse(rule, entry~name 'sets up / releases the compiled object')
        iterate
      end
      first = entry~line
      if d < inClass~items then last = inClass[d+1]~line - 1
      else last = finish
      if d < inClass~items then if inClass[d+1]~line == first then do
        table~refuse(rule, 'shares its line with another directive')
        iterate
      end
      /* EXPOSE at clause start (not an assignment to a variable named EXPOSE). */
      exposes = .false
      do t = 2 to tokens~items - 1
        tok = tokens[t]
        if tok~line < first then iterate
        if tok~line > last then leave
        if tok~kind == 'IDENT' & tok~text == 'EXPOSE' & tokens[t-1]~kind == 'SEP' & tokens[t+1]~text \== '=' then exposes = .true
      end
      if exposes then do
        table~refuse(rule, 'EXPOSE shares variables with the compiled methods of ' || className)
        iterate
      end
      rule~honoured = .true
      do j = first to last
        moved~put(j)
      end
    end
  end
  return moved
/* A class the interpreter itself provides (.Stream, .Directory, .Comparator, ...): allowed as the parent of a native root. */
::method interpreterClass private
  expose requiredElsewhere
  use arg name
  /* A class of a package or library this one ::REQUIREs is resolved by the interpreter when the library loads. */
  if var('REQUIREDELSEWHERE') then if requiredElsewhere then return .true
  candidate = .environment[name~upper]
  if candidate == .nil then return .false
  return candidate~isA(.Class)
::method reject private
  use arg lineNo, reason
  raise syntax 40.1 array('rx2cpp: native package line ' || lineNo || ': ' || reason)
::requires 'core/RxLexer.cls'
::requires 'hybrid/compiler/RxHybridCompiler.cls'
::requires 'native/NativeInheritanceRules.cls'

::requires 'native/NativePackageOptions.cls'
::requires 'native/NativeInterpretedTable.cls'
