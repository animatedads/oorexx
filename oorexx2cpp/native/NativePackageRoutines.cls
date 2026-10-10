/* Compile a restricted PUBLIC ::ROUTINE body using the existing native
   method-body compiler, without creating a second Rexx expression backend.
   The generated class is a private C++ implementation detail; package routine
   exports are registered through the official RexxPackageEntry ABI. */
::class RxNativePackageRoutines public
::attribute sanitized get
::attribute implementation get
::attribute names get
::method parse
  expose sanitized implementation names
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
    if header[3]~kind \= 'IDENT' then self~reject(start, 'routine name must be a simple symbol')
    do h = 5 to header~items
      if header[h]~kind \= 'SEP' & header[h]~kind \= 'EOF' then
        self~reject(start, 'routine declaration must occupy its own line')
    end
    name = header[3]~text
    if header[4]~text \= 'PUBLIC' | header[5]~kind \= 'SEP' then
      self~reject(start, 'only ::ROUTINE name PUBLIC is supported by native ABI')
    if seen~hasIndex(name) then self~reject(start, 'duplicate ::ROUTINE ' || name)
    seen[name] = .true
    if verify(name, 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_') > 0 then
      self~reject(start, 'unsupported routine identifier ' || name)
    names~append(name)
    if start == 1 then self~reject(start, 'native routine must follow a package class')
    synthetic[start] = '::method ' || name
    ignored[start] = .true
    do j = start + 1 to finish
      synthetic[j] = lines[j]
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
  implementation = .RxHybridCompiler~new(routineSource, .true)~parse
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
