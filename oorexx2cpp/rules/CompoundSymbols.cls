/* Compound symbol dispatch rule. ooRexx owns the lexer/grammar; this class
   keeps compound names distinct from ordinary simple symbols and delegates
   dynamic tail resolution and stem defaults to the native symbol adapter.
   No BIF implementation belongs in this rule. */
::class RxCompoundSymbols public
::method load class
  use arg name
  return 'rx::getSymbol(vars, ' || .RxQuote~cpp(name) || ')'
::method store class
  use arg name, expression
  return 'rx::setSymbol(vars, ' || .RxQuote~cpp(name) || ', ' || expression || ');'
::requires 'core/RxQuote.cls'
