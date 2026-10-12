/* Shared lexical rule resolver. A backend supplies candidate rules only;
 * neither backend reimplements selection, precedence or fallback behavior.
 * When rule implementations converge, remove the duplicate candidates,
 * not this resolver or the caller's scope/activation contract. */
::class RxRexxRuleSelection public
::method find
  use arg context
  /* Rexx: a clause whose second token is '=' is an assignment, whatever its first word (GUARD = 10, SAY = 1). */
  s = context~stream
  if s~peek~kind == 'IDENT' & s~lookAheadText(1) == '=' & s~lookAheadKind(1) == 'OP' then do
    candidates = self~rules
    return candidates[candidates~last]
  end
  do rule over self~rules
    if rule~accepts(context) then return rule
  end
  return .nil
