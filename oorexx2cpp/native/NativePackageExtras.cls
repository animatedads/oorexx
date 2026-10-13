/* Package metadata carried by the interpreter-backed native-library backend.
 * Return a source of identical physical line numbering with these directives
 * masked, then append the validated declarations to the embedded Rexx package.
 * In particular a RESOURCE payload is raw data, not Rexx source for our lexer.
 * The standalone C++ executable backend does not use this pass-through layer.
 */
::class RxNativePackageExtras public
::attribute sanitized get
::attribute suffix get
::method parse
  expose sanitized suffix annotationTargets
  use arg source
  lines = source~makeArray('0a'x)
  kept = .array~new
  records = .array~new
  annotationTargets = .array~new
  resourceNames = .directory~new
  i = 1
  commentDepth = 0
  do while i <= lines~items
    line = lines[i]
    /* Resource markers must be outside multiline Rexx comments. */
    header = line~strip
    if commentDepth == 0 & header~left(10)~translate == '::RESOURCE' & ,
       (header~length == 10 | header~substr(11,1) == ' ' | header~substr(11,1) == '09'x) then do
      tokens = .RxLexer~new(line || '0a'x)~scan
      if tokens~items < 4 | tokens[1]~text \= '::' | tokens[2]~text \= 'RESOURCE' then
        self~reject(i, 'invalid RESOURCE header')
      if tokens[3]~kind \= 'IDENT' & tokens[3]~kind \= 'STRING' then
        self~reject(i, 'RESOURCE name must be a constant')
      name = tokens[3]~text~translate
      if resourceNames~hasIndex(name) then self~reject(i, 'duplicate RESOURCE name ' || name)
      resourceNames[name] = .true
      delim = '::END'
      if tokens[4]~text == 'END' then do
        if tokens[5]~kind \= 'IDENT' & tokens[5]~kind \= 'STRING' then
          self~reject(i, 'RESOURCE END needs a constant delimiter')
        delim = tokens[5]~text
        if tokens[6]~kind \= 'SEP' then self~reject(i, 'unsupported RESOURCE header')
      end
      else if tokens[4]~kind \= 'SEP' then self~reject(i, 'unsupported RESOURCE option')
      if delim == '' then self~reject(i, 'empty RESOURCE delimiter')
      block = line || '0a'x
      kept~append('')
      start = i
      found = .false
      i += 1
      do while i <= lines~items
        data = lines[i]
        block = block || data || '0a'x
        kept~append('')
        if data~left(delim~length) == delim then do
          found = .true
          leave
        end
        i += 1
      end
      if \found then self~reject(start, 'missing RESOURCE end delimiter ' || delim)
      records~append(block)
    end
    else do
      kept~append(line)
      /* Avoid mistaking markers in comments for executable directives. */
      commentDepth = self~commentsAfter(line, commentDepth)
    end
    i += 1
  end
  masked = ''
  do line over kept
    masked = masked || line || '0a'x
  end
  tokens = .RxLexer~new(masked)~scan
  removable = .directory~new
  previous = 'SEP'
  i = 1
  do while i <= tokens~items
    token = tokens[i]
    if token~kind == 'EOF' then leave
    if token~text == '::' & previous == 'SEP' & i < tokens~items then do
      kind = tokens[i+1]~text
      if kind == 'ANNOTATE' | kind == 'REQUIRES' then do
        lineno = token~line
        if token~col \= 1 then do
          /* Leading whitespace is allowed, but never two directives per line. */
          if lines[lineno]~strip~left(2) \= '::' then
            self~reject(lineno, 'package directive must occupy its own line')
        end
        j = i + 2
        do while j <= tokens~items & tokens[j]~kind \= 'SEP' & tokens[j]~kind \= 'EOF'
          if tokens[j]~line \= lineno then
            self~reject(lineno, 'continued package directive unsupported')
          j += 1
        end
        /* Never strip a second physical-line instruction after a semicolon. */
        if j <= tokens~items & tokens[j]~line == lineno & tokens[j]~col < lines[lineno]~length then
          self~reject(lineno, 'package directive must occupy its own line')
        if kind == 'ANNOTATE' then self~annotation(tokens, i+2, j, lineno)
        else self~dependency(tokens, i+2, j, lineno)
        records~append(lines[lineno] || '0a'x)
        removable[lineno] = .true
        i = j - 1
      end
    end
    if token~kind == 'SEP' then previous = 'SEP'
    else previous = 'OTHER'
    i += 1
  end
  sanitized = ''
  do k = 1 to kept~items
    if removable~hasIndex(k) then sanitized = sanitized || '0a'x
    else sanitized = sanitized || kept[k] || '0a'x
  end
  suffix = ''
  do rec over records
    suffix = suffix || rec
  end
  return self
