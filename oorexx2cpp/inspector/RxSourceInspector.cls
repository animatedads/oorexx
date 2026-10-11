/* RX2CPP inspector: let ooRexx compile a temporary inspection-only package.
 * Source before the first directive is relocated into MAIN on a synthetic
 * class, so inspection does not execute the original program prologue.
 * Package, Class, Method and Routine objects are the definition authority.
 * The temporary source is never an emitted program and is never executed.
 */
::class RxSourceInspector public
::constant SYNTHETIC 'RX2CPP_INSPECTION_PROLOGUE_0D41192'
::constant INIT_ALIAS 'RX2CPP_INSPECTION_CLASS_INIT_0D41192'
::attribute rows get
::attribute package get
::attribute originalName get
::attribute prologLineCount get
::attribute resolver
::method init
  expose rows package prologLineCount originalName resolver
  resolver = .nil
  originalName = ''
  rows = .array~new
  package = .nil
  prologLineCount = 0
::method inspect
  expose rows package prologLineCount originalName
  use arg original, temporary
  originalName = original
  if original == '' | temporary == '' | original == temporary then
    raise syntax 40.1 array('rx2cpp inspector: original and distinct temporary paths required')
  if stream(original, 'C', 'QUERY EXISTS') == '' then
    raise syntax 40.1 array('rx2cpp inspector: no such source ' || original)
  if stream(temporary, 'C', 'QUERY EXISTS') \== '' then
    raise syntax 40.1 array('rx2cpp inspector: temporary path already exists (refusing overwrite)')
  suffix = self~prepare(original)
  /* Opening a .Package via NEW compiles method/routine objects without
     invoking the synthetic MAIN. Never use REQUIRES to load this file. */
  status = stream(temporary, 'C', 'OPEN WRITE REPLACE')
  if left(status, 6) \= 'READY:' then
    raise syntax 40.1 array('rx2cpp inspector: cannot open temporary file: ' || status)
  call charout temporary, suffix
  call stream temporary, 'C', 'CLOSE'
  package = .Package~new(temporary)
  classes = package~classes
  publicClasses = package~publicClasses
  do name over self~sorted(classes~allIndexes)
    if name == self~SYNTHETIC then do
      classObject = classes[name]
      m = .nil
      methods = classObject~methods
      do while methods~available
        if methods~index == 'MAIN' & methods~item~scope == classObject then m = methods~item
        methods~next
      end
      if m == .nil then raise syntax 40.1 array('rx2cpp inspector: missing synthetic MAIN')
      rows~append(.array~of('PROLOGUE', '', 'MAIN', 'PACKAGE', '', self~methodSource(m)))
      iterate
    end
    visibility = 'PRIVATE'
    if publicClasses~hasIndex(name) then visibility = 'PUBLIC'
    rows~append(.array~of('CLASS', '', name, visibility, '', ''))
    c = classes[name]
    /* ~METHODS exposes the instance method dictionary, including PRIVATE;
       class-side methods live in ~INSTANCEMETHODS on the class object. */
    self~appendMethods(c~methods, c, name, 'METHOD')
    self~appendMethods(c~instanceMethods, c, name, 'CLASS_METHOD')
  end
  routines = package~routines
  publicRoutines = package~publicRoutines
  do name over self~sorted(routines~allIndexes)
    visibility = 'PRIVATE'
    if publicRoutines~hasIndex(name) then visibility = 'PUBLIC'
    rows~append(.array~of('ROUTINE', '', name, visibility, '', self~methodSource(routines[name])))
  end
  return self
/* Block dependency imports (which execute their prologues) and rename
   class-side INIT so constructing the inspected package cannot invoke it.
   Only one physical-line ::METHOD header is currently admitted for aliasing. */
/* Neutralised inspection text for one source: prologue relocated into the synthetic MAIN, class INIT aliased,
   ::REQUIRES refused unless a resolver is set (then each one is mapped to an already-neutralised copy). */
::method prepare
  expose prologLineCount resolver
  use arg original
  text = charin(original, 1, chars(original))
  call stream original, 'C', 'CLOSE'
  tokens = .RxLexer~new(text)~scan
  first = 0
  previous = 'SEP'
  do i = 1 to tokens~items - 1
    t = tokens[i]
    if t~kind == 'OP' & t~text == '::' & previous == 'SEP' then do
      first = t~line
      leave
    end
    if t~kind == 'SEP' then previous = 'SEP'
    else previous = 'OTHER'
  end
  lines = text~makeArray('0a'x)
  /* Package NEW eagerly executes class-side INIT and ::REQUIRES prologues.
     Never run a dependency while inspecting a source-only package. */
  self~safeHeaders(tokens, lines, original)
  prefix = ''
  suffix = ''
  do i = 1 to lines~items
    line = lines[i]~strip('T', '0d'x)
    if first == 0 | i < first then do
      prefix = prefix || line || '0a'x
      prologLineCount += 1
    end
    else suffix = suffix || line || '0a'x
  end
  /* Collision is not a reason to rename a user class or to expose it. */
  if prologLineCount > 0 then do
    if self~declaresSynthetic(tokens) then
      raise syntax 40.1 array('rx2cpp inspector: synthetic class name collision')
    suffix = suffix || '0a'x || '::class ' || self~SYNTHETIC || ' public' || '0a'x || ,
                         '::method main' || '0a'x || prefix
  end
  return suffix
