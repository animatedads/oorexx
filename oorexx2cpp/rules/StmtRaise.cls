/* RAISE SYNTAX code [ARRAY(arg, ...)] — throws a trappable SYNTAX condition.
   Only the ARRAY(...) additional-information form used by real code is accepted. */
::class RxStmtRaise public
::method accepts
  use arg ctx
  return ctx~stream~is('RAISE')
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('RAISE')
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
  else if \(s~peek~kind == 'SEP' | s~peek~kind == 'EOF' | s~is('RETURN') | s~is('EXIT')) then s~fail('RAISE SYNTAX supports only ARRAY(...) additional information')
  local = 'false'
  if s~accept('RETURN') then local = 'true'
  else if s~accept('EXIT') then local = 'false'
  ctx~line(depth, 'rx::raiseSyntax(' || .RxQuote~cpp(t~text) || ', std::vector<rx::Value>{' || args || '}, ' || local || ');')
  s~separator
::requires 'core/RxQuote.cls'
