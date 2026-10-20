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
  /* A clause whose first token is a symbol followed by ~, ~~ or [ is a message instruction, whatever the symbol
     (LanguageParser::nextInstruction parses the message term before it looks for a keyword): DO~x = 1, SAY~m. */
  messageClause = s~peek~kind == 'IDENT' & s~lookAheadKind(1) == 'OP' & wordpos(s~lookAheadText(1), '~ ~~ [') > 0
  do rule over self~rules
    if messageClause then do
      id = rule~class~id~upper
      if rule~hasMethod('INNER') then id = rule~inner~class~id~upper
      if wordpos(id, 'RXHYBRIDMESSAGESTATEMENT RXSTMTMESSAGE RXSTMTINDEXEDASSIGN') == 0 then iterate
    end
    if rule~accepts(context) then return rule
  end
  /* (no message rule took it: the keyword rules, as before) */
  if messageClause then
    do rule over self~rules
      if rule~accepts(context) then return rule
    end
  return .nil