/* Point one ::REQUIRES at its neutralised scratch copy; LIBRARY (native code) is always refused. */
::method mapRequires private
  use arg tokens, lines, i, original
  nameToken = tokens[i+2]
  library = .false
  j = i + 3
  do while j <= tokens~items & tokens[j]~kind \= 'SEP' & tokens[j]~kind \= 'EOF'
    if tokens[j]~text~translate == 'LIBRARY' then library = .true
    j += 1
  end
  if library then raise syntax 40.1 array('rx2cpp inspector: ::REQUIRES LIBRARY loads native code: ' || nameToken~text)
  if nameToken~line \= tokens[i]~line then raise syntax 40.1 array('rx2cpp inspector: continued ::REQUIRES unsupported')
  mapped = self~resolver~map(nameToken~text, original)
  line = lines[nameToken~line]
  if mapped == .nil then lines[nameToken~line] = '-- (missing) ' || line
  else if nameToken~kind == 'STRING' then
    lines[nameToken~line] = left(line, nameToken~col-1) || "'" || mapped || "'" || substr(line, nameToken~col+length(nameToken~text)+2)
  else
    lines[nameToken~line] = left(line, nameToken~col-1) || "'" || mapped || "'" || substr(line, nameToken~col+length(nameToken~text))
::method safeHeaders private
  use arg tokens, lines, original
  previous = 'SEP'
  do i = 1 to tokens~items - 2
    t = tokens[i]
    if t~text == '::' & previous == 'SEP' then do
      directive = tokens[i+1]~text
      if directive == 'REQUIRES' then do
        if self~resolver == .nil then
          raise syntax 40.1 array('rx2cpp inspector: ::REQUIRES executes dependencies; inspect them separately first')
        self~mapRequires(tokens, lines, i, original)
      end
      if directive == 'METHOD' & tokens[i+2]~text == self~INIT_ALIAS then
        raise syntax 40.1 array('rx2cpp inspector: reserved method alias collision')
      if directive == 'METHOD' & tokens[i+2]~text == 'INIT' then do
        j = i + 3
        classSide = .false
        do while j <= tokens~items & tokens[j]~kind \= 'SEP' & tokens[j]~kind \= 'EOF'
          if tokens[j]~text == 'CLASS' then classSide = .true
          j += 1
        end
        if classSide then do
          nameToken = tokens[i+2]
          if nameToken~kind \= 'IDENT' then
            raise syntax 40.1 array('rx2cpp inspector: quoted CLASS INIT requires explicit normalisation')
          if nameToken~line \= t~line then
            raise syntax 40.1 array('rx2cpp inspector: continued CLASS INIT header unsupported')
          line = lines[t~line]
          col = nameToken~col
          lines[t~line] = left(line, col-1) || self~INIT_ALIAS || substr(line, col+length(nameToken~text))
        end
      end
    end
    if t~kind == 'SEP' then previous = 'SEP'
    else previous = 'OTHER'
  end
::method declaresSynthetic private
  use arg tokens
  do i = 1 to tokens~items - 2
    if tokens[i]~text == '::' & tokens[i+1]~text == 'CLASS' & ,
       tokens[i+2]~text == self~SYNTHETIC then return .true
  end
  return .false
::method sorted private
  use arg values
  return values~sort
::method methodSource private
  use arg method
  result = ''
  first = .true
  do line over method~source
    if \first then result = result || '0a'x
    result = result || line
    first = .false
  end
  return result
::method appendMethods private
  expose rows
  use arg supplier, classObject, className, kind
  do while supplier~available
    name = supplier~index
    method = supplier~item
    /* Ignore inherited methods. Only definitions owned by this class count. */
    if method~scope == classObject then do
      visibility = 'PUBLIC'
      if method~isPrivate then visibility = 'PRIVATE'
      else if method~isPackage then visibility = 'PACKAGE'
      flags = ''
      if method~isProtected then flags = flags || 'PROTECTED,'
      if method~isGuarded then flags = flags || 'GUARDED,'
      if method~isAbstract then flags = flags || 'ABSTRACT,'
      if method~isAttribute then flags = flags || 'ATTRIBUTE,'
      if method~isConstant then flags = flags || 'CONSTANT,'
      if kind == 'CLASS_METHOD' & name == self~INIT_ALIAS then do
        name = 'INIT'
        flags = flags || 'INSPECTION_ALIAS,'
      end
      rows~append(.array~of(kind, className, name, visibility, flags, self~methodSource(method)))
    end
    supplier~next
  end
/* Return the body collected from a real Method or Routine object.  No code is
   regenerated from raw directive offsets after the interpreter inspection. */
::method sourceOf
  expose rows
  use arg kind, owner, selector
  do row over rows
    if row[1] == kind & row[2] == owner & row[3] == selector then return row[6]
  end
  return .nil
::method printMap
  expose package rows prologLineCount originalName
  /* Tab-delimited model with hex-encoded UTF-8 fields and source. Lossless
     even when a method contains quotes, tabs, semicolons or embedded NUL. */
  say 'RX2CPP_OBJECT_MODEL/0.1'
  say 'PACKAGE' || '09'x || c2x(originalName) || '09'x || ,
      package~digits || '09'x || package~fuzz || '09'x || package~form || '09'x || ,
      package~options('Prolog') || '09'x || prologLineCount
  ordered = .directory~new
  do row over rows
    ordered[row[1] || '09'x || row[2] || '09'x || row[3]] = row
  end
  do key over self~sorted(ordered~allIndexes)
    row = ordered[key]
    result = row[1]
    do i = 2 to row~items
      result = result || '09'x || c2x(row[i])
    end
    say result
  end
::requires 'core/RxLexer.cls'
