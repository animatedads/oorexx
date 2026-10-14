/* DROP name [name | (name)] ...: each variable becomes uninitialized, as interpreted. A stem gets a new empty stem (no
   default, no elements); a compound variable is dropped even under a stem default; (name) drops the variables listed
   (blank-separated) in the value of name. */
::class RxStmtDrop public
::method accepts
  use arg ctx
  s = ctx~stream
  return s~is('DROP') & s~lookAheadText(1) \== '=' & s~lookAheadKind(1) \= 'SEP' & s~lookAheadKind(1) \= 'EOF'
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('DROP')
  do while s~peek~kind \= 'SEP' & s~peek~kind \= 'EOF'
    if s~accept('(') then do
      if s~peek~kind \= 'IDENT' then s~fail('DROP (name) requires a variable name')
      name = s~next~text
      s~expect(')')
      ctx~line(depth, 'rx::dropList(vars, ' || .RxCompoundSymbols~load(name) || ');')
    end
    else do
      if s~peek~kind \= 'IDENT' then s~fail('DROP requires variable names')
      name = s~next~text
      ctx~line(depth, 'rx::dropSymbol(vars, ' || .RxQuote~cpp(name) || ');')
    end
  end
  s~separator
::requires 'core/RxQuote.cls'
::requires 'rules/CompoundSymbols.cls'
