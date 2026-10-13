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
      return 'rx::Value::string(' || .RxQuote~cpp(t~text) || ')'
    end
    when t~kind == 'NUMBER' | t~kind == 'INT' then do
      s~next
      return 'rx::Value::number(' || .RxQuote~cpp(t~text) || ')'
    end
    when t~kind == 'DOTIDENT' then do
      s~next
      /* .NIL is a singleton, never a string or absent method result. */
      if t~text == 'NIL' then return 'rx::nil()'
      if t~text == 'CONTEXT' & ctx~hasHostUnit & ctx~hostedEnabled then do
        ctx~markHosted('.CONTEXT')
        return 'rx::host::contextObject()'
      end
      /* .LOCAL / .ENVIRONMENT are the interpreter's own directories (shared with every package it runs). */
      if (t~text == 'LOCAL' | t~text == 'ENVIRONMENT') & ctx~hostedEnabled & value('RX2CPP_KERNEL', , 'ENVIRONMENT') == '' & value('RX2CPP_HOST_API', , 'ENVIRONMENT') == '' then do
        ctx~markHosted('.' || t~text)
        return 'rx::host::environmentDirectory(' || .RxQuote~cpp(t~text) || ')'
      end
      if t~text == 'OUTPUT' | t~text == 'ROUTINES' then do
        if \ctx~hostedEnabled then s~fail('.' || t~text || ' requires RX2CPP_HOSTED=1')
        ctx~markHosted('.' || t~text)
        if t~text == 'OUTPUT' then return 'rx::host::localSymbol("OUTPUT")'
        return 'rx::host::packageRoutines()'
      end
      /* Native library (host API): .CONTEXT answers PACKAGE with the library's own package. */
      if t~text == 'CONTEXT' & value('RX2CPP_HOST_API', , 'ENVIRONMENT') \= '' then return 'rx::libraryContext()'
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
      if wordpos(t~text, 'THEN DO ELSE END IF EXIT') > 0 then s~fail('reserved word in expression')
      s~next
      /* Rexx function invocation requires abuttal: F(3) differs from F (3). */
      if s~is('(') & s~peek~line == t~endLine & s~peek~col == t~endCol then -
        return ctx~builtinExpr~parse(ctx, t~text)
      /* A bare stem as an argument (or a whole clause value) is passed as the stem object (shared, not copied): see StemObject. */
      if right(t~text, 1) == '.' & pos('.', t~text) == length(t~text) & (s~is(',') | s~is(')') | s~peek~kind == 'SEP' | s~peek~kind == 'EOF') then
        return 'rx::stemArg(vars, ' || .RxQuote~cpp(t~text) || ')'
      return .RxCompoundSymbols~load(t~text)
    end
    when s~accept('(') then do
      value = ctx~logicalExpr~parse(ctx)
      s~expect(')')
      return value
    end
    otherwise s~fail('expected expression atom')
  end
::requires 'core/RxQuote.cls'

::requires 'rules/CompoundSymbols.cls'
