/* Fallback decisions are written in ooRexx and based on source-derived
   macros + pinned catalogue; unsafe BIFs require an activation-specific host. */
::class BifBreadthRouteRule public
::method init
  expose catalogue native
  catalogue = .BifBreadthCatalog~new
  native = .BifRuleEngine~new
::method catalogue
  expose catalogue
  return catalogue
::method convert
  expose catalogue native
  use arg definition
  n = definition~name
  entry = catalogue~signature(n)
  if entry == '' then return .nil
  expectedMin = word(entry,1) + 0
  expectedMax = word(entry,2) + 0
  mode = word(entry,3)
  if definition~minArg \= expectedMin | definition~maxArg \= expectedMax then return .nil
  if pos('fix_args(' || n || ')',definition~joined) == 0 & ,
     pos('check_args(' || n || ')',definition~joined) == 0 then return .nil
  /* Original native forwarding rule is authoritative.  Do not claim native
     acceptance if the upstream C++ call shape has changed. */
  if mode == 'NATIVE_SUBSET' then do
    if n == 'SIGN' then do
      /* SIGN uses a dedicated native numeric scanner rather than the generic
         RexxString method forwarder. Preserve native admission only while
         the upstream source still selects the string sign() method. */
      body = definition~joined
      if pos('required_string(SIGN, n)',body) == 0 | ,
         pos('return n->sign()',body) == 0 | ,
         pos('fix_args(SIGN)',body) == 0 then mode = 'HOST_ACTIVATION'
    end
    else do
      validated = native~convert(definition)
      if validated == .nil then mode = 'HOST_ACTIVATION'
    end
  end
  return .BifIR~new(n, definition~line, expectedMin, expectedMax, mode, ,
          'source-verified catalog; route ' || mode, 'original C++ BUILTIN wrapper', mode)
::requires 'compiler/BifBreadthCatalog.cls'
::requires 'compiler/BifRuleEngine.cls'
::requires 'compiler/BifIR.cls'
