/* NUMERIC operates on the current activation, never a process-wide BIF setting.
   Expressions are evaluated before setting the new context. */
::class RxStmtNumeric public
::method accepts
  use arg ctx
  return ctx~stream~is('NUMERIC')
::method emit
  use arg ctx, depth
  s = ctx~stream
  s~expect('NUMERIC')
  mode = s~next~text
  select
    when mode == 'DIGITS' | mode == 'FUZZ' then do
      if s~peek~kind == 'SEP' | s~peek~kind == 'EOF' then do
        if mode == 'DIGITS' then ctx~line(depth, 'rx::setNumericDigits(vars.numeric, rx::Value::number("9"));')
        else ctx~line(depth, 'rx::setNumericFuzz(vars.numeric, rx::Value::number("0"));')
      end
      else do
        argExpr = ctx~logicalExpr~parse(ctx)
        if mode == 'DIGITS' then fn = 'setNumericDigits'
        else fn = 'setNumericFuzz'
        ctx~line(depth, 'rx::' || fn || '(vars.numeric, ' || argExpr || ');')
      end
    end
    when mode == 'FORM' then do
      if s~accept('SCIENTIFIC') then ctx~line(depth, 'rx::setNumericForm(vars.numeric, false);')
      else if s~accept('ENGINEERING') then ctx~line(depth, 'rx::setNumericForm(vars.numeric, true);')
      else if s~peek~kind == 'SEP' | s~peek~kind == 'EOF' then ctx~line(depth, 'rx::setNumericForm(vars.numeric, false);')
      else s~fail('NUMERIC FORM VALUE is not implemented')
    end
    otherwise s~fail('unknown NUMERIC option')
  end
  s~separator
