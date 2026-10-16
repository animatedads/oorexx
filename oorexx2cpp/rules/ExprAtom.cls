/* Language rule: atom = string | integer | simple variable | (arithmetic). */
::class RxExprAtom public
::method parse
  use arg ctx
  s = ctx~stream
  t = s~peek
  select
    when t~kind == 'STRING' then do
      s~next
      /* "NAME"(args): a function call by literal name (no internal-label search), library lane. */
      if s~is('(') & s~peek~line == t~endLine & s~peek~col == t~endCol & ctx~builtinExpr~hasMethod('PARSEQUOTED') then
        return ctx~builtinExpr~parseQuoted(ctx, t~text)
      /* made once and read by every evaluation (its numeric form, once known, kept with it) */
      return '([]() -> const rx::Value & { static const rx::Value _rxLit = rx::Value::string(' || .RxQuote~cpp(t~text) || '); return _rxLit; }())'
    end
    /* A lone period is a constant symbol: its value is "." (xrange(., .)); so is ... outside USE ARG (length(...) is 3). */
    when t~kind == 'OP' & (t~text == '.' | t~text == '...') then do
      s~next
      return 'rx::Value::string(' || .RxQuote~cpp(t~text) || ')'
    end
    when t~kind == 'NUMBER' | t~kind == 'INT' then do
      s~next
      /* Any symbol abutting "(" names a function, a constant symbol too (5A() calls 5A). */
      if s~is('(') & s~peek~line == t~endLine & s~peek~col == t~endCol then -
        return ctx~builtinExpr~parse(ctx, t~text)
      /* made once (its numeric form classified with it) and read by every evaluation, as the interpreter's literal */
      return '([]() -> const rx::Value & { static const rx::Value _rxLit = rx::Value::number(' || .RxQuote~cpp(t~text) || '); return _rxLit; }())'
    end
    when t~kind == 'DOTIDENT' then do
      s~next
      /* .NIL is a singleton, never a string or absent method result. */
      if t~text == 'NIL' then return 'rx::nil()'
      /* .LINE: the line number of the current clause (a constant of the compiled clause). */
      if t~text == 'LINE' & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \== '' & .local['RX2CPP.CLAUSELINE'] \== .nil then
        return 'rx::Value::number("' || .local['RX2CPP.CLAUSELINE'] || '")'
      if t~text == 'CONTEXT' & ctx~hasHostUnit & ctx~hostedEnabled then do
        ctx~markHosted('.CONTEXT')
        return 'rx::host::contextObject()'
      end
      /* .LOCAL / .ENVIRONMENT are the interpreter's own directories (shared with every package it runs). */
      if (t~text == 'LOCAL' | t~text == 'ENVIRONMENT') & ctx~hostedEnabled & value('RX2CPP_KERNEL', , 'ENVIRONMENT') == '' & value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then do
        ctx~markHosted('.' || t~text)
        return 'rx::host::environmentDirectory(' || .RxQuote~cpp(t~text) || ')'
      end
      /* (In a native library .OUTPUT is the interpreter's own, like any environment symbol: see below.) */
      if (t~text == 'OUTPUT' & value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '') | t~text == 'ROUTINES' then do
        if \ctx~hostedEnabled then s~fail('.' || t~text || ' requires RX2CPP_HOSTED=1')
        ctx~markHosted('.' || t~text)
        if t~text == 'OUTPUT' then return 'rx::host::localSymbol("OUTPUT")'
        return 'rx::host::packageRoutines()'
      end
      /* Native library (host API): .CONTEXT answers PACKAGE with the library's own package. */
      if t~text == 'CONTEXT' & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \= '' then return self~activationContext(ctx)
      /* .METHODS: the package's floating methods (in a native library: the declaration package carries them) */
      if t~text == 'METHODS' & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \= '' & \ctx~hasProgramClass('METHODS') then return 'rx::packageMethods()'
      /* .RS: the return status of the activation's last command (.nil before any) */
      if t~text == 'RS' & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \= '' & \ctx~hasProgramClass('RS') then return 'rx::returnStatusValue()'
      /* Native library: .MUTABLEBUFFER builds native buffers that become the interpreter's own only when they leave. */
      if t~text == 'MUTABLEBUFFER' & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \= '' & \ctx~hasProgramClass(t~text) then return 'rx::mutableBufferClass()'
      if t~text == 'ARRAY' & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \= '' & \ctx~hasProgramClass(t~text) then return 'rx::nativeArrayClass()'
      if t~text == 'DIRECTORY' & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \= '' & \ctx~hasProgramClass(t~text) then return 'rx::nativeDirectoryClass()'
      /* Nine native ooRexx object classes in the compiled host-library lane only. */
      if value('RX2CPP_HOST_API', , 'ENVIRONMENT') \= '' & wordpos(t~text, 'LIST QUEUE TABLE SET BAG RELATION SUPPLIER MESSAGE DATETIME') > 0 & \ctx~hasProgramClass(t~text) then -
        return 'rx::nativeNineClass(' || .RxQuote~cpp(t~text) || ')'
      /* Kernel / host-API mode: environment classes are the interpreter's own objects, not reimplementations. */
      if (value('RX2CPP_KERNEL', , 'ENVIRONMENT') \= '' | value('RX2CPP_HOST_API', , 'ENVIRONMENT') \= '') & wordpos(t~text, 'TRUE FALSE NIL') = 0 & \ctx~hasProgramClass(t~text) then -
        return 'rx::envClass(' || .RxQuote~cpp(t~text) || ')'
      if ctx~hasProgramClass(t~text) then return 'rx::Value::fromObject(_rxClasses.at(' || .RxQuote~cpp(t~text) || '))'
      /* A hosted unit shares objects with the interpreter, so collections must be interpreter objects. */
      if t~text == 'ARRAY' & ctx~hasHostUnit & ctx~hostedEnabled then do
        ctx~markHosted('.ARRAY')
        return 'rx::host::findClass("ARRAY")'
      end
      if t~text == 'ARRAY' then return 'rx::arrayClass()'
      /* .STEM~new gives a native StemObject; it becomes an interpreter stem only if it crosses to the hosted tier. */
      if t~text == 'STEM' then return 'rx::stemClass()'
      /* .TRUE/.FALSE are the strings 1 and 0 */
      if t~text == 'TRUE' then return 'rx::Value::string("1")'
      if t~text == 'FALSE' then return 'rx::Value::string("0")'
      /* Environment symbols that are not classes (or need native support) stay fail-closed. */
      if wordpos(t~text, 'ENVIRONMENT LOCAL METHODS RS STDOUT STDERR STDIN STDQUE TRACEOBJECT ERROR OUTPUT INPUT DEBUGINPUT') = 0 & ctx~hostedEnabled then do
        ctx~markHosted('.' || t~text)
        return 'rx::host::findClass(' || .RxQuote~cpp(t~text) || ')'
      end
      s~fail('unsupported environment class .' || t~text)
    end
    when t~kind == 'IDENT' & t~text == 'SELF' & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \= '' then do
      s~next
      return 'rx::selfObject()'
    end
    when t~kind == 'IDENT' then do
      s~next
      /* Rexx function invocation requires abuttal: F(3) differs from F (3). */
      if s~is('(') & s~peek~line == t~endLine & s~peek~col == t~endCol then -
        return ctx~builtinExpr~parse(ctx, t~text)
      /* A bare stem symbol is the stem object wherever it appears (shared, not copied: see StemObject); its string
         value, where one is needed, is its default value through STRING, with NOSTRING (s. || 'x'). */
      if right(t~text, 1) == '.' & pos('.', t~text) == length(t~text) then
        return 'rx::stemArg(vars, ' || .RxQuote~cpp(t~text) || ')'
      return .RxCompoundSymbols~load(t~text)
    end
    when s~accept('(') then do
      value = ctx~logicalExpr~parse(ctx)
      /* (a, b, ...): an Array term (ooRexx 5), as .array~of(a, b, ...) */
      if s~is(',') then do
        items = value
        do while s~accept(',')
          items = items || ', ' || ctx~logicalExpr~parse(ctx)
        end
        s~expect(')')
        if value('RX2CPP_HOST_API', , 'ENVIRONMENT') \= '' then arrayClass = 'rx::nativeArrayClass()'
        else arrayClass = 'rx::arrayClass()'
        return 'rx::messageValue(' || arrayClass || ', "OF", std::vector<rx::Value>{' || items || '}, false)'
      end
      s~expect(')')
      return value
    end
    otherwise s~fail('expected expression atom')
  end
