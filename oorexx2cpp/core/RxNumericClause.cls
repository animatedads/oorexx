/* One Rexx NUMERIC instruction parser for every executable code-unit scope.
 * Source syntax and runtime operations live here. The two backends supply
 * expression parsing and statement emission, NOT alternative Rexx grammar.
 * A scope selects the activation; NUMERIC always mutates that activation. */
::class RxNumericClause public
::method accepts
  use arg ctx
  return ctx~stream~is('NUMERIC')
::method emitClause
  use arg ctx, depth
  s = ctx~stream
  s~expect('NUMERIC')
  mode = s~next~text
  select
    when mode == 'DIGITS' | mode == 'FUZZ' then do
      if s~peek~kind == 'SEP' | s~peek~kind == 'EOF' then do
        if mode == 'DIGITS' then expr = 'rx::Value::number("9")'
        else expr = 'rx::Value::number("0")'
      end
      else expr = self~expression(ctx)
      if mode == 'DIGITS' then action = 'setNumericDigits'
      else action = 'setNumericFuzz'
      self~append(ctx, depth, 'rx::' || action || '(vars.numeric, ' || expr || ');')
    end
    when mode == 'FORM' then do
      if s~accept('ENGINEERING') then engineering = 'true'
      else if s~accept('SCIENTIFIC') | s~peek~kind == 'SEP' | s~peek~kind == 'EOF' then engineering = 'false'
      else do
        /* NUMERIC FORM VALUE expr, or an expression that does not start with a symbol (a symbol is refused when the
           clause is parsed, 25.11, as interpreted). */
        if \s~accept('VALUE') & s~peek~kind == 'IDENT' then
          s~fail('NUMERIC FORM must be followed by one of the keywords SCIENTIFIC or ENGINEERING; found "' || s~peek~text || '"')
        self~append(ctx, depth, 'rx::setNumericFormValue(vars.numeric, ' || self~expression(ctx) || ');')
        return
      end
      self~append(ctx, depth, 'rx::setNumericForm(vars.numeric, ' || engineering || ');')
    end
    otherwise s~fail('unknown NUMERIC option')
  end
  s~separator
/* The compiler backend must implement expression(ctx) and append(ctx,depth,cpp).
 * An absent method is a programming error, never a hidden fallback. */
