/* Language rule: atom = string | integer | simple variable | (arithmetic). */
::class RxExprAtom public
::method parse
  use arg ctx
  s = ctx~stream
  t = s~peek
  select
    when t~kind == 'STRING' then do
      s~next
      return 'rx::Value::string(' || .RxQuote~cpp(t~text) || ')'
    end
    when t~kind == 'NUMBER' | t~kind == 'INT' then do
      s~next
      return 'rx::Value::number(' || .RxQuote~cpp(t~text) || ')'
    end
    when t~kind == 'DOTIDENT' then do
      s~next
      if ctx~hasProgramClass(t~text) then return 'rx::Value::fromObject(_rxClasses.at(' || .RxQuote~cpp(t~text) || '))'
      if t~text == 'ARRAY' then return 'rx::Value::fromObject(std::make_shared<rx::ArrayClass>())'
      /* .TRUE/.FALSE are the strings 1 and 0 */
      if t~text == 'TRUE' then return 'rx::Value::string("1")'
      if t~text == 'FALSE' then return 'rx::Value::string("0")'
      /* Environment symbols that are not classes (or need native support) stay fail-closed. */
      if wordpos(t~text, 'NIL ENVIRONMENT LOCAL METHODS ROUTINES RS STDOUT STDERR STDIN STDQUE TRACEOBJECT ERROR OUTPUT INPUT DEBUGINPUT') = 0 & ctx~hostedEnabled then do
        ctx~markHosted(t~text)
        return 'rx::host::findClass(' || .RxQuote~cpp(t~text) || ')'
      end
      s~fail('unsupported environment class .' || t~text)
    end
    when t~kind == 'IDENT' then do
      if wordpos(t~text, 'THEN TO BY DO UNTIL ELSE END IF EXIT') > 0 then s~fail('reserved word in expression')
      s~next
      /* Rexx function invocation requires abuttal: F(3) differs from F (3). */
      if s~is('(') & s~peek~line == t~endLine & s~peek~col == t~endCol then -
        return ctx~builtinExpr~parse(ctx, t~text)
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