::method validate
  /* Check that declared metadata targets will exist in the generated package,
     rather than producing a .so that fails only on interpreter loading. */
  expose annotationTargets
  use arg units
  do item over annotationTargets
    kind = item[1]
    name = item[2]
    found = .false
    do unit over units
      if kind == 'CLASS' & unit~className == name then found = .true
      if kind == 'METHOD' then do
        do method over unit~methods
          if method~selector == name then found = .true
        end
      end
      if kind == 'CONSTANT' then do
        do constant over unit~constants
          if constant[1] == name then found = .true
        end
      end
    end
    if \found then self~reject(item[3], 'ANNOTATE ' || kind || ' target not in compiled package: ' || name)
  end
  return self
::method annotation private
  expose annotationTargets
  use arg tokens, start, finish, lineNo
  if finish < start + 2 then self~reject(lineNo, 'incomplete ANNOTATE')
  target = tokens[start]~text
  if target == 'PACKAGE' then n = start + 1
  else if target == 'CLASS' | target == 'METHOD' | target == 'CONSTANT' then do
    if tokens[start+1]~kind \= 'IDENT' & tokens[start+1]~kind \= 'STRING' then
      self~reject(lineNo, 'ANNOTATE target name required')
    n = start + 2
  end
  else self~reject(lineNo, 'unsupported ANNOTATE target ' || target)
  if n + 2 \= finish then self~reject(lineNo, 'ANNOTATE requires one name and literal value')
  if tokens[n]~kind \= 'IDENT' then self~reject(lineNo, 'ANNOTATE name must be a symbol')
  if tokens[n+1]~kind \= 'IDENT' & tokens[n+1]~kind \= 'NUMBER' & tokens[n+1]~kind \= 'STRING' then
    self~reject(lineNo, 'ANNOTATE value must be a literal')
  if target \= 'PACKAGE' then annotationTargets~append(.array~of(target, tokens[start+1]~text, lineNo))
::method dependency private
  use arg tokens, start, finish, lineNo
  /* ::REQUIRES 'name' LIBRARY: another native library this one needs; the interpreter loads it with this package. */
  if finish == start + 2 & tokens[start]~kind == 'STRING' & tokens[start+1]~text == 'LIBRARY' then return
  /* ::REQUIRES 'name' of an interpreted package (json.cls, a file not combined in): the declaration package requires
     it, so the interpreter loads it with the library, searching as it would for the source. */
  if finish == start + 1 & tokens[start]~kind == 'STRING' then do
    if tokens[start]~text == '' then self~reject(lineNo, 'empty REQUIRES package')
    return
  end
  if finish \= start + 3 | tokens[start]~kind \= 'STRING' | ,
      tokens[start+1]~text \= 'NAMESPACE' | tokens[start+2]~kind \= 'IDENT' then
    self~reject(lineNo, 'only ::REQUIRES literal NAMESPACE symbol is supported')
  filename = tokens[start]~text
  if filename == '' then self~reject(lineNo, 'empty REQUIRES package')
  /* Namespace dependencies must be resolvable through the explicit build
     environment, not discovered by accident at runtime. */
  if stream(filename, 'C', 'QUERY EXISTS') \== '' then return
  env = value('REXX_PATH',, 'ENVIRONMENT')
  do while env \== ''
    parse var env parent ':' env
    if parent == '' then iterate
    full = parent || '/' || filename
    if stream(full, 'C', 'QUERY EXISTS') \== '' then return
  end
  self~reject(lineNo, 'unresolved ::REQUIRES package ' || filename)
::method commentsAfter private
  /* Track nested block comments, without interpreting comment text as headers.
     Lexical validity of non-resource source remains the Rexx lexer's job. */
  use arg line, depth
  quote = ''
  p = 1
  do while p <= line~length
    ch = line~substr(p,1)
    next = line~substr(p+1,1)
    if depth > 0 then do
      if ch == '/' & next == '*' then do
        depth += 1; p += 2; iterate
      end
      if ch == '*' & next == '/' then do
        depth -= 1; p += 2; iterate
      end
    end
    else if quote \== '' then do
      if ch == quote then do
        if next == quote then do
          p += 2; iterate
        end
        quote = ''
      end
    end
    else do
      if ch == '-' & next == '-' then leave
      if ch == "'" | ch == '"' then quote = ch
      else if ch == '/' & next == '*' then do
        depth += 1; p += 2; iterate
      end
    end
    p += 1
  end
  return depth
::method reject private
  use arg line, reason
  raise syntax 40.1 array('rx2cpp: native extras line ' || line || ': ' || reason)
::requires 'core/RxLexer.cls'
