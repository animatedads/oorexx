/* Shared lexical rule resolver. A backend supplies candidate rules only;
 * neither backend reimplements selection, precedence or fallback behavior.
 * When rule implementations converge, remove the duplicate candidates,
 * not this resolver or the caller's scope/activation contract. */
::class RxRexxRuleSelection public
::method find
  use arg context
  do rule over self~rules
    if rule~accepts(context) then return rule
  end
  return .nil
