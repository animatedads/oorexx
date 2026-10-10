/* Counted DO with a stable body activation and matching optional END name.
   ITERATE jumps to the increment step, LEAVE to loop exit. */
::class RxStmtCountedDo public
::method accepts
  use arg ctx
  s = ctx~stream
  return s~is('DO') & s~lookAheadText(2) == '='
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('DO')
  if s~peek~kind \= 'IDENT' then s~fail('only counted DO variable = start TO end [BY step] supported')
  name = s~next~text
  if pos('.', name) > 0 then s~fail('compound control variable needs a dedicated DO rule')
  s~expect('=')
  first = ctx~addExpr~parse(ctx)
  s~expect('TO')
  last = ctx~addExpr~parse(ctx)
  step = 'rx::Value::number("1")'
  if s~accept('BY') then step = ctx~addExpr~parse(ctx)
  s~separator
  suffix = ctx~label
  iterLabel = '_rx_iter_' || suffix
  exitLabel = '_rx_exit_' || suffix
  ctx~line(depth, '{')
  ctx~line(depth + 1, 'const rx::Value _end' || suffix || ' = ' || last || ';')
  ctx~line(depth + 1, 'const rx::Value _step' || suffix || ' = ' || step || ';')
  ctx~line(depth + 1, 'rx::set(vars, ' || .RxQuote~cpp(name) || ', ' || first || ');')
  ctx~line(depth + 1, 'if (false) { goto ' || iterLabel || '; goto ' || exitLabel || '; }')
  ctx~line(depth + 1, 'while (rx::withinNumeric(rx::get(vars, ' || .RxQuote~cpp(name) || '), _end' || suffix || ', _step' || suffix || ', vars.numeric)) {')
  ctx~line(depth + 2, '{')
  ctx~pushLoop(name, iterLabel, exitLabel)
  ctx~block(depth + 3, .true, name)
  ctx~popLoop
  ctx~line(depth + 2, '}')
  ctx~line(depth + 2, iterLabel || ':;')
  ctx~line(depth + 2, 'rx::set(vars, ' || .RxQuote~cpp(name) || ', rx::numericAdd(rx::get(vars, ' || .RxQuote~cpp(name) || '), _step' || suffix || ', vars.numeric));')
  ctx~line(depth + 1, '}')
  ctx~line(depth + 1, exitLabel || ':;')
  ctx~line(depth, '}')
::requires 'core/RxQuote.cls'
