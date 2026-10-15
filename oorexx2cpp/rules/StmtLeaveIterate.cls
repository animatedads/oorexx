/* LEAVE / ITERATE [name]: resolved lexically to the enclosing loop or labeled block (see the compiler's loopTarget,
   a port of RexxActivation::leaveLoop / iterate). With no match the instruction raises the interpreter's run-time
   error when it executes (28.1 - 28.5), as interpreted; it is not a compile-time error. */
::class RxStmtLeaveIterate public
::method accepts
  use arg ctx
  s = ctx~stream
  return s~is('LEAVE') | s~is('ITERATE')
::method emit
  use arg ctx, depth
  s = ctx~stream
  kind = s~next~text
  name = ''
  if s~peek~kind == 'IDENT' | s~peek~kind == 'NUMBER' then name = s~next~text
  target = ctx~loopTarget(kind, name)
  if word(target, 1) \== 'ERROR' then ctx~line(depth, 'goto ' || target || ';')
  else do
    code = word(target, 2)
    select
      when code == '28.1' then text = 'LEAVE is valid only within a repetitive loop or labeled block instruction'
      when code == '28.2' then text = 'ITERATE is valid only within a repetitive loop'
      when code == '28.3' then text = 'Symbol following LEAVE ("' || name || '") must either match the label of a current loop or block instruction'
      when code == '28.4' then text = 'Symbol following ITERATE ("' || name || '") must either match the label of a current loop or be omitted'
      otherwise text = 'Symbol following ITERATE ("' || name || '") does not match a repetitive block instruction'
    end
    subs = ''
    if name \== '' then subs = ' _rxLeave.substitutions.push_back(rx::Value::string(' || .RxQuote~cpp(name) || '));'
    ctx~line(depth, '{ rx::SyntaxCondition _rxLeave(' || .RxQuote~cpp(code) || ', ' || .RxQuote~cpp(text) || ', false);' || subs || ' throw _rxLeave; }')
  end
  s~separator
::requires 'core/RxQuote.cls'