/* .CONTEXT in a compiled method or routine of a native library: .CONTEXT~PACKAGE is the library's package; any other
   use is a snapshot of the activation (rx::activationContext), with its variables unless only another method follows. */
::method activationContext private
  use arg ctx
  s = ctx~stream
  following = ''
  if s~is('~') & s~lookAheadKind(1) == 'IDENT' then following = s~lookAheadText(1)
  if following == 'PACKAGE' | \ctx~hasMethod('CURRENT') then return 'rx::libraryContext()'
  method = ctx~current
  if method == .nil then return 'rx::libraryContext()'
  className = ctx~className
  isRoutine = className == 'RX2CPP_ROUTINE_IMPL'
  scope = ''
  if \isRoutine then scope = className
  classSide = .false
  if method~hasMethod('OPTIONS') then if method~options \== .nil then classSide = method~options~isClass
  name = .RxQuote~cpp(method~selector)
  /* an internal routine's context is named by its label (getCallname) */
  if method~hasMethod('HASINTERNALCALLS') then if method~hasInternalCalls then do
    labels = method~labels
    labelExpr = name
    do labelName over labels~allIndexes
      labelExpr = '(_rxEntry == ' || labels[labelName] || ' ? std::string(' || .RxQuote~cpp(labelName) || ') : ' || labelExpr || ')'
    end
    name = '(_rxInternal ? ' || labelExpr || ' : std::string(' || name || '))'
  end
  line = .local['RX2CPP.CLAUSELINE']
  if line == .nil then line = 0
  withVariables = word('true false', 1 + (following \== '' & following \== 'VARIABLES'))
  return 'rx::activationContext(vars, arguments, ' || line || ', ' || name || ', ' || .RxQuote~cpp(scope) || ', ' || -
         .RxQuote~cpp(method~selector) || ', ' || word('false true', 1 + classSide) || ', ' || withVariables || ')'
::requires 'core/RxQuote.cls'

::requires 'rules/CompoundSymbols.cls'
