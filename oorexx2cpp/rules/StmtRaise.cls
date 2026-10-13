/* RAISE SYNTAX code [ARRAY(arg, ...)] — throws a trappable SYNTAX condition.
   Only the ARRAY(...) additional-information form used by real code is accepted. */
::class RxStmtRaise public
::method accepts
  use arg ctx
  return ctx~stream~is('RAISE')
::method emit
  use arg ctx, depth
  .local['RX2CPP.CLAUSEWORDS'] = 'ARRAY ADDITIONAL DESCRIPTION RETURN EXIT'   /* keywords of this clause end its expressions */
  s = ctx~stream
  s~expect('RAISE')
  /* RAISE PROPAGATE in a compiled trap handler: the trapped condition again, to the caller. */
  if s~accept('PROPAGATE') then do
    trapped = .false
    if ctx~current~hasMethod('TRAPPED') then trapped = ctx~current~trapped
    if \trapped then s~fail('RAISE PROPAGATE needs a SIGNAL ON trap in this method')
    ctx~line(depth, '_rxTrap.propagate();')
    s~separator
    return
  end
  if \s~accept('SYNTAX') then s~fail('RAISE supports only SYNTAX in this subset')
  t = s~next
  if t~kind \= 'NUMBER' then s~fail('RAISE SYNTAX needs a literal error code such as 88.900')
  args = ''
  if s~peek~kind == 'IDENT' & s~peek~text == 'ARRAY' then do
    s~next
    s~expect('(')
    if \s~is(')') then do
      do forever
        if args \== '' then args = args || ', '
        args = args || ctx~logicalExpr~parse(ctx)
        if \s~accept(',') then leave
      end
    end
    s~expect(')')
  end
  else if s~peek~kind == 'IDENT' & s~peek~text == 'ADDITIONAL' then do
    /* ADDITIONAL (expr): one substitution value (93.900's "&1"), as the interpreter uses it for SYNTAX. */
    s~next
    s~expect('(')
    additional = ctx~logicalExpr~parse(ctx)
    s~expect(')')
  end
  else if \(s~peek~kind == 'SEP' | s~peek~kind == 'EOF' | s~is('RETURN') | s~is('EXIT')) then s~fail('RAISE SYNTAX supports only ARRAY(...) additional information')
  if var('ADDITIONAL') then do
    local = 'false'
    if s~accept('RETURN') then local = 'true'
    else if s~accept('EXIT') then local = 'false'
    ctx~line(depth, 'rx::raiseSyntax(' || .RxQuote~cpp(t~text) || ', rx::additionalItems(' || additional || '), ' || local || ');')
    s~separator
    return
  end
  local = 'false'
  if s~accept('RETURN') then local = 'true'
  else if s~accept('EXIT') then local = 'false'
  ctx~line(depth, 'rx::raiseSyntax(' || .RxQuote~cpp(t~text) || ', std::vector<rx::Value>{' || args || '}, ' || local || ');')
  s~separator
::requires 'core/RxQuote.cls'
