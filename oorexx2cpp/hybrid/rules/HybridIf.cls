/* Compiled IF/THEN[/ELSE]. The condition is always evaluated through the
   existing ooRexx expression machinery. Branch statements share the same
   hybrid rules and activation frame; conditional RETURN is not a terminal
   declaration-level RETURN. No speculative interpreter fallback. */
::class RxHybridIf public
::method accepts
  use arg ctx
  return ctx~stream~is('IF')
::method emit
  use arg ctx
  s = ctx~stream
  s~expect('IF')
  .local['RX2CPP.CLAUSEWORDS'] = 'THEN'
  condition = ctx~compareExpr~parse(ctx)
  s~expect('THEN')
  s~skipSeparators
  ctx~current~addInstruction('if (' || .RxOperatorRules~condition(condition, 'rx::Truth::If') || ') {')
  ctx~enterControl
  ctx~emitStatement
  ctx~leaveControl
  ctx~current~addInstruction('}')
  if s~accept('ELSE') then do
    s~skipSeparators
    ctx~current~addInstruction('else {')
    ctx~enterControl
    ctx~emitStatement
    ctx~leaveControl
    ctx~current~addInstruction('}')
  end
::requires 'rules/OperatorRules.cls'
