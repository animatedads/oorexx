/* Interpreter-side proxy source generated directly from the source ::METHODs.
   The entry clause is a standalone test harness for macrospace function lookup;
   the class itself is a token-holding Rexx proxy with native dispatch. */
::class RxHybridProxyEmitter public
::method emit
  use arg unit
  name = 'Compiled' || unit~className || 'Proxy'
  lines = .array~new
  lines~append('/* Generated interpreter-side macrospace bridge for ' || unit~className || '. */')
  lines~append('parse arg compiledToken, operation, argument')
  lines~append('proxy = .' || name || '~new(compiledToken)')
  lines~append("if operation == '@OBJECT' then return proxy")
  lines~append('select')
  do method over unit~methods
    if method~selector == 'INIT' then iterate
    call = 'proxy~' || method~selector~lower
    if method~parameter \== '' then call = call || '(argument)'
    lines~append("  when operation == '" || method~selector || "' then return " || call)
  end
  lines~append('  otherwise raise syntax 40.1 array("rx2cpp: unsupported proxy selector")')
  lines~append('end')
  lines~append('')
  lines~append('::class ' || name || ' public')
  lines~append('::method init')
  lines~append('  expose token')
  lines~append('  use arg token')
  do method over unit~methods
    if method~selector == 'INIT' then iterate
    lines~append('::method ' || method~selector~lower)
    lines~append('  expose token')
    if method~parameter \== '' then do
      lines~append('  use arg argument')
      lines~append("  if \arg(1, 'E') then raise syntax 40.1 array('rx2cpp: missing proxy argument')")
      call = '.array~of(argument)'
    end
    else call = '.array~new'
    lines~append("  return NativeDispatch(token, '" || method~selector || "', " || call || ')')
  end
  lines~append('::routine NativeDispatch external ''LIBRARY rx2cppbridge NativeDispatch''')
  out = ''
  do l over lines
    out = out || l || '0a'x
  end
  return out
