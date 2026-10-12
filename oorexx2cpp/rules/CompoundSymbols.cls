/* Compound symbol dispatch rule. ooRexx owns the lexer/grammar; this class
   keeps compound names distinct from ordinary simple symbols and delegates
   dynamic tail resolution and stem defaults to the native symbol adapter.
   A simple (non-compound) name compiles to a per-site variable slot (RX_VGET/RX_VSET,
   minirexx_runtime.hpp VarSlot): same semantics as get()/set(), without a hash lookup per access.
   A compound name with tails compiles its derived name directly (rx::compoundKeyOf): constant tails are literals, symbol
   tails read their variable through a slot. RX2CPP_NO_VARSLOTS=1 restores the name-keyed form for both.
   No BIF implementation belongs in this rule. */
::class RxCompoundSymbols public
::method slots class
  return value('RX2CPP_NO_VARSLOTS', , 'ENVIRONMENT') \== '1'
/* C++ expression for the derived name of a compound symbol, or '' when it should stay name-keyed. */
::method derivedName class
  use arg name
  dot = pos('.', name)
  if dot = 0 | dot = length(name) | \self~slots then return ''
  code = 'rx::compoundKeyOf(' || .RxQuote~cpp(left(name, dot))
  rest = substr(name, dot + 1)
  do forever
    p = pos('.', rest)
    if p = 0 then do; part = rest; rest = ''; end
    else do; part = left(rest, p - 1); rest = substr(rest, p + 1); end
    if part == '' | verify(left(part, 1), '0123456789') = 0 then code = code || ', rx::TailLiteral{' || .RxQuote~cpp(part) || '}'
    else code = code || ', RX_VGET(' || .RxQuote~cpp(part) || ')'
    if p = 0 then leave
  end
  return code || ')'
::method load class
  use arg name
  if pos('.', name) = 0 & self~slots then return 'RX_VGET(' || .RxQuote~cpp(name) || ')'
  key = self~derivedName(name)
  if key \== '' then return 'rx::compoundGet(vars, ' || key || ', ' || .RxQuote~cpp(left(name, pos('.', name))) || ')'
  return 'rx::getSymbol(vars, ' || .RxQuote~cpp(name) || ')'
::method store class
  use arg name, expression
  if pos('.', name) = 0 & self~slots then return 'RX_VSET(' || .RxQuote~cpp(name) || ', ' || expression || ');'
  key = self~derivedName(name)
  /* Rexx evaluates the expression before substituting the tails. */
  if key \== '' then return '{ rx::Value _rxcv = ' || expression || '; rx::compoundSet(vars, ' || key || ', std::move(_rxcv)); }'
  return 'rx::setSymbol(vars, ' || .RxQuote~cpp(name) || ', ' || expression || ');'
::requires 'core/RxQuote.cls'
