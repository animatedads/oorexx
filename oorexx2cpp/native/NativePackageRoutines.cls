/* Compile restricted PUBLIC and package-private ::ROUTINE bodies using the existing native
   method-body compiler, without creating a second Rexx expression backend.
   The generated class is a private C++ implementation detail; package routine
   exports are registered through the official RexxPackageEntry ABI. */
::class RxNativePackageRoutines public
::attribute sanitized get
::attribute implementation get
::attribute names get
::attribute visibilities get
::attribute externalDeclarations get
::attribute publicExternals get       /* PUBLIC EXTERNAL routine names: exported by forwarding entries */
::method parse
  expose sanitized implementation names visibilities externalDeclarations publicExternals
  use arg source
  lines = source~makeArray('0a'x)
  tokens = .RxLexer~new(source)~scan
  starts = .array~new
  boundaries = .array~new
  before = 'SEP'
  do i = 1 to tokens~items - 1
    t = tokens[i]
    if t~text == '::' & before == 'SEP' then do
      kind = tokens[i+1]~text
      if kind == 'ROUTINE' then do
        starts~append(t~line)
        boundaries~append(t~line)
      end
      else if kind == 'CLASS' | kind == 'METHOD' | kind == 'ATTRIBUTE' | ,
              kind == 'CONSTANT' | kind == 'OPTIONS' then boundaries~append(t~line)
    end
    if t~kind == 'SEP' then before = 'SEP'
    else before = 'OTHER'
  end
  names = .array~new
  externalDeclarations = .array~new
  publicExternals = .array~new
  visibilities = .directory~new
  ignored = .directory~new
  if starts~items == 0 then do
    sanitized = source
    implementation = .nil
    return self
  end
  synthetic = .array~new
  do k = 1 to lines~items
    synthetic~append('')
  end
  synthetic[1] = '::class RX2CPP_ROUTINE_IMPL public'
  seen = .directory~new
  do n = 1 to starts~items
    start = starts[n]
    finish = lines~items
    do b over boundaries
      if b > start then do
        finish = b - 1
        leave
      end
    end
    line = lines[start]
    header = .RxLexer~new(line || '0a'x)~scan
    if header~items < 5 | header[1]~text \= '::' | header[2]~text \= 'ROUTINE' then
      self~reject(start, 'invalid ::ROUTINE declaration')
    /* A quoted name is a routine name like a symbol (upper case, as the interpreter registers it). */
    if header[3]~kind \= 'IDENT' & header[3]~kind \= 'STRING' then self~reject(start, 'routine name must be a symbol or a string')
    name = header[3]~text
    if header[3]~kind == 'STRING' then name = name~upper
    /* An EXTERNAL routine is implemented by ooRexx's named library, not the
       native class compiler. Keep the original package directive verbatim. */
    visibility = 'PRIVATE'
    optionIndex = 4
    if header[optionIndex]~text == 'PUBLIC' | header[optionIndex]~text == 'PRIVATE' then do
      visibility = header[optionIndex]~text
      optionIndex += 1
    end
    isExternal = header[optionIndex]~text == 'EXTERNAL'
    if isExternal then do
      /* (PUBLIC too: the directive goes to the declaration package as written, which exports it like any public
         routine of the library's package) */
      if header[optionIndex+1]~kind \= 'STRING' | ,
         header[optionIndex+2]~kind \= 'SEP' | header[optionIndex+3]~kind \= 'EOF' then
        self~reject(start, 'EXTERNAL needs one standalone quoted library specification')
      spec = header[optionIndex+1]~text
      if words(spec) \= 3 | translate(word(spec, 1)) \= 'LIBRARY' then
        self~reject(start, 'EXTERNAL supports only LIBRARY package procedure')
      namePattern = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_'
      if verify(word(spec, 2), namePattern) > 0 | verify(word(spec, 3), namePattern) > 0 then
        self~reject(start, 'unsafe EXTERNAL library or procedure')
    end
    else if header[optionIndex]~kind \= 'SEP' then
      self~reject(start, 'unsupported ::ROUTINE options; expected name [PUBLIC|PRIVATE] [EXTERNAL "LIBRARY ..."]')
    /* The routine's first clauses may follow its directive on the same line, after ';' (::routine r public; return 1):
       they stay on that line (its line number) as the start of the body. */
    inlineBody = ''
    if \isExternal then if line~substr(header[optionIndex]~col, 1) == ';' then inlineBody = line~substr(header[optionIndex]~endCol)
    if seen~hasIndex(name) then self~reject(start, 'duplicate ::ROUTINE ' || name)
    seen[name] = .true
    /* Any symbol or string names a routine (ooRexxUnit.getShellName); C++ names are mangled (.RxQuote~identifier). */
    if name == '' then self~reject(start, 'empty routine name')
    if isExternal then do
      /* An external routine has no implementation body. Non-comment clauses
         before the next directive must be diagnosed, not silently dropped. */
      chunk = ''
      do j = start + 1 to finish
        chunk = chunk || lines[j] || '0a'x
      end
      bodyTokens = .RxLexer~new(chunk)~scan
      do tk over bodyTokens
        if tk~kind \= 'SEP' & tk~kind \= 'EOF' then
          self~reject(start, 'EXTERNAL routine must not have an executable body')
      end
      externalDeclarations~append(line)
      if visibility == 'PUBLIC' then publicExternals~append(name)
      if \.local~rx2cpp.externals~isA(.directory) then .local~put(.directory~new, "RX2CPP.EXTERNALS")
      .local~rx2cpp.externals[name~upper] = line
    end
    else do
      names~append(name)
      visibilities[name] = visibility
      /* (a routine on line 1 shares the line with the class of the routines: line numbers kept) */
      synthetic[start] = '::method "' || name || '"'
      if start == 1 then synthetic[start] = '::class RX2CPP_ROUTINE_IMPL public;' synthetic[start]
      if inlineBody~strip \== '' then synthetic[start] = synthetic[start] || ';' || inlineBody
      /* PARSE SOURCE names the routine's original file: the combine marker before it, else the compiled file. */
      sourcePath = .local['RX2CPP.INPUTNAME']
      if sourcePath == .nil then sourcePath = ''
      /* (the marker may also end the routine's own directive line: a compiled program's main code, compile_program.sh)
         Its lines are numbered as in that file: line L here is line L - m there (SIGL, .LINE, SOURCELINE). */
      markerAt = 0
      do m = start to 1 by -1
        if lines[m]~pos('/* ---- rx2cpp combined: ') > 0 then do
          parse value lines[m] with '/* ---- rx2cpp combined: ' sourcePath ' ----'
          markerAt = m
          leave
        end
      end
      if \.local['RX2CPP.ROUTINESOURCES']~isA(.directory) then .local['RX2CPP.ROUTINESOURCES'] = .directory~new
      .local['RX2CPP.ROUTINESOURCES'][name~upper] = sourcePath
      if \.local['RX2CPP.ROUTINEOFFSETS']~isA(.directory) then .local['RX2CPP.ROUTINEOFFSETS'] = .directory~new
      .local['RX2CPP.ROUTINEOFFSETS'][name~upper] = -markerAt
      do j = start + 1 to finish
        synthetic[j] = lines[j]
      end
    end
    ignored[start] = .true
    do j = start + 1 to finish
      ignored[j] = .true
    end
  end
  sanitized = ''
  do i = 1 to lines~items
    if ignored~hasIndex(i) then sanitized = sanitized || '0a'x
    else sanitized = sanitized || lines[i] || '0a'x
  end
  routineSource = ''
  do textLine over synthetic
    routineSource = routineSource || textLine || '0a'x
  end
  if names~items == 0 then do
    implementation = .nil
    return self
  end
  .local~put(names, 'RX2CPP.LOCALROUTINES')
  implementation = .RxHybridCompiler~new(routineSource, .true, names)~parse
  if implementation~methods~items \= names~items then self~reject(1, 'native routine method count mismatch')
  do method over implementation~methods
    if method~exposed~items > 0 then self~reject(1, 'routine cannot EXPOSE object fields')
  end
  return self
::method reject private
  use arg line, reason
  raise syntax 40.1 array('rx2cpp: native routine line ' || line || ': ' || reason)
::requires 'core/RxLexer.cls'
::requires 'hybrid/compiler/RxHybridCompiler.cls'
